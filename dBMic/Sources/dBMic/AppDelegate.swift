import AppKit
import Combine
import dBMicCore
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var panel: PopoverPanel?
    private let monitor = AudioLevelMonitor()
    private var hostingView: NSHostingView<MenuBarView>!
    private var eventMonitor: Any?
    private var rightClickMonitor: Any?
    private var statusCancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("[dBMic] applicationDidFinishLaunching")
        setupStatusItem()
        setupEventMonitor()
        setupRightClickMenu()
        requestPermissionAndStart()
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        guard let button = statusItem.button else { return }

        let menuBarView = MenuBarView(monitor: monitor)
        hostingView = PassthroughHostingView(rootView: menuBarView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 24, height: button.bounds.height)

        button.addSubview(hostingView)
        button.frame = hostingView.frame
        button.action = #selector(togglePopover(_:))
        button.target = self
    }

    // MARK: - Panel

    private func closePanel() {
        panel?.close()
        panel = nil
    }

    private func showPanel() {
        let mouseLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: {
            $0.frame.contains(mouseLocation)
        }) else { return }

        let panelWidth: CGFloat = 280
        let panelHeight: CGFloat = 400

        // Position below menu bar, centered on mouse, clamped to screen edges
        let menuBarBottom = screen.visibleFrame.maxY
        var panelX = mouseLocation.x - panelWidth / 2
        panelX = max(screen.visibleFrame.minX + 4,
                     min(panelX, screen.visibleFrame.maxX - panelWidth - 4))
        let panelY = menuBarBottom - panelHeight

        let newPanel = PopoverPanel(
            contentRect: NSRect(x: panelX, y: panelY, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        newPanel.isFloatingPanel = true
        newPanel.level = .statusBar
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = true

        // Visual effect background (matches system popover appearance)
        let visualEffect = NSVisualEffectView()
        visualEffect.material = .popover
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 10
        visualEffect.layer?.masksToBounds = true
        newPanel.contentView = visualEffect

        // SwiftUI content pinned to all edges via auto layout
        let contentView = PopoverContentView(monitor: monitor)
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        visualEffect.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: visualEffect.topAnchor),
            hostingView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor),
        ])

        newPanel.makeKeyAndOrderFront(nil)
        panel = newPanel
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        if let panel = panel, panel.isVisible {
            closePanel()
        } else {
            showPanel()
        }
    }

    // MARK: - Right-Click Menu

    private func setupRightClickMenu() {
        // Monitor for right-clicks on the status item: temporarily attach an
        // NSMenu so AppKit shows it, then remove it so left-click still fires
        // the button action (togglePopover).
        rightClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown]) { [weak self] event in
            guard let self,
                  let button = self.statusItem.button,
                  event.window == button.window else { return event }

            let locationInButton = button.convert(event.locationInWindow, from: nil)
            guard button.bounds.contains(locationInButton) else { return event }

            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "Quit dBMic", action: #selector(self.quitApp), keyEquivalent: "q"))
            menu.items.forEach { $0.target = self }
            self.statusItem.menu = menu
            button.performClick(nil)
            self.statusItem.menu = nil
            return nil
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Event Monitor

    private func setupEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            if let panel = self?.panel, panel.isVisible {
                self?.closePanel()
            }
        }
    }

    // MARK: - Permission

    private func requestPermissionAndStart() {
        monitor.requestPermission { [weak self] granted in
            if granted {
                self?.monitor.startMonitoring()
            }
        }
    }
}

/// Custom panel for menu bar popover, positioned explicitly to avoid
/// NSPopover coordinate drift after display changes.
final class PopoverPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// NSHostingView subclass that passes all mouse events through to the
/// superview (the status item button), so the button action still fires.
final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

/// Wrapper that decides between showing the permission view or the main popover.
struct PopoverContentView: View {
    @ObservedObject var monitor: AudioLevelMonitor

    var body: some View {
        if monitor.permissionGranted {
            PopoverView(monitor: monitor)
        } else {
            PermissionView {
                monitor.requestPermission { granted in
                    if granted {
                        monitor.startMonitoring()
                    }
                }
            }
        }
    }
}
