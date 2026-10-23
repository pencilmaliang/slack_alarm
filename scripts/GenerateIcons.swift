import Foundation
import CoreGraphics
import ImageIO

@main enum GenerateIcons {
    static func png(size: Int, path: String, draw: (CGContext) -> Void) {
        let c = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        c.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024); draw(c)
        let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, c.makeImage()!, nil)
        precondition(CGImageDestinationFinalize(destination), "PNG write failed")
    }
    static func main() throws {
        let root = CommandLine.arguments[1]
        let iconset = root + "/AppIcon.iconset"
        try FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)
        for size in [16, 32, 128, 256, 512] {
            png(size: size, path: iconset + "/icon_\(size)x\(size).png", draw: IconArtwork.applicationIcon)
            png(size: size * 2, path: iconset + "/icon_\(size)x\(size)@2x.png", draw: IconArtwork.applicationIcon)
        }
        // Standard ICNS container with PNG representations; no GUI/icon service required.
        func word(_ value: Int) -> Data {
            var number = UInt32(value).bigEndian
            return withUnsafeBytes(of: &number) { Data($0) }
        }
        let entries = [("icp4", "16x16"), ("ic11", "16x16@2x"), ("icp5", "32x32"), ("ic12", "32x32@2x"),
                       ("ic07", "128x128"), ("ic13", "128x128@2x"), ("ic08", "256x256"), ("ic14", "256x256@2x"),
                       ("ic09", "512x512"), ("ic10", "512x512@2x")]
        var chunks = Data()
        for (type, name) in entries {
            let image = try Data(contentsOf: URL(fileURLWithPath: iconset + "/icon_" + name + ".png"))
            chunks.append(Data(type.utf8)); chunks.append(word(image.count + 8)); chunks.append(image)
        }
        var icns = Data("icns".utf8); icns.append(word(chunks.count + 8)); icns.append(chunks)
        try icns.write(to: URL(fileURLWithPath: root + "/AppIcon.icns"))
        png(size: 1024, path: root + "/AppIcon.png", draw: IconArtwork.applicationIcon)
        // Four samples: light inactive/active, dark inactive/active, using the same glyph.
        png(size: 512, path: root + "/MenuBarPreview.png") { c in
            for row in 0..<2 {
                for col in 0..<2 {
                    c.saveGState(); c.translateBy(x: CGFloat(col) * 512, y: CGFloat(row) * 512)
                    c.setFillColor(CGColor(gray: row == 0 ? 0.14 : 0.94, alpha: 1)); c.fill(CGRect(x: 0, y: 0, width: 512, height: 512))
                    c.translateBy(x: 16, y: 16); c.scaleBy(x: 480 / 1024, y: 480 / 1024)
                    IconArtwork.glyph(c, outline: CGColor(gray: row == 0 ? 0.95 : 0.16, alpha: 1), active: col == 1, polished: false)
                    c.restoreGState()
                }
            }
        }
    }
}
