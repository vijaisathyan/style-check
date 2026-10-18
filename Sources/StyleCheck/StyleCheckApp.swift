import AppKit
import SwiftUI

@main
struct StyleCheckApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var modelManager = ModelManager()
    @StateObject private var library = LibraryModel()
    @StateObject private var chat = ChatModel()

    var body: some Scene {
        WindowGroup("Style Check") {
            ContentView()
                .environmentObject(modelManager)
                .environmentObject(library)
                .environmentObject(chat)
                .frame(minWidth: 760, minHeight: 520)
        }
        .defaultSize(width: 1040, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Chat") { chat.clear() }
                    .keyboardShortcut("n", modifiers: .command)
            }
            CommandGroup(after: .newItem) {
                Button("Add Style Guide…") { library.isShowingImporter = true }
                    .keyboardShortcut("o", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(modelManager)
                .environmentObject(library)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Needed when running straight from Swift Package Manager / Xcode,
        // so the app gets a Dock icon and a key window.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
