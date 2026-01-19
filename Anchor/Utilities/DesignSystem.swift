import SwiftUI

// MARK: - Color Palette
extension Color {
    // Modern Dark Mode Background - Deep blue-black instead of pure black
    static let anchorBackground = Color(red: 0.04, green: 0.055, blue: 0.10) // #0A0E1A
    static let anchorCardBg = Color(red: 0.08, green: 0.11, blue: 0.16) // Warmer dark gray

    // Priority Colors - Descending Urgency
    // Priority 1: Red (Most Urgent) - Vibrant red for high urgency
    static let anchorCoral = Color(red: 1.0, green: 0.3, blue: 0.3) // Red - #FF4D4D
    static let anchorCoralDeep = Color(red: 1.0, green: 0.15, blue: 0.15) // Deeper red for gradient

    // Priority 2: Orange (Medium Urgency) - Warm orange for medium priority
    static let anchorMint = Color(red: 1.0, green: 0.6, blue: 0.2) // Orange - #FF9933
    static let anchorAmber = Color(red: 1.0, green: 0.75, blue: 0.0) // Amber for gradient

    // Priority 3: Blue (Least Urgent) - Calm blue for lower urgency
    static let anchorIndigo = Color(red: 0.3, green: 0.6, blue: 1.0) // Blue - #4D99FF
    static let anchorDeepIndigo = Color(red: 0.2, green: 0.3, blue: 0.8) // Deep indigo-purple for gradient

    // Completion / Success - Enhanced with gradient capability (teal scheme to avoid Christmas red+green)
    static let anchorCompletedGreen = Color(red: 0.55, green: 0.72, blue: 0.82) // Steel blue (renamed for compatibility)
    static let anchorCompletedTeal = Color(red: 0.35, green: 0.62, blue: 0.70) // Deeper teal for gradient
    static let anchorCompletedSlate = Color(red: 0.55, green: 0.72, blue: 0.82) // Stronger steel blue

    // Success accent - Teal for completion indicators, swipe affordances, calendar dots
    static let anchorSuccessTeal = Color(red: 0.2, green: 0.75, blue: 0.78) // Vibrant teal

    // Streak indicators - with gradient support (teal scheme)
    static let anchorStreakGreen = Color(red: 0.2, green: 0.75, blue: 0.78) // Teal (renamed for compatibility)
    static let anchorStreakTeal = Color(red: 0.15, green: 0.60, blue: 0.65) // Deeper teal for gradient
    static let anchorStreakRed = Color(red: 0.9, green: 0.3, blue: 0.3)

    // Neutral - For empty placeholders and inactive elements
    static let anchorNeutral = Color(red: 0.55, green: 0.55, blue: 0.58) // Warm gray

    // Text - Higher contrast for dark mode
    static let anchorTextPrimary = Color.white
    static let anchorTextSecondary = Color.white.opacity(0.7)
}

// MARK: - Gradients
extension LinearGradient {
    // Priority Gradients - Diagonal for depth
    static let priority1Gradient = LinearGradient(
        colors: [Color.anchorCoral, Color.anchorCoralDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let priority2Gradient = LinearGradient(
        colors: [Color.anchorMint, Color.anchorAmber],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let priority3Gradient = LinearGradient(
        colors: [Color.anchorIndigo, Color.anchorDeepIndigo],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let completedGradient = LinearGradient(
        colors: [Color.anchorCompletedGreen, Color.anchorCompletedTeal],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let streakGradient = LinearGradient(
        colors: [Color.anchorStreakGreen, Color.anchorStreakTeal],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Helper to get gradient for priority
    static func forPriority(_ priority: Int) -> LinearGradient {
        switch priority {
        case 1: return priority1Gradient
        case 2: return priority2Gradient
        case 3: return priority3Gradient
        default: return priority1Gradient
        }
    }
}

// MARK: - Typography & Styles (View Modifiers)

struct AnchorCardStyle: ViewModifier {
    var cornerRadius: CGFloat = 20 // Increased from 16 to 20 for softer feel
    var useEnhancedShadow: Bool = true

    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.white.opacity(0.1))
            .background(.thinMaterial)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4) // Outer shadow
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1) // Inner shadow for depth
    }
}

// Enhanced Priority Card Style with colored glow
struct PriorityCardStyle: ViewModifier {
    let priorityColor: Color
    let isCompleted: Bool
    var cornerRadius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1.5
                    )
            )
            // Multi-layer shadow system
            .shadow(color: isCompleted ? Color.black.opacity(0.1) : priorityColor.opacity(0.3), radius: 12, x: 0, y: 6)
            .shadow(color: isCompleted ? Color.black.opacity(0.05) : priorityColor.opacity(0.15), radius: 4, x: 0, y: 2)
            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
}

extension View {
    func anchorCard(cornerRadius: CGFloat = 20) -> some View {
        modifier(AnchorCardStyle(cornerRadius: cornerRadius))
    }

    func priorityCard(color: Color, isCompleted: Bool = false, cornerRadius: CGFloat = 20) -> some View {
        modifier(PriorityCardStyle(priorityColor: color, isCompleted: isCompleted, cornerRadius: cornerRadius))
    }

    func anchorFont(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> some View {
        self.font(.system(style, design: .rounded).weight(weight))
    }

    // Enhanced typography for different contexts
    func anchorTitle(weight: Font.Weight = .bold) -> some View {
        self.font(.system(.title2, design: .rounded).weight(weight))
            .foregroundColor(.anchorTextPrimary)
    }

    func anchorBody(weight: Font.Weight = .regular) -> some View {
        self.font(.system(.body, design: .rounded).weight(weight))
            .foregroundColor(.anchorTextPrimary)
    }

    func anchorCaption(weight: Font.Weight = .regular) -> some View {
        self.font(.system(.caption, design: .rounded).weight(weight))
            .foregroundColor(.anchorTextSecondary)
    }
}
