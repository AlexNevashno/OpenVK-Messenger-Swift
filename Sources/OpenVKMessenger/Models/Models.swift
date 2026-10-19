import Foundation

// MARK: - Generic API Wrappers
public struct VKAPIResponse<T: Decodable>: Decodable {
    public let response: T?
    public let error: VKAPIErrorPayload?
}

public struct VKAPIErrorPayload: Decodable, LocalizedError {
    public let errorCode: Int
    public let errorMsg: String

    enum CodingKeys: String, CodingKey {
        case errorCode = "error_code"
        case errorMsg = "error_msg"
    }

    public var errorDescription: String? {
        "[\(errorCode)] \(errorMsg)"
    }
}

public struct VKTokenResponse: Decodable {
    public let accessToken: String
    public let userId: Int?
    public let expiresIn: Int?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case userId = "user_id"
        case expiresIn = "expires_in"
    }
}

// MARK: - VK Last Seen
public struct VKLastSeen: Codable, Hashable {
    public let time: Double
    public let platform: Int?

    public init(time: Double, platform: Int? = nil) {
        self.time = time
        self.platform = platform
    }

    public init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            if let d = try? container.decode(Double.self, forKey: .time) {
                self.time = d
            } else if let i = try? container.decode(Int.self, forKey: .time) {
                self.time = Double(i)
            } else {
                self.time = 0
            }
            self.platform = try? container.decode(Int.self, forKey: .platform)
        } else if let single = try? decoder.singleValueContainer() {
            if let d = try? single.decode(Double.self) {
                self.time = d
                self.platform = nil
            } else if let i = try? single.decode(Int.self) {
                self.time = Double(i)
                self.platform = nil
            } else {
                self.time = 0
                self.platform = nil
            }
        } else {
            self.time = 0
            self.platform = nil
        }
    }

    enum CodingKeys: String, CodingKey {
        case time, platform
    }
}

// MARK: - VK User
public struct VKUser: Identifiable, Codable, Hashable {
    public let id: Int
    public let firstName: String
    public let lastName: String
    public let photo100: String?
    public let photo200: String?
    public let online: Int?
    public let onlineMobile: Int?
    public let onlineApp: Int?
    public let verified: Int?
    public let lastSeen: VKLastSeen?
    public let sex: Int?

    public var fullName: String {
        let f = firstName.trimmingCharacters(in: .whitespaces)
        let l = lastName.trimmingCharacters(in: .whitespaces)
        return l.isEmpty ? f : "\(f) \(l)"
    }

    public var isOnline: Bool {
        (online ?? 0) == 1
    }

    public var isMobileOnline: Bool {
        (onlineMobile ?? 0) == 1
    }

    public var isVerified: Bool {
        (verified ?? 0) == 1
    }

    public var avatarURL: URL? {
        if let p200 = photo200, let u = URL(string: p200) { return u }
        if let p100 = photo100, let u = URL(string: p100) { return u }
        return nil
    }

    public var photoURL: URL? {
        avatarURL
    }

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case photo100 = "photo_100"
        case photo200 = "photo_200"
        case online
        case onlineMobile = "online_mobile"
        case onlineApp = "online_app"
        case verified
        case lastSeen = "last_seen"
        case sex
    }

    public init(
        id: Int,
        firstName: String,
        lastName: String,
        photo100: String? = nil,
        photo200: String? = nil,
        online: Int? = nil,
        onlineMobile: Int? = nil,
        onlineApp: Int? = nil,
        verified: Int? = nil,
        lastSeen: VKLastSeen? = nil,
        sex: Int? = nil
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.photo100 = photo100
        self.photo200 = photo200
        self.online = online
        self.onlineMobile = onlineMobile
        self.onlineApp = onlineApp
        self.verified = verified
        self.lastSeen = lastSeen
        self.sex = sex
    }
}

// MARK: - VK Users List Response (for friends.get, users.search)
public struct VKUsersListResponse: Decodable {
    public let count: Int?
    public let items: [VKUser]

    enum CodingKeys: String, CodingKey {
        case count, items
    }

    public init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            self.count = try? container.decode(Int.self, forKey: .count)
            self.items = (try? container.decode([VKUser].self, forKey: .items)) ?? []
        } else if let singleList = try? decoder.singleValueContainer().decode([VKUser].self) {
            self.count = singleList.count
            self.items = singleList
        } else {
            self.count = 0
            self.items = []
        }
    }
}

// MARK: - VK Group
public struct VKGroup: Identifiable, Codable, Hashable {
    public let id: Int
    public let name: String
    public let screenName: String?
    public let photo100: String?
    public let photo200: String?
    public var isAdmin: Int?
    public var adminLevel: Int?
    public var isMember: Int?
    public var isClosed: Int?
    public var type: String?

    public init(
        id: Int,
        name: String,
        screenName: String? = nil,
        photo100: String? = nil,
        photo200: String? = nil,
        isAdmin: Int? = nil,
        adminLevel: Int? = nil,
        isMember: Int? = nil,
        isClosed: Int? = nil,
        type: String? = nil
    ) {
        self.id = id
        self.name = name
        self.screenName = screenName
        self.photo100 = photo100
        self.photo200 = photo200
        self.isAdmin = isAdmin
        self.adminLevel = adminLevel
        self.isMember = isMember
        self.isClosed = isClosed
        self.type = type
    }

    public var isUserAdmin: Bool {
        (isAdmin ?? 0) == 1 || (adminLevel ?? 0) > 0
    }

    public var adminRoleTitle: String? {
        guard isUserAdmin else { return nil }
        switch adminLevel {
        case 1: return "Модератор"
        case 2: return "Редактор"
        case 3: return "Администратор"
        default: return "Администратор"
        }
    }

    public var avatarURL: URL? {
        if let p200 = photo200, let u = URL(string: p200) { return u }
        if let p100 = photo100, let u = URL(string: p100) { return u }
        return nil
    }

    enum CodingKeys: String, CodingKey {
        case id, name
        case screenName = "screen_name"
        case photo100 = "photo_100"
        case photo200 = "photo_200"
        case isAdmin = "is_admin"
        case adminLevel = "admin_level"
        case isMember = "is_member"
        case isClosed = "is_closed"
        case type
    }
}

// MARK: - Attachment Models
public struct VKSticker: Identifiable, Codable, Hashable {
    public let id: Int
    public let productId: Int?
    public let url: URL?
    public let animationURL: URL?

    public init(id: Int, productId: Int? = nil, url: URL? = nil, animationURL: URL? = nil) {
        self.id = id
        self.productId = productId
        self.url = url
        self.animationURL = animationURL
    }
}

public struct VKPhotoAttachment: Identifiable, Codable, Hashable {
    public let id: Int
    public let url: URL?
    public let text: String
    public var localImage: PlatformImage?
    public let width: Int?
    public let height: Int?

    public init(id: Int, url: URL? = nil, text: String = "", localImage: PlatformImage? = nil, width: Int? = nil, height: Int? = nil) {
        self.id = id
        self.url = url
        self.text = text
        self.localImage = localImage
        self.width = width
        self.height = height
    }

    enum CodingKeys: String, CodingKey {
        case id, url, text, width, height
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(Int.self, forKey: .id)) ?? 0
        self.url = try? container.decodeIfPresent(URL.self, forKey: .url)
        self.text = (try? container.decode(String.self, forKey: .text)) ?? ""
        self.width = try? container.decodeIfPresent(Int.self, forKey: .width)
        self.height = try? container.decodeIfPresent(Int.self, forKey: .height)
        self.localImage = nil
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(url, forKey: .url)
        try container.encode(text, forKey: .text)
        try container.encodeIfPresent(width, forKey: .width)
        try container.encodeIfPresent(height, forKey: .height)
    }
}

public struct VKVoiceAttachment: Identifiable, Codable, Hashable {
    public let id: String
    public let duration: Int
    public let audioURL: URL?

    public init(id: String = UUID().uuidString, duration: Int, audioURL: URL? = nil) {
        self.id = id
        self.duration = duration
        self.audioURL = audioURL
    }
}

public struct VKDocAttachment: Identifiable, Codable, Hashable {
    public let id: Int
    public var title: String
    public var size: Int
    public var ext: String
    public var url: URL?

    public init(id: Int, title: String, size: Int, ext: String, url: URL? = nil) {
        self.id = id
        self.title = title
        self.size = size
        self.ext = ext
        self.url = url
    }
}

public struct VKAudioAttachment: Identifiable, Codable, Hashable {
    public let id: Int
    public let ownerId: Int
    public let artist: String
    public let title: String
    public let duration: Int
    public let url: URL?

    public init(id: Int, ownerId: Int, artist: String, title: String, duration: Int, url: URL? = nil) {
        self.id = id
        self.ownerId = ownerId
        self.artist = artist
        self.title = title
        self.duration = duration
        self.url = url
    }

    public var attachmentString: String {
        "audio\(ownerId)_\(id)"
    }
}

public struct VKVideoAttachment: Identifiable, Codable, Hashable {
    public let id: Int
    public let ownerId: Int
    public let title: String
    public let duration: Int
    public let imageURL: URL?
    public let playerURL: URL?
    public let directVideoURL: URL?
    public let accessKey: String?

    public init(
        id: Int,
        ownerId: Int,
        title: String,
        duration: Int,
        imageURL: URL? = nil,
        playerURL: URL? = nil,
        directVideoURL: URL? = nil,
        accessKey: String? = nil
    ) {
        self.id = id
        self.ownerId = ownerId
        self.title = title
        self.duration = duration
        self.imageURL = imageURL
        self.playerURL = playerURL
        self.directVideoURL = directVideoURL
        self.accessKey = accessKey
    }

    public var attachmentString: String {
        "video\(ownerId)_\(id)"
    }
}

public struct VKVideoDetail: Identifiable, Codable, Hashable {
    public let id: Int
    public let ownerId: Int
    public let title: String
    public let description: String
    public let duration: Int
    public let imageURL: URL?
    public let playerURL: URL?
    public let accessKey: String?
    public let directFiles: [String: URL]

    public init(
        id: Int,
        ownerId: Int,
        title: String,
        description: String = "",
        duration: Int = 0,
        imageURL: URL? = nil,
        playerURL: URL? = nil,
        accessKey: String? = nil,
        directFiles: [String: URL] = [:]
    ) {
        self.id = id
        self.ownerId = ownerId
        self.title = title
        self.description = description
        self.duration = duration
        self.imageURL = imageURL
        self.playerURL = playerURL
        self.accessKey = accessKey
        self.directFiles = directFiles
    }

    public var bestDirectURL: URL? {
        for key in ["mp4_1080", "1080", "mp4_720", "720", "mp4_480", "480", "mp4_360", "360", "mp4_240", "240", "external"] {
            if let u = directFiles[key] {
                return u
            }
        }
        return directFiles.values.first
    }
}

public struct VKWallPost: Identifiable, Codable, Hashable {
    public let id: Int
    public let authorName: String
    public let authorPhoto: URL?
    public let date: Date
    public let text: String
    public let imageURL: URL?
    public let photos: [VKPhotoAttachment]
    public let audios: [VKAudioAttachment]
    public let videos: [VKVideoAttachment]
    public let docs: [VKDocAttachment]

    public init(
        id: Int,
        authorName: String,
        authorPhoto: URL? = nil,
        date: Date,
        text: String,
        imageURL: URL? = nil,
        photos: [VKPhotoAttachment] = [],
        audios: [VKAudioAttachment] = [],
        videos: [VKVideoAttachment] = [],
        docs: [VKDocAttachment] = []
    ) {
        self.id = id
        self.authorName = authorName
        self.authorPhoto = authorPhoto
        self.date = date
        self.text = text
        self.imageURL = imageURL ?? photos.first?.url
        if photos.isEmpty, let u = imageURL {
            self.photos = [VKPhotoAttachment(id: 0, url: u)]
        } else {
            self.photos = photos
        }
        self.audios = audios
        self.videos = videos
        self.docs = docs
    }
}

public struct VKReplyMessage: Identifiable, Codable, Hashable {
    public let id: Int
    public let fromId: Int
    public let senderName: String
    public let senderAvatarURL: URL?
    public let date: Date?
    public let text: String
    public let photoURL: URL?
    public let hasPhoto: Bool

    public init(
        id: Int,
        fromId: Int,
        senderName: String,
        senderAvatarURL: URL? = nil,
        date: Date? = nil,
        text: String,
        photoURL: URL? = nil,
        hasPhoto: Bool = false
    ) {
        self.id = id
        self.fromId = fromId
        self.senderName = senderName
        self.senderAvatarURL = senderAvatarURL
        self.date = date
        self.text = text
        self.photoURL = photoURL
        self.hasPhoto = hasPhoto
    }
}

public struct VKGiftAttachment: Identifiable, Codable, Hashable {
    public let id: Int
    public let thumbURL: URL?
    public let description: String?

    public init(id: Int, thumbURL: URL? = nil, description: String? = nil) {
        self.id = id
        self.thumbURL = thumbURL
        self.description = description
    }
}

public struct VKMoneyTransferAttachment: Identifiable, Codable, Hashable {
    public let id: Int
    public let fromId: Int
    public let toId: Int
    public let amount: Int
    public let currency: String
    public let text: String

    public init(id: Int, fromId: Int = 0, toId: Int = 0, amount: Int, currency: String = "голосов", text: String = "") {
        self.id = id
        self.fromId = fromId
        self.toId = toId
        self.amount = amount
        self.currency = currency
        self.text = text
    }
}

// MARK: - Service Action Messages
public struct VKMessageAction: Codable, Hashable {
    public let type: String
    public let memberId: Int?
    public let memberName: String?
    public let text: String?

    public init(type: String, memberId: Int? = nil, memberName: String? = nil, text: String? = nil) {
        self.type = type
        self.memberId = memberId
        self.memberName = memberName
        self.text = text
    }

    public func displayText(authorName: String, authorId: Int = 0) -> String {
        let isSelf = (memberId != nil && memberId == authorId) || (memberId == nil)
        switch type {
        case "chat_invite_user":
            if isSelf {
                return "\(authorName) вернулся(лась) в беседу"
            } else if let mem = memberName, !mem.isEmpty {
                return "\(authorName) пригласил(а) \(mem)"
            } else {
                return "\(authorName) вернулся(лась) в беседу"
            }

        case "chat_invite_user_by_link":
            return "\(authorName) присоединился(лась) к беседе по ссылке"

        case "chat_kick_user":
            if isSelf {
                return "\(authorName) покинул(а) беседу"
            } else if let mem = memberName, !mem.isEmpty {
                return "\(authorName) исключил(а) \(mem)"
            } else {
                return "\(authorName) покинул(а) беседу"
            }

        case "chat_title_update":
            let title = text?.isEmpty == false ? " «\(text!)»" : ""
            return "\(authorName) изменил(а) название беседы\(title)"

        case "chat_photo_update":
            return "\(authorName) обновил(а) фотографию беседы"

        case "chat_photo_remove":
            return "\(authorName) удалил(а) фотографию беседы"

        case "chat_pin_message":
            return "\(authorName) закрепил(а) сообщение"

        case "chat_unpin_message":
            return "\(authorName) открепил(а) сообщение"

        case "chat_create":
            let title = text?.isEmpty == false ? " «\(text!)»" : ""
            return "\(authorName) создал(а) беседу\(title)"

        case "chat_screenshot":
            return "\(authorName) сделал(а) скриншот"

        default:
            return text ?? "Действие в беседе"
        }
    }
}

// MARK: - Unified Message
public struct VKMessage: Identifiable, Codable, Hashable {
    public var id: Int
    public let peerId: Int
    public let fromId: Int
    public let date: Date
    public var text: String
    public var out: Bool
    public var isRead: Bool

    // Attachments & Actions
    public var sticker: VKSticker?
    public var photo: VKPhotoAttachment?
    public var photos: [VKPhotoAttachment] = []
    public var voiceMessage: VKVoiceAttachment?
    public var doc: VKDocAttachment?
    public var wallPost: VKWallPost?
    public var audio: VKAudioAttachment?
    public var video: VKVideoAttachment?
    public var gift: VKGiftAttachment?
    public var moneyTransfer: VKMoneyTransferAttachment?
    public var action: VKMessageAction?
    public var sender: VKUser?
    public var replyMessage: VKReplyMessage?
    public var isPinned: Bool = false
    public var isFailed: Bool = false
    public var sendError: String? = nil

    public var isServiceAction: Bool {
        if action != nil { return true }
        if moneyTransfer != nil { return true }
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return t.contains("присоединился к беседе") ||
               t.contains("присоединилась к беседе") ||
               t.contains("вернулся в беседу") ||
               t.contains("вернулась в беседу") ||
               t.contains("покинул беседу") ||
               t.contains("покинула беседу") ||
               t.contains("исключил из беседы") ||
               t.contains("исключила из беседы") ||
               t.contains("изменил название беседы") ||
               t.contains("изменила название беседы") ||
               t.contains("обновил фотографию беседы") ||
               t.contains("обновила фотографию беседы") ||
               t.contains("удалил фотографию беседы") ||
               t.contains("удалила фотографию беседы") ||
               t.contains("закрепил сообщение") ||
               t.contains("закрепила сообщение") ||
               t.starts(with: "передал вам") ||
               t.starts(with: "передала вам") ||
               t.contains("передал вам") ||
               t.contains("передала вам")
    }

    public var serviceDisplayText: String {
        let author = sender?.fullName ?? "Пользователь"
        if let act = action {
            return act.displayText(authorName: author, authorId: fromId)
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().starts(with: author.lowercased()) {
            return trimmed
        }
        return "\(author) \(trimmed)"
    }

    public var hasAttachments: Bool {
        !photos.isEmpty || photo != nil || voiceMessage != nil || doc != nil || wallPost != nil || sticker != nil || audio != nil || video != nil || gift != nil || moneyTransfer != nil
    }

    public init(
        id: Int,
        peerId: Int,
        fromId: Int,
        date: Date = Date(),
        text: String,
        out: Bool,
        isRead: Bool = false,
        sticker: VKSticker? = nil,
        photo: VKPhotoAttachment? = nil,
        photos: [VKPhotoAttachment] = [],
        voiceMessage: VKVoiceAttachment? = nil,
        doc: VKDocAttachment? = nil,
        wallPost: VKWallPost? = nil,
        audio: VKAudioAttachment? = nil,
        video: VKVideoAttachment? = nil,
        gift: VKGiftAttachment? = nil,
        moneyTransfer: VKMoneyTransferAttachment? = nil,
        action: VKMessageAction? = nil,
        sender: VKUser? = nil,
        replyMessage: VKReplyMessage? = nil,
        isPinned: Bool = false,
        isFailed: Bool = false,
        sendError: String? = nil
    ) {
        self.id = id
        self.peerId = peerId
        self.fromId = fromId
        self.date = date
        self.text = text
        self.out = out
        self.isRead = isRead
        self.sticker = sticker
        var resolvedPhotos = photos
        if resolvedPhotos.isEmpty, let p = photo {
            resolvedPhotos = [p]
        }
        self.photos = resolvedPhotos
        self.photo = photo ?? resolvedPhotos.first
        self.voiceMessage = voiceMessage
        self.doc = doc
        self.wallPost = wallPost
        self.audio = audio
        self.video = video
        self.gift = gift
        self.moneyTransfer = moneyTransfer
        self.action = action
        self.sender = sender
        self.replyMessage = replyMessage
        self.isPinned = isPinned
        self.isFailed = isFailed
        self.sendError = sendError
    }
}

// MARK: - Conversation
public struct VKConversation: Identifiable, Codable, Hashable {
    public var id: Int { peerId }
    public let peerId: Int
    public var title: String
    public var avatarURL: URL?
    public var unreadCount: Int
    public var lastMessage: VKMessage?
    public var isOnline: Bool
    public var isMobile: Bool
    public var isVerified: Bool
    public var isChat: Bool
    public var membersCount: Int?
    public var isSavedMessages: Bool
    public var lastSeen: VKLastSeen?
    public var sex: Int?
    public var pinnedMessage: VKMessage?
    public var hasUnreadMention: Bool = false

    public var displayTitle: String {
        isSavedMessages ? "Избранное" : title
    }

    public init(
        peerId: Int,
        title: String,
        avatarURL: URL? = nil,
        unreadCount: Int = 0,
        lastMessage: VKMessage? = nil,
        isOnline: Bool = false,
        isMobile: Bool = false,
        isVerified: Bool = false,
        isChat: Bool = false,
        membersCount: Int? = nil,
        isSavedMessages: Bool = false,
        lastSeen: VKLastSeen? = nil,
        sex: Int? = nil,
        pinnedMessage: VKMessage? = nil,
        hasUnreadMention: Bool = false
    ) {
        self.peerId = peerId
        self.title = title
        self.avatarURL = avatarURL
        self.unreadCount = unreadCount
        self.lastMessage = lastMessage
        self.isOnline = isOnline
        self.isMobile = isMobile
        self.isVerified = isVerified
        self.isChat = isChat
        self.membersCount = membersCount
        self.isSavedMessages = isSavedMessages || title == "Избранное"
        self.lastSeen = lastSeen
        self.sex = sex
        self.pinnedMessage = pinnedMessage
        self.hasUnreadMention = hasUnreadMention
    }
}

// MARK: - Chat Folder Model
public struct VKChatFolder: Identifiable, Codable, Hashable {
    public let id: UUID
    public var name: String
    public var icon: String
    public var peerIds: [Int]

    public init(
        id: UUID = UUID(),
        name: String,
        icon: String = "folder.fill",
        peerIds: [Int] = []
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.peerIds = peerIds
    }
}

// MARK: - Multi-Account Model
public struct VKAccount: Identifiable, Codable, Hashable {
    public let id: String
    public let userId: Int
    public let firstName: String
    public let lastName: String
    public let photoURL: URL?
    public let token: String
    public let serverURL: String
    public let addedDate: Date

    public init(
        userId: Int,
        firstName: String,
        lastName: String,
        photoURL: URL? = nil,
        token: String,
        serverURL: String,
        addedDate: Date = Date()
    ) {
        let cleanServer = serverURL.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.id = "\(userId)@\(cleanServer)"
        self.userId = userId
        self.firstName = firstName
        self.lastName = lastName
        self.photoURL = photoURL
        self.token = token
        self.serverURL = serverURL
        self.addedDate = addedDate
    }

    public var fullName: String {
        "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }

    public var serverDomain: String {
        serverURL.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}

// MARK: - Resilient Raw VK API Structures
public struct VKRawConversationsResponse: Decodable {
    public let count: Int?
    public let unreadCount: Int?
    public let items: [VKRawConversationItem]
    public let profiles: [VKUser]?
    public let groups: [VKGroup]?

    enum CodingKeys: String, CodingKey {
        case count
        case unreadCount = "unread_count"
        case items, profiles, groups
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.count = try? container.decode(Int.self, forKey: .count)
        self.unreadCount = try? container.decode(Int.self, forKey: .unreadCount)
        self.profiles = try? container.decode([VKUser].self, forKey: .profiles)
        self.groups = try? container.decode([VKGroup].self, forKey: .groups)

        if var itemsContainer = try? container.nestedUnkeyedContainer(forKey: .items) {
            var decodedItems: [VKRawConversationItem] = []
            while !itemsContainer.isAtEnd {
                if let item = try? itemsContainer.decode(VKRawConversationItem.self) {
                    decodedItems.append(item)
                } else {
                    _ = try? itemsContainer.decode(DummyDiscardable.self)
                }
            }
            self.items = decodedItems
        } else {
            self.items = []
        }
    }
}

public struct VKRawConversationItem: Decodable {
    public let conversation: VKRawConversationData
    public let lastMessage: VKRawMessageData?

    enum CodingKeys: String, CodingKey {
        case conversation
        case lastMessage = "last_message"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.conversation = try container.decode(VKRawConversationData.self, forKey: .conversation)
        self.lastMessage = try? container.decode(VKRawMessageData.self, forKey: .lastMessage)
    }
}

public struct VKRawConversationData: Decodable {
    public let peer: VKRawPeer
    public let inRead: Int?
    public let outRead: Int?
    public let unreadCount: Int?
    public let chatSettings: VKRawChatSettings?
    public let pinnedMessage: VKRawMessageData?

    enum CodingKeys: String, CodingKey {
        case peer
        case inRead = "in_read"
        case outRead = "out_read"
        case unreadCount = "unread_count"
        case chatSettings = "chat_settings"
        case pinnedMessage = "pinned_message"
    }

    public var effectivePinnedMessage: VKRawMessageData? {
        chatSettings?.pinnedMessage ?? pinnedMessage
    }
}

public struct VKRawChatSettings: Decodable {
    public let title: String?
    public let membersCount: Int?
    public let photo: VKRawChatPhoto?
    public let ownerId: Int?
    public let adminId: Int?
    public let pinnedMessage: VKRawMessageData?

    enum CodingKeys: String, CodingKey {
        case title
        case membersCount = "members_count"
        case photo
        case ownerId = "owner_id"
        case adminId = "admin_id"
        case pinnedMessage = "pinned_message"
    }

    public var effectiveOwnerId: Int? {
        ownerId ?? adminId
    }
}

public struct VKRawChatPhoto: Decodable {
    public let photo100: String?
    public let photo200: String?

    enum CodingKeys: String, CodingKey {
        case photo100 = "photo_100"
        case photo200 = "photo_200"
    }
}

public struct VKRawPeer: Decodable {
    public let id: Int
    public let type: String
    public let localId: Int?

    enum CodingKeys: String, CodingKey {
        case id, type
        case localId = "local_id"
    }
}

public struct VKRawReplyMessageData: Decodable {
    public let id: Int
    public let fromId: Int
    public let date: Double?
    public let text: String
    public let attachments: [VKRawAttachment]?

    enum CodingKeys: String, CodingKey {
        case id, text, date, attachments
        case fromId = "from_id"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(Int.self, forKey: .id)) ?? 0
        self.fromId = (try? container.decode(Int.self, forKey: .fromId)) ?? 0
        self.date = try? container.decode(Double.self, forKey: .date)
        self.text = (try? container.decode(String.self, forKey: .text)) ?? ""
        self.attachments = try? container.decode([VKRawAttachment].self, forKey: .attachments)
    }
}

public struct VKRawMessageData: Decodable {
    public let id: Int
    public let date: Double
    public let peerId: Int?
    public let fromId: Int
    public let text: String
    public let out: Int?
    public let readState: Int?
    public let isPinned: Int?
    public let attachments: [VKRawAttachment]?
    public let action: VKRawMessageAction?
    public let replyMessage: VKRawReplyMessageData?

    enum CodingKeys: String, CodingKey {
        case id, date
        case peerId = "peer_id"
        case chatId = "chat_id"
        case fromId = "from_id"
        case userId = "user_id"
        case text, out, attachments, action
        case actionMid = "action_mid"
        case actionMemberId = "action_member_id"
        case actionText = "action_text"
        case sourceAct = "source_act"
        case sourceMid = "source_mid"
        case sourceText = "source_text"
        case readState = "read_state"
        case isPinned = "is_pinned"
        case replyMessage = "reply_message"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(Int.self, forKey: .id)) ?? 0
        self.isPinned = try? container.decode(Int.self, forKey: .isPinned)

        if let d = try? container.decode(Double.self, forKey: .date) {
            self.date = d
        } else if let i = try? container.decode(Int.self, forKey: .date) {
            self.date = Double(i)
        } else {
            self.date = Date().timeIntervalSince1970
        }

        if let p = try? container.decode(Int.self, forKey: .peerId) {
            self.peerId = p
        } else if let c = try? container.decode(Int.self, forKey: .chatId) {
            self.peerId = 2_000_000_000 + c
        } else {
            self.peerId = try? container.decode(Int.self, forKey: .userId)
        }

        if let f = try? container.decode(Int.self, forKey: .fromId) {
            self.fromId = f
        } else if let u = try? container.decode(Int.self, forKey: .userId) {
            self.fromId = u
        } else {
            self.fromId = 0
        }

        self.text = (try? container.decode(String.self, forKey: .text)) ?? ""
        self.out = try? container.decode(Int.self, forKey: .out)
        self.readState = try? container.decode(Int.self, forKey: .readState)

        if let act = try? container.decode(VKRawMessageAction.self, forKey: .action) {
            self.action = act
        } else if let actType = try? container.decode(String.self, forKey: .action) {
            let mid = (try? container.decode(Int.self, forKey: .actionMid))
                ?? (try? container.decode(Int.self, forKey: .actionMemberId))
            let aText = try? container.decode(String.self, forKey: .actionText)
            self.action = VKRawMessageAction(type: actType, memberId: mid, text: aText)
        } else if let srcAct = try? container.decode(String.self, forKey: .sourceAct) {
            let mid = (try? container.decode(Int.self, forKey: .sourceMid))
                ?? Int((try? container.decode(String.self, forKey: .sourceMid)) ?? "")
            let aText = try? container.decode(String.self, forKey: .sourceText)
            self.action = VKRawMessageAction(type: srcAct, memberId: mid, text: aText)
        } else {
            self.action = nil
        }

        self.replyMessage = try? container.decode(VKRawReplyMessageData.self, forKey: .replyMessage)

        if var attContainer = try? container.nestedUnkeyedContainer(forKey: .attachments) {
            var atts: [VKRawAttachment] = []
            while !attContainer.isAtEnd {
                if let att = try? attContainer.decode(VKRawAttachment.self) {
                    atts.append(att)
                } else {
                    _ = try? attContainer.decode(DummyDiscardable.self)
                }
            }
            self.attachments = atts
        } else {
            self.attachments = nil
        }
    }
}

public struct VKRawMessageAction: Decodable {
    public let type: String
    public let memberId: Int?
    public let text: String?
    public let email: String?

    public init(type: String, memberId: Int? = nil, text: String? = nil, email: String? = nil) {
        self.type = type
        self.memberId = memberId
        self.text = text
        self.email = email
    }

    enum CodingKeys: String, CodingKey {
        case type
        case memberId = "member_id"
        case text, email
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = (try? container.decode(String.self, forKey: .type)) ?? "action"
        self.memberId = try? container.decode(Int.self, forKey: .memberId)
        self.text = try? container.decode(String.self, forKey: .text)
        self.email = try? container.decode(String.self, forKey: .email)
    }
}

public struct VKRawWallPost: Decodable {
    public let id: Int?
    public let toId: Int?
    public let fromId: Int?
    public let ownerId: Int?
    public let date: Double?
    public let text: String?
    public let authorName: String?
    public let authorAvatar: String?
    public let attachments: [VKRawAttachment]?

    enum CodingKeys: String, CodingKey {
        case id, text, attachments
        case toId = "to_id"
        case fromId = "from_id"
        case ownerId = "owner_id"
        case date
        case authorName = "author_name"
        case authorAvatar = "author_avatar"
    }

    public init(from decoder: Decoder) throws {
        let container = try? decoder.container(keyedBy: CodingKeys.self)
        self.id = try? container?.decode(Int.self, forKey: .id)
        self.toId = try? container?.decode(Int.self, forKey: .toId)
        self.fromId = try? container?.decode(Int.self, forKey: .fromId)
        self.ownerId = try? container?.decode(Int.self, forKey: .ownerId)
        if let d = try? container?.decode(Double.self, forKey: .date) {
            self.date = d
        } else if let dInt = try? container?.decode(Int.self, forKey: .date) {
            self.date = Double(dInt)
        } else {
            self.date = nil
        }
        self.text = try? container?.decode(String.self, forKey: .text)
        self.authorName = try? container?.decode(String.self, forKey: .authorName)
        self.authorAvatar = try? container?.decode(String.self, forKey: .authorAvatar)
        self.attachments = try? container?.decode([VKRawAttachment].self, forKey: .attachments)
    }
}

public struct VKRawGift: Decodable {
    public let id: Int?
    public let thumb256: String?
    public let thumb96: String?
    public let thumb48: String?

    enum CodingKeys: String, CodingKey {
        case id
        case thumb256 = "thumb_256"
        case thumb96 = "thumb_96"
        case thumb48 = "thumb_48"
    }
}

public struct VKRawMoneyTransfer: Decodable {
    public let id: Int?
    public let fromId: Int?
    public let toId: Int?
    public let status: Int?
    public let date: Double?
    public let amount: Int?
    public let currency: String?
    public let text: String?

    enum CodingKeys: String, CodingKey {
        case id, status, date, amount, currency, text, comment
        case fromId = "from_id"
        case toId = "to_id"
        case amountText = "amount_text"
    }

    public init(from decoder: Decoder) throws {
        let container = try? decoder.container(keyedBy: CodingKeys.self)
        self.id = try? container?.decode(Int.self, forKey: .id)
        self.fromId = (try? container?.decode(Int.self, forKey: .fromId)) ?? Int((try? container?.decode(String.self, forKey: .fromId)) ?? "")
        self.toId = (try? container?.decode(Int.self, forKey: .toId)) ?? Int((try? container?.decode(String.self, forKey: .toId)) ?? "")
        self.status = try? container?.decode(Int.self, forKey: .status)
        if let d = try? container?.decode(Double.self, forKey: .date) {
            self.date = d
        } else if let dInt = try? container?.decode(Int.self, forKey: .date) {
            self.date = Double(dInt)
        } else {
            self.date = nil
        }

        if let aInt = try? container?.decode(Int.self, forKey: .amount) {
            self.amount = aInt
        } else if let aStr = try? container?.decode(String.self, forKey: .amount), let p = Int(aStr.filter { $0.isNumber }) {
            self.amount = p
        } else if let aD = try? container?.decode(Double.self, forKey: .amount) {
            self.amount = Int(aD)
        } else if let aTxt = try? container?.decode(String.self, forKey: .amountText), let p = Int(aTxt.filter { $0.isNumber }) {
            self.amount = p
        } else {
            self.amount = nil
        }

        if let cStr = try? container?.decode(String.self, forKey: .currency) {
            self.currency = cStr
        } else if let cInt = try? container?.decode(Int.self, forKey: .currency) {
            self.currency = cInt == 643 ? "RUB" : "голосов"
        } else {
            self.currency = "голосов"
        }

        self.text = (try? container?.decode(String.self, forKey: .text)) ?? (try? container?.decode(String.self, forKey: .comment))
    }
}

public struct VKRawAttachment: Decodable {
    public let type: String?
    public let photo: VKRawPhoto?
    public let sticker: VKRawSticker?
    public let audioMessage: VKRawAudioMessage?
    public let doc: VKRawDoc?
    public let audio: VKRawAudio?
    public let video: VKRawVideo?
    public let wall: VKRawWallPost?
    public let gift: VKRawGift?
    public let moneyTransfer: VKRawMoneyTransfer?

    enum CodingKeys: String, CodingKey {
        case type, photo, sticker, doc, audio, video, wall, gift
        case audioMessage = "audio_message"
        case wallReply = "wall_reply"
        case moneyTransfer = "money_transfer"
    }

    public init(from decoder: Decoder) throws {
        let container = try? decoder.container(keyedBy: CodingKeys.self)
        self.type = try? container?.decode(String.self, forKey: .type)
        self.photo = try? container?.decode(VKRawPhoto.self, forKey: .photo)
        self.sticker = try? container?.decode(VKRawSticker.self, forKey: .sticker)
        self.audioMessage = try? container?.decode(VKRawAudioMessage.self, forKey: .audioMessage)
        self.doc = try? container?.decode(VKRawDoc.self, forKey: .doc)
        self.audio = try? container?.decode(VKRawAudio.self, forKey: .audio)
        self.video = try? container?.decode(VKRawVideo.self, forKey: .video)
        self.wall = (try? container?.decode(VKRawWallPost.self, forKey: .wall)) ?? (try? container?.decode(VKRawWallPost.self, forKey: .wallReply))
        self.gift = try? container?.decode(VKRawGift.self, forKey: .gift)
        self.moneyTransfer = try? container?.decode(VKRawMoneyTransfer.self, forKey: .moneyTransfer)
    }
}

public struct VKRawAudio: Decodable {
    public let id: Int?
    public let ownerId: Int?
    public let artist: String?
    public let title: String?
    public let duration: Int?
    public let url: String?

    enum CodingKeys: String, CodingKey {
        case id, artist, title, duration, url
        case ownerId = "owner_id"
    }
}

public struct VKRawVideo: Decodable {
    public let id: Int?
    public let ownerId: Int?
    public let title: String?
    public let description: String?
    public let duration: Int?
    public let image: [VKRawImageSize]?
    public let photo320: String?
    public let photo800: String?
    public let player: String?
    public let accessKey: String?
    public let files: [String: String]?

    enum CodingKeys: String, CodingKey {
        case id, title, description, duration, image, player, files
        case ownerId = "owner_id"
        case photo320 = "photo_320"
        case photo800 = "photo_800"
        case accessKey = "access_key"
    }

    public init(from decoder: Decoder) throws {
        let container = try? decoder.container(keyedBy: CodingKeys.self)
        self.id = try? container?.decodeIfPresent(Int.self, forKey: .id)
        self.ownerId = try? container?.decodeIfPresent(Int.self, forKey: .ownerId)
        self.title = try? container?.decodeIfPresent(String.self, forKey: .title)
        self.description = try? container?.decodeIfPresent(String.self, forKey: .description)
        self.duration = try? container?.decodeIfPresent(Int.self, forKey: .duration)
        self.image = try? container?.decodeIfPresent([VKRawImageSize].self, forKey: .image)
        self.photo320 = try? container?.decodeIfPresent(String.self, forKey: .photo320)
        self.photo800 = try? container?.decodeIfPresent(String.self, forKey: .photo800)
        self.player = try? container?.decodeIfPresent(String.self, forKey: .player)
        self.accessKey = try? container?.decodeIfPresent(String.self, forKey: .accessKey)
        self.files = try? container?.decodeIfPresent([String: String].self, forKey: .files)
    }
}

public struct VKRawSticker: Decodable {
    public let productId: Int?
    public let stickerId: Int?
    public let images: [VKRawImageSize]?
    public let imagesWithBackground: [VKRawImageSize]?
    public let animationUrl: String?

    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case stickerId = "sticker_id"
        case images
        case imagesWithBackground = "images_with_background"
        case animationUrl = "animation_url"
    }

    public init(from decoder: Decoder) throws {
        let container = try? decoder.container(keyedBy: CodingKeys.self)
        self.productId = try? container?.decode(Int.self, forKey: .productId)
        self.stickerId = try? container?.decode(Int.self, forKey: .stickerId)
        self.images = try? container?.decode([VKRawImageSize].self, forKey: .images)
        self.imagesWithBackground = try? container?.decode([VKRawImageSize].self, forKey: .imagesWithBackground)
        if let str = try? container?.decode(String.self, forKey: .animationUrl) {
            self.animationUrl = str.isEmpty ? nil : str
        } else {
            self.animationUrl = nil
        }
    }
}

public struct VKRawImageSize: Decodable {
    public let url: String?
    public let src: String?
    public let width: Int?
    public let height: Int?

    public var bestUrlString: String? {
        url ?? src
    }
}

public struct VKRawPhoto: Decodable {
    public let id: Int?
    public let ownerId: Int?
    public let accessKey: String?
    public let sizes: [VKRawPhotoSize]?
    public let text: String?
    public let photo75: String?
    public let photo130: String?
    public let photo604: String?
    public let photo807: String?
    public let photo1280: String?
    public let photo2560: String?

    enum CodingKeys: String, CodingKey {
        case id, pid
        case ownerId = "owner_id"
        case accessKey = "access_key"
        case sizes, text
        case photo75 = "photo_75"
        case photo130 = "photo_130"
        case photo604 = "photo_604"
        case photo807 = "photo_807"
        case photo1280 = "photo_1280"
        case photo2560 = "photo_2560"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let primaryId = try? container.decode(Int.self, forKey: .id)
        let altId = try? container.decode(Int.self, forKey: .pid)
        self.id = primaryId ?? altId
        self.ownerId = try? container.decode(Int.self, forKey: .ownerId)
        self.accessKey = try? container.decode(String.self, forKey: .accessKey)
        self.sizes = try? container.decode([VKRawPhotoSize].self, forKey: .sizes)
        self.text = try? container.decode(String.self, forKey: .text)
        self.photo75 = try? container.decode(String.self, forKey: .photo75)
        self.photo130 = try? container.decode(String.self, forKey: .photo130)
        self.photo604 = try? container.decode(String.self, forKey: .photo604)
        self.photo807 = try? container.decode(String.self, forKey: .photo807)
        self.photo1280 = try? container.decode(String.self, forKey: .photo1280)
        self.photo2560 = try? container.decode(String.self, forKey: .photo2560)
    }

    public var bestUrlString: String? {
        if let s = sizes?.last?.bestUrlString, !s.isEmpty { return s }
        return photo807 ?? photo604 ?? photo1280 ?? photo130 ?? photo75 ?? photo2560
    }
}

public struct VKRawPhotoSize: Decodable {
    public let type: String?
    public let url: String?
    public let src: String?
    public let width: Int?
    public let height: Int?

    public var bestUrlString: String? {
        url ?? src
    }
}

public struct VKRawAudioMessage: Decodable {
    public let duration: Int?
    public let linkOgg: String?
    public let linkMp3: String?

    enum CodingKeys: String, CodingKey {
        case duration
        case linkOgg = "link_ogg"
        case linkMp3 = "link_mp3"
    }
}

public struct VKRawDoc: Decodable {
    public let id: Int?
    public let ownerId: Int?
    public let title: String?
    public let size: Int?
    public let ext: String?
    public let url: String?
    public let accessKey: String?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case title, size, ext, url
        case accessKey = "access_key"
    }
}

public struct VKRawHistoryResponse: Decodable {
    public let count: Int?
    public let items: [VKRawMessageData]
    public let profiles: [VKUser]?
    public let groups: [VKGroup]?
    public let conversations: [VKRawConversationData]?

    enum CodingKeys: String, CodingKey {
        case count, items, profiles, groups, conversations
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.count = try? container.decode(Int.self, forKey: .count)
        self.profiles = try? container.decode([VKUser].self, forKey: .profiles)
        self.groups = try? container.decode([VKGroup].self, forKey: .groups)
        self.conversations = try? container.decode([VKRawConversationData].self, forKey: .conversations)

        if var itemsContainer = try? container.nestedUnkeyedContainer(forKey: .items) {
            var decodedItems: [VKRawMessageData] = []
            while !itemsContainer.isAtEnd {
                if let msg = try? itemsContainer.decode(VKRawMessageData.self) {
                    decodedItems.append(msg)
                } else {
                    _ = try? itemsContainer.decode(DummyDiscardable.self)
                }
            }
            self.items = decodedItems
        } else {
            self.items = []
        }
    }
}

private struct DummyDiscardable: Decodable {}

// MARK: - Sticker Pack Models
public struct VKStickerPack: Identifiable, Hashable, Codable {
    public let id: Int
    public let title: String
    public let iconURL: URL?
    public let stickers: [VKStickerItem]

    public init(id: Int, title: String, iconURL: URL? = nil, stickers: [VKStickerItem]) {
        self.id = id
        self.title = title
        self.iconURL = iconURL
        self.stickers = stickers
    }
}

public struct VKStickerItem: Identifiable, Hashable, Codable {
    public let id: Int
    public let packId: Int
    public let url: URL?
    public let animationURL: URL?

    public init(id: Int, packId: Int, url: URL? = nil, animationURL: URL? = nil) {
        self.id = id
        self.packId = packId
        self.url = url
        self.animationURL = animationURL
    }
}

public struct VKRawStickersResponse: Decodable {
    public let count: Int?
    public let items: [VKRawStickerPackItem]?
}

public struct VKRawStickerPackItem: Decodable {
    public let id: Int?
    public let title: String?
    public let name: String?
    public let photo: String?
    public let photo35: String?
    public let photo70: String?
    public let photo140: String?
    public let stickers: [VKRawStickerPackStickerItem]?

    enum CodingKeys: String, CodingKey {
        case id, title, name, photo, stickers
        case photo35 = "photo_35"
        case photo70 = "photo_70"
        case photo140 = "photo_140"
    }
}

public struct VKRawStickerPackStickerItem: Decodable {
    public let id: Int?
    public let stickerId: Int?
    public let images: [VKRawImageSize]?
    public let photo64: String?
    public let photo128: String?
    public let photo256: String?
    public let photo512: String?
    public let animationUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, images
        case stickerId = "sticker_id"
        case photo64 = "photo_64"
        case photo128 = "photo_128"
        case photo256 = "photo_256"
        case photo512 = "photo_512"
        case animationUrl = "animation_url"
    }

    public init(from decoder: Decoder) throws {
        let container = try? decoder.container(keyedBy: CodingKeys.self)
        self.id = try? container?.decode(Int.self, forKey: .id)
        self.stickerId = try? container?.decode(Int.self, forKey: .stickerId)
        self.images = try? container?.decode([VKRawImageSize].self, forKey: .images)
        self.photo64 = try? container?.decode(String.self, forKey: .photo64)
        self.photo128 = try? container?.decode(String.self, forKey: .photo128)
        self.photo256 = try? container?.decode(String.self, forKey: .photo256)
        self.photo512 = try? container?.decode(String.self, forKey: .photo512)
        if let str = try? container?.decode(String.self, forKey: .animationUrl) {
            self.animationUrl = str.isEmpty ? nil : str
        } else {
            self.animationUrl = nil
        }
    }

    public var effectiveId: Int {
        stickerId ?? id ?? 0
    }
}

// MARK: - Conversation Members & Settings
public struct VKChatMember: Identifiable, Hashable {
    public let id: Int // member_id / user_id
    public let isAdmin: Bool
    public let isOwner: Bool
    public let joinDate: Date?
    public var user: VKUser?

    public init(id: Int, isAdmin: Bool = false, isOwner: Bool = false, joinDate: Date? = nil, user: VKUser? = nil) {
        self.id = id
        self.isAdmin = isAdmin
        self.isOwner = isOwner
        self.joinDate = joinDate
        self.user = user
    }
}

public struct VKChatDetails: Hashable {
    public let title: String
    public let membersCount: Int
    public let ownerId: Int?
    public let photoURL: URL?
    public let members: [VKChatMember]

    public init(title: String, membersCount: Int, ownerId: Int? = nil, photoURL: URL? = nil, members: [VKChatMember]) {
        self.title = title
        self.membersCount = membersCount
        self.ownerId = ownerId
        self.photoURL = photoURL
        self.members = members
    }
}

public struct VKRawConversationMembersResponse: Decodable {
    public let count: Int?
    public let items: [VKRawConversationMemberItem]?
    public let profiles: [VKUser]?
    public let chatSettings: VKRawChatSettings?

    enum CodingKeys: String, CodingKey {
        case count, items, profiles
        case chatSettings = "chat_settings"
    }
}

public struct VKRawConversationMemberItem: Decodable {
    public let memberId: Int?
    public let invitedBy: Int?
    public let joinDate: Int?
    public let isAdmin: Bool?
    public let isOwner: Bool?

    enum CodingKeys: String, CodingKey {
        case memberId = "member_id"
        case invitedBy = "invited_by"
        case joinDate = "join_date"
        case isAdmin = "is_admin"
        case isOwner = "is_owner"
    }
}

// MARK: - User Media Items from Instance
public enum VKInstanceMediaType: String, CaseIterable, Identifiable {
    case photos = "Фото"
    case audio = "Музыка"
    case video = "Видео"
    case docs = "Документы"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .photos: return "photo.on.rectangle"
        case .audio: return "music.note"
        case .video: return "video"
        case .docs: return "doc.text.fill"
        }
    }
}

public struct VKRawDocsListResponse: Decodable {
    public let count: Int?
    public let items: [VKRawDoc]?
}

public struct VKInstanceMediaItem: Identifiable, Hashable {
    public let id: String
    public let type: VKInstanceMediaType
    public let title: String
    public let subtitle: String
    public let thumbnailURL: URL?
    public let attachmentCode: String

    public init(id: String, type: VKInstanceMediaType, title: String, subtitle: String, thumbnailURL: URL? = nil, attachmentCode: String) {
        self.id = id
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.thumbnailURL = thumbnailURL
        self.attachmentCode = attachmentCode
    }
}

public struct VKRawAudioListResponse: Decodable {
    public let count: Int?
    public let items: [VKRawAudio]?

    enum CodingKeys: String, CodingKey {
        case count, items
    }

    public init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            self.count = try? container.decode(Int.self, forKey: .count)
            self.items = try? container.decode([VKRawAudio].self, forKey: .items)
        } else if var arr = try? decoder.unkeyedContainer() {
            var res: [VKRawAudio] = []
            while !arr.isAtEnd {
                if let a = try? arr.decode(VKRawAudio.self) {
                    res.append(a)
                } else {
                    _ = try? arr.decode(DummyDiscardable.self)
                }
            }
            self.items = res
            self.count = res.count
        } else {
            self.count = 0
            self.items = []
        }
    }
}

public struct VKRawVideoListResponse: Decodable {
    public let count: Int?
    public let items: [VKRawVideo]?

    enum CodingKeys: String, CodingKey {
        case count, items
    }

    public init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            self.count = try? container.decode(Int.self, forKey: .count)
            self.items = try? container.decode([VKRawVideo].self, forKey: .items)
        } else if var arr = try? decoder.unkeyedContainer() {
            var res: [VKRawVideo] = []
            while !arr.isAtEnd {
                if let v = try? arr.decode(VKRawVideo.self) {
                    res.append(v)
                } else {
                    _ = try? arr.decode(DummyDiscardable.self)
                }
            }
            self.items = res
            self.count = res.count
        } else {
            self.count = 0
            self.items = []
        }
    }
}

public struct VKRawPhotosListResponse: Decodable {
    public let count: Int?
    public let items: [VKRawPhoto]?

    enum CodingKeys: String, CodingKey {
        case count, items
    }

    public init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            self.count = try? container.decode(Int.self, forKey: .count)
            self.items = try? container.decode([VKRawPhoto].self, forKey: .items)
        } else if var arr = try? decoder.unkeyedContainer() {
            var res: [VKRawPhoto] = []
            while !arr.isAtEnd {
                if let p = try? arr.decode(VKRawPhoto.self) {
                    res.append(p)
                } else {
                    _ = try? arr.decode(DummyDiscardable.self)
                }
            }
            self.items = res
            self.count = res.count
        } else {
            self.count = 0
            self.items = []
        }
    }
}

// MARK: - Photo Upload Models
public struct VKRawUploadServerResponse: Decodable {
    public let uploadUrl: String?

    enum CodingKeys: String, CodingKey {
        case uploadUrl = "upload_url"
    }
}

public struct VKRawUploadPhotoResult: Decodable {
    public let server: FlexibleIntOrString?
    public let photo: String?
    public let hash: String?

    enum CodingKeys: String, CodingKey {
        case server, photo, hash
    }
}

public struct FlexibleIntOrString: Decodable, CustomStringConvertible {
    public let stringValue: String
    public var description: String { stringValue }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            self.stringValue = String(intVal)
        } else if let strVal = try? container.decode(String.self) {
            self.stringValue = strVal
        } else {
            self.stringValue = ""
        }
    }
}

public struct VKRawSavePhotoResponse: Decodable {
    public let photos: [VKRawPhoto]

    enum CodingKeys: String, CodingKey {
        case items, photos, photo
    }

    public init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer() {
            if let arr = try? container.decode([VKRawPhoto].self) {
                self.photos = arr
                return
            } else if let single = try? container.decode(VKRawPhoto.self) {
                self.photos = [single]
                return
            }
        }
        if let keyed = try? decoder.container(keyedBy: CodingKeys.self) {
            if let items = try? keyed.decode([VKRawPhoto].self, forKey: .items) {
                self.photos = items
                return
            }
            if let photos = try? keyed.decode([VKRawPhoto].self, forKey: .photos) {
                self.photos = photos
                return
            }
            if let photo = try? keyed.decode(VKRawPhoto.self, forKey: .photo) {
                self.photos = [photo]
                return
            }
        }
        self.photos = []
    }
}

// MARK: - Conversation History Attachments
public struct VKRawHistoryAttachmentsResponse: Decodable {
    public let items: [VKRawHistoryAttachmentItem]?
    public let nextFrom: String?

    enum CodingKeys: String, CodingKey {
        case items
        case nextFrom = "next_from"
    }
}

public struct VKRawHistoryAttachmentItem: Decodable {
    public let messageId: Int?
    public let attachment: VKRawAttachment?

    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case attachment
    }
}


