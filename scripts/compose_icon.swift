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

// menu-bar template: bare black strokes, trimmed tight to the drawing (wide, not square).
// Marked as a template at runtime so macOS tints it for light/dark menu bars.
func makeMenubar(out: String) {
    let art = keyedArt(white: false)                 // black strokes on transparent
    guard let cg = art.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
    let w = cg.width, h = cg.height
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: w*4, bitsPerPixel: 32)!
    let c = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = c
    c.cgContext.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
    NSGraphicsContext.restoreGraphicsState()

    // tight alpha bounding box (rep is top-left origin)
    let d = rep.bitmapData!, bpr = rep.bytesPerRow
    var minX = w, minY = h, maxX = -1, maxY = -1
    for y in 0..<h { for x in 0..<w where d[y*bpr + x*4 + 3] > 20 {
        if x < minX { minX = x }; if x > maxX { maxX = x }
        if y < minY { minY = y }; if y > maxY { maxY = y }
    } }
    guard maxX >= minX else { return }
    let cw = maxX - minX + 1, chh = maxY - minY + 1

    let targetH = 44                                  // crisp for an ~18pt menu bar
    let scale = CGFloat(targetH) / CGFloat(chh)
    let outW = max(1, Int((CGFloat(cw) * scale).rounded()))
    let outRep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: outW, pixelsHigh: targetH,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let oc = NSGraphicsContext(bitmapImageRep: outRep)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = oc
    oc.imageInterpolation = .high
    let full = NSImage(size: NSSize(width: w, height: h)); full.addRepresentation(rep)
    let fromRect = NSRect(x: minX, y: h - 1 - maxY, width: cw, height: chh)   // rep top-left → image bottom-left
    full.draw(in: NSRect(x: 0, y: 0, width: outW, height: targetH), from: fromRect, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    try! outRep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
    print("wrote \(out) (\(outW)x\(targetH))")
}

makeIcon(bg: [rgb(255, 224, 158), rgb(244, 180, 92)], art: keyedArt(white: false), out: "assets/icon.png")
makeIcon(bg: [rgb(46, 58, 66), rgb(24, 32, 38)], art: keyedArt(white: true), out: "assets/icon-dark.png")
makeMenubar(out: "assets/menubar.png")
