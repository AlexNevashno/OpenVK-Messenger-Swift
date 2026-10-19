import Foundation
import UserNotifications
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

@MainActor
public final class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    public static let shared = NotificationService()

    @Published public var isNotificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isNotificationsEnabled, forKey: "notifications_enabled")
        }
    }

    @Published public var isSoundEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isSoundEnabled, forKey: "notifications_sound")
        }
    }

    @Published public var showPreview: Bool {
        didSet {
            UserDefaults.standard.set(showPreview, forKey: "notifications_preview")
        }
    }

    public var onNotificationClicked: ((Int) -> Void)?

    private override init() {
        self.isNotificationsEnabled = UserDefaults.standard.object(forKey: "notifications_enabled") as? Bool ?? true
        self.isSoundEnabled = UserDefaults.standard.object(forKey: "notifications_sound") as? Bool ?? true
        self.showPreview = UserDefaults.standard.object(forKey: "notifications_preview") as? Bool ?? true
        super.init()

        UNUserNotificationCenter.current().delegate = self
        requestAuthorization()
    }

    public func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("DEBUG: Notifications auth error: \(error)")
            }
        }
    }

    public func postNotification(for message: VKMessage, conversation: VKConversation?) {
        guard isNotificationsEnabled else { return }

        // Don't notify for outgoing messages
        guard !message.out else { return }

        let content = UNMutableNotificationContent()

        let senderName = message.sender?.fullName ?? "Пользователь"
        let isGroup = conversation?.isChat ?? false

        let cleanText = message.text.replacingOccurrences(of: "&#8203;", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = cleanText.lowercased()

        let isGift = message.gift != nil || lower.contains("подарок") || lower.contains("подарил")
        let isVotesTransfer = message.moneyTransfer != nil || lower.contains("перевод голосов") || (lower.contains("голос") && (lower.contains("перевод") || lower.contains("вам перевели") || lower.contains("перевел")))

        if isGift {
            content.title = "🎁 Новый подарок"
            if !cleanText.isEmpty {
                content.body = "\(senderName): \(cleanText)"
            } else if let desc = message.gift?.description, !desc.isEmpty {
                content.body = "\(senderName): \(desc)"
            } else {
                content.body = "Вам отправлен подарок от \(senderName)!"
            }
        } else if isVotesTransfer {
            content.title = "💰 Перевод голосов"
            if let transfer = message.moneyTransfer {
                let comment = transfer.text.isEmpty ? "" : " («\(transfer.text)»)"
                content.body = "\(senderName) перевел(а) вам \(transfer.amount) \(transfer.currency)\(comment)"
            } else if !cleanText.isEmpty {
                content.body = "\(senderName): \(cleanText)"
            } else {
                content.body = "Вам поступил перевод голосов от \(senderName)!"
            }
        } else if isGroup, let title = conversation?.title {
            content.title = "\(senderName) (\(title))"
        } else {
            content.title = senderName
        }

        if !isGift && !isVotesTransfer {
            if showPreview {
                if !cleanText.isEmpty {
                    content.body = cleanText
                } else if message.photo != nil {
                    content.body = "📷 Фотография"
                } else if message.voiceMessage != nil {
                    content.body = "🎤 Голосовое сообщение"
                } else if message.audio != nil {
                    content.body = "🎵 Аудиозапись: \(message.audio?.title ?? "")"
                } else if message.doc != nil {
                    content.body = "📄 Документ: \(message.doc?.title ?? "")"
                } else if message.wallPost != nil {
                    content.body = "📢 Запись со стены"
                } else if message.sticker != nil {
                    content.body = "👾 Стикер"
                } else {
                    content.body = "📎 Новое сообщение"
                }
            } else {
                content.body = "Новое сообщение"
            }
        }

        if isSoundEnabled {
            content.sound = .default
            #if os(macOS)
            if NSApp.isActive {
                NSSound.beep()
            }
            #endif
        }

        content.userInfo = ["peerId": message.peerId]

        let request = UNNotificationRequest(
            identifier: "msg_\(message.id)_\(UUID().uuidString)",
            content: content,
            trigger: nil // immediate
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("DEBUG: Failed to deliver notification: \(error)")
            }
        }
    }

    public func updateDockBadge(unreadCount: Int) {
        DispatchQueue.main.async {
            #if os(macOS)
            if unreadCount > 0 {
                NSApp.dockTile.badgeLabel = "\(unreadCount)"
            } else {
                NSApp.dockTile.badgeLabel = nil
            }
            #else
            UNUserNotificationCenter.current().setBadgeCount(unreadCount)
            #endif
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner, list, sound, and badge even when app is in foreground
        completionHandler([.banner, .list, .sound, .badge])
    }

    nonisolated public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let peerId = userInfo["peerId"] as? Int {
            Task { @MainActor in
                #if os(macOS)
                NSApp.activate(ignoringOtherApps: true)
                #endif
                NotificationService.shared.onNotificationClicked?(peerId)
            }
        }
        completionHandler()
    }
}
