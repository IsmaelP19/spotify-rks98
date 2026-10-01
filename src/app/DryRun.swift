import CoreGraphics
import Foundation

/// Decides when a still image would be sent. Pause keeps the current image.
/// Stop and a closed Spotify app do not invent a command to restore the clock.
struct DisplayPlanner {
    private(set) var shownFingerprint: String?

    static func fingerprint(_ snapshot: PlaybackSnapshot) -> String {
        let id = snapshot.trackID.trimmingCharacters(in: .whitespacesAndNewlines)
        let art = snapshot.artworkURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !id.isEmpty || !art.isEmpty { return "\(id)\n\(art)" }
        return "\(snapshot.title)\n\(snapshot.artist)\n\(snapshot.album)"
    }

    mutating func step(_ snapshot: PlaybackSnapshot) -> DryRunAction {
        switch snapshot.state {
        case "playing", "paused":
            let fingerprint = Self.fingerprint(snapshot)
            if fingerprint == shownFingerprint { return .keep }
            return .upload
        default:
            return .idle
        }
    }

    mutating func commit(_ snapshot: PlaybackSnapshot) {
        shownFingerprint = Self.fingerprint(snapshot)
    }

    mutating func restore(fingerprint: String) {
        shownFingerprint = fingerprint.isEmpty ? nil : fingerprint
    }
}

enum DryRunAction {
    case upload
    case keep
    case idle
}

enum DryRun {
    static func evaluate(_ snapshot: PlaybackSnapshot, planner: inout DisplayPlanner, artwork: CGImage?) throws -> DryRunPlan {
        switch planner.step(snapshot) {
        case .idle:
            return DryRunPlan(action: .idle, packets: 0, png: nil)
        case .keep:
            return DryRunPlan(action: .keep, packets: 0, png: nil)
        case .upload:
            var track = snapshot.track
            track.artwork = artwork
            let frame = try DisplayRenderer.render(track)
            let sequence = try TftUpload.uploadPayloads(rgb565: frame.rgb565)
            let png = try frame.pngData()
            planner.commit(snapshot)
            return DryRunPlan(action: .upload, packets: 3 + sequence.blocks.count, png: png)
        }
    }
}

struct DryRunPlan {
    var action: DryRunAction
    var packets: Int
    var png: Data?

    var logLine: String {
        switch action {
        case .idle:
            return "dry-run no track; no report"
        case .keep:
            return "dry-run keep image; no report"
        case .upload:
            return "dry-run renderer.completed; would send \(packets) feature reports on id 9 (password, start, blocks, end); no report sent"
        }
    }
}
