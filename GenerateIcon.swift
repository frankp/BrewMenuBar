import Cocoa

func createIcon() {
    let size = CGSize(width: 1024, height: 1024)
    let img = NSImage(size: size)

    img.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else { return }

    // ---------------------------------------------------------
    // 1. Background: Dark Squircle (macOS Utility Style)
    // ---------------------------------------------------------
    let bgRect = CGRect(origin: .zero, size: size)
    // macOS Big Sur+ Icon shape is a rounded rect with approx 22.4% radius
    let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 224, yRadius: 224)
    
    let bgStart = NSColor(calibratedRed: 0.2, green: 0.2, blue: 0.22, alpha: 1.0)
    let bgEnd = NSColor(calibratedRed: 0.1, green: 0.1, blue: 0.12, alpha: 1.0)
    let bgGradient = NSGradient(starting: bgStart, ending: bgEnd)
    bgGradient?.draw(in: bgPath, angle: -90)

    // ---------------------------------------------------------
    // 2. The Mug
    // ---------------------------------------------------------
    // Center and scale the drawing
    ctx.translateBy(x: 512, y: 512)
    let scale: CGFloat = 0.6
    ctx.scaleBy(x: scale, y: scale)
    ctx.translateBy(x: -512, y: -512)

    // Shadow for the mug to pop from the background
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -20), blur: 40, color: CGColor(gray: 0, alpha: 0.6))

    // Handle (Right side)
    // We draw this first so it sits "behind" or connects nicely
    let handleRect = CGRect(x: 680, y: 300, width: 220, height: 350)
    let handlePath = NSBezierPath(roundedRect: handleRect, xRadius: 80, yRadius: 80)
    handlePath.lineWidth = 70
    NSColor(calibratedWhite: 0.9, alpha: 1.0).setStroke()
    handlePath.stroke()

    // Mug Body
    // Flat top, rounded bottom
    let mugX: CGFloat = 162
    let mugY: CGFloat = 150
    let mugW: CGFloat = 550
    let mugH: CGFloat = 650
    
    let mugPath = NSBezierPath()
    mugPath.move(to: CGPoint(x: mugX, y: mugY + mugH)) // Top Left
    mugPath.line(to: CGPoint(x: mugX + mugW, y: mugY + mugH)) // Top Right
    mugPath.line(to: CGPoint(x: mugX + mugW, y: mugY + 80)) // Bottom Right (start of curve)
    mugPath.curve(to: CGPoint(x: mugX + mugW - 80, y: mugY),
                  controlPoint1: CGPoint(x: mugX + mugW, y: mugY + 30),
                  controlPoint2: CGPoint(x: mugX + mugW - 30, y: mugY)) // Curve to bottom
    mugPath.line(to: CGPoint(x: mugX + 80, y: mugY)) // Bottom Line
    mugPath.curve(to: CGPoint(x: mugX, y: mugY + 80),
                  controlPoint1: CGPoint(x: mugX + 30, y: mugY),
                  controlPoint2: CGPoint(x: mugX, y: mugY + 30)) // Curve to left
    mugPath.close()

    NSColor(calibratedWhite: 0.95, alpha: 1.0).setFill()
    mugPath.fill()
    
    ctx.restoreGState() // End Shadow

    // ---------------------------------------------------------
    // 3. Beer Content
    // ---------------------------------------------------------
    NSGraphicsContext.saveGraphicsState()
    mugPath.addClip() // Clip everything to the mug body

    // Liquid
    let fillLevel: CGFloat = 0.85
    let liquidH = mugH * fillLevel
    let liquidRect = CGRect(x: mugX, y: mugY, width: mugW, height: liquidH)
    
    let beerStart = NSColor(calibratedRed: 1.0, green: 0.75, blue: 0.1, alpha: 1.0)
    let beerEnd = NSColor(calibratedRed: 0.9, green: 0.5, blue: 0.0, alpha: 1.0)
    let beerGradient = NSGradient(starting: beerStart, ending: beerEnd)
    beerGradient?.draw(in: liquidRect, angle: 90)

    // Foam Head
    let foamH: CGFloat = 80
    let foamRect = CGRect(x: mugX, y: mugY + liquidH - foamH/2, width: mugW, height: foamH)
    NSColor(calibratedWhite: 1.0, alpha: 0.95).setFill()
    NSBezierPath(rect: foamRect).fill()
    
    // Glass Reflection / Shine (Optional, keeps it cleaner if omitted or subtle)
    // let shinePath = NSBezierPath(rect: CGRect(x: mugX + 40, y: mugY, width: 40, height: mugH))
    // NSColor(white: 1.0, alpha: 0.1).setFill()
    // shinePath.fill()

    NSGraphicsContext.restoreGraphicsState()
    
    img.unlockFocus()

    // Save
    guard let tiff = img.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else { return }
    try? png.write(to: URL(fileURLWithPath: "icon_1024.png"))
    print("Generated icon_1024.png")
}

createIcon()
