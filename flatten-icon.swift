// Flattens an app-icon PNG onto an opaque background and strips the alpha channel,
// producing a 1024x1024 PNG that satisfies App Store Connect (no transparency allowed).
// Usage: swift flatten-icon.swift <in.png> <out.png>
import Foundation
import AppKit

let args = CommandLine.arguments
guard args.count >= 3 else { fputs("usage: flatten-icon.swift <in.png> <out.png>\n", stderr); exit(1) }
let inURL = URL(fileURLWithPath: args[1])
let outURL = URL(fileURLWithPath: args[2])

guard let src = NSImage(contentsOf: inURL),
      let tiff = src.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let cg = rep.cgImage else { fputs("could not load \(inURL.path)\n", stderr); exit(1) }

let size = 1024
let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                          bytesPerRow: 0, space: cs,
                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
    fputs("context failed\n", stderr); exit(1)
}
// Opaque backstop in case the source has any transparent pixels.
ctx.setFillColor(CGColor(red: 0.06, green: 0.20, blue: 0.40, alpha: 1)) // ocean blue
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
ctx.draw(cg, in: CGRect(x: 0, y: 0, width: size, height: size))

guard let out = ctx.makeImage() else { fputs("makeImage failed\n", stderr); exit(1) }
let outRep = NSBitmapImageRep(cgImage: out)
guard let png = outRep.representation(using: .png, properties: [:]) else {
    fputs("png encode failed\n", stderr); exit(1)
}
try! png.write(to: outURL)
print("wrote \(outURL.path)")
