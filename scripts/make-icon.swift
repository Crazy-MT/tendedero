// Original PegNest artwork: a single note, teal peg and suspended arc.
import AppKit

let output = CommandLine.arguments.dropFirst().first ?? "Assets/icon.png"
let size = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let bg = NSBezierPath(roundedRect: NSRect(x: 72, y: 72, width: 880, height: 880), xRadius: 192, yRadius: 192)
NSGradient(starting: NSColor(calibratedRed: 0.08, green: 0.19, blue: 0.32, alpha: 1), ending: NSColor(calibratedRed: 0.035, green: 0.08, blue: 0.16, alpha: 1))!.draw(in: bg, angle: -90)
let rope = NSBezierPath()
rope.move(to: NSPoint(x: 143, y: 750))
rope.curve(to: NSPoint(x: 881, y: 750), controlPoint1: NSPoint(x: 325, y: 628), controlPoint2: NSPoint(x: 699, y: 628))
rope.lineWidth = 18; rope.lineCapStyle = .round
NSColor(calibratedRed: 0.5, green: 0.72, blue: 0.77, alpha: 1).setStroke(); rope.stroke()
NSGraphicsContext.saveGraphicsState()
let transform = AffineTransform(translationByX: 512, byY: 463); var rotation = AffineTransform(); rotation.rotate(byDegrees: -8)
var back = AffineTransform(translationByX: -512, byY: -463)
(transform as NSAffineTransform).concat(); (rotation as NSAffineTransform).concat(); (back as NSAffineTransform).concat()
let note = NSBezierPath(roundedRect: NSRect(x: 300, y: 218, width: 424, height: 480), xRadius: 40, yRadius: 40)
let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.3); shadow.shadowBlurRadius = 32; shadow.shadowOffset = NSSize(width: 0, height: -18); shadow.set()
NSColor(calibratedRed: 0.99, green: 0.97, blue: 0.9, alpha: 1).setFill(); note.fill()
NSShadow().set()
for (y, width) in [(529.0, 258.0), (450.0, 258.0), (371.0, 170.0)] {
    let line = NSBezierPath(roundedRect: NSRect(x: 357, y: y, width: width, height: 25), xRadius: 12.5, yRadius: 12.5)
    NSColor(calibratedRed: 0.34, green: 0.48, blue: 0.49, alpha: 0.65).setFill(); line.fill()
}
NSGraphicsContext.restoreGraphicsState()
let peg = NSBezierPath(roundedRect: NSRect(x: 473, y: 634, width: 78, height: 158), xRadius: 22, yRadius: 22)
NSGradient(starting: NSColor(calibratedRed: 0.28, green: 0.87, blue: 0.72, alpha: 1), ending: NSColor(calibratedRed: 0.07, green: 0.56, blue: 0.5, alpha: 1))!.draw(in: peg, angle: 0)
let slot = NSBezierPath(roundedRect: NSRect(x: 492, y: 684, width: 40, height: 12), xRadius: 6, yRadius: 6)
NSColor(calibratedRed: 0.02, green: 0.32, blue: 0.3, alpha: 1).setFill(); slot.fill()
NSGraphicsContext.restoreGraphicsState()
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
