import AppKit
import SwiftUI

/// Invisible keepalive host so AppKit does not quit when the borderless NSPanel is the only visible UI.
struct AppHostView: View {
    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .background(HostWindowConfigurator(identifier: "swiftui-host"))
    }
}

/// Locks the keepalive host window to a fixed 1×1 off-screen frame so AppKit does not
/// fight SwiftUI over content-size constraints (which causes infinite update-constraint passes).
private struct HostWindowConfigurator: NSViewRepresentable {
    let identifier: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
        let coordinator = context.coordinator
        DispatchQueue.main.async {
            Self.configureHostWindow(from: view, identifier: identifier, coordinator: coordinator)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            Self.configureHostWindow(from: nsView, identifier: identifier, coordinator: context.coordinator)
        }
    }

    private static func configureHostWindow(
        from view: NSView,
        identifier: String,
        coordinator: Coordinator
    ) {
        guard let window = view.window,
              window.identifier?.rawValue == identifier,
              !coordinator.didConfigure
        else { return }

        coordinator.didConfigure = true

        let fixedSize = NSSize(width: 1, height: 1)
        window.styleMask = [.borderless]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.contentMinSize = fixedSize
        window.contentMaxSize = fixedSize
        window.setContentSize(fixedSize)
        window.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))
        window.orderOut(nil)
    }

    final class Coordinator {
        var didConfigure = false
    }
}
