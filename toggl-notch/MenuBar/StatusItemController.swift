import AppKit
import SwiftUI

extension Color {
    var nsColor: NSColor {
        NSColor(self)
    }
}

/// Menu bar status item showing running timer or idle icon.
final class StatusItemController {
    private let store: NotchStore
    private let statusItem: NSStatusItem
    private var refreshTask: Task<Void, Never>?
    private var menuDelegate: StatusMenuDelegate?

    init(store: NotchStore, panelController: NotchPanelController) {
        self.store = store
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menuDelegate = StatusMenuDelegate(store: store, panelController: panelController)
        configure()
        startObserving()
    }

    deinit {
        refreshTask?.cancel()
    }

    private func configure() {
        guard let button = statusItem.button else { return }
        updateButton(button)
        let menu = StatusMenuBuilder.build(store: store, panelController: menuDelegate!.panelController)
        menu.delegate = menuDelegate
        statusItem.menu = menu
    }

    private func startObserving() {
        refreshTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                self?.refresh()
            }
        }
    }

    @MainActor
    func refresh() {
        guard store.showMenuBar, let button = statusItem.button else {
            statusItem.isVisible = store.showMenuBar
            return
        }
        statusItem.isVisible = true
        updateButton(button)
        statusItem.menu = StatusMenuBuilder.build(store: store, panelController: menuDelegate!.panelController)
    }

    @MainActor
    private func updateButton(_ button: NSStatusBarButton) {
        if let running = store.runningEntry, let project = store.runningProject {
            let elapsed = max(0, Int(Date.now.timeIntervalSince(running.startedAt)))
            let time = TimeFormatting.formatTimer(elapsed)
            let color = project.color.nsColor.usingColorSpace(.sRGB) ?? .gray
            let title = NSMutableAttributedString()
            title.append(NSAttributedString(
                string: "● ",
                attributes: [.foregroundColor: color, .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)]
            ))
            title.append(NSAttributedString(
                string: time,
                attributes: [.foregroundColor: NSColor.labelColor, .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)]
            ))
            button.attributedTitle = title
            button.image = nil
        } else if store.isOnboarding {
            button.attributedTitle = NSAttributedString(
                string: "Set up",
                attributes: [.font: NSFont.systemFont(ofSize: 12, weight: .medium)]
            )
            button.image = nil
        } else {
            button.attributedTitle = NSAttributedString(string: "")
            button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Toggl Notch")
            button.image?.isTemplate = true
        }
    }
}

final class StatusMenuDelegate: NSObject, NSMenuDelegate {
    let store: NotchStore
    let panelController: NotchPanelController

    init(store: NotchStore, panelController: NotchPanelController) {
        self.store = store
        self.panelController = panelController
    }

    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()
        let items = StatusMenuBuilder.makeItems(store: store, panelController: panelController)
        for item in items { menu.addItem(item) }
    }
}

enum StatusMenuBuilder {
    static func build(store: NotchStore, panelController: NotchPanelController) -> NSMenu {
        let menu = NSMenu()
        for item in makeItems(store: store, panelController: panelController) {
            menu.addItem(item)
        }
        return menu
    }

    @MainActor
    static func makeItems(store: NotchStore, panelController: NotchPanelController) -> [NSMenuItem] {
        var items: [NSMenuItem] = []

        if let running = store.runningEntry, let project = store.runningProject {
            let elapsed = max(0, Int(Date.now.timeIntervalSince(running.startedAt)))
            let header = NSMenuItem(
                title: "\(project.name)    \(TimeFormatting.formatTimer(elapsed))",
                action: nil,
                keyEquivalent: ""
            )
            header.isEnabled = false
            items.append(header)
        }

        let stop = NSMenuItem(title: "Stop Timer", action: #selector(NotchPanelController.menuStopTimer), keyEquivalent: "s")
        stop.target = panelController
        stop.keyEquivalentModifierMask = .command
        items.append(stop)
        items.append(.separator())

        let recents = NSMenuItem(title: "Continue Recent", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for entry in store.recentEntries {
            let item = NSMenuItem(
                title: entry.description,
                action: #selector(NotchPanelController.menuContinueEntry(_:)),
                keyEquivalent: ""
            )
            item.target = panelController
            item.representedObject = entry.id
            submenu.addItem(item)
        }
        recents.submenu = submenu
        items.append(recents)

        let newEntry = NSMenuItem(title: "New Entry…", action: #selector(NotchPanelController.menuNewEntry), keyEquivalent: "")
        newEntry.target = panelController
        items.append(newEntry)
        items.append(.separator())

        let open = NSMenuItem(title: "Open Toggl Notch", action: #selector(NotchPanelController.menuOpenPanel), keyEquivalent: "")
        open.target = panelController
        items.append(open)

        let settings = NSMenuItem(title: "Settings…", action: #selector(NotchPanelController.menuSettings), keyEquivalent: "")
        settings.target = panelController
        items.append(settings)

        let quit = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.keyEquivalentModifierMask = .command
        items.append(quit)

        return items
    }
}