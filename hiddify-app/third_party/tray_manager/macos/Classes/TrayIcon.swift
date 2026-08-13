//
//  TrayIcon.swift
//  tray_manager
//
//  Created by Lijy91 on 2022/5/15.
//

public class TrayIcon: NSView {
    public var onTrayIconMouseDown:(() -> Void)?
    public var onTrayIconMouseUp:(() -> Void)?
    public var onTrayIconRightMouseDown:(() -> Void)?
    public var onTrayIconRightMouseUp:(() -> Void)?
    
    var statusItem: NSStatusItem?

    /// Widest readout measured so far (ratchet): the item never shrinks while
    /// the speeds are visible, so ticking digits can't nudge the neighbours.
    var reservedTextWidth: CGFloat = 0

    /// The state icon as supplied by setImage (template mask); kept so the
    /// speed readout can be composited around it and restored when cleared.
    var baseImage: NSImage?

    /// Current speed lines; both empty means the plain icon is shown.
    var speedTop: String = ""
    var speedBottom: String = ""
    
    public init() {
        super.init(frame: NSRect.zero)
        statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength)
        statusItem?.button?.addSubview(self)
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame:frameRect);
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func setImage(_ image: NSImage, _ imagePosition: String) {
        baseImage = image
        if !speedTop.isEmpty || !speedBottom.isEmpty {
            // Speeds are showing: fold the new state icon into the composite
            // right away so the item never flashes back to icon-only.
            renderSpeedComposite()
            return
        }
        if let button = statusItem?.button {
            button.image = image
            setImagePosition(imagePosition)
        }


        self.frame = statusItem!.button!.frame
    }
    
    public func setImagePosition(_ imagePosition: String) {
        if let button = statusItem?.button {
            button.imagePosition = imagePosition == "right" ? NSControl.ImagePosition.imageRight : NSControl.ImagePosition.imageLeft
        }
        self.frame = statusItem!.button!.frame
    }
    
    public func removeImage() {
        statusItem?.button?.image = nil
        self.frame = statusItem!.button!.frame
    }
    
    public func setTitle(_ title: String) {
        if let button = statusItem?.button {
            button.title  = title
        }
        self.frame = statusItem!.button!.frame
    }
    
    /// Shows a compact two-line readout (up/down live speeds) beside the
    /// icon, the way macOS network monitors do. Empty strings restore the
    /// plain icon. Everything — reserved text area, gap, icon — is drawn
    /// into ONE fixed-size template image, so nothing inside the item can
    /// drift and the ticking digits never nudge the neighbouring items.
    public func setTitleLines(_ top: String, _ bottom: String) {
        guard let button = statusItem?.button else { return }
        speedTop = top
        speedBottom = bottom
        if top.isEmpty && bottom.isEmpty {
            button.attributedTitle = NSAttributedString(string: "")
            if let icon = baseImage {
                button.image = icon
            }
            statusItem?.length = NSStatusItem.variableLength
            reservedTextWidth = 0
            self.frame = button.frame
            return
        }
        renderSpeedComposite()
    }

    private func speedAttributes(_ paragraph: NSParagraphStyle) -> [NSAttributedString.Key: Any] {
        return [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .medium),
            .paragraphStyle: paragraph,
        ]
    }

    /// One line of the readout as a template mask: digits at full strength,
    /// the direction arrow dimmed so the numbers carry the emphasis.
    private func speedLine(_ line: String, _ paragraph: NSParagraphStyle) -> NSAttributedString {
        let text = NSMutableAttributedString(string: line, attributes: speedAttributes(paragraph))
        text.addAttribute(
            .foregroundColor, value: NSColor.black,
            range: NSRange(location: 0, length: text.length))
        for arrow in ["↑ ", "↓ "] {
            let r = (text.string as NSString).range(of: arrow)
            if r.location != NSNotFound {
                text.addAttribute(
                    .foregroundColor, value: NSColor.black.withAlphaComponent(0.5), range: r)
            }
        }
        return text
    }

    private func renderSpeedComposite() {
        guard let button = statusItem?.button, let icon = baseImage else { return }
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .right
        paragraph.lineBreakMode = .byClipping
        paragraph.minimumLineHeight = 10
        paragraph.maximumLineHeight = 10
        let attributes = speedAttributes(paragraph)
        // Reserve the widest string each unit tier can produce, ratcheting
        // if a live line ever measures wider (never clips, never jitters).
        var reserve: CGFloat = 0
        for candidate in ["↑ 888 MB/s", "↑ 88.8 MB/s", "↑ 8.88 GB/s", speedTop, speedBottom] {
            reserve = max(reserve, NSAttributedString(string: candidate, attributes: attributes).size().width)
        }
        reservedTextWidth = max(reservedTextWidth, ceil(reserve))

        let textWidth = reservedTextWidth
        let gap: CGFloat = 6
        let iconSize = icon.size
        let height: CGFloat = 22
        let width = textWidth + gap + iconSize.width
        let topLine = speedLine(speedTop, paragraph)
        let bottomLine = speedLine(speedBottom, paragraph)

        let composite = NSImage(size: NSSize(width: width, height: height), flipped: false) { rect in
            let iconRect = NSRect(
                x: rect.maxX - iconSize.width,
                y: (rect.height - iconSize.height) / 2,
                width: iconSize.width,
                height: iconSize.height)
            icon.draw(in: iconRect)
            // 2 × 10pt lines optically centered in the 22pt bar.
            let blockRect = NSRect(x: 0, y: (rect.height - 20) / 2, width: textWidth, height: 20)
            topLine.draw(in: NSRect(x: 0, y: blockRect.maxY - 10, width: textWidth, height: 10))
            bottomLine.draw(in: NSRect(x: 0, y: blockRect.minY, width: textWidth, height: 10))
            return true
        }
        composite.isTemplate = true
        button.attributedTitle = NSAttributedString(string: "")
        button.imagePosition = .imageOnly
        button.image = composite
        statusItem?.length = NSStatusItem.variableLength
        self.frame = button.frame
    }
    
    public func setToolTip(_ toolTip: String) {
        if let button = statusItem?.button {
            button.toolTip  = toolTip
        }
    }
    
    public override func mouseDown(with event: NSEvent) {
        statusItem?.button?.highlight(true)
        self.onTrayIconMouseDown!()
    }
    
    public override func mouseUp(with event: NSEvent) {
        statusItem?.button?.highlight(false)
        self.onTrayIconMouseUp!()
    }
    
    public override func rightMouseDown(with event: NSEvent) {
        self.onTrayIconRightMouseDown!()
    }
    
    public override func rightMouseUp(with event: NSEvent) {
        self.onTrayIconRightMouseUp!()
    }
}
