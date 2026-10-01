import Foundation

@main
struct DryRunTests {
    static func main() {
        var tests = 0
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            guard condition() else { fatalError(message) }
            tests += 1
        }
        func snap(_ state: String, _ id: String, _ title: String = "Song") -> PlaybackSnapshot {
            PlaybackSnapshot(state: state, title: title, artist: "Artist", album: "Album", trackID: id, artworkURL: "https://example.test/\(id).jpg")
        }

        var planner = DisplayPlanner()
        let first = try! DryRun.evaluate(snap("playing", "a"), planner: &planner, artwork: nil)
        check(first.action == .upload && first.packets == 218, "A new track would send password, start, 215 blocks and end")
        check(first.png?.starts(with: Data([0x89, 0x50, 0x4E, 0x47])) == true, "Dry run still renders a PNG")
        check(first.logLine.contains("no report sent"), "The log states that nothing was sent")

        let paused = try! DryRun.evaluate(snap("paused", "a"), planner: &planner, artwork: nil)
        check(paused.action == .keep && paused.packets == 0, "Pausing the same track does not upload again")

        let resumed = try! DryRun.evaluate(snap("playing", "a"), planner: &planner, artwork: nil)
        check(resumed.action == .keep, "Resuming the same track keeps the image")

        let next = try! DryRun.evaluate(snap("playing", "b", "Other"), planner: &planner, artwork: nil)
        check(next.action == .upload && next.packets == 218, "A different track would upload once")

        let stopped = try! DryRun.evaluate(snap("stopped", ""), planner: &planner, artwork: nil)
        check(stopped.action == .idle && stopped.packets == 0, "Stop does not invent a home-screen command")
        let again = try! DryRun.evaluate(snap("playing", "b", "Other"), planner: &planner, artwork: nil)
        check(again.action == .keep, "Returning to the shown track after a stop does not upload again")

        print("PASS: \(tests) offline dry-run assertions")
    }
}
