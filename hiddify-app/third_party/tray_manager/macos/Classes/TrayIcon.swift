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
    
    /// Renders a compact two-line title (e.g. up/down live speeds) next to
    /// the icon, the way macOS network monitors do. Empty strings clear it.
    /// While a title is shown the status item keeps a stable width (widest
    /// realistic readout, ratcheting up if ever exceeded) so the ticking
    /// numbers never shift the neighbouring menu-bar items.
    public func setTitleLines(_ top: String, _ bottom: String) {
        guard let button = statusItem?.button else { return }
        if top.isEmpty && bottom.isEmpty {
            button.attributedTitle = NSAttributedString(string: "")
            statusItem?.length = NSStatusItem.variableLength
            reservedTextWidth = 0
            self.frame = button.frame
            return
        }
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .right
        paragraph.lineBreakMode = .byClipping
        paragraph.minimumLineHeight = 10
        paragraph.maximumLineHeight = 10
        // AppKit lays a multi-line button title out from the first line's
        // baseline, leaving the block a few points above the bar's center;
        // the negative offset re-centers it (see CodexBar#2345).
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .medium),
            .paragraphStyle: paragraph,
            .baselineOffset: -3.5,
        ]
        // Non-breaking space: breathing room between the readout and the
        // icon (a plain trailing space would hang outside right-aligned
        // text and render no gap).
        let gap = "\u{00A0}"
        let topLine = "\(top)\(gap)"
        let bottomLine = "\(bottom)\(gap)"
        let text = NSMutableAttributedString(
            string: "\(topLine)\n\(bottomLine)", attributes: attributes)
        // Dim the direction arrows so the digits carry the emphasis.
        let full = text.string as NSString
        for arrow in ["↑ ", "↓ "] {
            var search = NSRange(location: 0, length: full.length)
            while true {
                let r = full.range(of: arrow, options: [], range: search)
                if r.location == NSNotFound { break }
                text.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: r)
                let next = r.location + r.length
                if next >= full.length { break }
                search = NSRange(location: next, length: full.length - next)
            }
        }
        button.attributedTitle = text
        // Reserve the widest string each unit tier can produce, then ratchet
        // if a live line ever measures wider (never clips, never jitters).
        var reserve: CGFloat = 0
        for candidate in ["↑ 888 KB/s", "↑ 888 MB/s", "↑ 88.8 MB/s", "↑ 8.88 GB/s", topLine, bottomLine] {
            let sample = candidate.hasSuffix(gap) ? candidate : candidate + gap
            reserve = max(reserve, NSAttributedString(string: sample, attributes: attributes).size().width)
        }
        reservedTextWidth = max(reservedTextWidth, ceil(reserve))
        let iconWidth = button.image?.size.width ?? 18
        statusItem?.length = reservedTextWidth + iconWidth + 14
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
