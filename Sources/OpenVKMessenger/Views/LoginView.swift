import SwiftUI

public struct LoginView: View {
    @ObservedObject var api: OpenVKAPIService
    @ObservedObject var store: MessengerStore
    @Environment(\.dismiss) private var dismiss

    public var isAddingAccount: Bool = false

    @State private var selectedTab: Int = 0 // 0: Password, 1: Token
    @State private var serverURL: String = "https://openvk.org"
    @State private var usernameInput: String = ""
    @State private var passwordInput: String = ""
    @State private var tokenInput: String = ""
    @State private var localError: String?

    public init(api: OpenVKAPIService, store: MessengerStore, isAddingAccount: Bool = false) {
        self.api = api
        self.store = store
        self.isAddingAccount = isAddingAccount
        self._serverURL = State(initialValue: api.serverURL)
    }

    public var body: some View {
        VStack(spacing: 24) {
            if isAddingAccount {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(VKColors.textSecondary)
                            .padding(6)
                            .background(VKColors.secondarySurface)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, -12)
            }
            // VK Brand Header
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(VKColors.accent)
                        .frame(width: 64, height: 64)
                        .shadow(color: VKColors.accent.opacity(0.3), radius: 8, x: 0, y: 4)

                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                }

                VStack(spacing: 4) {
                    Text("Вход в OpenVK")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(VKColors.textPrimary)

                    Text("Подключение к соцсети OpenVK")
                        .font(VKTypography.subhead)
                        .foregroundColor(VKColors.textSecondary)
                }
            }

            // Server Selector
            VStack(alignment: .leading, spacing: 6) {
                Text("Сервер OpenVK:")
                    .font(VKTypography.headline)
                    .foregroundColor(VKColors.textSecondary)

                HStack(spacing: 8) {
                    Image(systemName: "server.rack")
                        .foregroundColor(VKColors.textSecondary)

                    TextField("https://openvk.org", text: $serverURL)
                        .textFieldStyle(.plain)
                        .font(VKTypography.body)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(VKColors.secondarySurface)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(VKColors.separator, lineWidth: 0.8)
                )
            }

            // Auth Method Picker
            Picker("", selection: $selectedTab) {
                Text("Логин и пароль").tag(0)
                Text("По токену").tag(1)
            }
            .pickerStyle(.segmented)

            // Input Fields
            VStack(spacing: 12) {
                if selectedTab == 0 {
                    // Login / Email
                    HStack(spacing: 8) {
                        Image(systemName: "person")
                            .foregroundColor(VKColors.textSecondary)
                        TextField("Email или телефон", text: $usernameInput)
                            .textFieldStyle(.plain)
                            .font(VKTypography.body)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(VKColors.secondarySurface)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(VKColors.separator, lineWidth: 0.8)
                    )

                    // Password
                    HStack(spacing: 8) {
                        Image(systemName: "lock")
                            .foregroundColor(VKColors.textSecondary)
                        SecureField("Пароль", text: $passwordInput)
                            .textFieldStyle(.plain)
                            .font(VKTypography.body)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(VKColors.secondarySurface)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(VKColors.separator, lineWidth: 0.8)
                    )
                } else {
                    // Token Input
                    HStack(spacing: 8) {
                        Image(systemName: "key")
                            .foregroundColor(VKColors.textSecondary)
                        SecureField("Вставьте access_token...", text: $tokenInput)
                            .textFieldStyle(.plain)
                            .font(VKTypography.body)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(VKColors.secondarySurface)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(VKColors.separator, lineWidth: 0.8)
                    )
                }
            }

            // Error Display
            if let error = localError ?? api.lastAuthError {
                Text(error)
                    .font(VKTypography.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            // Submit Button
            Button(action: handleLogin) {
                HStack(spacing: 8) {
                    if api.isAuthenticating {
                        ProgressView()
                            .controlSize(.small)
                            .colorInvert()
                    }
                    Text(api.isAuthenticating ? "Авторизация..." : "Войти")
                        .font(VKTypography.headline)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(VKColors.accent)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .disabled(api.isAuthenticating)
        }
        .padding(32)
        #if os(macOS)
        .frame(width: 380)
        #else
        .frame(maxWidth: 440)
        #endif
        .background(VKColors.surface)
    }

    private func handleLogin() {
        localError = nil
        Task {
            do {
                if selectedTab == 0 {
                    guard !usernameInput.isEmpty, !passwordInput.isEmpty else {
                        localError = "Введите логин и пароль"
                        return
                    }
                    try await api.login(login: usernameInput, password: passwordInput, server: serverURL)
                } else {
                    guard !tokenInput.isEmpty else {
                        localError = "Введите access_token"
                        return
                    }
                    try await api.loginWithToken(token: tokenInput, server: serverURL)
                }

                // Successfully logged in! Register account & fetch conversations
                store.registerCurrentAccount()
                await store.fetchConversations()
                await store.fetchAdministeredGroups()
                dismiss()
            } catch {
                localError = error.localizedDescription
            }
        }
    }
}
