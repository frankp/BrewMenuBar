import Cocoa

func createIcon(name: String, bgColor: NSColor, beerColor: NSColor, glassColor: NSColor, foamColor: NSColor) {
    let size = CGSize(width: 1024, height: 1024)
    let img = NSImage(size: size)

    img.lockFocus()
    guard let context = NSGraphicsContext.current?.cgContext else { return }

    // Background
    let bgRect = CGRect(origin: .zero, size: size)
    let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 200, yRadius: 200)
    bgColor.setFill()
    bgPath.fill()

    let margin: CGFloat = 200
    let mugRect = CGRect(
        x: margin, y: margin, width: size.width - 2 * margin, height: size.height - 2 * margin)

    // Handle
    let handleRect = CGRect(x: mugRect.maxX - 20, y: mugRect.midY - 150, width: 150, height: 300)
    let handlePath = NSBezierPath(roundedRect: handleRect, xRadius: 40, yRadius: 40)
    handlePath.lineWidth = 60
    glassColor.setStroke()
    handlePath.stroke()

    // Mug Body
    let mugPath = NSBezierPath(roundedRect: mugRect, xRadius: 40, yRadius: 40)
    beerColor.setFill()
    mugPath.fill()
    glassColor.setStroke()
    mugPath.lineWidth = 20
    mugPath.stroke()

    // Vertical lines
    let lineCount = 3
    let sectionWidth = mugRect.width / CGFloat(lineCount + 1)
    glassColor.withAlphaComponent(0.5).setStroke()
    let linePath = NSBezierPath()
    linePath.lineWidth = 10

    for i in 1...lineCount {
        let x = mugRect.minX + sectionWidth * CGFloat(i)
        linePath.move(to: CGPoint(x: x, y: mugRect.minY + 50))
        linePath.line(to: CGPoint(x: x, y: mugRect.maxY - 150))
    }
    linePath.stroke()

    // Foam
    let foamHeight: CGFloat = 200
    let foamRect = CGRect(
        x: mugRect.minX, y: mugRect.maxY - foamHeight + 50, width: mugRect.width, height: foamHeight
    )
    let foamPath = NSBezierPath(roundedRect: foamRect, xRadius: 20, yRadius: 20)
    foamColor.setFill()
    foamPath.fill()

    // Bubbles
    let bubbles: [(CGFloat, CGFloat, CGFloat)] = [
        (mugRect.minX + 50, mugRect.maxY + 20, 60),
        (mugRect.minX + 180, mugRect.maxY + 40, 70),
        (mugRect.midX, mugRect.maxY + 50, 80),
        (mugRect.maxX - 180, mugRect.maxY + 30, 75),
        (mugRect.maxX - 60, mugRect.maxY + 10, 65),
    ]

    for (x, y, r) in bubbles {
        let bubbleRect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
        let bubblePath = NSBezierPath(ovalIn: bubbleRect)
        foamColor.setFill()
        bubblePath.fill()
    }

    img.unlockFocus()

    guard let tiffData = img.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiffData),
        let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        print("Failed to create PNG data for \(name)")
        return
    }

    let url = URL(fileURLWithPath: name)
    try? pngData.write(to: url)
    print("Generated: \(name)")
}

// Option 1: "Stout" - Light BG, Dark Beer, Black Outline
createIcon(
    name: "option1.png",
    bgColor: NSColor(white: 0.94, alpha: 1.0),
    beerColor: NSColor(red: 0.2, green: 0.1, blue: 0.05, alpha: 1.0), // Dark Stout Brown
    glassColor: NSColor.black,
    foamColor: NSColor(white: 0.95, alpha: 1.0)
)

// Option 2: "Dark Mode Gold" - Black BG, Gold Beer, White Outline
createIcon(
    name: "option2.png",
    bgColor: NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0), // Dark Gray/Black
    beerColor: NSColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0), // Original Gold
    glassColor: NSColor(white: 0.8, alpha: 1.0), // Light Gray outline
    foamColor: NSColor.white
)

// Option 3: "Midnight Stout" - Black BG, Dark Beer, Dark Grey Outline
createIcon(
    name: "option3.png",
    bgColor: NSColor.black,
    beerColor: NSColor(red: 0.25, green: 0.15, blue: 0.05, alpha: 1.0),
    glassColor: NSColor(white: 0.4, alpha: 1.0),
    foamColor: NSColor(white: 0.9, alpha: 1.0)
)
