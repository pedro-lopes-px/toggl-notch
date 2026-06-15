import AppKit
import SwiftUI

/// Owns the NSPanel: window configuration, screen placement, click-through
/// monitors, and key/blur handling. Contains no business logic.
final class NotchPanelController: NSObject, NSWindowDelegate {
    private let store: NotchStore
    private let panel: NotchPanel

    private var interactiveRect: CGRect = .zero
    private var lastShellGlobalRect: CGRect = .zero

    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var localKeyMonitor: Any?

    private var hoverExpandTask: Task<Void, Never>?
    private var hoverCollapseTask: Task<Void, Never>?

    private static let hoverExpandDelay: Duration = .milliseconds(200)
    private static let hoverCollapseDelay: Duration = .milliseconds(350)

    init(store: NotchStore) {
        self.store = store
        self.panel = NotchPanel(
            contentRect: NSRect(x: 0, y: 0, width: NotchMetrics.stageWidth, height: NotchMetrics.stageHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()

        configurePanel()
        installHostingView()
        positionOnNotchScreen()
        installMonitors()
        wireStore()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func show() {
        panel.orderFrontRegardless()
        panel.ignoresMouseEvents = true
    }

    // MARK: - Menu bar actions

    @objc func menuStopTimer() {
        store.stopTimer()
    }

    @objc func menuNewEntry() {
        summonPanel(route: .home)
    }

    @objc func menuOpenPanel() {
        summonPanel(route: .home)
    }

    @objc func menuSettings() {
        summonPanel(route: .settings(.general))
    }

    @objc func menuContinueEntry(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let entry = store.recentEntries.first(where: { $0.id == id })
        else { return }
        store.continueEntry(entry)
    }

    func summonPanel(route: PanelRoute) {
        let screen = notchScreen() ?? NSScreen.main
        if let screen {
            positionOnScreen(screen)
        }
        store.popToHome()
        if route != .home {
            store.push(route)
        }
        store.expand()
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
    }

    // MARK: - Configuration

    private func configurePanel() {
        panel.isFloatingPanel = true
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.delegate = self
    }

    private func installHostingView() {
        let hosting = NSHostingView(rootView: RootView().environment(store))
        hosting.frame = panel.contentRect(forFrameRect: panel.frame)
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
    }

    private func wireStore() {
        store.onExpansionChange = { [weak self] expanded in
            self?.handleExpansion(expanded)
        }
        store.onShellFrameChange = { [weak self] globalRect in
            self?.updateInteractiveRect(fromGlobal: globalRect)
        }
    }

    // MARK: - Placement

    private func notchScreen() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main
    }

    private func positionOnNotchScreen() {
        guard let screen = notchScreen() else { return }
        positionOnScreen(screen)
    }

    private func positionOnScreen(_ screen: NSScreen) {
        store.notchSize = notchSize(for: screen)
        let frame = screen.frame
        let origin = NSPoint(
            x: frame.midX - NotchMetrics.stageWidth / 2,
            y: frame.maxY - NotchMetrics.stageHeight
        )
        panel.setFrame(NSRect(origin: origin, size: panel.frame.size), display: true)
        updateInteractiveRect(fromGlobal: lastShellGlobalRect)
    }

    private func notchSize(for screen: NSScreen) -> CGSize {
        let height = screen.safeAreaInsets.top > 0 ? screen.safeAreaInsets.top : NotchMetrics.collapsedHeight
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            let width = screen.frame.width - left.width - right.width
            if width > 0 {
                return CGSize(width: width, height: height)
            }
        }
        return CGSize(width: NotchMetrics.collapsedWidth, height: NotchMetrics.collapsedHeight)
    }

    @objc private func screenParametersChanged() {
        positionOnNotchScreen()
    }

    // MARK: - Click-through

    private func installMonitors() {
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            self?.recomputeIgnoreMouse()
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.recomputeIgnoreMouse()
            return event
        }
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            self?.handleKeyDown(event)
        }
    }

    private func updateInteractiveRect(fromGlobal global: CGRect) {
        lastShellGlobalRect = global
        let panelFrame = panel.frame
        interactiveRect = CGRect(
            x: panelFrame.minX + global.minX,
            y: panelFrame.maxY - global.maxY,
            width: global.width,
            height: global.height
        )
        recomputeIgnoreMouse()
    }

    private func recomputeIgnoreMouse() {
        let inside = interactiveRect.contains(NSEvent.mouseLocation)
        if panel.ignoresMouseEvents == inside {
            panel.ignoresMouseEvents = !inside
        }
        handleHoverOpenTrigger(inside: inside)
    }

    private func handleHoverOpenTrigger(inside: Bool) {
        guard store.panelOpenTrigger == .hover else {
            cancelHoverExpand()
            cancelHoverCollapse()
            return
        }

        if store.isExpanded {
            cancelHoverExpand()
            if inside {
                cancelHoverCollapse()
            } else {
                scheduleHoverCollapse()
            }
        } else if inside {
            scheduleHoverExpand()
        } else {
            cancelHoverExpand()
        }
    }

    private func scheduleHoverExpand() {
        guard hoverExpandTask == nil else { return }
        hoverExpandTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.hoverExpandDelay)
            guard let self, !Task.isCancelled else { return }
            defer { hoverExpandTask = nil }
            guard store.panelOpenTrigger == .hover, !store.isExpanded else { return }
            let inside = interactiveRect.contains(NSEvent.mouseLocation)
            if inside {
                store.expand()
            }
        }
    }

    private func cancelHoverExpand() {
        hoverExpandTask?.cancel()
        hoverExpandTask = nil
    }

    private func scheduleHoverCollapse() {
        guard hoverCollapseTask == nil else { return }
        hoverCollapseTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.hoverCollapseDelay)
            guard let self, !Task.isCancelled else { return }
            defer { hoverCollapseTask = nil }
            guard store.panelOpenTrigger == .hover, store.isExpanded else { return }
            guard !interactiveRect.contains(NSEvent.mouseLocation) else { return }
            guard !mouseIsOverAppUI(excluding: panel) else { return }
            guard !store.isEditingRecentEntry else { return }
            store.collapse()
        }
    }

    private func cancelHoverCollapse() {
        hoverCollapseTask?.cancel()
        hoverCollapseTask = nil
    }

    private func mouseIsOverAppUI(excluding excluded: NSWindow) -> Bool {
        let mouse = NSEvent.mouseLocation
        return NSApp.windows.contains { window in
            window !== excluded
                && window.isVisible
                && window.alphaValue > 0
                && window.frame.contains(mouse)
        }
    }

    // MARK: - Key / blur

    private func handleExpansion(_ expanded: Bool) {
        if expanded {
            NSApp.activate()
            panel.makeKeyAndOrderFront(nil)
        } else {
            cancelHoverExpand()
            cancelHoverCollapse()
        }
        recomputeIgnoreMouse()
    }

    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        if event.keyCode == 53 {
            if store.isExpanded {
                store.handleEscape()
                return nil
            }
        }
        if event.modifierFlags.contains(.command),
           event.charactersIgnoringModifiers?.lowercased() == "q" {
            NSApp.terminate(nil)
            return nil
        }
        return event
    }

    func windowDidResignKey(_ notification: Notification) {
        if store.isExpanded {
            store.collapse()
        }
    }
}
