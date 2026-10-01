import CoreGraphics
import CoreGraphics
import Foundation
import ImageIO
import ImageIO

struct DaemonStatus: Sendable {
    var title: String
    var artist: String
    var album: String
    var note: String
    var artworkPNG: Data?
    var progress: Double?
}

struct DaemonConfiguration {
    var live: Bool
    var once: Bool
    var interval: TimeInterval
    var storageDirectory: URL
    var onStatus: ((DaemonStatus) -> Void)?
    var shouldStop: (() -> Bool)?
    var onBusy: ((Bool) -> Void)?
}

enum DaemonRunner {
    static func run(_ configuration: DaemonConfiguration) throws {
        var planner = DisplayPlanner()
        if let saved = savedFingerprint(in: configuration.storageDirectory) {
            planner.restore(fingerprint: saved)
        }
        var failures: [String: Int] = [:]
        var artworkCacheData: (key: String, png: Data)?
        let output = configuration.storageDirectory.appendingPathComponent("preview.png")
        let artworkCache = configuration.storageDirectory.appendingPathComponent("artwork-cache", isDirectory: true)
        try FileManager.default.createDirectory(at: configuration.storageDirectory, withIntermediateDirectories: true)
        log("daemon \(configuration.live ? "live" : "dry-run"); one image per track; menu detection unavailable")
        while configuration.shouldStop?() != true {
            let snapshot = try SpotifyLocal.fetch()
            let label = snapshot.title.isEmpty ? snapshot.state : snapshot.title
            let art = artworkPNG(for: snapshot, cacheDirectory: artworkCache, store: &artworkCacheData)
            switch planner.step(snapshot) {
            case .idle:
                report(configuration, status(snapshot, note: "La pantalla no se toca", artworkPNG: nil))
                log("\(label); dry-run no track; no report")
            case .keep:
                report(configuration, status(snapshot, note: "", artworkPNG: art))
                log("\(label); keep image; no report")
            case .upload:
                let fingerprint = DisplayPlanner.fingerprint(snapshot)
                if (failures[fingerprint] ?? 0) >= 2 {
                    planner.commit(snapshot)
                    report(configuration, status(snapshot, note: "Se reintentará con la siguiente pista", artworkPNG: art))
                    log("tft.upload.failed \(label); giving up until the track changes")
                } else {
                    do {
                        let artwork = (snapshot.state == "playing" || snapshot.state == "paused")
                            ? try? SpotifyLocal.artwork(for: snapshot, cacheDirectory: artworkCache)
                            : nil
                        var track = snapshot.track
                        track.artwork = artwork
                        let frame = try DisplayRenderer.render(track)
                        try frame.pngData().write(to: output)
                        if configuration.live {
                            report(configuration, status(snapshot, note: "", artworkPNG: art, progress: 0))
                            log("tft.upload.started \(label)")
                            configuration.onBusy?(true)
                            defer { configuration.onBusy?(false) }
                            try TftTransport.upload(frame: frame.rgb565) { done, total in
                                let fraction = total > 0 ? Double(done) / Double(total) : 1
                                report(configuration, status(snapshot, note: "", artworkPNG: art, progress: fraction))
                            }
                            log("tft.upload.completed \(label)")
                        } else {
                            let sequence = try TftUpload.uploadPayloads(rgb565: frame.rgb565)
                            log("\(label); would send \(3 + sequence.blocks.count) feature reports; no report sent")
                        }
                        commit(snapshot, planner: &planner, configuration: configuration, persist: configuration.live)
                        failures[fingerprint] = 0
                        report(configuration, status(snapshot, note: "", artworkPNG: art))
                    } catch {
                        let message = String(describing: error)
                        let keyboardMissing = message.contains("found 0") || message.contains("not permitted")
                        let note: String
                        if message.contains("not permitted") {
                            note = "Falta el permiso de monitorización"
                        } else if keyboardMissing {
                            note = "El teclado no está disponible"
                        } else {
                            failures[fingerprint, default: 0] += 1
                            note = "No se ha podido subir"
                        }
                        report(configuration, status(snapshot, note: note, artworkPNG: art))
                        log("tft.upload.failed \(label); \(error)")
                    }
                }
            }
            if configuration.once || configuration.shouldStop?() == true { return }
            if wait(configuration.interval, shouldStop: configuration.shouldStop) { return }
        }
    }

    private static func commit(_ snapshot: PlaybackSnapshot, planner: inout DisplayPlanner, configuration: DaemonConfiguration, persist: Bool) {
        planner.commit(snapshot)
        guard persist else { return }
        let url = configuration.storageDirectory.appendingPathComponent("shown-fingerprint.txt")
        try? Data(DisplayPlanner.fingerprint(snapshot).utf8).write(to: url)
    }

    private static func savedFingerprint(in directory: URL) -> String? {
        let url = directory.appendingPathComponent("shown-fingerprint.txt")
        guard var text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        if text.hasSuffix("\n") { text.removeLast() }
        return text.isEmpty ? nil : text
    }

    private static func report(_ configuration: DaemonConfiguration, _ status: DaemonStatus) {
        configuration.onStatus?(status)
    }

    private static func status(_ snapshot: PlaybackSnapshot, note: String, artworkPNG: Data?, progress: Double? = nil) -> DaemonStatus {
        let playing = snapshot.state == "playing" || snapshot.state == "paused"
        return DaemonStatus(
            title: playing ? displayTitle(snapshot) : idleTitle(snapshot),
            artist: playing ? snapshot.artist : "",
            album: playing ? snapshot.album : "",
            note: note,
            artworkPNG: artworkPNG,
            progress: progress
        )
    }

    private static func artworkPNG(for snapshot: PlaybackSnapshot, cacheDirectory: URL, store: inout (key: String, png: Data)?) -> Data? {
        guard snapshot.state == "playing" || snapshot.state == "paused" else { return nil }
        let key = DisplayPlanner.fingerprint(snapshot)
        if store?.key == key { return store?.png }
        guard let image = try? SpotifyLocal.artwork(for: snapshot, cacheDirectory: cacheDirectory) else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        let png = data as Data
        store = (key, png)
        return png
    }

    private static func idleTitle(_ snapshot: PlaybackSnapshot) -> String {
        snapshot.state == "unavailable" ? "Spotify cerrado" : "Sin reproducción"
    }

    private static func displayTitle(_ snapshot: PlaybackSnapshot) -> String {
        let title = snapshot.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "Sin título" : title
    }

    private static func wait(_ interval: TimeInterval, shouldStop: (() -> Bool)?) -> Bool {
        let deadline = Date().addingTimeInterval(interval)
        while Date() < deadline {
            if shouldStop?() == true { return true }
            Thread.sleep(forTimeInterval: min(0.2, max(0, deadline.timeIntervalSinceNow)))
        }
        return shouldStop?() == true
    }
}

func log(_ message: String) {
    FileHandle.standardError.write(Data("rk-s98: \(message)\n".utf8))
}
