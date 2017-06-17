//
//  TokenCell.swift
//  Ilion
//
//  Created by Tamas Lustyik on 2017. 06. 17..
//  Copyright © 2017. Tamas Lustyik. All rights reserved.
//

import Cocoa

// Heavily inspired by https://github.com/octiplex/OEXTokenField

class TokenCell: NSTextAttachmentCell {

    static let titleMargin: CGFloat = 11
    static let tokenMargin: CGFloat = 3

    enum DrawingMode {
        case `default`, highlighted, selected
    }
    
    private var drawingMode: DrawingMode = .default
    
    // MARK: - NSTextAttachmentCell
    
    override func cellBaselineOffset() -> NSPoint {
        return NSPoint(x: 0, y: font?.descender ?? 0)
    }
    
    override func cellSize() -> NSSize {
        let attribs = [NSFontAttributeName: font ?? NSFont.systemFont(ofSize: 13)]
        let titleSize = (stringValue as NSString).size(withAttributes: attribs)
        return cellSize(forTitleSize: titleSize)
    }
    
    override func titleRect(forBounds rect: NSRect) -> NSRect {
        var bounds = rect
        bounds.size.width = max(bounds.size.width, TokenCell.titleMargin * 2 + bounds.size.height)
        return bounds.insetBy(dx: TokenCell.titleMargin + bounds.size.height / 2, dy: 0)
    }
    
    override func draw(withFrame cellFrame: NSRect, in controlView: NSView?, characterIndex charIndex: Int, layoutManager: NSLayoutManager) {
        draw(withFrame: cellFrame, in: controlView, characterIndex: charIndex)
    }
    
    override func draw(withFrame cellFrame: NSRect, in controlView: NSView?) {
        draw(withFrame: cellFrame, in: controlView, characterIndex: -1)
    }
    
    override func draw(withFrame cellFrame: NSRect, in controlView: NSView?, characterIndex charIndex: Int) {
        guard let controlView = controlView else { return }
        
        drawingMode = isHighlighted && (controlView.window?.isKeyWindow ?? false) ?
            .highlighted : .default
        
        if charIndex >= 0, let textView = controlView as? NSTextView {
            for rangeValue in textView.selectedRanges {
                let range = rangeValue.rangeValue
                guard NSLocationInRange(charIndex, range) else { continue }
                if textView.window?.isKeyWindow ?? false {
                    drawingMode = .selected
                    break
                }
            }
        }
        
        drawToken(with: cellFrame, in: controlView)
    }
    
    // MARK: - private methods
    
    private func cellSize(forTitleSize titleSize: NSSize) -> NSSize {
        var size = titleSize
        size.width += size.height + TokenCell.titleMargin * 2
        let rect = NSRect(origin: .zero, size: size)
        return NSIntegralRect(rect).size;
    }
    
    private func tokenFillColor(for mode: DrawingMode) -> NSColor {
        switch mode {
        case .default: return NSColor(deviceRed: 0.8706, green: 0.9059, blue: 0.9725, alpha: 1)
        case .highlighted: return NSColor(deviceRed: 0.7330, green: 0.8078, blue: 0.9451, alpha: 1)
        case .selected: return NSColor(deviceRed: 0.3490, green: 0.5451, blue: 0.9255, alpha: 1)
        }
    }
    
    private func tokenStrokeColor(for mode: DrawingMode) -> NSColor {
        switch mode {
        case .default: return NSColor(deviceRed: 0.6431, green: 0.7412, blue: 0.9255, alpha: 1)
        case .highlighted: return NSColor(deviceRed: 0.4275, green: 0.5843, blue: 0.8784, alpha: 1)
        case .selected: return NSColor(deviceRed: 0.3490, green: 0.5451, blue: 0.9255, alpha: 1)
        }
    }
    
    private func tokenTitleColor(for mode: DrawingMode) -> NSColor {
        switch mode {
        case .selected: return .alternateSelectedControlTextColor
        default: return .controlTextColor
        }
    }
    
    private func outlinePath(for rect: NSRect) -> NSBezierPath {
        var bounds = rect
        bounds.size.width = max(bounds.size.width, TokenCell.tokenMargin * 2 + bounds.size.height)
        
        let radius = bounds.size.height / 4
        let innerRect = bounds.insetBy(dx: TokenCell.tokenMargin + radius, dy: 0)
        let x1 = innerRect.minX
        let x2 = innerRect.maxX
        let minY = bounds.minY
        let maxY = bounds.maxY
        
        let path = NSBezierPath()
        
        // Left edge
        path.move(to: NSPoint(x: x1-radius, y: minY))
        path.appendArc(withCenter: NSPoint(x: x1, y: maxY-radius), radius: radius, startAngle: 180, endAngle: 90, clockwise: true)
        
        // Top edge
        path.line(to: NSPoint(x: x2, y: maxY))
        
        // Right edge
        path.appendArc(withCenter: NSPoint(x: x2, y: maxY-radius), radius: radius, startAngle: 90, endAngle: 0, clockwise: true)
        path.line(to: NSPoint(x: x2+radius, y: minY+radius))
        path.appendArc(withCenter: NSPoint(x: x2, y: minY+radius), radius: radius, startAngle: 0, endAngle: -90, clockwise: true)
        
        // Bottom edge
        path.line(to: NSPoint(x: x1, y: minY))
        path.appendArc(withCenter: NSPoint(x: x1, y: minY+radius), radius: radius, startAngle: -90, endAngle: 180, clockwise: true)
        path.line(to: NSPoint(x: x1-radius, y: maxY-radius))

        path.close()
        
        path.lineWidth = 2
        
        return path;
    }

    private func drawToken(with rect: NSRect, in view: NSView) {
        NSGraphicsContext.current()?.saveGraphicsState()
    
        let fillColor = tokenFillColor(for: drawingMode)
        let strokeColor = tokenStrokeColor(for: drawingMode)

        let path = outlinePath(for: rect)
        path.addClip()

        fillColor.setFill()
        path.fill()
        
        strokeColor.setStroke()
        path.stroke()

        drawTitle(with: titleRect(forBounds: rect), in: view)

        NSGraphicsContext.current()?.restoreGraphicsState()
    }

    private func drawTitle(with rect: NSRect, in view: NSView) {
        let textColor = tokenTitleColor(for: drawingMode)
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        let attribs = [
            NSFontAttributeName: font ?? NSFont.systemFont(ofSize: 13),
            NSForegroundColorAttributeName: textColor,
            NSParagraphStyleAttributeName: style
        ]
        (stringValue as NSString).draw(in: rect, withAttributes: attribs)
    }
    
}
