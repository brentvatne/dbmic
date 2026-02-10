import AppKit
import Combine
import dBMicCore
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let monitor = AudioLevelMonitor()
    private var hostingView: NSHostingView<MenuBarView>!
    private var eventMonitor: Any?
    private var rightClickMonitor: Any?
    private var statusCancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("[dBMic] applicationDidFinishLaunching")
        // Menu-bar-only: hide Dock icon. This is the programmatic equivalent
        // of Info.plist's LSUIElement=true, ensuring it works even when the
        // binary runs outside a .app bundle (e.g. swift run, Xcode SPM).
        NSApplication.shared.setActivationPolicy(.accessory)

        setupStatusItem()
        setupPopover()
        setupEventMonitor()
        setupRightClickMenu()
        requestPermissionAndStart()

        // Close any windows macOS restored (the empty Settings scene window).
        // Dispatched async so it runs after SwiftUI finishes creating its scenes.
        DispatchQueue.main.async {
            for window in NSApplication.shared.windows {
                window.close()
            }
        }

        NSLog("[dBMic] startup complete, isMonitoring=%d, permissionGranted=%d",
              monitor.isMonitoring, monitor.permissionGranted)
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        guard let button = statusItem.button else { return }

        let menuBarView = MenuBarView(monitor: monitor)
        hostingView = NSHostingView(rootView: menuBarView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 24, height: button.bounds.height)

        button.addSubview(hostingView)
        button.frame = hostingView.frame
        button.action = #selector(togglePopover(_:))
        button.target = self
    }

    // MARK: - Popover

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 400)
        popover.behavior = .transient
        popover.animates = true

        let popoverView = PopoverContentView(monitor: monitor)
        popover.contentViewController = NSHostingController(rootView: popoverView)
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
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
            if let popover = self?.popover, popover.isShown {
                popover.performClose(nil)
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
