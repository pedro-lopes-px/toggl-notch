import SwiftUI

@main
struct TogglNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("", id: "swiftui-host") {
            AppHostView()
        }
        .defaultSize(width: 1, height: 1)
        .windowStyle(.plain)
    }
}
