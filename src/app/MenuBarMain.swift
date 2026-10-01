import AppKit
import Darwin
import Foundation
import IOKit

private let menuBarDelegate = MenuBarController()
private var heldInstanceLock: InstanceLock?

@main
enum MenuBarMain {
    static func main() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RK-S98", isDirectory: true)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        guard let lock = InstanceLock(url: support.appendingPathComponent("instance.lock")) else {
            fputs("rk-s98: already running\n", stderr)
            exit(0)
        }
        heldInstanceLock = lock
        let logURL = MenuStorage.directory().appendingPathComponent("menu.log")
        try? FileManager.default.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        freopen(logURL.path, "a", stderr)
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.delegate = menuBarDelegate
        app.run()
    }
}

/// Exclusive lock released automatically when this process exits, even if it is killed.
private final class InstanceLock {
    private let fd: Int32

    init?(url: URL) {
        let fd = open(url.path, O_CREAT | O_RDWR, 0o644)
        guard fd >= 0 else { return nil }
        if flock(fd, LOCK_EX | LOCK_NB) != 0 {
            close(fd)
            return nil
        }
        self.fd = fd
    }

    deinit { close(fd) }
}

final class MenuBarController: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let card = TrackMenuCard(frame: NSRect(origin: .zero, size: TrackMenuCard.preferredSize))
    private let worker = MenuWorker()
    private var quitAfterUpload = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "RK S98")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "RK S98"
        }
        let menu = NSMenu()
        menu.delegate = card
        let trackItem = NSMenuItem()
        trackItem.view = card
        menu.addItem(trackItem)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Salir", action: #selector(quit(_:)), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu

        requestKeyboardAccess()
        worker.onStatus = { [weak self] status in
            DispatchQueue.main.async { self?.show(status) }
        }
        worker.onStopped = { [weak self] in
            DispatchQueue.main.async {
                guard let self, self.quitAfterUpload else { return }
                NSApp.reply(toApplicationShouldTerminate: true)
            }
        }
        worker.start()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        quitAfterUpload = true
        return worker.requestStop() ? .terminateLater : .terminateNow
    }

    @objc private func quit(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    private func requestKeyboardAccess() {
        guard IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) != kIOHIDAccessTypeGranted else { return }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            let granted = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
            NSApp.setActivationPolicy(.accessory)
            log("input monitoring granted=\(granted)")
        }
    }

    private func show(_ status: DaemonStatus) {
        card.apply(status)
    }
}

private final class MenuWorker {
    private let lock = NSLock()
    private var stop = false
    private var busy = false
    var onStatus: ((DaemonStatus) -> Void)?
    var onStopped: (() -> Void)?

    func start() {
        Thread { [self] in
            let configuration = DaemonConfiguration(
                live: true,
                once: false,
                interval: 2,
                storageDirectory: MenuStorage.directory(),
                onStatus: { [weak self] status in self?.onStatus?(status) },
                shouldStop: { [weak self] in self?.isStopped() ?? true },
                onBusy: { [weak self] busy in self?.setBusy(busy) }
            )
            while !isStopped() {
                do {
                    try DaemonRunner.run(configuration)
                    break
                } catch {
                    onStatus?(DaemonStatus(title: "Error", artist: "", album: "", note: String(describing: error), artworkPNG: nil, progress: nil))
                    log("menu \(error)")
                    if waitForRetry() { break }
                }
            }
            onStopped?()
        }.start()
    }

    func requestStop() -> Bool {
        lock.lock()
        stop = true
        let stillUploading = busy
        lock.unlock()
        return stillUploading
    }

    private func isStopped() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return stop
    }

    private func setBusy(_ value: Bool) {
        lock.lock()
        busy = value
        lock.unlock()
    }

    private func waitForRetry() -> Bool {
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            if isStopped() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return isStopped()
    }
}

private enum MenuStorage {
    static func directory() -> URL {
        let bundle = Bundle.main.bundleURL
        let build = bundle.deletingLastPathComponent()
        let repo = build.deletingLastPathComponent()
        if FileManager.default.fileExists(atPath: repo.appendingPathComponent("src").path) {
            return build
        }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RK-S98", isDirectory: true)
    }
}
