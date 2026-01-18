#!/usr/bin/env swift
import AppKit

// Generates 3× 1024px app icons (default/dark/tinted) into the AppIcon.appiconset.
//
// Usage:
//   swift Scripts/generate_app_icon.swift /absolute/path/to/AppIcon.appiconset

enum Variant: String, CaseIterable {
    case `default` = "Default"
    case dark = "Dark"
    case tinted = "Tinted"
}

struct RGBA {
    let r: CGFloat
    let g: CGFloat
    let b: CGFloat
    let a: CGFloat
    var ns: NSColor { NSColor(calibratedRed: r, green: g, blue: b, alpha: a) }
}

let size: CGFloat = 1024
let canvasRect = CGRect(x: 0, y: 0, width: size, height: size)

func makeBitmap() -> NSBitmapImageRep {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size),
        pixelsHigh: Int(size),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("Failed to create NSBitmapImageRep")
    }
    rep.size = NSSize(width: size, height: size)
    return rep
}

func drawLinearGradient(_ ctx: CGContext, from: CGPoint, to: CGPoint, colors: [NSColor], locations: [CGFloat]) {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let cgColors = colors.map { $0.cgColor } as CFArray
    guard let gradient = CGGradient(colorsSpace: colorSpace, colors: cgColors, locations: locations) else { return }
    ctx.drawLinearGradient(gradient, start: from, end: to, options: [])
}

func drawRadialGlow(_ ctx: CGContext, center: CGPoint, radius: CGFloat, color: NSColor) {
    ctx.saveGState()
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let colors = [color.cgColor, NSColor.clear.cgColor] as CFArray
    guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0]) else { return }
    ctx.drawRadialGradient(
        gradient,
        startCenter: center, startRadius: 0,
        endCenter: center, endRadius: radius,
        options: [.drawsAfterEndLocation]
    )
    ctx.restoreGState()
}

func drawRoundedRect(_ ctx: CGContext, rect: CGRect, radius: CGFloat, fill: NSColor) {
    ctx.saveGState()
    ctx.setFillColor(fill.cgColor)
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    ctx.addPath(path)
    ctx.fillPath()
    ctx.restoreGState()
}

func drawAnchorMark(_ variant: Variant, in ctx: CGContext) {
    // Simple, friendly anchor mark. Keep it bold, geometric, and legible at small sizes.
    let foreground: NSColor = {
        switch variant {
        case .default, .dark:
            return .white
        case .tinted:
            return NSColor(white: 0.12, alpha: 1.0)
        }
    }()

    let cx: CGFloat = size * 0.5
    // Nudge the mark upward a bit so the bottom has more breathing room.
    let cy: CGFloat = size * 0.52 + size * 0.045
    let s: CGFloat = 1.0

    let ringRadius: CGFloat = 70 * s
    let ringLine: CGFloat = 26 * s

    let stroke: CGFloat = 66 * s
    let crossbarHalf: CGFloat = 200 * s
    let armRadius: CGFloat = 270 * s
    let armY: CGFloat = cy - 210 * s

    let ringCenter = CGPoint(x: cx, y: cy + 260 * s)
    let stemTopY: CGFloat = ringCenter.y - ringRadius - ringLine * 0.6
    let stemBottomY: CGFloat = armY + 40 * s
    let crossbarY: CGFloat = cy + 60 * s

    ctx.saveGState()
    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)

    // Stroke components
    ctx.setStrokeColor(foreground.cgColor)
    ctx.setLineWidth(stroke)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)

    // Ring (stroke circle)
    ctx.saveGState()
    ctx.setLineWidth(ringLine)
    ctx.strokeEllipse(in: CGRect(
        x: ringCenter.x - ringRadius,
        y: ringCenter.y - ringRadius,
        width: ringRadius * 2,
        height: ringRadius * 2
    ))
    ctx.restoreGState()

    // Stem
    ctx.beginPath()
    ctx.move(to: CGPoint(x: cx, y: stemTopY))
    ctx.addLine(to: CGPoint(x: cx, y: stemBottomY))
    ctx.strokePath()

    // Crossbar
    ctx.beginPath()
    ctx.move(to: CGPoint(x: cx - crossbarHalf, y: crossbarY))
    ctx.addLine(to: CGPoint(x: cx + crossbarHalf, y: crossbarY))
    ctx.strokePath()

    // Arms: a wide U + slight hooks up at ends
    let leftEnd = CGPoint(x: cx - armRadius, y: armY)
    let rightEnd = CGPoint(x: cx + armRadius, y: armY)
    let bottom = CGPoint(x: cx, y: armY - 240 * s)

    ctx.beginPath()
    ctx.move(to: leftEnd)
    ctx.addQuadCurve(to: bottom, control: CGPoint(x: cx - armRadius, y: armY - 230 * s))
    ctx.addQuadCurve(to: rightEnd, control: CGPoint(x: cx + armRadius, y: armY - 230 * s))
    // hooks (small upward curl)
    ctx.addQuadCurve(to: CGPoint(x: rightEnd.x - 60 * s, y: rightEnd.y + 60 * s),
                     control: CGPoint(x: rightEnd.x, y: rightEnd.y + 30 * s))
    ctx.move(to: leftEnd)
    ctx.addQuadCurve(to: CGPoint(x: leftEnd.x + 60 * s, y: leftEnd.y + 60 * s),
                     control: CGPoint(x: leftEnd.x, y: leftEnd.y + 30 * s))
    ctx.strokePath()

    // Flukes (filled triangles), kept very simple
    ctx.setFillColor(foreground.cgColor)
    let flukeW: CGFloat = 120 * s
    let flukeH: CGFloat = 120 * s

    let leftFluke = CGMutablePath()
    leftFluke.move(to: CGPoint(x: leftEnd.x - 25 * s, y: leftEnd.y - 10 * s))
    leftFluke.addLine(to: CGPoint(x: leftEnd.x - flukeW, y: leftEnd.y - flukeH))
    leftFluke.addLine(to: CGPoint(x: leftEnd.x + 10 * s, y: leftEnd.y - flukeH))
    leftFluke.closeSubpath()

    let rightFluke = CGMutablePath()
    rightFluke.move(to: CGPoint(x: rightEnd.x + 25 * s, y: rightEnd.y - 10 * s))
    rightFluke.addLine(to: CGPoint(x: rightEnd.x + flukeW, y: rightEnd.y - flukeH))
    rightFluke.addLine(to: CGPoint(x: rightEnd.x - 10 * s, y: rightEnd.y - flukeH))
    rightFluke.closeSubpath()

    ctx.addPath(leftFluke)
    ctx.fillPath()
    ctx.addPath(rightFluke)
    ctx.fillPath()

    ctx.restoreGState()
}

func drawBackground(_ variant: Variant, in ctx: CGContext) {
    // Green gradient background (subtle depth; reads well behind a simple white mark).
    let (c1, c2, glow): (NSColor, NSColor, NSColor)
    switch variant {
    case .default:
        c1 = RGBA(r: 0.05, g: 0.45, b: 0.26, a: 1.0).ns   // deep green
        c2 = RGBA(r: 0.20, g: 0.90, b: 0.55, a: 1.0).ns   // bright green
        glow = RGBA(r: 0.60, g: 1.00, b: 0.78, a: 0.22).ns
    case .dark:
        c1 = RGBA(r: 0.03, g: 0.30, b: 0.18, a: 1.0).ns
        c2 = RGBA(r: 0.10, g: 0.62, b: 0.38, a: 1.0).ns
        glow = RGBA(r: 0.45, g: 0.95, b: 0.70, a: 0.14).ns
    case .tinted:
        c1 = RGBA(r: 0.10, g: 0.55, b: 0.32, a: 1.0).ns
        c2 = RGBA(r: 0.35, g: 0.98, b: 0.64, a: 1.0).ns
        glow = RGBA(r: 0.70, g: 1.00, b: 0.84, a: 0.18).ns
    }

    ctx.saveGState()
    drawLinearGradient(
        ctx,
        from: CGPoint(x: canvasRect.minX, y: canvasRect.maxY),
        to: CGPoint(x: canvasRect.maxX, y: canvasRect.minY),
        colors: [c1, c2],
        locations: [0.0, 1.0]
    )

    // A soft glow near the top-left for a bit of depth (kept subtle).
    drawRadialGlow(
        ctx,
        center: CGPoint(x: size * 0.30, y: size * 0.78),
        radius: size * 0.70,
        color: glow
    )

    ctx.restoreGState()
}

func renderIcon(variant: Variant) -> Data {
    let rep = makeBitmap()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    ctx.imageInterpolation = .high
    ctx.shouldAntialias = true
    ctx.cgContext.setAllowsAntialiasing(true)
    ctx.cgContext.setShouldAntialias(true)

    drawBackground(variant, in: ctx.cgContext)
    drawAnchorMark(variant, in: ctx.cgContext)

    NSGraphicsContext.restoreGraphicsState()
    guard let png = rep.representation(using: .png, properties: [:]) else {
        fatalError("Failed to encode PNG for \(variant.rawValue)")
    }
    return png
}

func main() {
    guard CommandLine.arguments.count >= 2 else {
        fputs("Usage: swift Scripts/generate_app_icon.swift /absolute/path/to/AppIcon.appiconset\n", stderr)
        exit(2)
    }
    let outDir = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)

    for variant in Variant.allCases {
        let data = renderIcon(variant: variant)
        let filename = "AppIcon-\(variant.rawValue).png"
        let url = outDir.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            print("Wrote \(filename)")
        } catch {
            fputs("Failed writing \(filename): \(error)\n", stderr)
            exit(1)
        }
    }
}

main()


