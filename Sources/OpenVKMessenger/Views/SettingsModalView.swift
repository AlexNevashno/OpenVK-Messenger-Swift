import SwiftUI
import UniformTypeIdentifiers

public enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "Основные"
    case appearance = "Внешний вид"
    case notifications = "Уведомления"
    case blacklist = "Чёрный список"
    case communities = "Сообщества"
    case about = "О программе"

    public var id: String { rawValue }
}

public struct SettingsModalView: View {
    @ObservedObject var api: OpenVKAPIService
    @ObservedObject var store: MessengerStore
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject var notifications = NotificationService.shared
    public var onOpenLogin: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: SettingsTab = .appearance
    @State private var serverInput: String = ""
    @State private var tokenInput: String = ""
    @State private var previewThemePack: VKThemePack? = nil

    public init(api: OpenVKAPIService, store: MessengerStore, onOpenLogin: (() -> Void)? = nil) {
        self.api = api
        self.store = store
        self.onOpenLogin = onOpenLogin
        self._serverInput = State(initialValue: api.serverURL)
        self._tokenInput = State(initialValue: api.token)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Настройки")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(VKColors.textPrimary)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(VKColors.textSecondary)
                        .padding(6)
                        .background(VKColors.secondarySurface)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 12)

            // Tabs Bar
            HStack(spacing: 20) {
                ForEach(SettingsTab.allCases) { tab in
                    Button(action: { selectedTab = tab }) {
                        VStack(spacing: 8) {
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
                                .foregroundColor(selectedTab == tab ? VKColors.accent : VKColors.textSecondary)

                            // Underline indicator
                            Rectangle()
                                .fill(selectedTab == tab ? VKColors.accent : Color.clear)
                                .frame(height: 2.5)
                                .cornerRadius(1.5)
                        }
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 22)
            .frame(height: 38)
            .fixedSize(horizontal: false, vertical: true)

            Divider()
                .background(VKColors.separator)

            // Tab Content
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    switch selectedTab {
                    case .appearance:
                        appearanceTabContent
                    case .general:
                        generalTabContent
                    case .notifications:
                        notificationsTabContent
                    case .blacklist:
                        blacklistTabContent
                    case .communities:
                        communitiesTabContent
                    case .about:
                        aboutTabContent
                    }
                }
                .padding(22)
            }
        }
        #if os(macOS)
        .frame(width: 580, height: 490)
        #endif
        .background(VKColors.surface)
        .preferredColorScheme(theme.baseTheme.isDark ? .dark : .light)
        .animation(.easeInOut(duration: 0.35), value: theme.baseTheme)
        .animation(.easeInOut(duration: 0.35), value: theme.accentPreset)
        .animation(.easeInOut(duration: 0.35), value: theme.customColor)
        .sheet(item: $previewThemePack) { pack in
            ThemePreviewModalView(themePack: pack)
        }
    }

    // MARK: - Appearance Tab (Telegram-grade Theme Customization)

    private var appearanceTabContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Section 1: Theme Presets & Live Preview
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Темы оформления")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(VKColors.textPrimary)

                    Spacer()

                    #if os(macOS)
                    Button(action: {
                        if let imported = theme.importTelegramThemeFile() {
                            previewThemePack = imported
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.down.doc.fill")
                                .font(.system(size: 11))
                            Text("Портировать из Telegram...")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(VKColors.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(VKColors.accent.opacity(0.12))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("Импорт готовой темы Telegram Desktop (.tdesktop-theme, .palette, .attheme)")
                    #endif

                    Button(action: {
                        previewThemePack = theme.currentThemePack
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "eye.fill")
                                .font(.system(size: 11))
                            Text("Предпросмотр...")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(VKColors.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(VKColors.secondarySurface)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(VKThemePack.allPresets) { preset in
                            presetThemeCard(preset: preset)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Divider().background(VKColors.separator)

            // Section 2: Chat Wallpaper
            VStack(alignment: .leading, spacing: 14) {
                Text("Фоновое изображение чатов")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(VKColors.textPrimary)

                HStack(spacing: 14) {
                    // Wallpaper Preview Box
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(theme.backgroundColor)

                        if let img = theme.chatWallpaperImage {
                            if theme.wallpaperPattern == "telegram_doodles" {
                                Image(platformImage: img)
                                    .resizable(resizingMode: .tile)
                                    .opacity(theme.wallpaperOpacity)
                            } else {
                                Image(platformImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .opacity(theme.wallpaperOpacity)
                            }
                        } else {
                            Image(systemName: "photo")
                                .font(.system(size: 20))
                                .foregroundColor(VKColors.textSecondary)
                        }
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(VKColors.separator, lineWidth: 1))

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Button(action: chooseWallpaperImage) {
                                Label("Выбрать с Mac...", systemImage: "arrow.up.doc")
                                    .font(.system(size: 12, weight: .medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(VKColors.secondarySurface)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)

                            Button(action: {
                                theme.setTelegramDoodlesWallpaper()
                            }) {
                                Label("Telegram Doodles", systemImage: "sparkles")
                                    .font(.system(size: 12, weight: .medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(theme.wallpaperPattern == "telegram_doodles" ? VKColors.accent.opacity(0.18) : VKColors.secondarySurface)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)

                            if theme.chatWallpaperImage != nil {
                                Button(action: {
                                    theme.removeWallpaper()
                                }) {
                                    Text("Удалить")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.red)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // Opacity slider
                        HStack(spacing: 10) {
                            Text("Прозрачность:")
                                .font(.system(size: 11.5))
                                .foregroundColor(VKColors.textSecondary)
                                .frame(width: 85, alignment: .leading)
                            Slider(value: Binding(
                                get: { theme.wallpaperOpacity },
                                set: { theme.setWallpaperOpacity($0) }
                            ), in: 0.1...1.0)
                            Text("\(Int(theme.wallpaperOpacity * 100))%")
                                .font(.system(size: 11))
                                .foregroundColor(VKColors.textSecondary)
                                .frame(width: 35, alignment: .trailing)
                        }

                        // Blur slider
                        HStack(spacing: 10) {
                            Text("Размытие:")
                                .font(.system(size: 11.5))
                                .foregroundColor(VKColors.textSecondary)
                                .frame(width: 85, alignment: .leading)
                            Slider(value: Binding(
                                get: { theme.wallpaperBlur },
                                set: { theme.setWallpaperBlur($0) }
                            ), in: 0.0...20.0)
                            Text("\(Int(theme.wallpaperBlur)) px")
                                .font(.system(size: 11))
                                .foregroundColor(VKColors.textSecondary)
                                .frame(width: 35, alignment: .trailing)
                        }
                    }
                }
            }

            Divider().background(VKColors.separator)

            // Section 3: Message Bubbles & Strokes
            VStack(alignment: .leading, spacing: 14) {
                Text("Баблы сообщений и обводка интерфейса")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(VKColors.textPrimary)

                HStack(spacing: 18) {
                    // Incoming bubble color
                    Button(action: {
                        #if os(macOS)
                        ColorPanelObserver.shared.open(currentColor: theme.bubbleIncomingColor) { newColor in
                            theme.setBubbleIncomingColor(newColor)
                        }
                        #endif
                    }) {
                        HStack(spacing: 8) {
                            Circle().fill(theme.bubbleIncomingColor).frame(width: 20, height: 20)
                                .overlay(Circle().stroke(Color.gray.opacity(0.4), lineWidth: 1))
                            Text("Входящие сообщения")
                                .font(.system(size: 12))
                                .foregroundColor(VKColors.textPrimary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(VKColors.secondarySurface)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)

                    // Outgoing bubble color
                    Button(action: {
                        #if os(macOS)
                        ColorPanelObserver.shared.open(currentColor: theme.bubbleOutgoingColor) { newColor in
                            theme.setBubbleOutgoingColor(newColor)
                        }
                        #endif
                    }) {
                        HStack(spacing: 8) {
                            Circle().fill(theme.bubbleOutgoingColor).frame(width: 20, height: 20)
                                .overlay(Circle().stroke(Color.gray.opacity(0.4), lineWidth: 1))
                            Text("Исходящие сообщения")
                                .font(.system(size: 12))
                                .foregroundColor(VKColors.textPrimary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(VKColors.secondarySurface)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }

                // Stroke Settings
                HStack(spacing: 18) {
                    Button(action: {
                        #if os(macOS)
                        ColorPanelObserver.shared.open(currentColor: theme.bubbleStrokeColor ?? Color.gray) { newColor in
                            theme.setBubbleStroke(color: newColor, width: max(0.8, theme.bubbleStrokeWidth))
                        }
                        #endif
                    }) {
                        HStack(spacing: 8) {
                            Circle().fill(theme.bubbleStrokeColor ?? Color.clear).frame(width: 20, height: 20)
                                .overlay(Circle().stroke(Color.gray.opacity(0.6), lineWidth: 1.5))
                            Text("Цвет обводки")
                                .font(.system(size: 12))
                                .foregroundColor(VKColors.textPrimary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(VKColors.secondarySurface)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 8) {
                        Text("Толщина:")
                            .font(.system(size: 11.5))
                            .foregroundColor(VKColors.textSecondary)
                        Slider(value: Binding(
                            get: { theme.bubbleStrokeWidth },
                            set: { theme.setBubbleStroke(color: theme.bubbleStrokeColor, width: $0) }
                        ), in: 0.0...3.0)
                        .frame(width: 100)
                        Text(String(format: "%.1f px", theme.bubbleStrokeWidth))
                            .font(.system(size: 11))
                            .foregroundColor(VKColors.textSecondary)
                    }
                }
            }

            Divider().background(VKColors.separator)

            // Section 4: Accent Colors
            VStack(alignment: .leading, spacing: 14) {
                Text("Акцентный цвет интерфейса")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(VKColors.textPrimary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(VKAccentPreset.allCases) { preset in
                            accentColorCircle(preset: preset)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if theme.accentPreset == .custom {
                    HStack(spacing: 12) {
                        ColorPicker("Свой цвет акцента", selection: Binding(
                            get: { theme.customColor },
                            set: { theme.setCustomColor($0) }
                        ), supportsOpacity: false)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(VKColors.textPrimary)

                        #if os(macOS)
                        Button(action: {
                            ColorPanelObserver.shared.open(currentColor: theme.customColor) { newColor in
                                theme.setCustomColor(newColor)
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "paintpalette.fill")
                                Text("Палитра macOS...")
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(VKColors.accent)
                        }
                        .buttonStyle(.plain)
                        #endif
                    }
                    .padding(.vertical, 2)
                }
            }

            Divider().background(VKColors.separator)

            // Section 5: Theme Pack Export / Import / Share in Chat
            VStack(alignment: .leading, spacing: 10) {
                Text("Управление темами (.themepack)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(VKColors.textPrimary)

                Text("Для отправки через сайт OpenVK тема сохраняется как .themepack.txt (OpenVK разрешает .txt до 20 МБ). Также можно мгновенно отправить тему другу прямо в чат.")
                    .font(.system(size: 11.5))
                    .foregroundColor(VKColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    #if os(macOS)
                    Button(action: {
                        theme.saveThemeToFile()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.down")
                            Text("Сохранить в файл (.txt / .themepack)...")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(VKColors.secondarySurface)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        theme.loadThemeFromFile { loaded in
                            if let pack = loaded {
                                previewThemePack = pack
                            }
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Импорт .themepack...")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(VKColors.secondarySurface)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        if let imported = theme.importTelegramThemeFile() {
                            previewThemePack = imported
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.doc.fill")
                            Text("Портировать тему Telegram...")
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(VKColors.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(VKColors.accent.opacity(0.12))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    #endif

                    if store.selectedPeerId != nil {
                        Button(action: {
                            theme.shareThemeInChat(store: store)
                            dismiss()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "paperplane.fill")
                                Text("Поделиться в чате")
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(VKColors.accent)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func chooseWallpaperImage() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.title = "Выбрать фоновое изображение для чатов"
        panel.allowedContentTypes = [
            .png,
            .jpeg,
            UTType(filenameExtension: "webp") ?? .image,
            UTType(filenameExtension: "heic") ?? .image
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url, let img = PlatformImage(contentsOf: url) {
            theme.setCustomWallpaper(image: img)
        }
        #endif
    }

    @ViewBuilder
    private func presetThemeCard(preset: VKThemePack) -> some View {
        let isSelected = theme.currentThemePack.id == preset.id || theme.currentThemePack.name == preset.name

        Button(action: {
            previewThemePack = preset
        }) {
            VStack(spacing: 6) {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: preset.surfaceHex) ?? .gray)

                    VStack(alignment: .leading, spacing: 6) {
                        // Header bar
                        Rectangle()
                            .fill(Color(hex: preset.secondarySurfaceHex) ?? .gray)
                            .frame(height: 12)

                        // Message bubbles
                        HStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(hex: preset.bubbleIncomingHex) ?? .white)
                                .frame(width: 44, height: 14)
                            Spacer()
                        }
                        HStack {
                            Spacer()
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(hex: preset.bubbleOutgoingHex) ?? Color(hex: preset.accentHex) ?? .blue)
                                .frame(width: 50, height: 14)
                        }
                    }
                    .padding(6)

                    if isSelected {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: preset.accentHex) ?? VKColors.accent)
                                    .padding(4)
                            }
                        }
                    }
                }
                .frame(width: 96, height: 74)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? (Color(hex: preset.accentHex) ?? VKColors.accent) : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                )

                Text(preset.name)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? VKColors.accent : VKColors.textPrimary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    private func cardBackgroundColor(for base: VKBaseTheme) -> Color {
        switch base {
        case .classic: return Color.white
        case .day: return Color(red: 0.88, green: 0.90, blue: 0.92)
        case .tinted: return Color(red: 0.12, green: 0.17, blue: 0.23)
        case .night: return Color(red: 0.08, green: 0.08, blue: 0.09)
        }
    }

    private func cardAvatarColor(for base: VKBaseTheme) -> Color {
        switch base {
        case .classic: return Color(red: 0.55, green: 0.58, blue: 0.62)
        case .day: return Color(red: 0.45, green: 0.50, blue: 0.58)
        case .tinted: return Color(red: 0.25, green: 0.35, blue: 0.45)
        case .night: return Color(red: 0.22, green: 0.22, blue: 0.25)
        }
    }

    private func cardLineColor(for base: VKBaseTheme) -> Color {
        switch base {
        case .classic: return Color(red: 0.75, green: 0.77, blue: 0.80)
        case .day: return Color(red: 0.60, green: 0.65, blue: 0.70)
        case .tinted: return Color(red: 0.30, green: 0.40, blue: 0.50)
        case .night: return Color(red: 0.25, green: 0.25, blue: 0.28)
        }
    }

    @ViewBuilder
    private func accentColorCircle(preset: VKAccentPreset) -> some View {
        let isSelected = theme.accentPreset == preset

        Button(action: {
            theme.setAccentPreset(preset)
            #if os(macOS)
            if preset == .custom {
                ColorPanelObserver.shared.open(currentColor: theme.customColor) { newColor in
                    theme.setCustomColor(newColor)
                }
            }
            #endif
        }) {
            VStack(spacing: 6) {
                ZStack {
                    if preset == .custom {
                        Circle()
                            .fill(
                                AngularGradient(
                                    gradient: Gradient(colors: [.red, .yellow, .green, .blue, .purple, .red]),
                                    center: .center
                                )
                            )
                            .frame(width: 32, height: 32)
                    } else {
                        Circle()
                            .fill(preset.color)
                            .frame(width: 32, height: 32)
                    }

                    if isSelected {
                        Circle()
                            .stroke(Color.white, lineWidth: 2.5)
                            .frame(width: 36, height: 36)
                            .shadow(color: Color.black.opacity(0.3), radius: 2)

                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 38, height: 38)

                Text(preset.rawValue)
                    .font(.system(size: 10.5))
                    .foregroundColor(isSelected ? VKColors.accent : VKColors.textSecondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Notifications Tab

    private var notificationsTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle(isOn: $notifications.isNotificationsEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Включить уведомления на рабочем столе")
                        .font(VKTypography.headline)
                    Text("Показывать системные баннеры macOS при входящих сообщениях")
                        .font(VKTypography.caption)
                        .foregroundColor(VKColors.textSecondary)
                }
            }

            Divider()

            Toggle(isOn: $notifications.isSoundEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Звук уведомления")
                        .font(VKTypography.headline)
                    Text("Воспроизводить системный сигнал при получении нового сообщения")
                        .font(VKTypography.caption)
                        .foregroundColor(VKColors.textSecondary)
                }
            }

            Divider()

            Toggle(isOn: $notifications.showPreview) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Показывать текст сообщения")
                        .font(VKTypography.headline)
                    Text("Отображать текст или описание вложения прямо в баннере")
                        .font(VKTypography.caption)
                        .foregroundColor(VKColors.textSecondary)
                }
            }
        }
    }

    // MARK: - General Tab

    private var generalTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Account Status
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(api.isAuthenticated ? "Вы вошли как:" : "Статус аккаунта:")
                        .font(VKTypography.caption)
                        .foregroundColor(VKColors.textSecondary)

                    Text(api.isAuthenticated ? (api.currentUser?.fullName ?? "Пользователь OpenVK") : "Не авторизован")
                        .font(VKTypography.headline)
                        .foregroundColor(VKColors.textPrimary)
                }

                Spacer()

                Button(api.isAuthenticated ? "Сменить аккаунт" : "Войти...") {
                    dismiss()
                    onOpenLogin?()
                }
                .buttonStyle(.borderedProminent)
                .tint(VKColors.accent)
            }
            .padding(12)
            .background(VKColors.secondarySurface)
            .cornerRadius(10)

            // Web Session Status (Required for Document / File Uploads)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: (api.chandlerSessCookie != nil || api.savedPassword != nil) ? "checkmark.shield.fill" : "exclamationmark.shield")
                        .foregroundColor((api.chandlerSessCookie != nil || api.savedPassword != nil) ? .green : .orange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Сессия отправки файлов (OpenVK Web)")
                            .font(VKTypography.subhead)
                            .foregroundColor(VKColors.textPrimary)

                        Text((api.chandlerSessCookie != nil || api.savedPassword != nil) ? "Активна (отправка тем и документов доступна)" : "Не подключена (требуется вход по логину/паролю)")
                            .font(VKTypography.caption)
                            .foregroundColor(VKColors.textSecondary)
                    }

                    Spacer()

                    if api.chandlerSessCookie == nil && api.savedPassword == nil {
                        Button("Подключить...") {
                            dismiss()
                            onOpenLogin?()
                        }
                        .font(VKTypography.caption)
                        .buttonStyle(.bordered)
                    }
                }
                .padding(10)
                .background(VKColors.secondarySurface)
                .cornerRadius(8)
            }

            // Server URL
            VStack(alignment: .leading, spacing: 4) {
                Text("Адрес сервера OpenVK:")
                    .font(VKTypography.headline)
                    .foregroundColor(VKColors.textPrimary)

                TextField("https://openvk.org", text: $serverInput)
                    .textFieldStyle(.roundedBorder)
                    .font(VKTypography.body)
            }

            // Token Input
            VStack(alignment: .leading, spacing: 4) {
                Text("Access Token:")
                    .font(VKTypography.headline)
                    .foregroundColor(VKColors.textPrimary)

                SecureField("Введите токен вручную...", text: $tokenInput)
                    .textFieldStyle(.roundedBorder)
                    .font(VKTypography.body)

                Text("Для работы диалогов требуется токен с правами messages, offline.")
                    .font(VKTypography.caption)
                    .foregroundColor(VKColors.textSecondary)
            }

            Button("Сохранить настройки сервера") {
                api.serverURL = serverInput
                if !tokenInput.isEmpty {
                    api.saveCredentials(token: tokenInput, server: serverInput)
                }
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(VKColors.accent)
            .padding(.top, 4)
        }
    }

    // MARK: - Blacklist & Communities Tabs

    private var blacklistTabContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "hand.raised.slash.fill")
                .font(.system(size: 32))
                .foregroundColor(VKColors.textSecondary)
            Text("Чёрный список пуст")
                .font(VKTypography.headline)
                .foregroundColor(VKColors.textPrimary)
            Text("Заблокированные пользователи будут отображаться здесь.")
                .font(VKTypography.caption)
                .foregroundColor(VKColors.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
    }

    private var communitiesTabContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 32))
                .foregroundColor(VKColors.textSecondary)
            Text("Сообщества")
                .font(VKTypography.headline)
                .foregroundColor(VKColors.textPrimary)
            Text("Сообщения от администрируемых сообществ появятся в следующих версиях.")
                .font(VKTypography.caption)
                .foregroundColor(VKColors.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
    }

    private var aboutTabContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 48))
                .foregroundColor(VKColors.accent)
                .padding(.top, 10)

            Text("OpenVK Messenger")
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(VKColors.textPrimary)

            Text("Версия 1.0 (Build 2026)")
                .font(.system(size: 13))
                .foregroundColor(VKColors.textSecondary)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 14))
                    Text("Правовая информация")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(VKColors.textPrimary)
                }

                Text("OpenVK является любительской разработкой и никак не связан с ВКонтакте и компанией ООО \"ВК\".")
                    .font(.system(size: 13))
                    .foregroundColor(VKColors.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(VKColors.secondarySurface)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(VKColors.separator, lineWidth: 1)
            )

            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 250)
    }
}
