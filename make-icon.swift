import Foundation
import CoreGraphics
import ImageIO

let W = 1024
let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: nil, width: W, height: W, bitsPerComponent: 8,
                          bytesPerRow: 0, space: cs,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    fatalError("ctx")
}
// Use a top-left origin, y growing downward.
ctx.translateBy(x: 0, y: CGFloat(W))
ctx.scaleBy(x: 1, y: -1)

func color(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(srgbRed: r/255, green: g/255, blue: b/255, alpha: a)
}

// --- Background: ocean-blue vertical gradient (sky at top, deep sea at bottom) ---
let bg = CGGradient(colorsSpace: cs,
                    colors: [color(56, 180, 230), color(10, 46, 78)] as CFArray,
                    locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 512, y: 0), end: CGPoint(x: 512, y: 1024), options: [])

let apex = CGPoint(x: 512, y: 815)
let halfAngle = 31.0 * .pi / 180
let armLen = 770.0
let leftEnd = CGPoint(x: apex.x - armLen * sin(halfAngle), y: apex.y - armLen * cos(halfAngle))
let rightEnd = CGPoint(x: apex.x + armLen * sin(halfAngle), y: apex.y - armLen * cos(halfAngle))

// --- Wedge glow (the wind / no-go sector) ---
ctx.saveGState()
let wedge = CGMutablePath()
wedge.move(to: apex)
wedge.addLine(to: leftEnd)
wedge.addLine(to: rightEnd)
wedge.closeSubpath()
ctx.addPath(wedge)
ctx.clip()
let glow = CGGradient(colorsSpace: cs,
                      colors: [color(255, 196, 64, 0.55), color(255, 196, 64, 0.04)] as CFArray,
                      locations: [0, 1])!
ctx.drawLinearGradient(glow, start: apex, end: CGPoint(x: 512, y: 130), options: [])
ctx.restoreGState()

// --- Tack-line arms (the two close-hauled headings) ---
ctx.setLineCap(.round)
ctx.setStrokeColor(color(255, 255, 255))
ctx.setLineWidth(48)
ctx.move(to: apex); ctx.addLine(to: leftEnd); ctx.strokePath()
ctx.move(to: apex); ctx.addLine(to: rightEnd); ctx.strokePath()
// small tick caps at the ends
for p in [leftEnd, rightEnd] {
    ctx.setFillColor(color(255, 255, 255))
    ctx.fillEllipse(in: CGRect(x: p.x - 30, y: p.y - 30, width: 60, height: 60))
}

// --- Wind arrow bisecting the wedge, pointing down toward the boat ---
ctx.setStrokeColor(color(255, 138, 0))
ctx.setLineWidth(40)
ctx.setLineCap(.round)
ctx.move(to: CGPoint(x: 512, y: 250))
ctx.addLine(to: CGPoint(x: 512, y: 540))
ctx.strokePath()
let head = CGMutablePath()
head.move(to: CGPoint(x: 512, y: 612))      // tip
head.addLine(to: CGPoint(x: 446, y: 516))
head.addLine(to: CGPoint(x: 578, y: 516))
head.closeSubpath()
ctx.setFillColor(color(255, 138, 0))
ctx.addPath(head); ctx.fillPath()

// --- Heeling sailboat at the vertex ---
ctx.saveGState()
ctx.translateBy(x: 512, y: 812)
ctx.rotate(by: 8 * .pi / 180)               // a playful heel to starboard
let navy = color(10, 46, 78)

// Mainsail
let main = CGMutablePath()
main.move(to: CGPoint(x: 18, y: -8))
main.addLine(to: CGPoint(x: 18, y: -210))
main.addQuadCurve(to: CGPoint(x: 168, y: -8), control: CGPoint(x: 120, y: -70))
main.closeSubpath()
ctx.setFillColor(color(255, 255, 255)); ctx.addPath(main); ctx.fillPath()
ctx.setStrokeColor(navy); ctx.setLineWidth(7); ctx.setLineJoin(.round)
ctx.addPath(main); ctx.strokePath()

// Jib (front sail)
let jib = CGMutablePath()
jib.move(to: CGPoint(x: 2, y: -16))
jib.addLine(to: CGPoint(x: 2, y: -188))
jib.addQuadCurve(to: CGPoint(x: -128, y: -16), control: CGPoint(x: -92, y: -60))
jib.closeSubpath()
ctx.setFillColor(color(225, 240, 252)); ctx.addPath(jib); ctx.fillPath()
ctx.setStrokeColor(navy); ctx.addPath(jib); ctx.strokePath()

// Hull (a rounded boat)
let hull = CGMutablePath()
hull.move(to: CGPoint(x: -172, y: 6))
hull.addQuadCurve(to: CGPoint(x: 158, y: 6), control: CGPoint(x: -8, y: 96))
hull.addQuadCurve(to: CGPoint(x: -172, y: 6), control: CGPoint(x: -8, y: -22))
hull.closeSubpath()
ctx.setFillColor(color(255, 255, 255)); ctx.addPath(hull); ctx.fillPath()
ctx.setStrokeColor(navy); ctx.addPath(hull); ctx.strokePath()
ctx.restoreGState()

// --- Write PNG ---
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/icon-1024.png"
let url = URL(fileURLWithPath: out) as CFURL
let dest = CGImageDestinationCreateWithURL(url, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
CGImageDestinationFinalize(dest)
print("wrote \(out)")
