import Foundation

/// Service to poll OpenVK-IM Long Poll endpoint (/nim)
@MainActor
public final class OpenVKLongPollService: ObservableObject {
    private var isRunning = false
    private var task: Task<Void, Never>?
    private let api: OpenVKAPIService

    public var onNewMessage: ((VKMessage) -> Void)?
    public var onPeerUpdated: ((Int) -> Void)?
    public var onMessagesRead: ((Int, Int, Bool) -> Void)? // peerId, localId, isOut
    public var onMessageFlagRead: ((Int, Int) -> Void)? // peerId, messageId
    public var onUserOnlineChanged: ((Int, Bool) -> Void)?
    public var onUserTyping: ((_ userId: Int, _ peerId: Int) -> Void)?
    public var onUserStoppedTyping: ((_ peerId: Int) -> Void)?
    public var onConnectionStateChange: ((Bool) -> Void)?

    public init(api: OpenVKAPIService? = nil) {
        self.api = api ?? OpenVKAPIService.shared
    }

    public func start() {
        guard !isRunning else { return }
        isRunning = true

        task = Task { [weak self] in
            guard let self = self else { return }
            while self.isRunning && !Task.isCancelled {
                do {
                    let serverInfo = try await self.api.getLongPollServer()
                    self.onConnectionStateChange?(true)
                    await self.pollLoop(server: serverInfo.server, key: serverInfo.key, initialTS: serverInfo.ts)
                } catch {
                    self.onConnectionStateChange?(false)
                    // Backoff on connection failure
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                }
            }
        }
    }

    public func stop() {
        isRunning = false
        task?.cancel()
        task = nil
    }

    private func pollLoop(server: String, key: String, initialTS: Int) async {
        var currentTS = initialTS

        while isRunning && !Task.isCancelled {
            var urlString = server.trimmingCharacters(in: .whitespacesAndNewlines)

            // Normalize URL format
            if urlString.starts(with: "/") {
                let base = api.serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                urlString = "\(base)\(urlString)"
            } else if !urlString.starts(with: "http://") && !urlString.starts(with: "https://") {
                let isHttp = api.serverURL.starts(with: "http://")
                urlString = "\(isHttp ? "http://" : "https://")\(urlString)"
            }

            guard var components = URLComponents(string: urlString) else {
                print("DEBUG: Invalid Long Poll URL: \(urlString)")
                break
            }

            components.queryItems = [
                URLQueryItem(name: "act", value: "a_check"),
                URLQueryItem(name: "key", value: key),
                URLQueryItem(name: "ts", value: "\(currentTS)"),
                URLQueryItem(name: "wait", value: "25"),
                URLQueryItem(name: "mode", value: "2"),
                URLQueryItem(name: "version", value: "3")
            ]

            guard let url = components.url else { break }

            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    continue
                }

                if let failed = json["failed"] as? Int {
                    if failed == 1, let newTS = json["ts"] as? Int {
                        currentTS = newTS
                        continue
                    } else {
                        // Key expired or PTS out of sync
                        break
                    }
                }

                if let newTS = json["ts"] as? Int {
                    currentTS = newTS
                }

                if let updates = json["updates"] as? [[Any]] {
                    for event in updates {
                        self.handleEvent(event)
                    }
                }
            } catch {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    private func handleEvent(_ event: [Any]) {
        guard let code = event.first as? Int else { return }

        switch code {
        case 3:
            // Message flags reset: [3, message_id, flags, peer_id]
            if event.count >= 4,
               let msgId = event[1] as? Int,
               let flags = event[2] as? Int,
               let peerId = event[3] as? Int {
                if (flags & 1) != 0 { // Unread flag (1) removed -> message is read!
                    self.onMessageFlagRead?(peerId, msgId)
                }
            }

        case 4:
            // New message
            // Version < 4 format: [4, msg_id, flags, peer_id, timestamp, subject, text, extra, ...]
            // Version >= 4 format: [4, msg_id, flags, peer_id, timestamp, text, extra, ...]
            guard event.count >= 6,
                  let msgId = event[1] as? Int,
                  let flags = event[2] as? Int,
                  let peerId = event[3] as? Int else { return }

            let rawTs = event[4]
            let ts: Double
            if let d = rawTs as? Double { ts = d }
            else if let i = rawTs as? Int { ts = Double(i) }
            else { ts = Date().timeIntervalSince1970 }

            var messageText = ""
            var extra: [String: Any]? = nil

            if event.count >= 7 {
                if let str6 = event[6] as? String {
                    // Version < 4 format: index 5 is subject, index 6 is text
                    messageText = str6
                    if event.count > 7 {
                        extra = event[7] as? [String: Any]
                    }
                    if messageText.isEmpty, let str5 = event[5] as? String, !str5.isEmpty {
                        messageText = str5
                    }
                } else if let dict6 = event[6] as? [String: Any] {
                    // Version >= 4 format: index 5 is text, index 6 is extra
                    messageText = event[5] as? String ?? ""
                    extra = dict6
                } else {
                    messageText = event[5] as? String ?? ""
                }
            } else {
                messageText = event[5] as? String ?? ""
            }

            let isOut = (flags & 2) != 0
            let isRead = (flags & 1) == 0

            var fromId = isOut ? (api.currentUser?.id ?? 0) : peerId
            var sticker: VKSticker? = nil
            var photo: VKPhotoAttachment? = nil
            var voiceMessage: VKVoiceAttachment? = nil
            var doc: VKDocAttachment? = nil
            var audioAttachment: VKAudioAttachment? = nil
            var videoAttachment: VKVideoAttachment? = nil
            var action: VKMessageAction? = nil

            if let extra = extra {
                let actType = (extra["source_act"] as? String) ?? (extra["act"] as? String)
                if let actType = actType {
                    let mid = (extra["source_mid"] as? Int) ?? Int(extra["source_mid"] as? String ?? "")
                    let actText = (extra["source_text"] as? String) ?? (extra["source_message"] as? String)
                    action = VKMessageAction(type: actType, memberId: mid, text: actText)
                }

                // Group chat sender ID
                if !isOut && peerId > 2_000_000_000 {
                    if let fStr = extra["from"] as? String, let f = Int(fStr) {
                        fromId = f
                    } else if let f = extra["from"] as? Int {
                        fromId = f
                    }
                }

                // Attachments in Long Poll
                let base = api.serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                if let attType = extra["attach1_type"] as? String {
                    switch attType {
                    case "sticker":
                        var sid: Int? = nil
                        if let s = extra["attach1"] as? Int { sid = s }
                        else if let sStr = extra["attach1"] as? String, let s = Int(sStr) { sid = s }

                        var pid: Int? = nil
                        if let p = extra["attach1_product_id"] as? Int { pid = p }
                        else if let pStr = extra["attach1_product_id"] as? String, let p = Int(pStr) { pid = p }

                        if let s = sid {
                            var animUrl: URL? = nil
                            if let aStr = extra["attach1_animation_url"] as? String {
                                animUrl = URL(string: aStr.starts(with: "http") ? aStr : "\(base)/\(aStr.trimmingCharacters(in: CharacterSet(charactersIn: "/")))")
                            }
                            let url = URL(string: "\(base)/sticker/1-\(s)-256.png") ?? URL(string: "https://vk.com/sticker/1-\(s)-256.png")
                            sticker = VKSticker(id: s, productId: pid, url: url, animationURL: animUrl)
                        }

                    case "photo":
                        let pid = (extra["attach1"] as? Int) ?? Int(extra["attach1"] as? String ?? "") ?? msgId
                        var pUrl: URL? = nil
                        if let uStr = extra["attach1_url"] as? String {
                            pUrl = URL(string: uStr)
                        }
                        photo = VKPhotoAttachment(id: pid, url: pUrl, text: "")

                    case "audio_message", "audiomsg":
                        voiceMessage = VKVoiceAttachment(duration: 0, audioURL: nil)

                    case "doc":
                        doc = VKDocAttachment(id: msgId, title: "Документ", size: 0, ext: "", url: nil)

                    case "audio":
                        let aid = (extra["attach1"] as? Int) ?? Int(extra["attach1"] as? String ?? "") ?? msgId
                        let artist = extra["attach1_author"] as? String ?? extra["attach1_artist"] as? String ?? "Аудиозапись"
                        let title = extra["attach1_title"] as? String ?? "Трек"
                        audioAttachment = VKAudioAttachment(id: aid, ownerId: 0, artist: artist, title: title, duration: 0, url: nil)

                    case "video":
                        let vid = (extra["attach1"] as? Int) ?? Int(extra["attach1"] as? String ?? "") ?? msgId
                        let title = extra["attach1_title"] as? String ?? "Видеозапись"
                        videoAttachment = VKVideoAttachment(id: vid, ownerId: 0, title: title, duration: 0, imageURL: nil)

                    default:
                        break
                    }
                }
            }

            let msg = VKMessage(
                id: msgId,
                peerId: peerId,
                fromId: fromId,
                date: Date(timeIntervalSince1970: ts),
                text: messageText,
                out: isOut,
                isRead: isRead,
                sticker: sticker,
                photo: photo,
                voiceMessage: voiceMessage,
                doc: doc,
                audio: audioAttachment,
                video: videoAttachment,
                action: action
            )

            self.onNewMessage?(msg)
            self.onPeerUpdated?(peerId)

        case 6:
            // Incoming read: [6, peer_id, local_id]
            if event.count >= 3,
               let peerId = event[1] as? Int,
               let localId = event[2] as? Int {
                self.onMessagesRead?(peerId, localId, false)
            }

        case 7:
            // Outgoing read: [7, peer_id, local_id]
            if event.count >= 3,
               let peerId = event[1] as? Int,
               let localId = event[2] as? Int {
                self.onMessagesRead?(peerId, localId, true)
            }

        case 51:
            // Chat parameters updated: [51, chat_id, self_change]
            if event.count >= 2, let chatId = event[1] as? Int {
                self.onPeerUpdated?(2_000_000_000 + chatId)
            }

        case 61:
            // User typing in direct PM (v0-v2): [61, user_id, flags]
            if event.count >= 2, let uid = event[1] as? Int {
                let flags = event.count > 2 ? (event[2] as? Int ?? 1) : 1
                if flags == 0 {
                    self.onUserStoppedTyping?(uid)
                } else {
                    self.onUserTyping?(uid, uid)
                }
            }

        case 62:
            // User typing in group chat (v0-v2): [62, user_id, chat_id]
            if event.count >= 3,
               let uid = event[1] as? Int,
               let chatId = event[2] as? Int {
                let peerId = 2_000_000_000 + chatId
                self.onUserTyping?(uid, peerId)
            }

        case 63:
            // User typing in v3+: [63, peer_id, user_ids, total_count, timestamp]
            if event.count >= 4,
               let peerId = event[1] as? Int,
               let totalCount = event[3] as? Int {
                if totalCount == 0 {
                    self.onUserStoppedTyping?(peerId)
                } else if let userIds = event[2] as? [Int], let firstUid = userIds.first {
                    self.onUserTyping?(firstUid, peerId)
                } else if let userIds = event[2] as? [Double], let firstUid = userIds.first {
                    self.onUserTyping?(Int(firstUid), peerId)
                } else if let userIds = event[2] as? [Any] {
                    var found = false
                    for u in userIds {
                        if let uid = u as? Int {
                            self.onUserTyping?(uid, peerId)
                            found = true
                            break
                        } else if let uid = u as? Double {
                            self.onUserTyping?(Int(uid), peerId)
                            found = true
                            break
                        }
                    }
                    if !found {
                        self.onUserTyping?(peerId, peerId)
                    }
                } else {
                    self.onUserTyping?(peerId, peerId)
                }
            }

        case 64:
            // Audio recording in v3+: [64, peer_id, user_ids, total_count, timestamp]
            if event.count >= 4,
               let peerId = event[1] as? Int {
                self.onUserTyping?(peerId, peerId)
            }


        case 8:
            // User online: [8, -user_id, flags, timestamp]
            if event.count >= 2, let uid = event[1] as? Int {
                self.onUserOnlineChanged?(abs(uid), true)
            }

        case 9:
            // User offline: [9, -user_id, flags, timestamp]
            if event.count >= 2, let uid = event[1] as? Int {
                self.onUserOnlineChanged?(abs(uid), false)
            }


        default:
            break
        }
    }
}
