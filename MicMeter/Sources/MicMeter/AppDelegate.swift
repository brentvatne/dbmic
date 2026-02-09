import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let monitor = AudioLevelMonitor()
    private var hostingView: NSHostingView<MenuBarView>!
    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
        setupEventMonitor()
        requestPermissionAndStart()
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem.button else { return }

        let menuBarView = MenuBarView(monitor: monitor)
        hostingView = NSHostingView(rootView: menuBarView)

        // Calculate initial size
        let fittingSize = hostingView.fittingSize
        hostingView.frame = NSRect(x: 0, y: 0, width: fittingSize.width, height: button.bounds.height)

        button.addSubview(hostingView)
        button.frame = hostingView.frame

        // Set up a timer to resize the button as the dB text changes width
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateStatusItemSize()
        }

        button.action = #selector(togglePopover(_:))
        button.target = self
    }

    private func updateStatusItemSize() {
        guard let button = statusItem.button else { return }
        let fittingSize = hostingView.fittingSize
        let newWidth = max(fittingSize.width + 4, 36) // min width
        hostingView.frame = NSRect(x: 0, y: 0, width: newWidth, height: button.bounds.height)
        statusItem.length = newWidth
    }

    // MARK: - Popover

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 340)
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

            // Ensure popover window becomes key for interaction
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - Event Monitor

    /// Closes the popover when clicking outside of it.
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
