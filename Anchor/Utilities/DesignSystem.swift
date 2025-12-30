import SwiftUI

// MARK: - Color Palette
extension Color {
    static let anchorBackground = Color(uiColor: .systemBackground) // Define in Assets or fallback
    static let anchorCardBg = Color(uiColor: .secondarySystemBackground)
    
    // Priority Colors - Descending Urgency
    // Priority 1: Red (Most Urgent) - Vibrant red for high urgency
    static let anchorCoral = Color(red: 1.0, green: 0.3, blue: 0.3) // Red - #FF4D4D
    
    // Priority 2: Orange (Medium Urgency) - Warm orange for medium priority
    static let anchorMint = Color(red: 1.0, green: 0.6, blue: 0.2) // Orange - #FF9933
    
    // Priority 3: Blue (Least Urgent) - Calm blue for lower urgency
    static let anchorIndigo = Color(red: 0.3, green: 0.6, blue: 1.0) // Blue - #4D99FF

    // Completion / Success - Pastel green for subtle, non-distracting completed tasks
    static let anchorCompletedGreen = Color(red: 0.70, green: 0.88, blue: 0.75) // Pastel green - soft and muted
    
    // Text
    static let anchorTextPrimary = Color.primary
    static let anchorTextSecondary = Color.secondary
}

// MARK: - Typography & Styles (View Modifiers)

struct AnchorCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.white.opacity(0.1)) // Glassmorphic hint or plain white
            .background(.thinMaterial)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

extension View {
    func anchorCard() -> some View {
        modifier(AnchorCardStyle())
    }
    
    func anchorFont(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> some View {
        self.font(.system(style, design: .rounded).weight(weight))
    }
}
