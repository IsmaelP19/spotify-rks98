// Regenerates docs/images from the real renderer and menu card. Does not open the keyboard.
import AppKit
import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers

@main
enum FigureMain {
    static func main() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let outputDirectory = root.appendingPathComponent("docs/images", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        NSApplication.shared.setActivationPolicy(.prohibited)

        let playingArt = cover(size: 480, style: .harbor)
        let wideArt = cover(size: CGSize(width: 640, height: 280), style: .horizon)
        let longArt = cover(size: 480, style: .night)
        let playing = TrackInfo(title: "Noche en el puerto", artist: "Marina Sol", album: "Costa norte", artwork: playingArt)
        let wide = TrackInfo(title: "Horizonte", artist: "Mar de fondo", album: "Marea baja", artwork: wideArt)
        let longTitle = TrackInfo(
            title: "Una canción cuyo título no cabe en la columna",
            artist: "Compañía del faro",
            album: "Señales largas",
            artwork: longArt
        )
        let noArt = TrackInfo(title: "Notas de voz", artist: "Archivo local", album: nil, artwork: nil)
        let frames: [(String, TrackInfo)] = [
            ("tft-playing", playing),
            ("tft-wide", wide),
            ("tft-long-title", longTitle),
            ("tft-no-artwork", noArt),
            ("tft-mock", DisplayRenderer.mockTrack())
        ]

        var rendered: [String: CGImage] = [:]
        for (name, track) in frames {
            let image = try DisplayRenderer.render(track).readmeImage()
            rendered[name] = image
            try writePNG(present(image), to: outputDirectory.appendingPathComponent("\(name).png"))
        }

        let photo = try loadImage(root.appendingPathComponent("research/captures/tft-red-2026-10-01.jpg"))
        let prepared = blackOutRedScreen(photo)
        guard let playingFrame = rendered["tft-playing"] else { throw CocoaError(.fileReadCorruptFile) }
        do {
            let onKeyboard = try compositeOnKeyboard(rounded(playingFrame, radius: 16), over: prepared)
            try writeJPEG(onKeyboard, to: outputDirectory.appendingPathComponent("tft-on-keyboard.jpg"), quality: 0.88)
        } catch {
            fputs("keyboard composite failed: \(error)\n", stderr)
        }

        let playingPNG = try pngData(playingArt)
        try writePNG(menuImage(status: DaemonStatus(
            title: "Noche en el puerto", artist: "Marina Sol", album: "Costa norte", note: "", artworkPNG: playingPNG, progress: nil
        )), to: outputDirectory.appendingPathComponent("menu-playing.png"))
        try writePNG(menuImage(status: DaemonStatus(
            title: "Noche en el puerto", artist: "Marina Sol", album: "Costa norte", note: "", artworkPNG: playingPNG, progress: 0.64
        )), to: outputDirectory.appendingPathComponent("menu-upload.png"))
        try writePNG(menuImage(status: DaemonStatus(
            title: "Noche en el puerto", artist: "Marina Sol", album: "Costa norte",
            note: "El teclado no está disponible", artworkPNG: playingPNG, progress: nil
        )), to: outputDirectory.appendingPathComponent("menu-keyboard.png"))
        try writePNG(menuImage(status: DaemonStatus(
            title: "Spotify cerrado", artist: "", album: "", note: "La pantalla no se toca", artworkPNG: nil, progress: nil
        )), to: outputDirectory.appendingPathComponent("menu-stopped.png"))
        try writePNG(appIcon(side: 256), to: outputDirectory.appendingPathComponent("app-icon.png"))
        FileHandle.standardError.write(Data("rk-s98: wrote README figures in \(outputDirectory.path)\n".utf8))
    }
}

enum CoverStyle {
    case harbor
    case horizon
    case night
}

func cover(size: Int, style: CoverStyle) -> CGImage {
    cover(size: CGSize(width: size, height: size), style: style)
}

func cover(size: CGSize, style: CoverStyle) -> CGImage {
    let width = Int(size.width)
    let height = Int(size.height)
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fputs("rk-s98: cover context failed\n", stderr)
        exit(1)
    }
    let colors: [CGColor]
    switch style {
    case .harbor:
        colors = [
            CGColor(srgbRed: 0.05, green: 0.16, blue: 0.34, alpha: 1),
            CGColor(srgbRed: 0.95, green: 0.45, blue: 0.28, alpha: 1)
        ]
    case .horizon:
        colors = [
            CGColor(srgbRed: 0.05, green: 0.28, blue: 0.32, alpha: 1),
            CGColor(srgbRed: 0.93, green: 0.72, blue: 0.38, alpha: 1)
        ]
    case .night:
        colors = [
            CGColor(srgbRed: 0.08, green: 0.07, blue: 0.16, alpha: 1),
            CGColor(srgbRed: 0.36, green: 0.22, blue: 0.62, alpha: 1)
        ]
    }
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
    context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: CGFloat(height)), end: CGPoint(x: CGFloat(width), y: 0), options: [])
    context.setFillColor(CGColor(srgbRed: 1, green: 0.86, blue: 0.62, alpha: 0.95))
    let sun = min(CGFloat(width), CGFloat(height)) * (style == .horizon ? 0.42 : 0.34)
    context.fillEllipse(in: CGRect(
        x: CGFloat(width) * (style == .horizon ? 0.62 : 0.48) - sun / 2,
        y: CGFloat(height) * (style == .night ? 0.62 : 0.42) - sun / 2,
        width: sun,
        height: sun
    ))
    context.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.55))
    context.setLineWidth(max(2, CGFloat(height) * 0.012))
    context.move(to: CGPoint(x: CGFloat(width) * 0.12, y: CGFloat(height) * 0.22))
    context.addLine(to: CGPoint(x: CGFloat(width) * 0.88, y: CGFloat(height) * 0.22))
    context.strokePath()
    guard let image = context.makeImage() else {
        fputs("rk-s98: cover image failed\n", stderr)
        exit(1)
    }
    return image
}

func present(_ image: CGImage) -> CGImage {
    let scale: CGFloat = 3
    let bezel: CGFloat = 18
    let screen = CGSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
    let size = CGSize(width: screen.width + bezel * 2, height: screen.height + bezel * 2)
    guard let context = CGContext(
        data: nil,
        width: Int(size.width),
        height: Int(size.height),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fputs("rk-s98: present context failed\n", stderr)
        exit(1)
    }
    let bounds = CGRect(origin: .zero, size: size)
    context.setFillColor(CGColor(srgbRed: 0.07, green: 0.07, blue: 0.08, alpha: 1))
    context.fill(bounds)
    let housing = bounds.insetBy(dx: 4, dy: 4)
    context.setFillColor(CGColor(srgbRed: 0.22, green: 0.22, blue: 0.24, alpha: 1))
    context.addPath(CGPath(roundedRect: housing, cornerWidth: 28, cornerHeight: 28, transform: nil))
    context.fillPath()
    let screenRect = CGRect(x: bezel, y: bezel, width: screen.width, height: screen.height)
    context.saveGState()
    context.addPath(CGPath(roundedRect: screenRect, cornerWidth: 22, cornerHeight: 22, transform: nil))
    context.clip()
    context.interpolationQuality = .high
    context.draw(image, in: screenRect)
    context.restoreGState()
    guard let presented = context.makeImage() else {
        fputs("rk-s98: present image failed\n", stderr)
        exit(1)
    }
    return presented
}

func rounded(_ image: CGImage, radius: CGFloat) -> CGImage {
    guard let context = CGContext(
        data: nil,
        width: image.width,
        height: image.height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fputs("rk-s98: round context failed\n", stderr)
        exit(1)
    }
    let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
    context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    context.clip()
    context.draw(image, in: rect)
    guard let result = context.makeImage() else {
        fputs("rk-s98: round image failed\n", stderr)
        exit(1)
    }
    return result
}

func loadImage(_ url: URL) throws -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw CocoaError(.fileReadCorruptFile)
    }
    return image
}

func blackOutRedScreen(_ image: CGImage) -> CGImage {
    let width = image.width
    let height = image.height
    let bytesPerRow = width * 4
    var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
    guard let context = CGContext(
        data: &pixels,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fputs("rk-s98: photo context failed\n", stderr)
        exit(1)
    }
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    var mask = [Bool](repeating: false, count: width * height)
    for index in 0..<(width * height) {
        let offset = index * 4
        let red = Int(pixels[offset])
        let green = Int(pixels[offset + 1])
        let blue = Int(pixels[offset + 2])
        if red > 170 && green < 100 && blue < 100 && red > green + 90 && red > blue + 90 {
            mask[index] = true
        }
    }
    for _ in 0..<5 {
        var grown = mask
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let index = y * width + x
                guard !mask[index] else { continue }
                if mask[index - 1] || mask[index + 1] || mask[index - width] || mask[index + width] {
                    grown[index] = true
                }
            }
        }
        mask = grown
    }
    for index in mask.indices where mask[index] {
        let offset = index * 4
        pixels[offset] = 16
        pixels[offset + 1] = 16
        pixels[offset + 2] = 20
        pixels[offset + 3] = 255
    }
    guard let result = context.makeImage() else {
        fputs("rk-s98: photo image failed\n", stderr)
        exit(1)
    }
    return result
}

func compositeOnKeyboard(_ frame: CGImage, over photo: CGImage) throws -> CGImage {
    let source = CIImage(cgImage: frame)
    guard let filter = CIFilter(name: "CIPerspectiveTransform") else {
        throw CocoaError(.serviceApplicationNotFound)
    }
    let height = CGFloat(photo.height)
    func point(_ x: CGFloat, _ pilY: CGFloat) -> CIVector {
        CIVector(x: x, y: height - pilY)
    }
    filter.setValue(source, forKey: kCIInputImageKey)
    filter.setValue(point(263.9, 351.4), forKey: "inputTopLeft")
    filter.setValue(point(450.7, 345.7), forKey: "inputTopRight")
    filter.setValue(point(451.8, 445.1), forKey: "inputBottomRight")
    filter.setValue(point(267.7, 451.8), forKey: "inputBottomLeft")
    guard let transformed = filter.outputImage else { throw CocoaError(.fileReadCorruptFile) }
    let context = CIContext(options: [.workingColorSpace: CGColorSpaceCreateDeviceRGB()])
    let pieceRect = transformed.extent.integral
    guard let piece = context.createCGImage(transformed, from: pieceRect) else {
        fputs("perspective render failed \(transformed.extent)\n", stderr)
        throw CocoaError(.fileWriteUnknown)
    }
    let width = photo.width
    let photoHeight = photo.height
    guard let canvas = CGContext(
        data: nil,
        width: width,
        height: photoHeight,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { throw CocoaError(.fileWriteUnknown) }
    canvas.draw(photo, in: CGRect(x: 0, y: 0, width: width, height: photoHeight))
    canvas.draw(piece, in: pieceRect)
    guard let full = canvas.makeImage() else { throw CocoaError(.fileWriteUnknown) }
    let crop = CGRect(x: 190, y: 300, width: 380, height: 320)
    guard let cropped = full.cropping(to: crop) else { throw CocoaError(.fileWriteUnknown) }
    return scale(cropped, factor: 3)
}

func scale(_ image: CGImage, factor: CGFloat) -> CGImage {
    let width = Int((CGFloat(image.width) * factor).rounded())
    let height = Int((CGFloat(image.height) * factor).rounded())
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fputs("rk-s98: scale context failed\n", stderr)
        exit(1)
    }
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    guard let scaled = context.makeImage() else {
        fputs("rk-s98: scale image failed\n", stderr)
        exit(1)
    }
    return scaled
}

func menuImage(status: DaemonStatus) -> CGImage {
    let width: CGFloat = 372
    let barHeight: CGFloat = 28
    let cardSize = TrackMenuCard.preferredSize
    let quitHeight: CGFloat = 32
    let menuHeight = cardSize.height + quitHeight
    let size = NSSize(width: width, height: barHeight + menuHeight)
    let chrome = MenuChrome(frame: NSRect(origin: .zero, size: size), cardSize: cardSize, barHeight: barHeight, quitHeight: quitHeight)
    chrome.apply(status)
    let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
    window.appearance = NSAppearance(named: .darkAqua)
    window.contentView = chrome
    chrome.appearance = window.appearance
    chrome.layoutSubtreeIfNeeded()
    window.displayIfNeeded()
    guard let image = rasterize(chrome, scale: 2) else {
        fputs("rk-s98: menu raster failed\n", stderr)
        exit(1)
    }
    return image
}

func rasterize(_ view: NSView, scale: CGFloat) -> CGImage? {
    let bounds = view.bounds
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(bounds.width * scale),
        pixelsHigh: Int(bounds.height * scale),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { return nil }
    rep.size = bounds.size
    view.cacheDisplay(in: bounds, to: rep)
    return rep.cgImage
}

final class MenuChrome: NSView {
    private let card: TrackMenuCard
    private let barHeight: CGFloat
    private let quitHeight: CGFloat

    init(frame frameRect: NSRect, cardSize: NSSize, barHeight: CGFloat, quitHeight: CGFloat) {
        card = TrackMenuCard(frame: NSRect(x: (frameRect.width - cardSize.width) / 2, y: quitHeight, width: cardSize.width, height: cardSize.height))
        self.barHeight = barHeight
        self.quitHeight = quitHeight
        super.init(frame: frameRect)
        wantsLayer = true
        addSubview(card)
    }

    required init?(coder: NSCoder) { nil }

    func apply(_ status: DaemonStatus) {
        card.apply(status)
        needsLayout = true
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor(srgbRed: 0.11, green: 0.11, blue: 0.12, alpha: 1).setFill()
        bounds.fill()
        let bar = NSRect(x: 0, y: bounds.height - barHeight, width: bounds.width, height: barHeight)
        NSColor(srgbRed: 0.16, green: 0.16, blue: 0.17, alpha: 1).setFill()
        bar.fill()
        let iconSide: CGFloat = 18
        let iconRect = NSRect(x: bounds.width - 34, y: bar.minY + (barHeight - iconSide) / 2, width: iconSide, height: iconSide)
        let highlight = iconRect.insetBy(dx: -6, dy: -4)
        NSColor(white: 1, alpha: 0.16).setFill()
        NSBezierPath(roundedRect: highlight, xRadius: 6, yRadius: 6).fill()
        if let symbol = NSImage(systemSymbolName: "music.note", accessibilityDescription: "RK S98") {
            let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
                .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
            symbol.withSymbolConfiguration(config)?.draw(in: iconRect)
        }
        let menu = NSRect(x: 0, y: 0, width: bounds.width, height: bounds.height - barHeight)
        NSColor(srgbRed: 0.20, green: 0.20, blue: 0.22, alpha: 1).setFill()
        NSBezierPath(roundedRect: menu, xRadius: 12, yRadius: 12).fill()
        NSColor(white: 1, alpha: 0.14).setFill()
        NSRect(x: 14, y: quitHeight - 1, width: bounds.width - 28, height: 1).fill()
        let title = "Salir" as NSString
        let shortcut = "⌘Q" as NSString
        let font = NSFont.systemFont(ofSize: 13)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        let shortcutAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(white: 1, alpha: 0.55)
        ]
        let titleSize = title.size(withAttributes: titleAttributes)
        title.draw(at: NSPoint(x: 18, y: (quitHeight - titleSize.height) / 2), withAttributes: titleAttributes)
        let shortcutSize = shortcut.size(withAttributes: shortcutAttributes)
        shortcut.draw(
            at: NSPoint(x: bounds.width - 16 - shortcutSize.width, y: (quitHeight - shortcutSize.height) / 2),
            withAttributes: shortcutAttributes
        )
    }
}

func appIcon(side: Int) -> CGImage {
    guard let context = CGContext(
        data: nil,
        width: side,
        height: side,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fputs("rk-s98: icon context failed\n", stderr)
        exit(1)
    }
    let canvas = CGFloat(side)
    context.setFillColor(CGColor(srgbRed: 0.08, green: 0.08, blue: 0.10, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: canvas, height: canvas))
    let font = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, canvas * 0.46, nil)
    let attributes: [CFString: Any] = [
        kCTFontAttributeName: font,
        kCTForegroundColorAttributeName: CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
    ]
    let text = CFAttributedStringCreate(nil, "RK" as CFString, attributes as CFDictionary)!
    let line = CTLineCreateWithAttributedString(text)
    var ascent: CGFloat = 0
    var descent: CGFloat = 0
    let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, nil))
    context.textPosition = CGPoint(x: (canvas - width) / 2, y: (canvas - ascent + descent) / 2 + canvas * 0.05)
    CTLineDraw(line, context)
    let bar = CGRect(x: canvas * 0.21, y: canvas * 0.20, width: canvas * 0.58, height: canvas * 0.041)
    context.setFillColor(CGColor(srgbRed: 0.35, green: 0.78, blue: 0.55, alpha: 1))
    context.addPath(CGPath(roundedRect: bar, cornerWidth: bar.height / 2, cornerHeight: bar.height / 2, transform: nil))
    context.fillPath()
    guard let image = context.makeImage() else {
        fputs("rk-s98: icon image failed\n", stderr)
        exit(1)
    }
    return image
}

func pngData(_ image: CGImage) throws -> Data {
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
        throw CocoaError(.fileWriteUnknown)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    return data as Data
}

func writePNG(_ image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw CocoaError(.fileWriteUnknown)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
}

func writeJPEG(_ image: CGImage, to url: URL, quality: CGFloat) throws {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
        throw CocoaError(.fileWriteUnknown)
    }
    CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
}

extension RenderedFrame {
    func readmeImage() throws -> CGImage {
        try pngDataImage()
    }

    private func pngDataImage() throws -> CGImage {
        let data = try pngData()
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw RenderError(description: "Could not read the rendered PNG")
        }
        return image
    }
}
