import SwiftUI
#if canImport(AppKit)
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        CrashLoggerService.shared.install()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // Set dock icon from bundled icns or fallback image
        if let iconUrl = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let img = NSImage(contentsOf: iconUrl) {
            NSApp.applicationIconImage = img
        } else if let fallbackUrl = Bundle.main.url(forResource: "AppIcon_1024", withExtension: "png"),
                  let img = NSImage(contentsOf: fallbackUrl) {
            NSApp.applicationIconImage = img
        } else if let localImg = NSImage(contentsOfFile: "/Users/alexs/Documents/OpenVK Messenger/AppIcon_1024.png") {
            NSApp.applicationIconImage = localImg
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            for window in NSApp.windows {
                window.title = "OpenVK Messenger"
                window.makeKeyAndOrderFront(nil)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
#elseif canImport(UIKit)
import UIKit
import AVFoundation

final class iOSAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        CrashLoggerService.shared.install()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers, .allowAirPlay])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to configure AVAudioSession: \(error)")
        }

        // Ensure Documents/Themes folder exists for Files app
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let themesDir = docs.appendingPathComponent("Themes")
            try? FileManager.default.createDirectory(at: themesDir, withIntermediateDirectories: true)
        }
        return true
    }
}
#endif

@main
struct OpenVKMessengerApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #elseif os(iOS)
    @UIApplicationDelegateAdaptor(iOSAppDelegate.self) var appDelegate
    #endif
    @ObservedObject private var theme = ThemeManager.shared

    var body: some Scene {
        #if os(macOS)
        WindowGroup("OpenVK Messenger") {
            MainView()
                .environmentObject(theme)
                .preferredColorScheme(theme.baseTheme.isDark ? .dark : .light)
                .animation(.easeInOut(duration: 0.35), value: theme.baseTheme)
                .animation(.easeInOut(duration: 0.35), value: theme.accentPreset)
                .animation(.easeInOut(duration: 0.35), value: theme.customColor)
                .frame(minWidth: 880, minHeight: 580)
                .frame(idealWidth: 1040, idealHeight: 700)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        #else
        WindowGroup {
            MainView()
                .environmentObject(theme)
                .preferredColorScheme(theme.baseTheme.isDark ? .dark : .light)
                .animation(.easeInOut(duration: 0.35), value: theme.baseTheme)
                .animation(.easeInOut(duration: 0.35), value: theme.accentPreset)
                .animation(.easeInOut(duration: 0.35), value: theme.customColor)
        }
        #endif
    }
}

