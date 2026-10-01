import CoreGraphics
import CryptoKit
import Foundation
import ImageIO

struct PlaybackSnapshot {
    var state: String
    var title: String
    var artist: String
    var album: String
    var trackID: String
    var artworkURL: String

    var track: TrackInfo {
        TrackInfo(title: title, artist: artist, album: album, artwork: nil)
    }

    var statusText: String {
        if state == "unavailable" { return "State: unavailable\nSpotify is not running" }
        if state == "stopped" { return "State: stopped\nNo current track" }
        let albumLine = album.trimmingCharacters(in: .whitespacesAndNewlines)
        return """
        State: \(state)
        Track: \(title)
        Artist: \(artist)
        Album: \(albumLine.isEmpty ? "—" : albumLine)
        Artwork: \(artworkURL.isEmpty ? "missing" : "url")
        Track ID: \(trackID.isEmpty ? "—" : trackID)
        """
    }

    static func parse(_ record: String) throws -> PlaybackSnapshot {
        let fields = record.split(separator: "\u{1F}", omittingEmptySubsequences: false).map(String.init)
        guard fields.count == 6 else {
            throw SpotifyError(description: "Spotify record has \(fields.count) fields")
        }
        return PlaybackSnapshot(
            state: fields[0],
            title: fields[1],
            artist: fields[2],
            album: fields[3],
            trackID: fields[4],
            artworkURL: fields[5]
        )
    }
}

enum SpotifyLocal {
    private static let separator = "\u{1F}"
    private static let script = """
    set sep to character id 31
    if application id "com.spotify.client" is not running then
      return "unavailable" & sep & "" & sep & "" & sep & "" & sep & "" & sep & ""
    end if
    tell application id "com.spotify.client"
      set stateText to player state as text
      if stateText is "stopped" then
        return stateText & sep & "" & sep & "" & sep & "" & sep & "" & sep & ""
      end if
      try
        tell current track
          return stateText & sep & my flatten(name) & sep & my flatten(artist) & sep & my flatten(album) & sep & my flatten(id) & sep & my flatten(artwork url)
        end tell
      on error
        return stateText & sep & "" & sep & "" & sep & "" & sep & "" & sep & ""
      end try
    end tell

    on flatten(value)
      set text item delimiters to {return, linefeed}
      set parts to text items of (value as text)
      set text item delimiters to " "
      set joined to parts as text
      set text item delimiters to ""
      return joined
    end flatten
    """

    static func fetch() throws -> PlaybackSnapshot {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-"]
        let input = Pipe()
        let output = Pipe()
        let errors = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = errors
        let finished = DispatchGroup()
        finished.enter()
        process.terminationHandler = { _ in finished.leave() }
        try process.run()
        input.fileHandleForWriting.write(Data(script.utf8))
        try input.fileHandleForWriting.close()
        guard finished.wait(timeout: .now() + 20) == .success else {
            process.terminate()
            throw SpotifyError(description: "Spotify query timed out. If macOS asked for Automation access, allow it and retry.")
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        let errorText = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw SpotifyError(description: errorText.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        let record = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return try PlaybackSnapshot.parse(record)
    }

    static func artwork(for snapshot: PlaybackSnapshot, cacheDirectory: URL) throws -> CGImage? {
        let address = snapshot.artworkURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: address), let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" else {
            return nil
        }
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        let name = SHA256.hash(data: Data(address.utf8)).map { String(format: "%02x", $0) }.joined() + ".img"
        let cached = cacheDirectory.appendingPathComponent(name)
        let data: Data
        if FileManager.default.fileExists(atPath: cached.path) {
            data = try Data(contentsOf: cached)
        } else {
            data = try download(url)
            try data.write(to: cached)
        }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        return image
    }

    private static func download(_ url: URL) throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = "GET"
        let semaphore = DispatchSemaphore(value: 0)
        var payload: Data?
        var failure: Error?
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            if let error {
                failure = error
                return
            }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200..<300).contains(status), let data, !data.isEmpty else {
                failure = SpotifyError(description: "Artwork download failed with status \(status)")
                return
            }
            payload = data
        }
        task.resume()
        guard semaphore.wait(timeout: .now() + 20) == .success else {
            task.cancel()
            throw SpotifyError(description: "Artwork download timed out")
        }
        if let failure { throw failure }
        return payload ?? Data()
    }
}

struct SpotifyError: Error, CustomStringConvertible {
    let description: String
}
