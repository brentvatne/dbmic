import SwiftUI

@main
struct dBMicApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No visible scenes — this is a menu-bar-only app.
        // All UI is in the NSStatusItem popover managed by AppDelegate.
        Settings {
            EmptyView()
        }
        .commands {
            // Suppress Cmd+, which would open an empty settings window
            CommandGroup(replacing: .appSettings) { }
        }
    }
}
