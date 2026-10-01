import CoreGraphics
import Foundation

/// Transfer raster accepted by the S98 and shown full-frame on 2026-10-01.
/// This is the size the official editor and our upload use, not a separate physical measurement.
enum CanvasLayout {
    static let width = 320
    static let height = 172
    static let margin: CGFloat = 10
    static let artSide: CGFloat = 148

    static var artOrigin: CGPoint {
        CGPoint(x: margin, y: (CGFloat(height) - artSide) / 2)
    }

    static var textColumn: CGRect {
        let x = margin + artSide + margin
        return CGRect(x: x, y: artOrigin.y, width: CGFloat(width) - x - margin, height: artSide)
    }

    static func aspectFit(content: CGSize, in box: CGSize) -> CGSize {
        guard content.width > 0, content.height > 0, box.width > 0, box.height > 0 else { return .zero }
        let scale = min(box.width / content.width, box.height / content.height)
        return CGSize(width: (content.width * scale).rounded(.down), height: (content.height * scale).rounded(.down))
    }
}
