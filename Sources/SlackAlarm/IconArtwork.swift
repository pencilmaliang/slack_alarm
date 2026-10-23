import AppKit
import CoreGraphics

// Code-native artwork shared by the runtime status view and reproducible icon generator.
enum IconArtwork {
    static func glyph(_ c: CGContext, outline: CGColor, active: Bool, polished: Bool) {
        c.saveGState()
        defer { c.restoreGState() }
        c.setStrokeColor(outline); c.setFillColor(outline)
        c.setLineCap(.round); c.setLineJoin(.round)
        c.setLineWidth(polished ? 57 : 68)
        c.strokeEllipse(in: CGRect(x: 246, y: 214, width: 532, height: 532))
        c.move(to: CGPoint(x: 328, y: 284)); c.addLine(to: CGPoint(x: 263, y: 208))
        c.move(to: CGPoint(x: 696, y: 284)); c.addLine(to: CGPoint(x: 761, y: 208)); c.strokePath()
        c.setLineWidth(35)
        c.move(to: CGPoint(x: 512, y: 754)); c.addLine(to: CGPoint(x: 512, y: 786)); c.strokePath()
        c.setLineWidth(39)
        c.move(to: CGPoint(x: 465, y: 796)); c.addLine(to: CGPoint(x: 559, y: 796)); c.strokePath()
        func bell() {
            c.beginPath(); c.move(to: CGPoint(x: 216, y: 666))
            c.addCurve(to: CGPoint(x: 202, y: 718), control1: CGPoint(x: 191, y: 665), control2: CGPoint(x: 192, y: 696))
            c.addCurve(to: CGPoint(x: 306, y: 843), control1: CGPoint(x: 208, y: 775), control2: CGPoint(x: 261, y: 833))
            c.addCurve(to: CGPoint(x: 393, y: 812), control1: CGPoint(x: 350, y: 857), control2: CGPoint(x: 390, y: 845))
            c.addCurve(to: CGPoint(x: 374, y: 784), control1: CGPoint(x: 398, y: 800), control2: CGPoint(x: 386, y: 791))
            c.addLine(to: CGPoint(x: 237, y: 676))
            c.addQuadCurve(to: CGPoint(x: 216, y: 666), control: CGPoint(x: 225, y: 666)); c.closePath(); c.fillPath()
        }
        bell()
        c.saveGState(); c.translateBy(x: 1024, y: 0); c.scaleBy(x: -1, y: 1); bell(); c.restoreGState()
        let center = CGRect(x: 337, y: 305, width: 350, height: 350)
        c.saveGState()
        c.addEllipse(in: center); c.clip()
        if active {
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [CGColor(red: 1, green: 0.23, blue: 0.17, alpha: 1), CGColor(red: 0.94, green: 0.015, blue: 0.025, alpha: 1)] as CFArray, locations: [0, 1])!
            c.drawLinearGradient(gradient, start: CGPoint(x: 440, y: 650), end: CGPoint(x: 600, y: 310), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        } else {
            c.setFillColor(outline.copy(alpha: 0.20)!); c.fill(center)
        }
        c.restoreGState()
        if polished && active {
            c.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.55)); c.setLineWidth(23)
            c.beginPath(); c.addArc(center: CGPoint(x: 512, y: 480), radius: 132, startAngle: 0.40, endAngle: 1.03, clockwise: false); c.strokePath()
        }
    }
    static func applicationIcon(_ c: CGContext) {
        c.saveGState(); defer { c.restoreGState() }
        let tile = CGRect(x: 73, y: 65, width: 878, height: 878)
        c.setShadow(offset: CGSize(width: 0, height: -13), blur: 25, color: CGColor(gray: 0, alpha: 0.18))
        c.setFillColor(CGColor(red: 0.98, green: 0.965, blue: 0.947, alpha: 1))
        c.addPath(CGPath(roundedRect: tile, cornerWidth: 192, cornerHeight: 192, transform: nil)); c.fillPath()
        c.setShadow(offset: .zero, blur: 0, color: nil)
        c.saveGState(); c.addPath(CGPath(roundedRect: tile, cornerWidth: 192, cornerHeight: 192, transform: nil)); c.clip()
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [CGColor(gray: 1, alpha: 1), CGColor(red: 0.95, green: 0.932, blue: 0.91, alpha: 1)] as CFArray, locations: [0, 1])!
        c.drawLinearGradient(gradient, start: CGPoint(x: 300, y: 950), end: CGPoint(x: 760, y: 60), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        c.restoreGState()
        glyph(c, outline: CGColor(red: 0.20, green: 0.205, blue: 0.21, alpha: 1), active: true, polished: true)
    }
}

@MainActor final class StatusLogoView: NSView {
    var listening = false { didSet { if oldValue != listening { needsDisplay = true } } }
    override func hitTest(_ point: NSPoint) -> NSView? { nil } // Keep native status-button menu clicks.
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); needsDisplay = true }
    override func draw(_ dirtyRect: NSRect) {
        guard let c = NSGraphicsContext.current?.cgContext else { return }
        let size = min(17, min(bounds.width, bounds.height) - 4)
        c.saveGState(); defer { c.restoreGState() }
        c.translateBy(x: (bounds.width - size) / 2, y: (bounds.height - size) / 2)
        // Crop transparent margins for a compact ~16pt silhouette on the status bar.
        c.scaleBy(x: size / 720, y: size / 720); c.translateBy(x: -152, y: -168)
        IconArtwork.glyph(c, outline: NSColor.labelColor.cgColor, active: listening, polished: false)
    }
}
