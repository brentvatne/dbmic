import AppKit
import Combine
import MicMeterCore
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let monitor = AudioLevelMonitor()
    private var hostingView: NSHostingView<MenuBarView>!
    private var eventMonitor: Any?
    private var statusCancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
        setupEventMonitor()
        requestPermissionAndStart()
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
