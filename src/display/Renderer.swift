import CoreGraphics
import CoreText
import Foundation
import ImageIO

struct RenderedFrame {
    let rgba: Data
    let width: Int
    let height: Int

    func pixel(x: Int, y: Int) -> (UInt8, UInt8, UInt8, UInt8) {
        let index = (y * width + x) * 4
        return (rgba[index], rgba[index + 1], rgba[index + 2], rgba[index + 3])
    }

    var rgb565: Data {
        var output = Data(count: width * height * 2)
        for pixelIndex in 0..<(width * height) {
            let source = pixelIndex * 4
            let value = (UInt16(rgba[source]) >> 3) << 11
                | (UInt16(rgba[source + 1]) >> 2) << 5
                | (UInt16(rgba[source + 2]) >> 3)
            output[pixelIndex * 2] = UInt8(value >> 8)
            output[pixelIndex * 2 + 1] = UInt8(value & 0xFF)
        }
        return output
    }

    func pngData() throws -> Data {
        let image = try cgImage()
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else {
            throw RenderError(description: "Could not create a PNG destination")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw RenderError(description: "Could not write the PNG")
        }
        return data as Data
    }

    private func cgImage() throws -> CGImage {
        let info = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        guard let provider = CGDataProvider(data: rgba as CFData),
              let image = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: info),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ) else {
            throw RenderError(description: "Could not wrap the rendered pixels")
        }
        return image
    }
}

enum DisplayRenderer {
    private static let titleColor = CGColor(red: 1, green: 1, blue: 1, alpha: 1)
    private static let artistColor = CGColor(red: 0.82, green: 0.82, blue: 0.84, alpha: 1)
    private static let albumColor = CGColor(red: 0.62, green: 0.64, blue: 0.68, alpha: 1)

    static func render(_ track: TrackInfo) throws -> RenderedFrame {
        let width = CanvasLayout.width
        let height = CanvasLayout.height
        let info = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: info
        ) else {
            throw RenderError(description: "Could not create the 320×172 context")
        }
        context.interpolationQuality = .high
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        context.setFillColor(CGColor(red: 16 / 255, green: 16 / 255, blue: 20 / 255, alpha: 1))
        context.fill(bounds)

        let art = CGRect(
            x: CanvasLayout.artOrigin.x,
            y: CanvasLayout.artOrigin.y,
            width: CanvasLayout.artSide,
            height: CanvasLayout.artSide
        )
        if let artwork = track.artwork {
            draw(artwork, fittedIn: art, context: context)
        } else {
            drawPlaceholder(initial: String(track.displayTitle.first ?? "?"), in: art, context: context)
        }
        drawText(track, in: CanvasLayout.textColumn, context: context)

        guard let raw = context.data else {
            throw RenderError(description: "The context has no pixels")
        }
        let rgba = Data(bytes: raw, count: width * height * 4)
        return RenderedFrame(rgba: rgba, width: width, height: height)
    }

    static func mockTrack() -> TrackInfo {
        TrackInfo(
            title: "Buenos días, sol",
            artist: "Álvaro Soler",
            album: "Mar de colores",
            artwork: wideSwatch()
        )
    }

    private static func draw(_ image: CGImage, fittedIn box: CGRect, context: CGContext) {
        let fitted = CanvasLayout.aspectFit(
            content: CGSize(width: image.width, height: image.height),
            in: box.size
        )
        let rect = CGRect(
            x: box.minX + (box.width - fitted.width) / 2,
            y: box.minY + (box.height - fitted.height) / 2,
            width: fitted.width,
            height: fitted.height
        )
        context.draw(image, in: rect)
    }

    private static func drawPlaceholder(initial: String, in box: CGRect, context: CGContext) {
        context.setFillColor(CGColor(red: 0.16, green: 0.16, blue: 0.2, alpha: 1))
        context.fill(box)
        let font = CTFontCreateWithName("Helvetica Neue" as CFString, 48, nil)
        let line = textLine(initial, font: font, color: titleColor, width: box.width)
        let ascent = CTFontGetAscent(font)
        let descent = CTFontGetDescent(font)
        let lineWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        context.textPosition = CGPoint(
            x: box.midX - lineWidth / 2,
            y: box.midY - (ascent - descent) / 2
        )
        CTLineDraw(line, context)
    }

    private static func drawText(_ track: TrackInfo, in column: CGRect, context: CGContext) {
        let rows: [(String, CTFont, CGColor)] = [
            (track.displayTitle, CTFontCreateWithName("Helvetica Neue" as CFString, 16, nil), titleColor),
            (track.displayArtist, CTFontCreateWithName("Helvetica Neue" as CFString, 13, nil), artistColor),
        ] + (track.displayAlbum.map {
            [($0, CTFontCreateWithName("Helvetica Neue" as CFString, 12, nil), albumColor)]
        } ?? [])
        let gap: CGFloat = 5
        let heights = rows.map { CTFontGetAscent($0.1) + CTFontGetDescent($0.1) }
        let total = heights.reduce(0, +) + gap * CGFloat(rows.count - 1)
        var top = column.maxY - (column.height - total) / 2
        for (index, row) in rows.enumerated() {
            let ascent = CTFontGetAscent(row.1)
            let line = textLine(row.0, font: row.1, color: row.2, width: column.width)
            context.textPosition = CGPoint(x: column.minX, y: top - ascent)
            CTLineDraw(line, context)
            top -= heights[index] + gap
        }
    }

    static func textLine(_ text: String, font: CTFont, color: CGColor, width: CGFloat) -> CTLine {
        let attributes: [CFString: Any] = [
            kCTFontAttributeName: font,
            kCTForegroundColorAttributeName: color,
        ]
        let full = CTLineCreateWithAttributedString(CFAttributedStringCreate(nil, text as CFString, attributes as CFDictionary))
        let ellipsis = CTLineCreateWithAttributedString(CFAttributedStringCreate(nil, "…" as CFString, attributes as CFDictionary))
        return CTLineCreateTruncatedLine(full, Double(width), .end, ellipsis) ?? full
    }

    private static func wideSwatch() -> CGImage {
        let width = 200
        let height = 80
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                let green = x < width / 2
                pixels[index] = green ? 32 : 230
                pixels[index + 1] = green ? 170 : 70
                pixels[index + 2] = green ? 90 : 50
                pixels[index + 3] = 255
            }
        }
        let info = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        return CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: info
        )!.makeImage()!
    }
}

struct RenderError: Error, CustomStringConvertible {
    let description: String
}
