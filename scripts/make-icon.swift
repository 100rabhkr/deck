import AppKit
import Foundation

// Renders the Deck app icon (a 2x2 grid of tiles, the "deck" motif) into an
// .iconset directory. Usage: swift make-icon.swift <output.iconset dir>
let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func drawPNG(px: Int, path: String) {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: px, height: px)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let s = CGFloat(px)
    let rect = CGRect(x: 0, y: 0, width: s, height: s)

    // Rounded background with a soft vertical gradient.
    let bg = NSBezierPath(roundedRect: rect.insetBy(dx: s * 0.06, dy: s * 0.06),
                          xRadius: s * 0.22, yRadius: s * 0.22)
    bg.addClip()
    NSGradient(colors: [
        NSColor(calibratedRed: 0.13, green: 0.14, blue: 0.19, alpha: 1),
        NSColor(calibratedRed: 0.05, green: 0.05, blue: 0.07, alpha: 1),
    ])!.draw(in: rect, angle: -90)

    // 2x2 grid of tiles in the status colours (live / waiting / idle / accent).
    let inset = s * 0.22, gap = s * 0.055
    let cell = (s - inset * 2 - gap) / 2
    let colours = [
        NSColor(calibratedRed: 0.35, green: 0.78, blue: 0.47, alpha: 1),  // green
        NSColor(calibratedRed: 1.00, green: 0.62, blue: 0.29, alpha: 1),  // amber
        NSColor(calibratedRed: 0.52, green: 0.57, blue: 0.65, alpha: 1),  // grey
        NSColor(calibratedRed: 0.40, green: 0.60, blue: 0.96, alpha: 1),  // blue
    ]
    var i = 0
    for row in 0..<2 {
        for col in 0..<2 {
            let x = inset + CGFloat(col) * (cell + gap)
            let y = inset + CGFloat(1 - row) * (cell + gap)
            let tile = NSBezierPath(roundedRect: CGRect(x: x, y: y, width: cell, height: cell),
                                    xRadius: cell * 0.20, yRadius: cell * 0.20)
            colours[i].setFill()
            tile.fill()
            i += 1
        }
    }

    NSGraphicsContext.restoreGraphicsState()
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: path))
}

for base in [16, 32, 128, 256, 512] {
    drawPNG(px: base, path: "\(outDir)/icon_\(base)x\(base).png")
    drawPNG(px: base * 2, path: "\(outDir)/icon_\(base)x\(base)@2x.png")
}
print("wrote iconset to \(outDir)")
