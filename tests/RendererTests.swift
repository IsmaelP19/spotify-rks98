import CoreGraphics
import CoreText
import Foundation

@main
struct RendererTests {
    static func main() {
        var tests = 0
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            guard condition() else { fatalError(message) }
            tests += 1
        }

        check(CanvasLayout.width == TftUpload.width && CanvasLayout.height == TftUpload.height,
              "The preview uses the same raster the keyboard accepted")
        let wide = CanvasLayout.aspectFit(content: CGSize(width: 200, height: 100), in: CGSize(width: 80, height: 80))
        check(wide == CGSize(width: 80, height: 40), "A wide image keeps its ratio inside the square")
        let tall = CanvasLayout.aspectFit(content: CGSize(width: 50, height: 100), in: CGSize(width: 80, height: 80))
        check(tall == CGSize(width: 40, height: 80), "A tall image keeps its ratio inside the square")
        check(CanvasLayout.aspectFit(content: .zero, in: CGSize(width: 10, height: 10)) == .zero, "Empty artwork does not divide")

        let missing = TrackInfo(title: "  ", artist: "", album: "   ", artwork: nil)
        check(missing.displayTitle == "Sin título", "Blank title gets a fallback")
        check(missing.displayArtist == "Artista desconocido", "Blank artist gets a fallback")
        check(missing.displayAlbum == nil, "Blank album is omitted")
        check(TrackInfo(title: "東京", artist: "café", album: nil, artwork: nil).displayAlbum == nil, "Missing album stays absent")

        let font = CTFontCreateWithName("Helvetica Neue" as CFString, 16, nil)
        let color = CGColor(gray: 1, alpha: 1)
        let long = String(repeating: "Supercalifragilistic ", count: 8)
        let full = DisplayRenderer.textLine(long, font: font, color: color, width: 10_000)
        let line = DisplayRenderer.textLine(long, font: font, color: color, width: CanvasLayout.textColumn.width)
        let used = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        let fullWidth = CGFloat(CTLineGetTypographicBounds(full, nil, nil, nil))
        check(used < fullWidth / 2, "Long titles are truncated")
        check(used < CanvasLayout.textColumn.width + 8, "Truncated titles stay within the column and its margin")
        let unicode = DisplayRenderer.textLine("東京 — café", font: font, color: color, width: 200)
        check(CTLineGetTypographicBounds(unicode, nil, nil, nil) > 0, "Unicode text produces a line")

        let marked = markedImage()
        let oriented = try! DisplayRenderer.render(TrackInfo(title: "Queen", artist: "Bohemian", album: nil, artwork: marked))
        let left = Int(CanvasLayout.artOrigin.x) + 24
        let right = Int(CanvasLayout.artOrigin.x + CanvasLayout.artSide) - 24
        let upper = Int(CanvasLayout.artOrigin.y) + 24
        let lower = Int(CanvasLayout.artOrigin.y + CanvasLayout.artSide) - 24
        let artTopLeft = oriented.pixel(x: left, y: upper)
        let artTopRight = oriented.pixel(x: right, y: upper)
        let artBottomLeft = oriented.pixel(x: left, y: lower)
        check(artTopLeft.0 > 200 && artTopLeft.1 < 40, "Artwork top-left stays top-left")
        check(artTopRight.1 > 200 && artTopRight.0 < 40, "Artwork top-right stays top-right")
        check(artBottomLeft.2 > 200 && artBottomLeft.0 < 40, "Artwork bottom-left stays bottom-left")

        let red = solidImage(width: 4, height: 2, red: 255, green: 0, blue: 0)
        let framed = try! DisplayRenderer.render(TrackInfo(title: "Queen", artist: "Bohemian", album: nil, artwork: red))
        check(framed.rgba.count == CanvasLayout.width * CanvasLayout.height * 4, "RGBA buffer matches the raster")
        check(framed.rgb565.count == 110_080, "RGB565 buffer is one upload frame")
        let center = framed.pixel(x: Int(CanvasLayout.artOrigin.x + CanvasLayout.artSide / 2), y: CanvasLayout.height / 2)
        check(center.0 > 200 && center.1 < 40 && center.2 < 40, "Square artwork stays red at its center")
        let outside = framed.pixel(x: CanvasLayout.width - 4, y: CanvasLayout.height / 2)
        check(outside.0 < 40 && outside.1 < 40 && outside.2 < 40, "Artwork does not cover the text column")
        let topBar = framed.pixel(x: Int(CanvasLayout.artOrigin.x + 4), y: 2)
        check(topBar.0 < 40, "A wide image is letterboxed instead of stretched")

        let placeholder = try! DisplayRenderer.render(TrackInfo(title: "東京", artist: "Artista", album: nil, artwork: nil))
        let panel = placeholder.pixel(x: Int(CanvasLayout.artOrigin.x + 20), y: CanvasLayout.height / 2)
        check(panel.0 != center.0 || panel.1 != center.1, "Missing artwork uses its own panel")
        let png = try! framed.pngData()
        check(png.starts(with: Data([0x89, 0x50, 0x4E, 0x47])), "Preview encodes as PNG")
        print("PASS: \(tests) offline renderer assertions")
    }

    private static func markedImage() -> CGImage {
        let width = 8
        let height = 8
        var pixels = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                let top = y < height / 2
                let left = x < width / 2
                pixels[index] = top ? (left ? 255 : 0) : 0
                pixels[index + 1] = top ? (left ? 0 : 255) : 0
                pixels[index + 2] = top ? 0 : (left ? 255 : 255)
            }
        }
        return image(width: width, height: height, pixels: pixels)
    }

    private static func solidImage(width: Int, height: Int, red: UInt8, green: UInt8, blue: UInt8) -> CGImage {
        var pixels = [UInt8](repeating: 255, count: width * height * 4)
        for index in stride(from: 0, to: pixels.count, by: 4) {
            pixels[index] = red
            pixels[index + 1] = green
            pixels[index + 2] = blue
        }
        return image(width: width, height: height, pixels: pixels)
    }

    private static func image(width: Int, height: Int, pixels: [UInt8]) -> CGImage {
        let info = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        return CGImage(
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
        )!
    }
}
