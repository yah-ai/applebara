import AppKit
import CoreImage

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor {
    NSColor(calibratedRed: r/255, green: g/255, blue: b/255, alpha: 1)
}

let ciCtx = CIContext(options: nil)
let srcURL = URL(fileURLWithPath: CommandLine.arguments[1])

// key out the light background: invert (lines->white), then luminance->alpha
func keyedArt(white: Bool) -> NSImage {
    let ci = CIImage(contentsOf: srcURL)!
    // crush the baked light-gray checkerboard to pure white; keep black strokes black
    let hi = ci.applyingFilter("CIColorControls", parameters: [
        "inputContrast": 3.6, "inputBrightness": 0.06, "inputSaturation": 0.0,
    ])
    let inv = hi.applyingFilter("CIColorInvert")
    var mask = inv.applyingFilter("CIMaskToAlpha")           // white strokes on transparent
    if !white {
        mask = mask.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),  // keep alpha, RGB->0 (black)
        ])
    }
    let cg = ciCtx.createCGImage(mask, from: ci.extent)!
    return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
}

func makeIcon(bg: [NSColor], art: NSImage, out: String) {
    let S: CGFloat = 1024
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(S), pixelsHigh: Int(S),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let bgPath = NSBezierPath(roundedRect: NSRect(x: 36, y: 36, width: S-72, height: S-72), xRadius: 224, yRadius: 224)
    if bg.count >= 2 { NSGradient(colors: bg)!.draw(in: bgPath, angle: -90) }
    else { bg[0].setFill(); bgPath.fill() }
    let aspect = art.size.width / max(art.size.height, 1)
    let tW = S * 0.9, tH = tW / aspect
    art.draw(in: NSRect(x: (S-tW)/2, y: (S-tH)/2, width: tW, height: tH),
             from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
    print("wrote \(out)")
}

makeIcon(bg: [rgb(255, 224, 158), rgb(244, 180, 92)], art: keyedArt(white: false), out: "icon_1024.png")
makeIcon(bg: [rgb(46, 58, 66), rgb(24, 32, 38)], art: keyedArt(white: true), out: "icon_white_1024.png")
