// Renders candidate app icons: a rising chart plus something that reads as health.
//
//   swift tools/generate-icon-concepts.swift [out-dir]
//
// Each icon is 1024x1024 and opaque, with square corners: Apple applies the
// masking. The contact sheet is for reviewing the set side by side.

import AppKit
import CoreGraphics

let size: CGFloat = 1024
let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "docs/icons"

// MARK: - Palette

struct Palette {
    let top: NSColor
    let bottom: NSColor
}

let palettes: [Palette] = [
    Palette(top: NSColor(srgbRed: 0.13, green: 0.38, blue: 0.86, alpha: 1),
            bottom: NSColor(srgbRed: 0.05, green: 0.72, blue: 0.66, alpha: 1)),
    Palette(top: NSColor(srgbRed: 0.16, green: 0.22, blue: 0.55, alpha: 1),
            bottom: NSColor(srgbRed: 0.10, green: 0.62, blue: 0.85, alpha: 1)),
    Palette(top: NSColor(srgbRed: 0.78, green: 0.15, blue: 0.32, alpha: 1),
            bottom: NSColor(srgbRed: 0.95, green: 0.42, blue: 0.25, alpha: 1)),
    Palette(top: NSColor(srgbRed: 0.11, green: 0.16, blue: 0.28, alpha: 1),
            bottom: NSColor(srgbRed: 0.13, green: 0.45, blue: 0.62, alpha: 1)),
    Palette(top: NSColor(srgbRed: 0.20, green: 0.30, blue: 0.95, alpha: 1),
            bottom: NSColor(srgbRed: 0.62, green: 0.22, blue: 0.72, alpha: 1)),
]

// MARK: - Geometry

/// Classic heart, drawn inside `rect`.
func heartPath(in rect: CGRect) -> NSBezierPath {
    let path = NSBezierPath()
    let w = rect.width, h = rect.height
    let x = rect.minX, y = rect.minY
    path.move(to: CGPoint(x: x + w / 2, y: y))
    path.curve(to: CGPoint(x: x, y: y + h * 0.72),
               controlPoint1: CGPoint(x: x + w * 0.16, y: y + h * 0.18),
               controlPoint2: CGPoint(x: x, y: y + h * 0.48))
    path.curve(to: CGPoint(x: x + w / 2, y: y + h * 0.94),
               controlPoint1: CGPoint(x: x, y: y + h * 0.92),
               controlPoint2: CGPoint(x: x + w * 0.3, y: y + h * 1.02))
    path.curve(to: CGPoint(x: x + w, y: y + h * 0.72),
               controlPoint1: CGPoint(x: x + w * 0.7, y: y + h * 1.02),
               controlPoint2: CGPoint(x: x + w, y: y + h * 0.92))
    path.curve(to: CGPoint(x: x + w / 2, y: y),
               controlPoint1: CGPoint(x: x + w, y: y + h * 0.48),
               controlPoint2: CGPoint(x: x + w * 0.84, y: y + h * 0.18))
    path.close()
    return path
}

func roundedBar(_ rect: CGRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func fillBackground(_ palette: Palette, in rect: CGRect) {
    NSGradient(starting: palette.top, ending: palette.bottom)?
        .draw(in: rect, angle: -90)
    // A soft highlight keeps the flat gradient from looking dead.
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.18), .clear])?
        .draw(in: NSBezierPath(ovalIn: CGRect(x: -rect.width * 0.25, y: rect.height * 0.35,
                                              width: rect.width * 1.5, height: rect.height * 0.9)),
              relativeCenterPosition: .zero)
}

// MARK: - Concepts

/// Paints the icon background through the given shapes, so "cut-outs" stay
/// opaque (an App Store icon may not have transparency).
func punch(_ shapes: [NSBezierPath], palette: Palette, canvas: CGRect) {
    guard !shapes.isEmpty else { return }
    NSGraphicsContext.saveGraphicsState()
    let clip = NSBezierPath()
    shapes.forEach { clip.append($0) }
    clip.addClip()
    fillBackground(palette, in: canvas)
    NSGraphicsContext.restoreGraphicsState()
}

/// 1. A heart with three ascending bars cut out of it.
func icon1(_ palette: Palette) {
    let canvas = CGRect(x: 0, y: 0, width: size, height: size)
    fillBackground(palette, in: canvas)

    let heart = heartPath(in: CGRect(x: 162, y: 250, width: 700, height: 640))
    NSColor.white.setFill()
    heart.fill()

    // Bars sit well inside the heart: above the point, below the lobes.
    let width: CGFloat = 106
    let gap: CGFloat = 54
    let baseline: CGFloat = 430
    let startX = 512 - (width * 1.5 + gap)
    let bars = [0.16, 0.27, 0.38].enumerated().map { index, share in
        roundedBar(
            CGRect(x: startX + CGFloat(index) * (width + gap), y: baseline,
                   width: width, height: 640 * share),
            radius: 40
        )
    }
    punch(bars, palette: palette, canvas: canvas)
}

/// 2. A pulse line that climbs.
func icon2(_ palette: Palette) {
    let canvas = CGRect(x: 0, y: 0, width: size, height: size)
    fillBackground(palette, in: canvas)

    let line = NSBezierPath()
    line.lineWidth = 72
    line.lineCapStyle = .round
    line.lineJoinStyle = .round
    line.move(to: CGPoint(x: 176, y: 372))
    line.line(to: CGPoint(x: 318, y: 372))
    line.line(to: CGPoint(x: 386, y: 500))
    line.line(to: CGPoint(x: 444, y: 236))
    line.line(to: CGPoint(x: 520, y: 566))
    line.line(to: CGPoint(x: 588, y: 452))
    line.line(to: CGPoint(x: 640, y: 566))
    NSColor.white.setStroke()
    line.stroke()

    // The heart marks where the trend lands.
    NSColor.white.setFill()
    heartPath(in: CGRect(x: 606, y: 592, width: 244, height: 222)).fill()

    // A baseline keeps the line from floating.
    let axis = NSBezierPath()
    axis.lineWidth = 26
    axis.lineCapStyle = .round
    axis.move(to: CGPoint(x: 176, y: 218))
    axis.line(to: CGPoint(x: 848, y: 218))
    NSColor.white.withAlphaComponent(0.45).setStroke()
    axis.stroke()
}

/// 3. Three ascending bars, the tallest topped by a heart.
func icon3(_ palette: Palette) {
    let canvas = CGRect(x: 0, y: 0, width: size, height: size)
    fillBackground(palette, in: canvas)
    NSColor.white.setFill()

    let width: CGFloat = 148
    let gap: CGFloat = 60
    let startX = 512 - (width * 1.5 + gap)
    let baseline: CGFloat = 236
    let heights: [CGFloat] = [230, 360, 470]
    for (index, height) in heights.enumerated() {
        roundedBar(
            CGRect(x: startX + CGFloat(index) * (width + gap), y: baseline, width: width, height: height),
            radius: 52
        ).fill()
    }

    // The heart rests on the tallest bar, overlapping it slightly.
    let heartWidth: CGFloat = 236
    let top = baseline + heights[2] + 26
    heartPath(in: CGRect(x: startX + 2 * (width + gap) + (width - heartWidth) / 2,
                         y: top, width: heartWidth, height: heartWidth * 0.92)).fill()
}

/// 4. A heart outline holding a rising line.
func icon4(_ palette: Palette) {
    let canvas = CGRect(x: 0, y: 0, width: size, height: size)
    fillBackground(palette, in: canvas)

    let heart = heartPath(in: CGRect(x: 168, y: 252, width: 688, height: 636))
    heart.lineWidth = 62
    heart.lineJoinStyle = .round
    NSColor.white.setStroke()
    heart.stroke()

    let line = NSBezierPath()
    line.lineWidth = 46
    line.lineCapStyle = .round
    line.lineJoinStyle = .round
    line.move(to: CGPoint(x: 366, y: 470))
    line.line(to: CGPoint(x: 466, y: 570))
    line.line(to: CGPoint(x: 546, y: 490))
    line.line(to: CGPoint(x: 656, y: 600))
    NSColor.white.setStroke()
    line.stroke()

    NSColor.white.setFill()
    for point in [CGPoint(x: 366, y: 470), CGPoint(x: 466, y: 570),
                  CGPoint(x: 546, y: 490), CGPoint(x: 656, y: 600)] {
        NSBezierPath(ovalIn: CGRect(x: point.x - 12, y: point.y - 12, width: 24, height: 24)).fill()
    }
}

/// 5. An ascending arrow driven through a solid heart.
func icon5(_ palette: Palette) {
    let canvas = CGRect(x: 0, y: 0, width: size, height: size)
    fillBackground(palette, in: canvas)

    let heart = heartPath(in: CGRect(x: 150, y: 246, width: 724, height: 660))
    NSColor.white.setFill()
    heart.fill()

    // The arrow is drawn in the icon's own gradient, so it reads as a cut-out
    // without making the image transparent.
    let arrow = NSBezierPath()
    arrow.lineWidth = 74
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    arrow.move(to: CGPoint(x: 318, y: 468))
    arrow.line(to: CGPoint(x: 470, y: 620))
    arrow.line(to: CGPoint(x: 566, y: 524))
    arrow.line(to: CGPoint(x: 700, y: 660))

    // Stroke the polyline into a fillable shape, then paint the background
    // through it (clipping to a stroke is not possible directly).
    let stroked = arrow.cgPath.copy(
        strokingWithWidth: 74, lineCap: .round, lineJoin: .round, miterLimit: 10
    )
    let shaft = NSBezierPath(cgPath: stroked)

    // Chevron head: two stroked wings that meet the shaft at its tip, which reads
    // as an arrow at any size and never looks detached.
    let tip = CGPoint(x: 752, y: 712)
    func wing(to point: CGPoint) -> NSBezierPath {
        let path = CGMutablePath()
        path.move(to: tip)
        path.addLine(to: point)
        let outline = path.copy(strokingWithWidth: 74, lineCap: .round, lineJoin: .round, miterLimit: 10)
        return NSBezierPath(cgPath: outline)
    }

    punch([shaft, wing(to: CGPoint(x: 664, y: 712)), wing(to: CGPoint(x: 752, y: 624))],
          palette: palette, canvas: canvas)
}

// MARK: - Rendering

/// Draws one icon into an exact 1024x1024 opaque bitmap. `lockFocus` would
/// render at the screen's backing scale, which on a Retina Mac produces a 2048px
/// file that App Store Connect refuses.
func render(_ draw: () -> Void) -> NSBitmapImageRep? {
    let side = Int(size)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
        bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { return nil }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

// MARK: - Run

let concepts: [(String, (Palette) -> Void)] = [
    ("01-heart-bars", icon1),
    ("02-pulse-trend", icon2),
    ("03-heart-cap", icon3),
    ("04-heart-outline-chart", icon4),
    ("05-arrow-through-heart", icon5),
]

try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

var rendered: [(String, NSImage)] = []
for (index, concept) in concepts.enumerated() {
    guard let rep = render({ concept.1(palettes[index]) }),
          let png = rep.representation(using: .png, properties: [:]) else { continue }
    try png.write(to: URL(fileURLWithPath: "\(outDir)/\(concept.0).png"))
    print("wrote \(outDir)/\(concept.0).png")

    // The contact sheet is drawn from an NSImage of the same artwork.
    let preview = NSImage(size: NSSize(width: size, height: size))
    preview.lockFocus()
    concept.1(palettes[index])
    preview.unlockFocus()
    rendered.append((concept.0, preview))
}

// Contact sheet: 5 icons in a row, labelled.
let tile = 300.0
let padding = 28.0
let labelHeight = 54.0
let sheetWidth = tile * Double(concepts.count) + padding * Double(concepts.count + 1)
let sheetHeight = tile + padding * 2 + labelHeight

let sheet = NSImage(size: NSSize(width: sheetWidth, height: sheetHeight))
sheet.lockFocus()
NSColor(calibratedWhite: 0.96, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: sheetWidth, height: sheetHeight).fill()

for (index, entry) in rendered.enumerated() {
    let x = padding + Double(index) * (tile + padding)
    let imageRect = NSRect(x: x, y: padding + labelHeight, width: tile, height: tile)
    entry.1.draw(in: imageRect, from: .zero, operation: .sourceOver, fraction: 1)
    let label = entry.0 as NSString
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 19, weight: .medium),
        .foregroundColor: NSColor(calibratedWhite: 0.2, alpha: 1),
    ]
    let labelSize = label.size(withAttributes: attributes)
    label.draw(at: NSPoint(x: x + (tile - labelSize.width) / 2, y: padding), withAttributes: attributes)
}
sheet.unlockFocus()

if let tiff = sheet.tiffRepresentation,
   let rep = NSBitmapImageRep(data: tiff),
   let png = rep.representation(using: .png, properties: [:]) {
    try png.write(to: URL(fileURLWithPath: "\(outDir)/concepts.png"))
    print("wrote \(outDir)/concepts.png")
}
