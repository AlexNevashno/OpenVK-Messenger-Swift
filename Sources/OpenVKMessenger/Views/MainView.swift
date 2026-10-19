import SwiftUI

public struct MainView: View {
    @StateObject private var store = MessengerStore.shared
    @ObservedObject private var theme = ThemeManager.shared
    @State private var showSettings: Bool = false
    @State private var showLogin: Bool = false
    @AppStorage("has_shown_openvk_disclaimer") private var hasShownDisclaimer: Bool = false
    @State private var showDisclaimerAlert: Bool = false

    public var body: some View {
        Group {
            if store.api.isAuthenticated {
                #if os(macOS)
                HStack(spacing: 0) {
                    ChatFoldersSidebarView(store: store)
                        .frame(maxHeight: .infinity)

                    Rectangle()
                        .fill(VKColors.separator)
                        .frame(width: 1)

                    HSplitView {
                        // Left sidebar: conversations
                        ConversationsSidebarView(
                            store: store,
                            showSettings: $showSettings,
                            showLogin: $showLogin
                        )
                        .frame(minWidth: 260, idealWidth: 300, maxWidth: 380)
                        .frame(maxHeight: .infinity)

                        // Right content: chat
                        ChatView(store: store)
                            .frame(minWidth: 480, maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .background(VKColors.surface)
                #else
                iOSMainView(
                    store: store,
                    showSettings: $showSettings,
                    showLogin: $showLogin
                )
                #endif
            } else {
                // Fullscreen Login Screen
                ZStack {
                    VKColors.background
                        .ignoresSafeArea()

                    LoginView(api: store.api, store: store)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 6)
                }
            }
        }
        .onAppear {
            if !hasShownDisclaimer {
                showDisclaimerAlert = true
            }
        }
        .alert("Предупреждение", isPresented: $showDisclaimerAlert) {
            Button("Понятно", role: .cancel) {
                hasShownDisclaimer = true
            }
        } message: {
            Text("OpenVK является любительской разработкой и никак не связан с ВКонтакте и компанией ООО \"ВК\".")
        }
        .sheet(isPresented: $showSettings) {
            SettingsModalView(
                api: store.api,
                store: store,
                onOpenLogin: {
                    showSettings = false
                    showLogin = true
                }
            )
        }
        .sheet(isPresented: $showLogin) {
            LoginView(api: store.api, store: store)
        }
    }
}
