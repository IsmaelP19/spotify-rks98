import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

let resources = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".build/icon", isDirectory: true)
try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)

func render(side: Int) -> CGImage {
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let context = CGContext(
        data: nil,
        width: side,
        height: side,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fputs("context failed\n", stderr)
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
    context.textPosition = CGPoint(
        x: (canvas - width) / 2,
        y: (canvas - ascent + descent) / 2 + canvas * 0.05
    )
    CTLineDraw(line, context)

    let bar = CGRect(x: canvas * 0.21, y: canvas * 0.20, width: canvas * 0.58, height: canvas * 0.041)
    context.setFillColor(CGColor(srgbRed: 0.35, green: 0.78, blue: 0.55, alpha: 1))
    context.addPath(CGPath(roundedRect: bar, cornerWidth: bar.height / 2, cornerHeight: bar.height / 2, transform: nil))
    context.fillPath()
    guard let image = context.makeImage() else {
        fputs("image failed\n", stderr)
        exit(1)
    }
    return image
}

func writePNG(_ image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw CocoaError(.fileWriteUnknown)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw CocoaError(.fileWriteUnknown)
    }
}

let iconset = resources.appendingPathComponent("AppIcon.iconset", isDirectory: true)
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let files: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]
for (name, side) in files {
    try writePNG(render(side: side), to: iconset.appendingPathComponent(name))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", resources.appendingPathComponent("AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
if iconutil.terminationStatus != 0 { exit(iconutil.terminationStatus) }
try? FileManager.default.removeItem(at: iconset)
