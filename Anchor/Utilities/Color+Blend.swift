import SwiftUI
import CoreGraphics

#if canImport(UIKit)
import UIKit

private extension UIColor {
    func anchorRGBA() -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)? {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        if self.getRed(&r, green: &g, blue: &b, alpha: &a) {
            return (r, g, b, a)
        }

        guard
            let srgb = CGColorSpace(name: CGColorSpace.sRGB),
            let converted = self.cgColor.converted(to: srgb, intent: .defaultIntent, options: nil),
            let comps = converted.components
        else { return nil }

        switch comps.count {
        case 2:
            // grayscale + alpha
            return (comps[0], comps[0], comps[0], comps[1])
        case 3:
            // RGB (no alpha)
            return (comps[0], comps[1], comps[2], 1.0)
        default:
            // RGBA (or more, ignore extras)
            return (comps[0], comps[1], comps[2], comps[3])
        }
    }
}
#elseif canImport(AppKit)
import AppKit

private extension NSColor {
    func anchorRGBA() -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)? {
        guard let c = usingColorSpace(.sRGB) else { return nil }
        return (c.redComponent, c.greenComponent, c.blueComponent, c.alphaComponent)
    }
}
#endif

extension Color {
    /// Blends this color towards `other` by `fraction` (0 = unchanged, 1 = fully `other`).
    func anchorBlended(with other: Color, fraction: CGFloat) -> Color {
        let f = max(0, min(1, fraction))

        #if canImport(UIKit)
        let c1 = UIColor(self)
        let c2 = UIColor(other)
        guard let a = c1.anchorRGBA(), let b = c2.anchorRGBA() else { return self }
        return Color(
            red: Double(a.r * (1 - f) + b.r * f),
            green: Double(a.g * (1 - f) + b.g * f),
            blue: Double(a.b * (1 - f) + b.b * f),
            opacity: Double(a.a * (1 - f) + b.a * f)
        )
        #elseif canImport(AppKit)
        let c1 = NSColor(self)
        let c2 = NSColor(other)
        guard let a = c1.anchorRGBA(), let b = c2.anchorRGBA() else { return self }
        return Color(
            red: Double(a.r * (1 - f) + b.r * f),
            green: Double(a.g * (1 - f) + b.g * f),
            blue: Double(a.b * (1 - f) + b.b * f),
            opacity: Double(a.a * (1 - f) + b.a * f)
        )
        #else
        return self
        #endif
    }

    /// Pastel version of the color (blended towards white).
    func anchorPastel(fraction: CGFloat = 0.6) -> Color {
        anchorBlended(with: .white, fraction: fraction)
    }
}



