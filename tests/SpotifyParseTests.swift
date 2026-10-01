import Foundation

@main
struct SpotifyParseTests {
    static func main() {
        var tests = 0
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            guard condition() else { fatalError(message) }
            tests += 1
        }
        let sep = "\u{1F}"
        let playing = try! PlaybackSnapshot.parse(["playing", "東京", "Álvaro Soler", "Mar de colores", "abc", "https://example.test/a.jpg"].joined(separator: sep))
        check(playing.state == "playing", "State is preserved")
        check(playing.title == "東京", "Unicode title is preserved")
        check(playing.track.displayAlbum == "Mar de colores", "Album reaches the renderer")
        check(playing.statusText.contains("Artwork: url"), "A URL counts as artwork available")
        check(!playing.statusText.contains("example.test"), "Status does not print the artwork URL")

        let paused = try! PlaybackSnapshot.parse(["paused", "One", "Two", "", "id", ""].joined(separator: sep))
        check(paused.track.displayAlbum == nil, "Empty album is omitted")
        check(paused.statusText.contains("Artwork: missing"), "Missing artwork is explicit")
        check(paused.statusText.contains("Album: —"), "Empty album prints a dash")

        let stopped = try! PlaybackSnapshot.parse(["stopped", "", "", "", "", ""].joined(separator: sep))
        check(stopped.track.displayTitle == "Sin título", "Stopped playback still has a title fallback")
        check(stopped.statusText == "State: stopped\nNo current track", "Stopped status does not invent a title")
        let closed = try! PlaybackSnapshot.parse(["unavailable", "", "", "", "", ""].joined(separator: sep))
        check(closed.statusText.contains("not running"), "A closed Spotify app is reported as unavailable")

        do {
            _ = try PlaybackSnapshot.parse("playing")
            fatalError("Short record accepted")
        } catch {
            tests += 1
        }
        print("PASS: \(tests) offline Spotify parse assertions")
    }
}
