import Foundation

/// Service for communicating with OpenVK backend and OpenVK-IM
@MainActor
public final class OpenVKAPIService: ObservableObject {
    public static let shared = OpenVKAPIService()

    @Published public var serverURL: String = "https://openvk.org"
    @Published public var token: String = ""
    @Published public var currentUser: VKUser?
    @Published public var isAuthenticated: Bool = false
    @Published public var isAuthenticating: Bool = false
    @Published public var lastAuthError: String?
    @Published public var chandlerSessCookie: String? = nil
    public var savedLogin: String? = nil
    public var savedPassword: String? = nil
    public var cachedUsers: [Int: VKUser] = [:]
    public var cachedGroups: [Int: VKGroup] = [:]

    // Track read positions per peer
    public var peerOutRead: [Int: Int] = [:]
    public var peerInRead: [Int: Int] = [:]

    public init() {
        if let savedToken = UserDefaults.standard.string(forKey: "openvk_token"), !savedToken.isEmpty {
            self.token = savedToken
            self.isAuthenticated = true
        }
        if let savedServer = UserDefaults.standard.string(forKey: "openvk_server"), !savedServer.isEmpty {
            if savedServer.contains("openvk.su") {
                self.serverURL = "https://openvk.org"
                UserDefaults.standard.set("https://openvk.org", forKey: "openvk_server")
            } else {
                self.serverURL = savedServer
            }
        } else {
            self.serverURL = "https://openvk.org"
            UserDefaults.standard.set("https://openvk.org", forKey: "openvk_server")
        }

        if let sess = UserDefaults.standard.string(forKey: "openvk_chandlersess"), !sess.isEmpty {
            self.chandlerSessCookie = sess
        }
        self.savedLogin = UserDefaults.standard.string(forKey: "openvk_saved_login")
        self.savedPassword = UserDefaults.standard.string(forKey: "openvk_saved_password")

        if let l = savedLogin, let p = savedPassword, !l.isEmpty, !p.isEmpty {
            Task.detached(priority: .utility) { [weak self] in
                await self?.ensureWebSession(login: l, password: p)
            }
        }

        if isAuthenticated {
            Task {
                try? await self.refreshCurrentUser()
            }
        }
    }

    // MARK: - Authentication Methods

    public func login(login: String, password: String, server: String? = nil) async throws {
        if let s = server, !s.isEmpty {
            self.serverURL = s.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }

        self.isAuthenticating = true
        self.lastAuthError = nil

        defer { self.isAuthenticating = false }

        var base = self.serverURL
        if !base.starts(with: "http://") && !base.starts(with: "https://") {
            base = "https://\(base)"
            self.serverURL = base
        }

        guard var components = URLComponents(string: "\(base)/oauth/token") else {
            throw URLError(.badURL)
        }

        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "password"),
            URLQueryItem(name: "client_id", value: "2274003"),
            URLQueryItem(name: "client_secret", value: "hHbZxrka2uZ6jB1inYsH"),
            URLQueryItem(name: "username", value: login),
            URLQueryItem(name: "password", value: password),
            URLQueryItem(name: "scope", value: "messages,offline,wall,photos,audio")
        ]

        guard let url = components.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("OpenVKMessenger-macOS/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if httpResponse.statusCode != 200 {
            if let errJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let desc = errJson["error_description"] as? String ?? errJson["error"] as? String {
                self.lastAuthError = desc
                throw NSError(domain: "OpenVKAuth", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: desc])
            }
            throw URLError(.userAuthenticationRequired)
        }

        let decoder = JSONDecoder()
        let tokenRes = try decoder.decode(VKTokenResponse.self, from: data)

        self.savedLogin = login
        self.savedPassword = password
        UserDefaults.standard.set(login, forKey: "openvk_saved_login")
        UserDefaults.standard.set(password, forKey: "openvk_saved_password")

        saveCredentials(token: tokenRes.accessToken, server: self.serverURL)
        await ensureWebSession(login: login, password: password)
        try await refreshCurrentUser()
    }

    public func loginWithToken(token: String, server: String? = nil) async throws {
        if let s = server, !s.isEmpty {
            var base = s.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if !base.starts(with: "http://") && !base.starts(with: "https://") {
                base = "https://\(base)"
            }
            self.serverURL = base
        }

        self.isAuthenticating = true
        self.lastAuthError = nil
        defer { self.isAuthenticating = false }

        self.token = token.trimmingCharacters(in: .whitespacesAndNewlines)

        try await refreshCurrentUser()
        saveCredentials(token: self.token, server: self.serverURL)
    }

    public func saveCredentials(token: String, server: String) {
        self.token = token
        self.serverURL = server
        self.isAuthenticated = !token.isEmpty

        UserDefaults.standard.set(token, forKey: "openvk_token")
        UserDefaults.standard.set(server, forKey: "openvk_server")
    }

    public func logout() {
        self.token = ""
        self.isAuthenticated = false
        self.currentUser = nil
        self.chandlerSessCookie = nil
        self.savedLogin = nil
        self.savedPassword = nil
        UserDefaults.standard.removeObject(forKey: "openvk_token")
        UserDefaults.standard.removeObject(forKey: "openvk_chandlersess")
        UserDefaults.standard.removeObject(forKey: "openvk_saved_login")
        UserDefaults.standard.removeObject(forKey: "openvk_saved_password")
    }

    @discardableResult
    public func ensureWebSession(login: String, password: String) async -> Bool {
        var base = self.serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if !base.starts(with: "http://") && !base.starts(with: "https://") {
            base = "https://\(base)"
        }
        guard let loginUrl = URL(string: "\(base)/login") else { return false }

        let delegate = NonRedirectingURLSessionDelegate()
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)

        do {
            // STEP 1: GET /login to obtain initial session cookie and CSRF token
            var getReq = URLRequest(url: loginUrl)
            getReq.httpMethod = "GET"
            getReq.setValue("OpenVKMessenger/1.0", forHTTPHeaderField: "User-Agent")

            let (getData, getResp) = try await session.data(for: getReq)
            guard let getHttp = getResp as? HTTPURLResponse else { return false }

            let initialCookie = parseChandlerSess(from: getHttp, url: loginUrl)
            let getHtml = String(data: getData, encoding: .utf8) ?? ""
            let csrfToken = extractCSRFToken(from: getHtml)

            // STEP 2: POST /login with login, password, and hash
            var postReq = URLRequest(url: loginUrl)
            postReq.httpMethod = "POST"
            postReq.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            postReq.setValue("OpenVKMessenger/1.0", forHTTPHeaderField: "User-Agent")
            if let initSess = initialCookie, !initSess.isEmpty {
                postReq.setValue("CHANDLERSESS=\(initSess)", forHTTPHeaderField: "Cookie")
            }

            var postParams = [
                "login": login,
                "password": password,
                "jReturnTo": "/"
            ]
            if let csrf = csrfToken {
                postParams["hash"] = csrf
            }

            let formBody = postParams.map { k, v in
                let ek = k.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? k
                let ev = v.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? v
                return "\(ek)=\(ev)"
            }.joined(separator: "&")
            postReq.httpBody = formBody.data(using: .utf8)

            let (_, postResp) = try await session.data(for: postReq)
            guard let postHttp = postResp as? HTTPURLResponse else { return false }

            // Check if login was rejected
            let headerFields = postHttp.allHeaderFields
            let userValidated = headerFields["X-Openvk-User-Validated"] as? String
                ?? (headerFields as? [String: String])?["X-Openvk-User-Validated"]
                ?? (headerFields as? [String: String])?["x-openvk-user-validated"]
            if userValidated == "0" {
                print("DEBUG: ensureWebSession failed: X-Openvk-User-Validated is 0 (wrong login/password)")
                return false
            }

            // Extract authenticated CHANDLERSESS cookie
            if let sess = parseChandlerSess(from: postHttp, url: loginUrl), !sess.isEmpty {
                self.chandlerSessCookie = sess
                self.savedLogin = login
                self.savedPassword = password
                UserDefaults.standard.set(sess, forKey: "openvk_chandlersess")
                UserDefaults.standard.set(login, forKey: "openvk_saved_login")
                UserDefaults.standard.set(password, forKey: "openvk_saved_password")
                print("DEBUG: ensureWebSession succeeded! Cookie: \(sess.prefix(15))...")
                return true
            }

            // Fallback: if status is 302 or 200, check if initialCookie is now authenticated
            if (200...302).contains(postHttp.statusCode) && userValidated != "0" {
                if let sess = initialCookie {
                    self.chandlerSessCookie = sess
                    self.savedLogin = login
                    self.savedPassword = password
                    UserDefaults.standard.set(sess, forKey: "openvk_chandlersess")
                    UserDefaults.standard.set(login, forKey: "openvk_saved_login")
                    UserDefaults.standard.set(password, forKey: "openvk_saved_password")
                    print("DEBUG: ensureWebSession succeeded with initial session!")
                    return true
                }
            }
        } catch {
            print("DEBUG: ensureWebSession failed: \(error)")
        }
        return false
    }

    public func extractCSRFToken(from html: String) -> String? {
        // Pattern 1: name="csrf" value="..."
        if let regex = try? NSRegularExpression(pattern: #"name=["']csrf["']\s+value=["']([^"']+)["']"#, options: [.caseInsensitive]) {
            let nsString = html as NSString
            let results = regex.matches(in: html, range: NSRange(location: 0, length: nsString.length))
            if let match = results.first, match.numberOfRanges > 1 {
                let token = nsString.substring(with: match.range(at: 1))
                if !token.isEmpty { return token }
            }
        }
        // Pattern 2: value="..." name="csrf"
        if let regex = try? NSRegularExpression(pattern: #"value=["']([^"']+)["']\s+name=["']csrf["']"#, options: [.caseInsensitive]) {
            let nsString = html as NSString
            let results = regex.matches(in: html, range: NSRange(location: 0, length: nsString.length))
            if let match = results.first, match.numberOfRanges > 1 {
                let token = nsString.substring(with: match.range(at: 1))
                if !token.isEmpty { return token }
            }
        }
        // Pattern 3: name="hash" value="..."
        if let regex = try? NSRegularExpression(pattern: #"name=["']hash["']\s+value=["']([^"']+)["']"#, options: [.caseInsensitive]) {
            let nsString = html as NSString
            let results = regex.matches(in: html, range: NSRange(location: 0, length: nsString.length))
            if let match = results.first, match.numberOfRanges > 1 {
                let token = nsString.substring(with: match.range(at: 1))
                if !token.isEmpty { return token }
            }
        }
        // Pattern 4: Hash token format (e.g. abcd1234...#12345678)
        if let regex = try? NSRegularExpression(pattern: #"[a-f0-9]{32,64}#[a-f0-9]{6,16}"#, options: [.caseInsensitive]) {
            let nsString = html as NSString
            let results = regex.matches(in: html, range: NSRange(location: 0, length: nsString.length))
            if let match = results.first {
                let token = nsString.substring(with: match.range(at: 0))
                if !token.isEmpty { return token }
            }
        }
        return nil
    }

    public func fetchWebCSRFToken() async -> String? {
        var base = self.serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if !base.starts(with: "http://") && !base.starts(with: "https://") {
            base = "https://\(base)"
        }
        guard let docsUrl = URL(string: "\(base)/docs") else { return nil }

        var req = URLRequest(url: docsUrl)
        req.httpMethod = "GET"
        req.setValue("OpenVKMessenger/1.0", forHTTPHeaderField: "User-Agent")
        if let sess = self.chandlerSessCookie ?? UserDefaults.standard.string(forKey: "openvk_chandlersess"), !sess.isEmpty {
            req.setValue("CHANDLERSESS=\(sess)", forHTTPHeaderField: "Cookie")
        }

        let delegate = NonRedirectingURLSessionDelegate()
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)

        do {
            let (data, resp) = try await session.data(for: req)
            if let http = resp as? HTTPURLResponse {
                if http.statusCode == 302, let loc = http.allHeaderFields["Location"] as? String, loc.contains("login") {
                    return nil
                }
            }
            if let html = String(data: data, encoding: .utf8) {
                return extractCSRFToken(from: html)
            }
        } catch {
            print("DEBUG: fetchWebCSRFToken error: \(error)")
        }
        return nil
    }

    private func parseChandlerSess(from response: HTTPURLResponse, url: URL) -> String? {
        if let fields = response.allHeaderFields as? [String: String] {
            let cookies = HTTPCookie.cookies(withResponseHeaderFields: fields, for: url)
            if let c = cookies.first(where: { $0.name == "CHANDLERSESS" }), !c.value.isEmpty {
                return c.value
            }
        }
        for (k, v) in response.allHeaderFields {
            if let keyStr = k as? String, keyStr.lowercased() == "set-cookie", let valStr = v as? String {
                if let sess = parseChandlerSess(from: valStr) {
                    return sess
                }
            }
        }
        if let cookies = HTTPCookieStorage.shared.cookies(for: url) {
            for c in cookies where c.name == "CHANDLERSESS" && !c.value.isEmpty {
                return c.value
            }
        }
        return nil
    }

    private func parseChandlerSess(from setCookie: String) -> String? {
        for part in setCookie.components(separatedBy: ",") {
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            if let range = trimmed.range(of: "CHANDLERSESS=") {
                let after = trimmed[range.upperBound...]
                let val = after.components(separatedBy: ";").first?.trimmingCharacters(in: .whitespacesAndNewlines)
                if let v = val, !v.isEmpty {
                    return v
                }
            }
        }
        return nil
    }

    // MARK: - OpenVK API Caller

    public func callMethod<T: Decodable>(
        method: String,
        params: [String: String] = [:]
    ) async throws -> T {
        var base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if !base.starts(with: "http://") && !base.starts(with: "https://") {
            base = "https://\(base)"
        }

        guard var components = URLComponents(string: "\(base)/method/\(method)") else {
            throw URLError(.badURL)
        }

        var queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        queryItems.append(URLQueryItem(name: "access_token", value: token))
        queryItems.append(URLQueryItem(name: "v", value: "5.131"))
        components.queryItems = queryItems

        guard let url = components.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("OpenVKMessenger-macOS/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        do {
            let decoder = JSONDecoder()
            let result = try decoder.decode(VKAPIResponse<T>.self, from: data)

            if let error = result.error {
                throw error
            }

            guard let payload = result.response else {
                throw URLError(.cannotParseResponse)
            }

            return payload
        } catch {
            if let str = String(data: data, encoding: .utf8) {
                print("DEBUG: API Method '\(method)' decoding error: \(error). Data snippet: \(str.prefix(300))")
            }
            throw error
        }
    }

    // MARK: - Profile & Conversations Loading

    public func refreshCurrentUser() async throws {
        let users: [VKUser] = try await callMethod(
            method: "users.get",
            params: ["fields": "photo_100,photo_200,verified,online"]
        )
        if let first = users.first {
            self.currentUser = first
            self.isAuthenticated = true
            self.cachedUsers[first.id] = first
        }
    }

    public func getUsers(ids: [Int]) async throws -> [VKUser] {
        guard !ids.isEmpty else { return [] }
        let idsStr = ids.map(String.init).joined(separator: ",")
        let users: [VKUser] = try await callMethod(
            method: "users.get",
            params: [
                "user_ids": idsStr,
                "fields": "photo_100,photo_200,verified,online,online_mobile,last_seen,sex"
            ]
        )
        for u in users {
            self.cachedUsers[u.id] = u
        }
        return users
    }

    public func getFriends(count: Int = 100, offset: Int = 0) async throws -> [VKUser] {
        let resp: VKUsersListResponse = try await callMethod(
            method: "friends.get",
            params: [
                "order": "hints",
                "fields": "photo_100,photo_200,verified,online,online_mobile,last_seen,sex",
                "count": "\(count)",
                "offset": "\(offset)"
            ]
        )
        for u in resp.items {
            self.cachedUsers[u.id] = u
        }
        return resp.items
    }

    public func searchUsers(query: String, count: Int = 30) async throws -> [VKUser] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        let resp: VKUsersListResponse = try await callMethod(
            method: "users.search",
            params: [
                "q": query,
                "fields": "photo_100,photo_200,verified,online,online_mobile,last_seen,sex",
                "count": "\(count)"
            ]
        )
        for u in resp.items {
            self.cachedUsers[u.id] = u
        }
        return resp.items
    }

    public func createChat(userIds: [Int], title: String) async throws -> Int {
        let idsStr = userIds.map(String.init).joined(separator: ",")
        struct CreateChatResponse: Decodable {
            let chatId: Int
            enum CodingKeys: String, CodingKey {
                case chatId = "chat_id"
            }
            init(from decoder: Decoder) throws {
                if let container = try? decoder.container(keyedBy: CodingKeys.self),
                   let id = try? container.decode(Int.self, forKey: .chatId) {
                    self.chatId = id
                } else if let intVal = try? decoder.singleValueContainer().decode(Int.self) {
                    self.chatId = intVal
                } else {
                    self.chatId = 0
                }
            }
        }
        let resp: CreateChatResponse = try await callMethod(
            method: "messages.createChat",
            params: [
                "user_ids": idsStr,
                "title": title
            ]
        )
        return resp.chatId > 0 ? (2_000_000_000 + resp.chatId) : 0
    }


    public func setActivity(peerId: Int, type: String = "typing") async {
        do {
            let _: VKIntOrBool = try await callMethod(method: "messages.setActivity", params: [
                "peer_id": "\(peerId)",
                "type": type
            ])
        } catch {
            // Silently ignore activity status failure
        }
    }

    // MARK: - Sticker Packs

    public func getStickerPacks() async -> [VKStickerPack] {
        let base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        if isAuthenticated {
            do {
                let raw: VKRawStickersResponse = try await callMethod(method: "stickers.get", params: ["count": "50"])
                if let items = raw.items, !items.isEmpty {
                    let parsed = parseStickerPacks(items, base: base)
                    if !parsed.isEmpty {
                        return parsed
                    }
                }
            } catch {
                do {
                    let raw: VKRawStickersResponse = try await callMethod(method: "stickers.getAll", params: ["count": "50"])
                    if let items = raw.items, !items.isEmpty {
                        let parsed = parseStickerPacks(items, base: base)
                        if !parsed.isEmpty {
                            return parsed
                        }
                    }
                } catch {
                    // Fallback to defaults
                }
            }
        }

        return defaultStickerPacks(base: base)
    }

    private func parseStickerPacks(_ items: [VKRawStickerPackItem], base: String) -> [VKStickerPack] {
        var packs: [VKStickerPack] = []
        for item in items {
            let pid = item.id ?? 1
            let title = item.title ?? item.name ?? "Стикеры"
            var iconUrl: URL? = nil
            if let p = item.photo ?? item.photo70 ?? item.photo140 ?? item.photo35 {
                iconUrl = URL(string: p.starts(with: "http") ? p : "\(base)/\(p.trimmingCharacters(in: CharacterSet(charactersIn: "/")))")
            }

            var stickers: [VKStickerItem] = []
            for stk in item.stickers ?? [] {
                let sid = stk.effectiveId
                guard sid > 0 else { continue }
                var sUrl: URL? = nil
                if let uStr = stk.photo256 ?? stk.photo128 ?? stk.photo512 ?? stk.images?.last?.bestUrlString {
                    sUrl = URL(string: uStr.starts(with: "http") ? uStr : "\(base)/\(uStr.trimmingCharacters(in: CharacterSet(charactersIn: "/")))")
                }
                var animUrl: URL? = nil
                if let aStr = stk.animationUrl {
                    animUrl = URL(string: aStr.starts(with: "http") ? aStr : "\(base)/\(aStr.trimmingCharacters(in: CharacterSet(charactersIn: "/")))")
                }
                stickers.append(VKStickerItem(id: sid, packId: pid, url: sUrl, animationURL: animUrl))
            }

            if !stickers.isEmpty {
                if iconUrl == nil {
                    iconUrl = stickers.first?.url
                }
                packs.append(VKStickerPack(id: pid, title: title, iconURL: iconUrl, stickers: stickers))
            }
        }
        return packs
    }

    public func defaultStickerPacks(base: String) -> [VKStickerPack] {
        let persikStickers = (1...32).map { id in
            let url = URL(string: "\(base)/images/stickers/\(id)/256b.png") ?? URL(string: "\(base)/sticker/1-\(id)-256.png") ?? URL(string: "https://vk.com/sticker/1-\(id)-256.png")
            return VKStickerItem(id: id, packId: 1, url: url)
        }
        let persikIcon = URL(string: "https://vk.com/sticker/1-1-128.png")

        let spottyStickers = (49...80).map { id in
            let url = URL(string: "\(base)/images/stickers/\(id)/256b.png") ?? URL(string: "\(base)/sticker/1-\(id)-256.png") ?? URL(string: "https://vk.com/sticker/1-\(id)-256.png")
            return VKStickerItem(id: id, packId: 2, url: url)
        }
        let spottyIcon = URL(string: "https://vk.com/sticker/1-49-128.png")

        let senyaStickers = (81...112).map { id in
            let url = URL(string: "\(base)/images/stickers/\(id)/256b.png") ?? URL(string: "\(base)/sticker/1-\(id)-256.png") ?? URL(string: "https://vk.com/sticker/1-\(id)-256.png")
            return VKStickerItem(id: id, packId: 3, url: url)
        }
        let senyaIcon = URL(string: "https://vk.com/sticker/1-81-128.png")

        return [
            VKStickerPack(id: 1, title: "Персик", iconURL: persikIcon, stickers: persikStickers),
            VKStickerPack(id: 2, title: "Спотти", iconURL: spottyIcon, stickers: spottyStickers),
            VKStickerPack(id: 3, title: "Сеня", iconURL: senyaIcon, stickers: senyaStickers),
        ]
    }

    public func getConversations(
        filter: String = "all",
        offset: Int = 0,
        count: Int = 50,
        groupId: Int? = nil
    ) async throws -> (conversations: [VKConversation], unreadCount: Int) {
        var params: [String: String] = [
            "offset": "\(offset)",
            "count": "\(count)",
            "filter": filter,
            "extended": "1",
            "fields": "photo_100,photo_200,verified,online,online_mobile,last_seen,sex"
        ]
        if let gId = groupId {
            params["group_id"] = "\(gId)"
        }

        let raw: VKRawConversationsResponse = try await callMethod(
            method: "messages.getConversations",
            params: params
        )

        for p in raw.profiles ?? [] {
            self.cachedUsers[p.id] = p
        }
        for g in raw.groups ?? [] {
            self.cachedGroups[g.id] = g
            self.cachedUsers[-g.id] = VKUser(
                id: -g.id,
                firstName: g.name,
                lastName: "",
                photo100: g.photo100,
                photo200: g.photo200
            )
        }

        // Pre-fetch any missing sender user IDs for lastMessage in group chats
        var missingUserIds = Set<Int>()
        for item in raw.items {
            if let fId = item.lastMessage?.fromId, fId > 0, self.cachedUsers[fId] == nil {
                missingUserIds.insert(fId)
            }
        }
        if !missingUserIds.isEmpty {
            _ = try? await self.getUsers(ids: Array(missingUserIds))
        }

        let profilesMap: [Int: VKUser] = self.cachedUsers
        let groupsMap: [Int: VKGroup] = Dictionary(uniqueKeysWithValues: (raw.groups ?? []).map { ($0.id, $0) })

        var result: [VKConversation] = []

        for item in raw.items {
            let peerId = item.conversation.peer.id
            if let outRead = item.conversation.outRead {
                self.peerOutRead[peerId] = max(self.peerOutRead[peerId] ?? 0, outRead)
            }
            if let inRead = item.conversation.inRead {
                self.peerInRead[peerId] = max(self.peerInRead[peerId] ?? 0, inRead)
            }

            var title = "Диалог"
            var avatarURL: URL? = nil
            var isOnline = false
            var isMobile = false
            var isVerified = false
            var isChat = false
            var membersCount: Int? = nil
            var lastSeen: VKLastSeen? = nil
            var sex: Int? = nil

            let isSaved = (self.currentUser?.id != nil && peerId == self.currentUser!.id) || title == "Избранное"
            if isSaved {
                title = "Избранное"
            } else if peerId > 2_000_000_000 {
                isChat = true
                title = item.conversation.chatSettings?.title ?? "Беседа"
                membersCount = item.conversation.chatSettings?.membersCount
                if let p200 = item.conversation.chatSettings?.photo?.photo200 ?? item.conversation.chatSettings?.photo?.photo100 {
                    avatarURL = URL(string: p200)
                }
            } else if peerId < 0 {
                let groupId = abs(peerId)
                if let group = groupsMap[groupId] {
                    title = group.name
                    avatarURL = group.avatarURL
                }
            } else if let user = profilesMap[peerId] ?? self.cachedUsers[peerId] {
                title = user.fullName
                avatarURL = user.avatarURL
                isOnline = user.isOnline
                isMobile = user.isMobileOnline
                isVerified = user.isVerified
                lastSeen = user.lastSeen
                sex = user.sex
            }

            var lastMsg: VKMessage? = nil
            if let rawMsg = item.lastMessage {
                lastMsg = self.mapRawMessage(rawMsg, profilesMap: profilesMap, defaultPeerId: peerId)
            }

            var pinnedMsg: VKMessage? = nil
            if let rawPinned = item.conversation.effectivePinnedMessage {
                pinnedMsg = self.mapRawMessage(rawPinned, profilesMap: profilesMap, defaultPeerId: peerId)
            }

            let conv = VKConversation(
                peerId: peerId,
                title: title,
                avatarURL: avatarURL,
                unreadCount: item.conversation.unreadCount ?? 0,
                lastMessage: lastMsg,
                isOnline: isOnline,
                isMobile: isMobile,
                isVerified: isVerified,
                isChat: isChat,
                membersCount: membersCount,
                isSavedMessages: isSaved,
                lastSeen: lastSeen,
                sex: sex,
                pinnedMessage: pinnedMsg
            )

            result.append(conv)
        }

        return (result, raw.unreadCount ?? 0)
    }

    public func getHistory(
        peerId: Int,
        offset: Int = 0,
        count: Int = 60
    ) async throws -> [VKMessage] {
        let raw: VKRawHistoryResponse = try await callMethod(
            method: "messages.getHistory",
            params: [
                "peer_id": "\(peerId)",
                "offset": "\(offset)",
                "count": "\(count)",
                "extended": "1",
                "fields": "photo_100,photo_200,verified"
            ]
        )

        for p in raw.profiles ?? [] {
            self.cachedUsers[p.id] = p
        }
        for g in raw.groups ?? [] {
            self.cachedGroups[g.id] = g
            self.cachedUsers[-g.id] = VKUser(
                id: -g.id,
                firstName: g.name,
                lastName: "",
                photo100: g.photo100,
                photo200: g.photo200
            )
        }
        var profilesMap: [Int: VKUser] = Dictionary(uniqueKeysWithValues: (raw.profiles ?? []).map { ($0.id, $0) })
        for g in raw.groups ?? [] {
            profilesMap[-g.id] = VKUser(
                id: -g.id,
                firstName: g.name,
                lastName: "",
                photo100: g.photo100,
                photo200: g.photo200
            )
        }

        if let convs = raw.conversations {
            for c in convs {
                let pid = c.peer.id
                if let outRead = c.outRead {
                    self.peerOutRead[pid] = max(self.peerOutRead[pid] ?? 0, outRead)
                }
                if let inRead = c.inRead {
                    self.peerInRead[pid] = max(self.peerInRead[pid] ?? 0, inRead)
                }
            }
        }

        var list: [VKMessage] = []
        for rawMsg in raw.items {
            let msg = self.mapRawMessage(rawMsg, profilesMap: profilesMap, defaultPeerId: peerId)
            list.append(msg)
        }
        // Always sort chronologically: oldest to newest
        list.sort {
            if $0.date == $1.date {
                return $0.id < $1.id
            }
            return $0.date < $1.date
        }
        return list
    }

    public func markAsRead(peerId: Int, startMessageId: Int? = nil) async {
        var params: [String: String] = [
            "peer_id": "\(peerId)",
            "mark_conversation": "1"
        ]
        if let mid = startMessageId, mid > 0 {
            params["start_message_id"] = "\(mid)"
        }
        do {
            let res: VKIntOrBool = try await callMethod(method: "messages.markAsRead", params: params)
            print("DEBUG: markAsRead succeeded for peer \(peerId), res=\(res.value)")
        } catch {
            print("DEBUG: markAsRead error for peer \(peerId): \(error)")
        }
    }


    public func pinMessage(peerId: Int, messageId: Int) async throws -> VKMessage {
        struct PinResponse: Decodable {
            let response: VKRawMessageData
        }
        let res: PinResponse = try await callMethod(method: "messages.pin", params: [
            "peer_id": "\(peerId)",
            "message_id": "\(messageId)"
        ])
        return self.mapRawMessage(res.response, profilesMap: self.cachedUsers, defaultPeerId: peerId)
    }

    public func unpinMessage(peerId: Int) async throws {
        struct UnpinResponse: Decodable {
            let response: Int
        }
        let _: UnpinResponse = try await callMethod(method: "messages.unpin", params: [
            "peer_id": "\(peerId)"
        ])
    }

    public func deleteMessage(messageId: Int, forAll: Bool = true) async throws {
        struct DeleteResponse: Decodable {
            let response: [String: Int]?
        }
        let _: DeleteResponse? = try? await callMethod(method: "messages.delete", params: [
            "message_ids": "\(messageId)",
            "delete_for_all": forAll ? "1" : "0"
        ])
    }

    public func editMessage(peerId: Int, messageId: Int, message: String) async throws {
        struct EditResponse: Decodable {
            let response: Int?
        }
        let _: EditResponse? = try? await callMethod(method: "messages.edit", params: [
            "peer_id": "\(peerId)",
            "message_id": "\(messageId)",
            "message": message,
            "keep_forward_messages": "1",
            "keep_snippets": "1"
        ])
    }

    // MARK: - Raw Message Mapping Helper

    public func mapRawMessage(_ rawMsg: VKRawMessageData, profilesMap: [Int: VKUser], defaultPeerId: Int = 0) -> VKMessage {
        let isOut = (rawMsg.out ?? 0) == 1
        var senderUser = isOut ? self.currentUser : (profilesMap[rawMsg.fromId] ?? self.cachedUsers[rawMsg.fromId])
        if senderUser == nil && rawMsg.fromId < 0 {
            let gid = abs(rawMsg.fromId)
            if let g = self.cachedGroups[gid] {
                let u = VKUser(
                    id: rawMsg.fromId,
                    firstName: g.name,
                    lastName: "",
                    photo100: g.photo100,
                    photo200: g.photo200
                )
                self.cachedUsers[rawMsg.fromId] = u
                senderUser = u
            }
        }

        let effectivePeerId = (rawMsg.peerId ?? 0) != 0 ? (rawMsg.peerId ?? defaultPeerId) : defaultPeerId

        var sticker: VKSticker? = nil
        var photo: VKPhotoAttachment? = nil
        var photosList: [VKPhotoAttachment] = []
        var voiceMessage: VKVoiceAttachment? = nil
        var doc: VKDocAttachment? = nil
        var audioAttachment: VKAudioAttachment? = nil
        var videoAttachment: VKVideoAttachment? = nil
        var giftAttachment: VKGiftAttachment? = nil
        var moneyTransferAttachment: VKMoneyTransferAttachment? = nil
        var wallPost: VKWallPost? = nil
        var action: VKMessageAction? = nil

        if let rawAct = rawMsg.action {
            var memberName: String? = nil
            if let mid = rawAct.memberId, let mUser = profilesMap[mid] ?? self.cachedUsers[mid] {
                memberName = mUser.fullName
            }
            action = VKMessageAction(
                type: rawAct.type,
                memberId: rawAct.memberId,
                memberName: memberName,
                text: rawAct.text
            )
        }

        if let rawAttachments = rawMsg.attachments {
            for att in rawAttachments {
                switch att.type {
                case "sticker":
                    if let s = att.sticker {
                        let sid = s.stickerId ?? rawMsg.id
                        var bestUrl = s.images?.max(by: { ($0.width ?? 0) < ($1.width ?? 0) })?.bestUrlString
                        if bestUrl == nil {
                            bestUrl = s.imagesWithBackground?.max(by: { ($0.width ?? 0) < ($1.width ?? 0) })?.bestUrlString
                        }
                        let base = self.serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                        if bestUrl == nil {
                            bestUrl = "\(base)/sticker/1-\(sid)-256.png"
                        }
                        let u = URL(string: bestUrl ?? "") ?? URL(string: "https://vk.com/sticker/1-\(sid)-256.png")
                        var animUrl: URL? = nil
                        if let aStr = s.animationUrl {
                            animUrl = URL(string: aStr.starts(with: "http") ? aStr : "\(base)/\(aStr.trimmingCharacters(in: CharacterSet(charactersIn: "/")))")
                        }
                        sticker = VKSticker(id: sid, productId: s.productId, url: u, animationURL: animUrl)
                    }

                case "photo":
                    if let p = att.photo {
                        let bestSize = p.sizes?.last ?? p.sizes?.first
                        let bestUrl = bestSize?.bestUrlString ?? p.bestUrlString
                        var photoUrl: URL? = nil
                        if var uStr = bestUrl, !uStr.isEmpty {
                            if !uStr.starts(with: "http://") && !uStr.starts(with: "https://") {
                                let base = self.serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                                uStr = "\(base)/\(uStr.trimmingCharacters(in: CharacterSet(charactersIn: "/")))"
                            }
                            photoUrl = URL(string: uStr)
                        }
                        if let u = photoUrl {
                            let attPhoto = VKPhotoAttachment(
                                id: p.id ?? rawMsg.id,
                                url: u,
                                text: p.text ?? "",
                                width: bestSize?.width,
                                height: bestSize?.height
                            )
                            photosList.append(attPhoto)
                            if photo == nil {
                                photo = attPhoto
                            }
                        }
                    }
                case "audio_message":
                    if let a = att.audioMessage {
                        let audioUrl = a.linkMp3 != nil ? URL(string: a.linkMp3!) : (a.linkOgg != nil ? URL(string: a.linkOgg!) : nil)
                        voiceMessage = VKVoiceAttachment(
                            id: "\(rawMsg.id)",
                            duration: a.duration ?? 0,
                            audioURL: audioUrl
                        )
                    }
                case "doc":
                    if let d = att.doc {
                        var docUrl: URL? = nil
                        if let uStr = d.url, !uStr.isEmpty {
                            if uStr.starts(with: "http://") || uStr.starts(with: "https://") {
                                docUrl = URL(string: uStr)
                            } else {
                                let base = self.serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                                docUrl = URL(string: "\(base)/\(uStr.trimmingCharacters(in: CharacterSet(charactersIn: "/")))")
                            }
                        }
                        if docUrl == nil, let did = d.id {
                            let oid = d.ownerId ?? rawMsg.fromId
                            let base = self.serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                            if let key = d.accessKey, !key.isEmpty {
                                docUrl = URL(string: "\(base)/doc\(oid)_\(did)?key=\(key)")
                            } else {
                                docUrl = URL(string: "\(base)/doc\(oid)_\(did)")
                            }
                        }
                        doc = VKDocAttachment(
                            id: d.id ?? rawMsg.id,
                            title: d.title ?? "Документ",
                            size: d.size ?? 0,
                            ext: d.ext ?? "",
                            url: docUrl
                        )
                    }
                case "audio":
                    if let a = att.audio {
                        audioAttachment = VKAudioAttachment(
                            id: a.id ?? rawMsg.id,
                            ownerId: a.ownerId ?? 0,
                            artist: a.artist ?? "Исполнитель",
                            title: a.title ?? "Аудиозапись",
                            duration: a.duration ?? 0,
                            url: a.url != nil ? URL(string: a.url!) : nil
                        )
                    }
                case "video":
                    if let v = att.video {
                        let base = self.serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                        var thumb: URL? = nil
                        if let uStr = v.photo800 ?? v.photo320 ?? v.image?.last?.bestUrlString {
                            thumb = URL(string: uStr.starts(with: "http") ? uStr : "\(base)/\(uStr.trimmingCharacters(in: CharacterSet(charactersIn: "/")))")
                        }
                        var pUrl: URL? = nil
                        if let ps = v.player, !ps.isEmpty {
                            pUrl = URL(string: ps.starts(with: "http") ? ps : "\(base)/\(ps.trimmingCharacters(in: CharacterSet(charactersIn: "/")))")
                        }
                        var directUrl: URL? = nil
                        if let files = v.files {
                            for key in ["mp4_1080", "1080", "mp4_720", "720", "mp4_480", "480", "mp4_360", "360", "mp4_240", "240", "external"] {
                                if let val = files[key], let u = URL(string: val.starts(with: "http") ? val : "\(base)/\(val.trimmingCharacters(in: CharacterSet(charactersIn: "/")))") {
                                    directUrl = u
                                    break
                                }
                            }
                        }
                        videoAttachment = VKVideoAttachment(
                            id: v.id ?? rawMsg.id,
                            ownerId: v.ownerId ?? 0,
                            title: v.title ?? "Видеозапись",
                            duration: v.duration ?? 0,
                            imageURL: thumb,
                            playerURL: pUrl,
                            directVideoURL: directUrl,
                            accessKey: v.accessKey
                        )
                    }
                case "wall", "wall_reply":
                    if let w = att.wall {
                        let wid = w.id ?? rawMsg.id
                        let wDate = w.date != nil ? Date(timeIntervalSince1970: w.date!) : Date(timeIntervalSince1970: Double(rawMsg.date))
                        let wText = w.text ?? ""

                        let fromUid = w.fromId ?? w.ownerId ?? 0
                        let authorUser = profilesMap[fromUid] ?? cachedUsers[fromUid]
                        let authorName = (w.authorName?.isEmpty == false) ? w.authorName! : (authorUser?.fullName ?? "Пользователь")

                        var authorAvatarUrl: URL? = nil
                        if let avStr = w.authorAvatar, !avStr.isEmpty {
                            authorAvatarUrl = URL(string: avStr)
                        } else if let uAv = authorUser?.avatarURL {
                            authorAvatarUrl = uAv
                        }

                        var postPhotos: [VKPhotoAttachment] = []
                        var postAudios: [VKAudioAttachment] = []
                        var postVideos: [VKVideoAttachment] = []
                        var postDocs: [VKDocAttachment] = []

                        if let wAtts = w.attachments {
                            for wa in wAtts {
                                if let p = wa.photo {
                                    let bestSize = p.sizes?.last ?? p.sizes?.first
                                    let best = bestSize?.bestUrlString ?? p.bestUrlString
                                    if let best = best, let u = URL(string: best) {
                                        postPhotos.append(VKPhotoAttachment(
                                            id: p.id ?? rawMsg.id,
                                            url: u,
                                            text: p.text ?? "",
                                            width: bestSize?.width,
                                            height: bestSize?.height
                                        ))
                                    }
                                } else if let a = wa.audio {
                                    postAudios.append(VKAudioAttachment(
                                        id: a.id ?? rawMsg.id,
                                        ownerId: a.ownerId ?? 0,
                                        artist: a.artist ?? "Исполнитель",
                                        title: a.title ?? "Аудиозапись",
                                        duration: a.duration ?? 0,
                                        url: a.url != nil ? URL(string: a.url!) : nil
                                    ))
                                } else if let d = wa.doc {
                                    var docUrl: URL? = nil
                                    if let uStr = d.url, !uStr.isEmpty {
                                        if uStr.starts(with: "http://") || uStr.starts(with: "https://") {
                                            docUrl = URL(string: uStr)
                                        } else {
                                            let base = self.serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                                            docUrl = URL(string: "\(base)/\(uStr.trimmingCharacters(in: CharacterSet(charactersIn: "/")))")
                                        }
                                    }
                                    postDocs.append(VKDocAttachment(
                                        id: d.id ?? rawMsg.id,
                                        title: d.title ?? "Документ",
                                        size: d.size ?? 0,
                                        ext: d.ext ?? "",
                                        url: docUrl
                                    ))
                                } else if let v = wa.video {
                                    let base = self.serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                                    var thumb: URL? = nil
                                    if let uStr = v.photo800 ?? v.photo320 ?? v.image?.last?.bestUrlString {
                                        thumb = URL(string: uStr.starts(with: "http") ? uStr : "\(base)/\(uStr.trimmingCharacters(in: CharacterSet(charactersIn: "/")))")
                                    }
                                    postVideos.append(VKVideoAttachment(
                                        id: v.id ?? rawMsg.id,
                                        ownerId: v.ownerId ?? 0,
                                        title: v.title ?? "Видеозапись",
                                        duration: v.duration ?? 0,
                                        imageURL: thumb
                                    ))
                                }
                            }
                        }

                        wallPost = VKWallPost(
                            id: wid,
                            authorName: authorName,
                            authorPhoto: authorAvatarUrl,
                            date: wDate,
                            text: wText,
                            imageURL: postPhotos.first?.url,
                            photos: postPhotos,
                            audios: postAudios,
                            videos: postVideos,
                            docs: postDocs
                        )
                    }
                case "gift":
                    if let g = att.gift {
                        let gid = g.id ?? rawMsg.id
                        let thumb = g.thumb256 ?? g.thumb96 ?? g.thumb48
                        let u = thumb != nil ? URL(string: thumb!) : nil
                        giftAttachment = VKGiftAttachment(id: gid, thumbURL: u)
                    }
                case "money_transfer", "transfer", "money_request":
                    if let m = att.moneyTransfer {
                        let mid = m.id ?? rawMsg.id
                        let commentText = (m.text?.isEmpty == false ? m.text! : rawMsg.text)
                        moneyTransferAttachment = VKMoneyTransferAttachment(
                            id: mid,
                            fromId: m.fromId ?? rawMsg.fromId,
                            toId: m.toId ?? 0,
                            amount: m.amount ?? 0,
                            currency: m.currency ?? "голосов",
                            text: commentText
                        )
                    }
                default:
                    if giftAttachment == nil, let g = att.gift {
                        let gid = g.id ?? rawMsg.id
                        let thumb = g.thumb256 ?? g.thumb96 ?? g.thumb48
                        let u = thumb != nil ? URL(string: thumb!) : nil
                        giftAttachment = VKGiftAttachment(id: gid, thumbURL: u)
                    }
                    if moneyTransferAttachment == nil, let m = att.moneyTransfer {
                        let mid = m.id ?? rawMsg.id
                        let commentText = (m.text?.isEmpty == false ? m.text! : rawMsg.text)
                        moneyTransferAttachment = VKMoneyTransferAttachment(
                            id: mid,
                            fromId: m.fromId ?? rawMsg.fromId,
                            toId: m.toId ?? 0,
                            amount: m.amount ?? 0,
                            currency: m.currency ?? "голосов",
                            text: commentText
                        )
                    }
                    break
                }
            }
        }

        // Fallback: detect vote / money transfer from text or action if not in attachments
        if moneyTransferAttachment == nil {
            let lowerText = rawMsg.text.lowercased()
            if lowerText.contains("передал вам") || lowerText.contains("передала вам") || lowerText.contains("передал(а) вам") || (lowerText.contains("голос") && (lowerText.contains("перевод") || lowerText.contains("передал"))) {
                let digits = rawMsg.text.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
                let parsedAmount = digits.first.flatMap { Int($0) } ?? 0
                moneyTransferAttachment = VKMoneyTransferAttachment(
                    id: rawMsg.id,
                    fromId: rawMsg.fromId,
                    toId: 0,
                    amount: parsedAmount,
                    currency: "голосов",
                    text: rawMsg.text
                )
            }
        }

        var replyObj: VKReplyMessage? = nil
        if let rm = rawMsg.replyMessage {
            let rUser = profilesMap[rm.fromId] ?? cachedUsers[rm.fromId]
            let rName = rUser?.fullName ?? "Пользователь"
            let rAvatar = rUser?.photoURL
            let rDate = rm.date != nil ? Date(timeIntervalSince1970: rm.date!) : nil

            var rPhotoUrl: URL? = nil
            var rHasPhoto = false
            if let atts = rm.attachments {
                for att in atts {
                    if let p = att.photo {
                        rHasPhoto = true
                        if let uStr = p.photo130 ?? p.photo75 ?? p.bestUrlString, let u = URL(string: uStr) {
                            rPhotoUrl = u
                        }
                        break
                    }
                }
            }

            replyObj = VKReplyMessage(
                id: rm.id,
                fromId: rm.fromId,
                senderName: rName,
                senderAvatarURL: rAvatar,
                date: rDate,
                text: rm.text,
                photoURL: rPhotoUrl,
                hasPhoto: rHasPhoto
            )
        }

        var isMsgRead = false
        if let rs = rawMsg.readState {
            isMsgRead = (rs == 1)
        } else if isOut {
            let outRead = self.peerOutRead[effectivePeerId] ?? 0
            isMsgRead = outRead > 0 && rawMsg.id <= outRead
        } else {
            let inRead = self.peerInRead[effectivePeerId] ?? 0
            isMsgRead = inRead > 0 && rawMsg.id <= inRead
        }

        return VKMessage(
            id: rawMsg.id,
            peerId: effectivePeerId,
            fromId: rawMsg.fromId,
            date: Date(timeIntervalSince1970: rawMsg.date),
            text: rawMsg.text.replacingOccurrences(of: "&#8203;", with: ""),
            out: isOut,
            isRead: isMsgRead,
            sticker: sticker,
            photo: photo,
            photos: photosList,
            voiceMessage: voiceMessage,
            doc: doc,
            wallPost: wallPost,
            audio: audioAttachment,
            video: videoAttachment,
            gift: giftAttachment,
            moneyTransfer: moneyTransferAttachment,
            action: action,
            sender: senderUser,
            replyMessage: replyObj,
            isPinned: (rawMsg.isPinned ?? 0) == 1
        )
    }

    // MARK: - OpenVK-IM Long Poll Setup

    public func getLongPollServer() async throws -> LongPollServerResponse {
        let isHttp = serverURL.starts(with: "http://")
        let res: LongPollServerResponse = try await callMethod(method: "messages.getLongPollServer", params: [
            "need_pts": "1",
            "lp_version": "3",
            "ssl": isHttp ? "0" : "1"
        ])
        return res
    }

    // MARK: - Conversation Members & Settings

    public func getConversationMembers(peerId: Int) async throws -> VKChatDetails {
        let raw: VKRawConversationMembersResponse = try await callMethod(
            method: "messages.getConversationMembers",
            params: [
                "peer_id": "\(peerId)",
                "extended": "1",
                "fields": "photo_100,photo_200,verified,online,online_mobile"
            ]
        )

        for p in raw.profiles ?? [] {
            self.cachedUsers[p.id] = p
        }
        let profilesMap: [Int: VKUser] = self.cachedUsers

        var members: [VKChatMember] = []
        for item in raw.items ?? [] {
            let mid = item.memberId ?? 0
            guard mid > 0 else { continue }
            let user = profilesMap[mid] ?? self.cachedUsers[mid]
            let joinDate = item.joinDate != nil ? Date(timeIntervalSince1970: Double(item.joinDate!)) : nil
            members.append(VKChatMember(
                id: mid,
                isAdmin: item.isAdmin == true,
                isOwner: item.isOwner == true,
                joinDate: joinDate,
                user: user
            ))
        }

        // Sort: owner first, then admins, then by name
        members.sort {
            if $0.isOwner != $1.isOwner { return $0.isOwner }
            if $0.isAdmin != $1.isAdmin { return $0.isAdmin }
            return ($0.user?.fullName ?? "") < ($1.user?.fullName ?? "")
        }

        let title = raw.chatSettings?.title ?? "Беседа"
        let count = raw.count ?? members.count
        var photoUrl: URL? = nil
        if let pStr = raw.chatSettings?.photo?.photo200 ?? raw.chatSettings?.photo?.photo100 {
            photoUrl = URL(string: pStr)
        }

        return VKChatDetails(
            title: title,
            membersCount: count,
            ownerId: raw.chatSettings?.effectiveOwnerId,
            photoURL: photoUrl,
            members: members
        )
    }

    // MARK: - Instance Media (Photos, Music, Videos)

    public func getUserMedia(type: VKInstanceMediaType, count: Int = 40) async throws -> [VKInstanceMediaItem] {
        guard let myId = currentUser?.id else { return [] }
        let base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        switch type {
        case .photos:
            var photos: [VKRawPhoto] = []
            do {
                let res: VKRawPhotosListResponse = try await callMethod(
                    method: "photos.getAll",
                    params: [
                        "owner_id": "\(myId)",
                        "count": "\(count)",
                        "extended": "1"
                    ]
                )
                photos = res.items ?? []
            } catch {
                let res: VKRawPhotosListResponse = try await callMethod(
                    method: "photos.get",
                    params: [
                        "owner_id": "\(myId)",
                        "album_id": "profile",
                        "count": "\(count)"
                    ]
                )
                photos = res.items ?? []
            }

            return photos.compactMap { p in
                guard let pid = p.id, let oid = p.ownerId ?? currentUser?.id else { return nil }
                var thumbUrl: URL? = nil
                if let uStr = p.bestUrlString {
                    thumbUrl = URL(string: uStr.starts(with: "http") ? uStr : "\(base)/\(uStr.trimmingCharacters(in: CharacterSet(charactersIn: "/")))")
                }
                let title = p.text?.isEmpty == false ? (p.text ?? "") : "Фотография #\(pid)"
                let code = (p.accessKey != nil && !p.accessKey!.isEmpty) ? "photo\(oid)_\(pid)_\(p.accessKey!)" : "photo\(oid)_\(pid)"
                return VKInstanceMediaItem(
                    id: "photo\(oid)_\(pid)",
                    type: .photos,
                    title: title,
                    subtitle: "Фотоальбом",
                    thumbnailURL: thumbUrl,
                    attachmentCode: code
                )
            }

        case .audio:
            let res: VKRawAudioListResponse = try await callMethod(
                method: "audio.get",
                params: [
                    "owner_id": "\(myId)",
                    "count": "\(count)"
                ]
            )
            return (res.items ?? []).compactMap { a in
                guard let aid = a.id, let oid = a.ownerId ?? currentUser?.id else { return nil }
                let artist = a.artist ?? "Исполнитель"
                let title = a.title ?? "Трек"
                let mins = (a.duration ?? 0) / 60
                let secs = (a.duration ?? 0) % 60
                let timeStr = String(format: "%d:%02d", mins, secs)
                return VKInstanceMediaItem(
                    id: "audio\(oid)_\(aid)",
                    type: .audio,
                    title: title,
                    subtitle: "\(artist) • \(timeStr)",
                    thumbnailURL: nil,
                    attachmentCode: "audio\(oid)_\(aid)"
                )
            }

        case .video:
            let res: VKRawVideoListResponse = try await callMethod(
                method: "video.get",
                params: [
                    "owner_id": "\(myId)",
                    "count": "\(count)"
                ]
            )
            return (res.items ?? []).compactMap { v in
                guard let vid = v.id, let oid = v.ownerId ?? currentUser?.id else { return nil }
                var thumbUrl: URL? = nil
                if let uStr = v.photo320 ?? v.image?.last?.bestUrlString {
                    thumbUrl = URL(string: uStr.starts(with: "http") ? uStr : "\(base)/\(uStr.trimmingCharacters(in: CharacterSet(charactersIn: "/")))")
                }
                let mins = (v.duration ?? 0) / 60
                let secs = (v.duration ?? 0) % 60
                let timeStr = String(format: "%d:%02d", mins, secs)
                return VKInstanceMediaItem(
                    id: "video\(oid)_\(vid)",
                    type: .video,
                    title: v.title ?? "Видеозапись",
                    subtitle: "Видео • \(timeStr)",
                    thumbnailURL: thumbUrl,
                    attachmentCode: "video\(oid)_\(vid)"
                )
            }

        case .docs:
            let res: VKRawDocsListResponse = try await callMethod(
                method: "docs.get",
                params: [
                    "owner_id": "\(myId)",
                    "count": "\(count)"
                ]
            )
            return (res.items ?? []).compactMap { d in
                guard let did = d.id, let oid = d.ownerId ?? currentUser?.id else { return nil }
                let title = d.title ?? "Документ"
                let sizeBytes = d.size ?? 0
                let sizeStr = ByteCountFormatter.string(fromByteCount: Int64(sizeBytes), countStyle: .file)
                let extStr = d.ext?.uppercased() ?? "FILE"
                let code = (d.accessKey != nil && !d.accessKey!.isEmpty) ? "doc\(oid)_\(did)_\(d.accessKey!)" : "doc\(oid)_\(did)"
                var thumbUrl: URL? = nil
                if let uStr = d.url {
                    thumbUrl = URL(string: uStr.starts(with: "http") ? uStr : "\(base)/\(uStr.trimmingCharacters(in: CharacterSet(charactersIn: "/")))")
                }
                return VKInstanceMediaItem(
                    id: "doc\(oid)_\(did)",
                    type: .docs,
                    title: title,
                    subtitle: "\(extStr) • \(sizeStr)",
                    thumbnailURL: thumbUrl,
                    attachmentCode: code
                )
            }
        }
    }

    // MARK: - Photo Upload (from PC / Clipboard / Drag & Drop)

    public func getMessagesUploadServer(peerId: Int) async throws -> String {
        let res: VKRawUploadServerResponse = try await callMethod(
            method: "photos.getMessagesUploadServer",
            params: ["peer_id": "\(peerId)"]
        )
        guard let url = res.uploadUrl, !url.isEmpty else {
            throw URLError(.badServerResponse)
        }
        return url
    }

    public func uploadPhotoData(uploadUrl: String, data: Data, filename: String = "photo.jpg") async throws -> (server: String, photo: String, hash: String) {
        var cleanUrl = uploadUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanUrl.starts(with: "//") {
            cleanUrl = "https:\(cleanUrl)"
        } else if !cleanUrl.starts(with: "http://") && !cleanUrl.starts(with: "https://") {
            let base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if cleanUrl.starts(with: "/") {
                cleanUrl = "\(base)\(cleanUrl)"
            } else {
                cleanUrl = "\(base)/\(cleanUrl)"
            }
        }
        guard let url = URL(string: cleanUrl) else { throw URLError(.badURL) }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("OpenVKMessenger-macOS/1.0", forHTTPHeaderField: "User-Agent")

        let mimeType = filename.lowercased().hasSuffix(".png") ? "image/png" : "image/jpeg"
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"photo\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.setValue("\(body.count)", forHTTPHeaderField: "Content-Length")

        let (responseData, response) = try await URLSession.shared.upload(for: request, from: body)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        guard let jsonObj = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            if let str = String(data: responseData, encoding: .utf8) {
                print("DEBUG: Upload response was not JSON: \(str)")
            }
            throw URLError(.cannotParseResponse)
        }

        let serverVal = jsonObj["server"]
        let hashVal = (jsonObj["hash"] as? String) ?? ""
        var photoStr = ""

        if let pStr = jsonObj["photo"] as? String {
            photoStr = pStr
        } else if let pStr = jsonObj["photos_list"] as? String {
            photoStr = pStr
        } else if let pObj = jsonObj["photo"] ?? jsonObj["photos_list"] {
            if let pData = try? JSONSerialization.data(withJSONObject: pObj, options: []),
               let s = String(data: pData, encoding: .utf8) {
                photoStr = s
            }
        }

        let serverStr: String
        if let sInt = serverVal as? Int {
            serverStr = String(sInt)
        } else if let sStr = serverVal as? String {
            serverStr = sStr
        } else {
            serverStr = "\(serverVal ?? "")"
        }

        return (server: serverStr, photo: photoStr, hash: hashVal)
    }

    public func saveMessagesPhoto(server: String, photo: String, hash: String) async throws -> [VKRawPhoto] {
        let params: [String: String] = [
            "server": server,
            "photo": photo,
            "hash": hash
        ]
        let res: VKRawSavePhotoResponse = try await callMethod(
            method: "photos.saveMessagesPhoto",
            params: params
        )
        return res.photos
    }

    public func uploadPhotoAttachment(imageData: Data, peerId: Int, filename: String = "photo.jpg") async throws -> String {
        let uploadUrl = try await getMessagesUploadServer(peerId: peerId)
        let (server, photo, hash) = try await uploadPhotoData(uploadUrl: uploadUrl, data: imageData, filename: filename)
        let savedPhotos = try await saveMessagesPhoto(server: server, photo: photo, hash: hash)
        guard let saved = savedPhotos.first, let pid = saved.id, let oid = saved.ownerId ?? currentUser?.id else {
            throw URLError(.cannotParseResponse)
        }
        if let key = saved.accessKey, !key.isEmpty {
            return "photo\(oid)_\(pid)_\(key)"
        }
        return "photo\(oid)_\(pid)"
    }

    public func uploadAndSendPhoto(imageData: Data, peerId: Int, filename: String = "photo.jpg", caption: String = "", replyTo: Int? = nil) async throws -> Int {
        let attachmentCode = try await uploadPhotoAttachment(imageData: imageData, peerId: peerId, filename: filename)
        let msgText = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        var params: [String: String] = [
            "peer_id": "\(peerId)",
            "message": msgText,
            "attachment": attachmentCode,
            "attachments": attachmentCode,
            "random_id": "\(Int.random(in: 1...2_147_483_647))"
        ]
        if let rep = replyTo {
            params["reply_to"] = "\(rep)"
        }
        let res: VKMessageSendResult = try await callMethod(method: "messages.send", params: params)
        return res.messageId ?? 0
    }

    // MARK: - Documents Upload & API

    public func getDocsUploadServer(peerId: Int, type: String = "doc") async throws -> String {
        do {
            let res: VKRawUploadServerResponse = try await callMethod(
                method: "docs.getMessagesUploadServer",
                params: ["peer_id": "\(peerId)", "type": type]
            )
            if let url = res.uploadUrl, !url.isEmpty {
                return url
            }
        } catch {
            let res: VKRawUploadServerResponse = try await callMethod(
                method: "docs.getUploadServer",
                params: ["type": type]
            )
            if let url = res.uploadUrl, !url.isEmpty {
                return url
            }
        }
        throw URLError(.badServerResponse)
    }

    public func uploadDocData(uploadUrl: String, data: Data, filename: String) async throws -> String {
        var cleanUrl = uploadUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanUrl.starts(with: "//") {
            cleanUrl = "https:\(cleanUrl)"
        } else if !cleanUrl.starts(with: "http://") && !cleanUrl.starts(with: "https://") {
            let base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            cleanUrl = cleanUrl.starts(with: "/") ? "\(base)\(cleanUrl)" : "\(base)/\(cleanUrl)"
        }
        guard let url = URL(string: cleanUrl) else {
            throw URLError(.badURL)
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (respData, resp) = try await URLSession.shared.data(for: request)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        if let json = try? JSONSerialization.jsonObject(with: respData) as? [String: Any],
           let fileStr = json["file"] as? String {
            return fileStr
        }
        if let str = String(data: respData, encoding: .utf8) {
            return str
        }
        throw URLError(.cannotParseResponse)
    }

    public func saveDoc(file: String, title: String) async throws -> (id: Int, ownerId: Int, accessKey: String?) {
        struct SaveDocResponse: Decodable {
            let response: [VKRawDocItem]?
            struct VKRawDocItem: Decodable {
                let id: Int?
                let ownerId: Int?
                let accessKey: String?
                enum CodingKeys: String, CodingKey {
                    case id
                    case ownerId = "owner_id"
                    case accessKey = "access_key"
                }
            }
        }
        struct SaveDocSingleResponse: Decodable {
            let response: VKRawDocItem?
            struct VKRawDocItem: Decodable {
                let id: Int?
                let ownerId: Int?
                let accessKey: String?
                enum CodingKeys: String, CodingKey {
                    case id
                    case ownerId = "owner_id"
                    case accessKey = "access_key"
                }
            }
        }

        do {
            let res: SaveDocResponse = try await callMethod(
                method: "docs.save",
                params: ["file": file, "title": title]
            )
            if let doc = res.response?.first, let did = doc.id, let oid = doc.ownerId ?? currentUser?.id {
                return (did, oid, doc.accessKey)
            }
        } catch {
            let singleRes: SaveDocSingleResponse = try await callMethod(
                method: "docs.save",
                params: ["file": file, "title": title]
            )
            if let doc = singleRes.response, let did = doc.id, let oid = doc.ownerId ?? currentUser?.id {
                return (did, oid, doc.accessKey)
            }
        }
        throw URLError(.cannotParseResponse)
    }

    public func uploadDocumentAttachment(data: Data, peerId: Int, filename: String) async throws -> String {
        var uploadFilename = filename
        let lower = filename.lowercased()
        if lower.hasSuffix(".themepack") || lower.hasSuffix(".attheme") || lower.hasSuffix(".tdesktop-theme") || lower.hasSuffix(".tgios-theme") {
            uploadFilename = "\(filename).txt"
        }
        do {
            let uploadUrl = try await getDocsUploadServer(peerId: peerId)
            let fileParam = try await uploadDocData(uploadUrl: uploadUrl, data: data, filename: uploadFilename)
            let (did, oid, key) = try await saveDoc(file: fileParam, title: uploadFilename)
            if let k = key, !k.isEmpty {
                return "doc\(oid)_\(did)_\(k)"
            }
            return "doc\(oid)_\(did)"
        } catch {
            // Fallback: direct OpenVK web upload (/docs/upload)
            return try await uploadDocViaWeb(data: data, filename: uploadFilename)
        }
    }

    private func uploadDocViaWeb(data: Data, filename: String) async throws -> String {
        var base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if !base.starts(with: "http://") && !base.starts(with: "https://") {
            base = "https://\(base)"
        }
        guard let webUploadUrl = URL(string: "\(base)/docs/upload") else {
            throw URLError(.badURL)
        }

        // 1. If we have saved credentials but no cookie, attempt to authenticate web session
        if (self.chandlerSessCookie == nil || self.chandlerSessCookie?.isEmpty == true),
           let l = savedLogin, let p = savedPassword, !l.isEmpty, !p.isEmpty {
            await ensureWebSession(login: l, password: p)
        }

        // 2. Fetch fresh CSRF token with session cookie
        var csrf = await fetchWebCSRFToken()

        // If CSRF is nil (e.g. cookie expired) and we have saved credentials, re-login once
        if csrf == nil, let l = savedLogin, let p = savedPassword, !l.isEmpty, !p.isEmpty {
            let relogged = await ensureWebSession(login: l, password: p)
            if relogged {
                csrf = await fetchWebCSRFToken()
            }
        }

        let cookieSess = self.chandlerSessCookie ?? UserDefaults.standard.string(forKey: "openvk_chandlersess")
        guard let sess = cookieSess, !sess.isEmpty else {
            throw NSError(
                domain: "OpenVKDocUpload",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Для отправки файлов требуется веб-сессия OpenVK. Войдите по логину и паролю."]
            )
        }

        guard let csrfHash = csrf, !csrfHash.isEmpty else {
            throw NSError(
                domain: "OpenVKDocUpload",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "Не удалось получить CSRF-токен OpenVK для отправки файла."]
            )
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: webUploadUrl)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue("1", forHTTPHeaderField: "X-OpenVK-Ajax-Query")
        request.setValue("OpenVKMessenger/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("CHANDLERSESS=\(sess)", forHTTPHeaderField: "Cookie")

        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let body = try await Task.detached(priority: .userInitiated) { () -> Data in
            var b = Data()
            b.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"name\"\r\n\r\n\(filename)\r\n".data(using: .utf8)!)
            b.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"folder\"\r\n\r\n0\r\n".data(using: .utf8)!)
            b.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"tags\"\r\n\r\n\r\n".data(using: .utf8)!)
            b.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"owner_hidden\"\r\n\r\noff\r\n".data(using: .utf8)!)
            b.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"ajax\"\r\n\r\n1\r\n".data(using: .utf8)!)
            b.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"return_template\"\r\n\r\n1\r\n".data(using: .utf8)!)
            b.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"hash\"\r\n\r\n\(csrfHash)\r\n".data(using: .utf8)!)
            b.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"blob\"; filename=\"\(filename)\"\r\nContent-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
            b.append(data)
            b.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
            return b
        }.value

        request.httpBody = body

        let delegate = NonRedirectingURLSessionDelegate()
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)

        let (d, resp) = try await session.data(for: request)

        if let http = resp as? HTTPURLResponse {
            if http.statusCode == 302 || http.statusCode == 401 || http.statusCode == 403 {
                // If we have saved credentials, try re-logging in once
                if let l = savedLogin, let p = savedPassword, !l.isEmpty, !p.isEmpty {
                    let relogged = await ensureWebSession(login: l, password: p)
                    if relogged, let newCsrf = await fetchWebCSRFToken() {
                        var retryReq = request
                        if let newSess = self.chandlerSessCookie, !newSess.isEmpty {
                            retryReq.setValue("CHANDLERSESS=\(newSess)", forHTTPHeaderField: "Cookie")
                        }
                        let newBody = try await Task.detached(priority: .userInitiated) { () -> Data in
                            var b = Data()
                            b.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"name\"\r\n\r\n\(filename)\r\n".data(using: .utf8)!)
                            b.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"folder\"\r\n\r\n0\r\n".data(using: .utf8)!)
                            b.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"tags\"\r\n\r\n\r\n".data(using: .utf8)!)
                            b.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"owner_hidden\"\r\n\r\noff\r\n".data(using: .utf8)!)
                            b.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"ajax\"\r\n\r\n1\r\n".data(using: .utf8)!)
                            b.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"return_template\"\r\n\r\n1\r\n".data(using: .utf8)!)
                            b.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"hash\"\r\n\r\n\(newCsrf)\r\n".data(using: .utf8)!)
                            b.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"blob\"; filename=\"\(filename)\"\r\nContent-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
                            b.append(data)
                            b.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
                            return b
                        }.value
                        retryReq.httpBody = newBody

                        let (retryData, retryResp) = try await session.data(for: retryReq)
                        if let retryHttp = retryResp as? HTTPURLResponse, (200...299).contains(retryHttp.statusCode) {
                            return try parseDocUploadResponse(data: retryData)
                        }
                    }
                }
                throw NSError(
                    domain: "OpenVKDocUpload",
                    code: 401,
                    userInfo: [NSLocalizedDescriptionKey: "Для отправки файлов требуется веб-сессия OpenVK. Войдите по логину и паролю."]
                )
            }
        }

        return try parseDocUploadResponse(data: d)
    }

    private func parseDocUploadResponse(data: Data) throws -> String {
        let text = String(data: data, encoding: .utf8) ?? ""

        // 1. Look for prettiest id in returned HTML template (e.g. data-id="1_104_a1b2c3d4e5f6")
        if let regex = try? NSRegularExpression(pattern: #"data-id=["']([0-9_-]+_[a-f0-9]+)["']"#, options: [.caseInsensitive]) {
            let nsString = text as NSString
            let results = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
            if let match = results.first, match.numberOfRanges > 1 {
                let id = nsString.substring(with: match.range(at: 1))
                if !id.isEmpty {
                    print("DEBUG: parseDocUploadResponse found prettiest id: \(id)")
                    return id.starts(with: "doc") ? id : "doc\(id)"
                }
            }
        }

        // 2. Look for href="/doc<prettyId>?key=<accessKey>"
        if let regex = try? NSRegularExpression(pattern: #"href=["'](?:/doc)?([0-9_-]+)\?key=([a-f0-9]+)["']"#, options: [.caseInsensitive]) {
            let nsString = text as NSString
            let results = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
            if let match = results.first, match.numberOfRanges > 2 {
                let prettyId = nsString.substring(with: match.range(at: 1))
                let key = nsString.substring(with: match.range(at: 2))
                if !prettyId.isEmpty && !key.isEmpty {
                    print("DEBUG: parseDocUploadResponse found key from href: doc\(prettyId)_\(key)")
                    return "doc\(prettyId)_\(key)"
                }
            }
        }

        // 3. Fallback: JSON response
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let success = json["success"] as? Bool, !success {
                if let flash = json["flash"] as? [String: Any], let msg = flash["message"] as? String {
                    throw NSError(domain: "OpenVKDocUpload", code: 1, userInfo: [NSLocalizedDescriptionKey: msg])
                }
            }
            if let idStr = json["id"] as? String, !idStr.isEmpty {
                let cleanId = idStr.starts(with: "doc") ? String(idStr.dropFirst(3)) : idStr
                if let key = (json["access_key"] ?? json["key"]) as? String, !key.isEmpty, !cleanId.contains(key) {
                    return "doc\(cleanId)_\(key)"
                }
                return "doc\(cleanId)"
            }
            if let idInt = json["id"] as? Int {
                if let key = (json["access_key"] ?? json["key"]) as? String, !key.isEmpty {
                    return "doc\(idInt)_\(key)"
                }
                return "doc\(idInt)"
            }
        }

        if text.contains("login") {
            throw NSError(
                domain: "OpenVKDocUpload",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Для отправки файлов требуется веб-сессия OpenVK. Войдите по логину и паролю."]
            )
        }
        if text.contains("CSRF token is missing or invalid") {
            throw NSError(
                domain: "OpenVKDocUpload",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "Ошибка CSRF при загрузке документа."]
            )
        }

        throw URLError(.cannotParseResponse)
    }

    public func addDoc(ownerId: Int, docId: Int, accessKey: String? = nil) async throws -> Int {
        var params: [String: String] = [
            "owner_id": "\(ownerId)",
            "doc_id": "\(docId)"
        ]
        if let key = accessKey, !key.isEmpty {
            params["access_key"] = key
        }
        struct AddDocResponse: Decodable {
            let response: Int?
        }
        let res: AddDocResponse = try await callMethod(method: "docs.add", params: params)
        return res.response ?? 1
    }

    // MARK: - Conversation Materials (History Attachments)

    public func getHistoryAttachments(peerId: Int, mediaType: String, count: Int = 40) async throws -> [VKInstanceMediaItem] {
        let base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        do {
            let res: VKRawHistoryAttachmentsResponse = try await callMethod(
                method: "messages.getHistoryAttachments",
                params: [
                    "peer_id": "\(peerId)",
                    "media_type": mediaType,
                    "count": "\(count)",
                    "photo_sizes": "1"
                ]
            )

            var result: [VKInstanceMediaItem] = []
            for item in res.items ?? [] {
                guard let att = item.attachment else { continue }
                if mediaType == "photo", let p = att.photo, let pid = p.id {
                    let oid = p.ownerId ?? 0
                    var thumbUrl: URL? = nil
                    if let uStr = p.bestUrlString {
                        thumbUrl = URL(string: uStr.starts(with: "http") ? uStr : "\(base)/\(uStr.trimmingCharacters(in: CharacterSet(charactersIn: "/")))")
                    }
                    result.append(VKInstanceMediaItem(
                        id: "photo\(oid)_\(pid)",
                        type: .photos,
                        title: p.text?.isEmpty == false ? p.text! : "Фотография #\(pid)",
                        subtitle: "Фото",
                        thumbnailURL: thumbUrl,
                        attachmentCode: "photo\(oid)_\(pid)"
                    ))
                } else if mediaType == "video", let v = att.video, let vid = v.id {
                    let oid = v.ownerId ?? 0
                    var thumbUrl: URL? = nil
                    if let uStr = v.photo320 ?? v.image?.last?.bestUrlString {
                        thumbUrl = URL(string: uStr.starts(with: "http") ? uStr : "\(base)/\(uStr.trimmingCharacters(in: CharacterSet(charactersIn: "/")))")
                    }
                    let mins = (v.duration ?? 0) / 60
                    let secs = (v.duration ?? 0) % 60
                    result.append(VKInstanceMediaItem(
                        id: "video\(oid)_\(vid)",
                        type: .video,
                        title: v.title ?? "Видеозапись",
                        subtitle: String(format: "%d:%02d", mins, secs),
                        thumbnailURL: thumbUrl,
                        attachmentCode: "video\(oid)_\(vid)"
                    ))
                } else if mediaType == "audio", let a = att.audio, let aid = a.id {
                    let oid = a.ownerId ?? 0
                    let mins = (a.duration ?? 0) / 60
                    let secs = (a.duration ?? 0) % 60
                    result.append(VKInstanceMediaItem(
                        id: "audio\(oid)_\(aid)",
                        type: .audio,
                        title: a.title ?? "Аудиозапись",
                        subtitle: "\(a.artist ?? "Исполнитель") • \(String(format: "%d:%02d", mins, secs))",
                        thumbnailURL: nil,
                        attachmentCode: "audio\(oid)_\(aid)"
                    ))
                } else if mediaType == "doc", let d = att.doc, let did = d.id {
                    result.append(VKInstanceMediaItem(
                        id: "doc\(did)",
                        type: .photos,
                        title: d.title ?? "Документ",
                        subtitle: d.ext ?? "файл",
                        thumbnailURL: nil,
                        attachmentCode: "doc\(did)"
                    ))
                }
            }
            return result
        } catch {
            return []
        }
    }

    public func getUserGroups(count: Int = 1000) async throws -> [VKGroup] {
        struct GroupsContainer: Decodable {
            let count: Int?
            let items: [VKGroup]?
        }

        // Fetch user's communities with full details and server-provided is_admin flag
        let res: GroupsContainer = try await callMethod(method: "groups.get", params: [
            "extended": "1",
            "count": "\(count)",
            "fields": "photo_50,photo_100,photo_200,is_admin,admin_level,type"
        ])
        return res.items ?? []
    }

    public func getAdministeredGroups() async throws -> [VKGroup] {
        let all = try await getUserGroups()
        return all.filter { $0.isUserAdmin }
    }

    // MARK: - Message Search

    public func searchMessages(
        query: String,
        peerId: Int? = nil,
        count: Int = 50,
        offset: Int = 0
    ) async throws -> [VKMessage] {
        var params: [String: String] = [
            "q": query,
            "count": "\(count)",
            "offset": "\(offset)",
            "extended": "1",
            "fields": "photo_100,photo_200,verified"
        ]
        if let pid = peerId {
            params["peer_id"] = "\(pid)"
        }

        let raw: VKRawHistoryResponse = try await callMethod(
            method: "messages.search",
            params: params
        )

        for p in raw.profiles ?? [] {
            self.cachedUsers[p.id] = p
        }
        for g in raw.groups ?? [] {
            self.cachedGroups[g.id] = g
            self.cachedUsers[-g.id] = VKUser(
                id: -g.id,
                firstName: g.name,
                lastName: "",
                photo100: g.photo100,
                photo200: g.photo200
            )
        }
        var profilesMap: [Int: VKUser] = Dictionary(uniqueKeysWithValues: (raw.profiles ?? []).map { ($0.id, $0) })
        for g in raw.groups ?? [] {
            profilesMap[-g.id] = VKUser(
                id: -g.id,
                firstName: g.name,
                lastName: "",
                photo100: g.photo100,
                photo200: g.photo200
            )
        }

        var list: [VKMessage] = []
        for rawMsg in raw.items {
            let pid = rawMsg.peerId ?? peerId ?? rawMsg.fromId
            let msg = self.mapRawMessage(rawMsg, profilesMap: profilesMap, defaultPeerId: pid)
            list.append(msg)
        }
        return list
    }

    // MARK: - Video Details & Playback Resolution

    public func getVideoDetails(ownerId: Int, videoId: Int, accessKey: String? = nil) async throws -> VKVideoDetail? {
        let vidStr: String
        if let key = accessKey, !key.isEmpty {
            vidStr = "\(ownerId)_\(videoId)_\(key)"
        } else {
            vidStr = "\(ownerId)_\(videoId)"
        }

        let base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let res: VKRawVideoListResponse = try await callMethod(
            method: "video.get",
            params: [
                "videos": vidStr,
                "extended": "1"
            ]
        )

        guard let v = res.items?.first else { return nil }

        var thumbUrl: URL? = nil
        if let uStr = v.photo800 ?? v.photo320 ?? v.image?.last?.bestUrlString {
            thumbUrl = URL(string: uStr.starts(with: "http") ? uStr : "\(base)/\(uStr.trimmingCharacters(in: CharacterSet(charactersIn: "/")))")
        }

        var playerUrl: URL? = nil
        if let pStr = v.player, !pStr.isEmpty {
            playerUrl = URL(string: pStr.starts(with: "http") ? pStr : "\(base)/\(pStr.trimmingCharacters(in: CharacterSet(charactersIn: "/")))")
        } else {
            let fallback = "\(base)/video_ext.php?oid=\(ownerId)&id=\(videoId)&hash=\(accessKey ?? "")"
            playerUrl = URL(string: fallback)
        }

        var directFiles: [String: URL] = [:]
        if let files = v.files {
            for (k, val) in files {
                if let u = URL(string: val.starts(with: "http") ? val : "\(base)/\(val.trimmingCharacters(in: CharacterSet(charactersIn: "/")))") {
                    directFiles[k] = u
                }
            }
        }

        return VKVideoDetail(
            id: v.id ?? videoId,
            ownerId: v.ownerId ?? ownerId,
            title: v.title ?? "Видеозапись",
            description: v.description ?? "",
            duration: v.duration ?? 0,
            imageURL: thumbUrl,
            playerURL: playerUrl,
            accessKey: v.accessKey ?? accessKey,
            directFiles: directFiles
        )
    }
}

public struct LongPollServerResponse: Decodable {
    public let key: String
    public let server: String
    public let ts: Int
    public let pts: Int?
}

public struct VKIntOrBool: Decodable {
    public let value: Int

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            self.value = intVal
        } else if let boolVal = try? container.decode(Bool.self) {
            self.value = boolVal ? 1 : 0
        } else {
            self.value = 1
        }
    }
}

public struct VKMessageSendResult: Decodable {
    public let messageId: Int?

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            self.messageId = intVal
        } else if let dict = try? container.decode([String: Int].self) {
            self.messageId = dict["message_id"] ?? dict["id"]
        } else {
            self.messageId = nil
        }
    }
}

final class NonRedirectingURLSessionDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        // Stop redirect so we catch 302 and headers directly
        completionHandler(nil)
    }
}

