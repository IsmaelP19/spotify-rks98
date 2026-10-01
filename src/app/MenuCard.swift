import AppKit

final class TrackMenuCard: NSView, NSMenuDelegate {
    static let preferredSize = NSSize(width: 360, height: 132)
    private let titleLine = MarqueeTextView()
    private let artistLine = MarqueeTextView()
    private let albumLine = MarqueeTextView()
    private let noteLine = NSTextField(labelWithString: "")
    private let percent = NSTextField(labelWithString: "")
    private let progressBar = NSView()
    private let progressFill = NSView()
    private var artwork = NSImage()
    private var hasArtwork = false
    private var progressValue: Double = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor(srgbRed: 16 / 255, green: 16 / 255, blue: 20 / 255, alpha: 1).cgColor
        layer?.cornerRadius = 10

        titleLine.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        titleLine.textColor = .white
        artistLine.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        artistLine.textColor = NSColor(srgbRed: 0.82, green: 0.82, blue: 0.84, alpha: 1)
        albumLine.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        albumLine.textColor = NSColor(srgbRed: 0.62, green: 0.64, blue: 0.68, alpha: 1)
        for line in [titleLine, artistLine, albumLine] {
            line.clipsToBounds = true
            addSubview(line)
        }

        noteLine.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        noteLine.textColor = NSColor(srgbRed: 0.95, green: 0.72, blue: 0.45, alpha: 1)
        noteLine.lineBreakMode = .byTruncatingTail
        noteLine.isBezeled = false
        noteLine.drawsBackground = false
        addSubview(noteLine)

        percent.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        percent.textColor = .white
        percent.alignment = .right
        percent.isBezeled = false
        percent.drawsBackground = false
        addSubview(percent)

        progressBar.wantsLayer = true
        progressBar.layer?.backgroundColor = NSColor(white: 1, alpha: 0.16).cgColor
        progressBar.layer?.cornerRadius = 2
        progressFill.wantsLayer = true
        progressFill.layer?.backgroundColor = NSColor(srgbRed: 0.35, green: 0.78, blue: 0.55, alpha: 1).cgColor
        progressFill.layer?.cornerRadius = 2
        progressBar.addSubview(progressFill)
        addSubview(progressBar)
    }

    required init?(coder: NSCoder) { nil }

    func apply(_ status: DaemonStatus) {
        titleLine.string = status.title
        artistLine.string = status.artist
        albumLine.string = status.album
        noteLine.stringValue = status.note
        if let data = status.artworkPNG, let image = NSImage(data: data) {
            artwork = image
            hasArtwork = true
        } else if status.artworkPNG == nil, status.artist.isEmpty, status.album.isEmpty {
            hasArtwork = false
        }
        let uploading = status.progress != nil
        progressBar.isHidden = !uploading
        percent.isHidden = !uploading
        if let progress = status.progress {
            progressValue = min(1, max(0, progress))
            percent.stringValue = "\(Int((progressValue * 100).rounded()))%"
        }
        needsLayout = true
        needsDisplay = true
    }

    override func layout() {
        super.layout()
        let margin: CGFloat = 10
        let artSide: CGFloat = 112
        let art = NSRect(x: margin, y: margin, width: artSide, height: artSide)
        let textX = art.maxX + 12
        let textWidth = max(0, bounds.width - textX - margin)
        titleLine.frame = NSRect(x: textX, y: art.maxY - 26, width: textWidth, height: 22)
        artistLine.frame = NSRect(x: textX, y: titleLine.frame.minY - 24, width: textWidth, height: 20)
        albumLine.frame = NSRect(x: textX, y: artistLine.frame.minY - 22, width: textWidth, height: 18)
        noteLine.frame = NSRect(x: textX, y: art.minY + 18, width: max(0, textWidth - 48), height: 16)
        percent.frame = NSRect(x: bounds.width - margin - 44, y: art.minY, width: 44, height: 16)
        progressBar.frame = NSRect(x: textX, y: art.minY + 6, width: max(0, percent.frame.minX - textX - 8), height: 4)
        progressFill.frame = NSRect(x: 0, y: 0, width: progressBar.bounds.width * progressValue, height: 4)
        artworkFrame = art
    }

    private var artworkFrame = NSRect.zero

    override func draw(_ dirtyRect: NSRect) {
        NSColor(srgbRed: 16 / 255, green: 16 / 255, blue: 20 / 255, alpha: 1).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 10, yRadius: 10).fill()
        let path = NSBezierPath(roundedRect: artworkFrame, xRadius: 8, yRadius: 8)
        NSGraphicsContext.current?.cgContext.saveGState()
        path.addClip()
        if hasArtwork {
            artwork.draw(in: artworkFrame, from: .zero, operation: .sourceOver, fraction: 1)
        } else {
            NSColor(white: 1, alpha: 0.08).setFill()
            artworkFrame.fill()
        }
        NSGraphicsContext.current?.cgContext.restoreGState()
    }

    func menuDidClose(_ menu: NSMenu) {
        FullTextTip.shared.hideTip()
    }
}

final class MarqueeTextView: NSView {
    var string = "" {
        didSet {
            if oldValue != string {
                offset = 0
                pause = 0.8
                toolTip = string
                needsDisplay = true
            }
        }
    }
    var font = NSFont.systemFont(ofSize: 13, weight: .medium)
    var textColor = NSColor.white
    private var offset: CGFloat = 0
    private var pause: TimeInterval = 0.8
    private var timer: Timer?
    private var tracking: NSTrackingArea?

    override var isFlipped: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        timer?.invalidate()
        guard window != nil else { return }
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer, forMode: .common)
        RunLoop.main.add(timer, forMode: .eventTracking)
        self.timer = timer
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) {
        guard !string.isEmpty else { return }
        FullTextTip.shared.show(string, from: self)
    }

    override func mouseExited(with event: NSEvent) {
        FullTextTip.shared.hideTip()
    }

    private func tick() {
        let extra = textWidth - bounds.width
        guard extra > 1, bounds.width > 0 else {
            if offset != 0 { offset = 0; needsDisplay = true }
            return
        }
        if pause > 0 {
            pause -= 1.0 / 30.0
            return
        }
        offset += 0.8
        if offset > extra + 16 {
            offset = 0
            pause = 1.1
        }
        needsDisplay = true
    }

    private var attributes: [NSAttributedString.Key: Any] {
        [.font: font, .foregroundColor: textColor]
    }

    private var textWidth: CGFloat {
        (string as NSString).size(withAttributes: attributes).width
    }

    override func draw(_ dirtyRect: NSRect) {
        guard !string.isEmpty, let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.clip(to: bounds)
        let size = (string as NSString).size(withAttributes: attributes)
        let rect = NSRect(x: -offset, y: (bounds.height - size.height) / 2, width: size.width + 4, height: size.height)
        (string as NSString).draw(in: rect, withAttributes: attributes)
        context.restoreGState()
    }
}

final class FullTextTip: NSPanel {
    static let shared = FullTextTip()
    private let label = NSTextField(wrappingLabelWithString: "")

    private init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 280, height: 40), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .popUpMenu
        backgroundColor = NSColor(srgbRed: 0.12, green: 0.12, blue: 0.14, alpha: 0.98)
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        label.maximumNumberOfLines = 4
        label.lineBreakMode = .byWordWrapping
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView?.addSubview(label)
        guard let content = contentView else { return }
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -10),
            label.topAnchor.constraint(equalTo: content.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -8)
        ])
    }

    func show(_ text: String, from view: NSView) {
        guard let host = view.window else { return }
        label.stringValue = text
        label.preferredMaxLayoutWidth = 320
        let fitting = label.fittingSize
        let width = min(340, max(160, fitting.width + 20))
        let height = fitting.height + 16
        let local = view.convert(view.bounds, to: nil)
        let screenRect = host.convertToScreen(local)
        var origin = NSPoint(x: host.frame.maxX + 8, y: screenRect.midY - height / 2)
        if let screen = host.screen, origin.x + width > screen.visibleFrame.maxX {
            origin.x = host.frame.minX - width - 8
        }
        setFrame(NSRect(origin: origin, size: NSSize(width: width, height: height)), display: true)
        orderFrontRegardless()
    }

    func hideTip() {
        orderOut(nil)
    }
}
