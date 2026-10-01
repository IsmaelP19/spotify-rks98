import CoreGraphics
import Foundation

let arguments = Array(CommandLine.arguments.dropFirst())
let help = """
Usage: rk-s98 info [--vid 0x258A] [--include-identifiers]
       rk-s98 descriptor PATH
       rk-s98 upload-solid blue|green|white --confirm-persistent-write
       rk-s98 render --mock [--output PATH]
       rk-s98 render --spotify [--output PATH]
       rk-s98 spotify status
       rk-s98 daemon --dry-run [--once] [--interval SECONDS]
       rk-s98 daemon --confirm-persistent-write [--once] [--interval SECONDS]
       rk-s98 --help

info: JSON snapshot of cached macOS IORegistry metadata. No device is opened.
Matches VID only; does not assume PID or confirm the physical model.
Serial numbers, registry paths/IDs and USB locations are omitted by default. Keep snapshots private.
descriptor: offline summary of a binary HID report descriptor.
"""

do {
    let output: [String: Any]
    if arguments.isEmpty || arguments == ["--help"] {
        print(help)
        exit(0)
    } else if arguments.first == "descriptor", arguments.count == 2 {
        let data = try Data(contentsOf: URL(fileURLWithPath: arguments[1]))
        guard data.count <= 1_048_576 else { throw RegistryInspectionError(description: "Descriptor exceeds 1 MiB offline limit") }
        output = summarizeHIDDescriptor(data).json
    } else if arguments.first == "spotify", arguments.count == 2, arguments[1] == "status" {
        let snapshot = try SpotifyLocal.fetch()
        print(snapshot.statusText)
        exit(0)
    } else if arguments.first == "daemon" {
        try runDaemon(Array(arguments.dropFirst()))
        exit(0)
    } else if arguments.first == "render" {
        try renderPreview(Array(arguments.dropFirst()))
        exit(0)
    } else if arguments.first == "upload-solid" {
        try uploadSolid(Array(arguments.dropFirst()))
        exit(0)
    } else if arguments.first == "info" {
        var vendor = 0x258A
        var includeIdentifiers = false
        var index = 1
        while index < arguments.count {
            switch arguments[index] {
            case "--include-identifiers": includeIdentifiers = true
            case "--vid":
                index += 1
                guard index < arguments.count else { throw RegistryInspectionError(description: "--vid requires a value") }
                let text = arguments[index]
                let value = text.lowercased().hasPrefix("0x") ? Int(text.dropFirst(2), radix: 16) : Int(text)
                guard let value, (0...65535).contains(value) else { throw RegistryInspectionError(description: "Invalid VID") }
                vendor = value
            default: throw RegistryInspectionError(description: "Unknown option: \(arguments[index])")
            }
            index += 1
        }
        output = try RegistryInspector(vendorID: vendor, includeIdentifiers: includeIdentifiers).inspect()
    } else { throw RegistryInspectionError(description: "Unsupported command. Use --help.") }
    let data = try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys])
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data([0x0A]))
} catch {
    FileHandle.standardError.write(Data("rk-s98: \(error)\n".utf8))
    exit(1)
}

func uploadSolid(_ arguments: [String]) throws {
    guard arguments.count == 2, arguments[1] == "--confirm-persistent-write" else {
        throw RegistryInspectionError(description: "upload-solid needs a color and --confirm-persistent-write")
    }
    let color: (UInt8, UInt8, UInt8)
    switch arguments[0] {
    case "blue": color = (0, 0, 255)
    case "green": color = (0, 255, 0)
    case "white": color = (255, 255, 255)
    case "red": throw RegistryInspectionError(description: "Red is already stored. Choose blue, green, or white.")
    default: throw RegistryInspectionError(description: "Color must be blue, green, or white")
    }
    FileHandle.standardError.write(Data("rk-s98: sending one persistent \(arguments[0]) frame to 258A:022B\n".utf8))
    try TftTransport.upload(frame: TftUpload.solidRGB565(red: color.0, green: color.1, blue: color.2))
}

func renderPreview(_ arguments: [String]) throws {
    var output = ".build/preview.png"
    var index = 0
    var mock = false
    var spotify = false
    while index < arguments.count {
        switch arguments[index] {
        case "--mock": mock = true
        case "--spotify": spotify = true
        case "--output":
            index += 1
            guard index < arguments.count else { throw RenderError(description: "--output requires a path") }
            output = arguments[index]
        default: throw RenderError(description: "Unknown render option: \(arguments[index])")
        }
        index += 1
    }
    guard mock != spotify else { throw RenderError(description: "render needs either --mock or --spotify") }
    let track: TrackInfo
    if mock {
        track = DisplayRenderer.mockTrack()
    } else {
        let snapshot = try SpotifyLocal.fetch()
        guard snapshot.state == "playing" || snapshot.state == "paused" else {
            throw SpotifyError(description: "Spotify state is \(snapshot.state); nothing to draw")
        }
        var info = snapshot.track
        info.artwork = try SpotifyLocal.artwork(for: snapshot, cacheDirectory: URL(fileURLWithPath: ".build/artwork-cache"))
        if info.artwork == nil, !snapshot.artworkURL.isEmpty {
            FileHandle.standardError.write(Data("rk-s98: artwork unavailable; drawing text only\n".utf8))
        }
        track = info
        FileHandle.standardError.write(Data("rk-s98: \(snapshot.state) — \(snapshot.title)\n".utf8))
    }
    let png = try DisplayRenderer.render(track).pngData()
    let url = URL(fileURLWithPath: output)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try png.write(to: url)
    FileHandle.standardError.write(Data("rk-s98: wrote \(output) without opening the keyboard\n".utf8))
}

func runDaemon(_ arguments: [String]) throws {
    var dryRun = false
    var live = false
    var once = false
    var interval = 2.0
    var index = 0
    while index < arguments.count {
        switch arguments[index] {
        case "--dry-run": dryRun = true
        case "--confirm-persistent-write": live = true
        case "--once": once = true
        case "--interval":
            index += 1
            guard index < arguments.count, let value = Double(arguments[index]), value > 0 else {
                throw RegistryInspectionError(description: "--interval requires a positive number of seconds")
            }
            interval = max(1, value)
        default:
            throw RegistryInspectionError(description: "Unknown daemon option: \(arguments[index])")
        }
        index += 1
    }
    guard dryRun != live else {
        throw RegistryInspectionError(description: "daemon needs --dry-run or --confirm-persistent-write")
    }
    try DaemonRunner.run(DaemonConfiguration(
        live: live,
        once: once,
        interval: interval,
        storageDirectory: URL(fileURLWithPath: ".build"),
        onStatus: nil,
        shouldStop: nil,
        onBusy: nil
    ))
}
