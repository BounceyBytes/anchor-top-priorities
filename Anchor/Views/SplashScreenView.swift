import SwiftUI

struct SplashScreenView: View {
    @State private var showAnchor = false
    @State private var showTitle = false
    @State private var showTagline = false
    @State private var showGlow = false
    @State private var anchorRotation: Double = -15
    @State private var particlesVisible = false
    
    let onComplete: () -> Void
    
    // Motivating taglines that rotate
    private let taglines = [
        "Drop anchor. Find focus.",
        "Three priorities. One mission.",
        "Stay grounded. Stay productive.",
        "Your compass for what matters.",
        "Anchor your day with intention."
    ]
    
    private var selectedTagline: String {
        taglines[Int.random(in: 0..<taglines.count)]
    }
    
    var body: some View {
        ZStack {
            // Deep atmospheric background
            backgroundGradient
            
            // Floating particles
            floatingParticles
            
            // Main content
            VStack(spacing: 32) {
                Spacer()
                
                // Anchor icon with glow
                anchorIcon
                
                // App title
                titleSection
                
                // Motivating tagline
                taglineSection
                
                Spacer()
                Spacer()
            }
            .padding(.horizontal, 40)
        }
        .ignoresSafeArea()
        .onAppear {
            startAnimationSequence()
        }
    }
    
    // MARK: - Background
    
    private var backgroundGradient: some View {
        ZStack {
            // Base color
            Color.anchorBackground
            
            // Radial glow from center
            RadialGradient(
                colors: [
                    Color.anchorIndigo.opacity(showGlow ? 0.15 : 0),
                    Color.anchorDeepIndigo.opacity(showGlow ? 0.08 : 0),
                    Color.clear
                ],
                center: .center,
                startRadius: 50,
                endRadius: 400
            )
            .animation(.easeInOut(duration: 2.0), value: showGlow)
            
            // Subtle top-down gradient for depth
            LinearGradient(
                colors: [
                    Color.anchorCoral.opacity(0.03),
                    Color.clear,
                    Color.anchorIndigo.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    // MARK: - Floating Particles
    
    private var floatingParticles: some View {
        GeometryReader { geo in
            ForEach(0..<12, id: \.self) { index in
                Circle()
                    .fill(particleColor(for: index))
                    .frame(width: particleSize(for: index), height: particleSize(for: index))
                    .blur(radius: 2)
                    .position(particlePosition(for: index, in: geo.size))
                    .opacity(particlesVisible ? particleOpacity(for: index) : 0)
                    .animation(
                        .easeInOut(duration: Double.random(in: 2.5...4.0))
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.15),
                        value: particlesVisible
                    )
            }
        }
    }
    
    private func particleColor(for index: Int) -> Color {
        let colors: [Color] = [
            .anchorIndigo,
            .anchorSuccessTeal,
            .anchorMint,
            .anchorCoral
        ]
        return colors[index % colors.count].opacity(0.4)
    }
    
    private func particleSize(for index: Int) -> CGFloat {
        CGFloat.random(in: 4...12)
    }
    
    private func particleOpacity(for index: Int) -> Double {
        Double.random(in: 0.3...0.6)
    }
    
    private func particlePosition(for index: Int, in size: CGSize) -> CGPoint {
        let angle = Double(index) * (360.0 / 12.0) * .pi / 180
        let radius = min(size.width, size.height) * 0.35
        let centerX = size.width / 2
        let centerY = size.height / 2
        
        return CGPoint(
            x: centerX + cos(angle) * radius * CGFloat.random(in: 0.7...1.3),
            y: centerY + sin(angle) * radius * CGFloat.random(in: 0.7...1.3)
        )
    }
    
    // MARK: - Anchor Icon
    
    private var anchorIcon: some View {
        ZStack {
            // Outer glow ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.anchorIndigo.opacity(0.6),
                            Color.anchorSuccessTeal.opacity(0.4)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                .frame(width: 140, height: 140)
                .blur(radius: 8)
                .opacity(showGlow ? 1 : 0)
            
            // Inner circle background
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.anchorCardBg,
                            Color.anchorBackground
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: Color.anchorIndigo.opacity(0.3), radius: 20, x: 0, y: 10)
            
            // Anchor symbol
            Image(systemName: "scope")
                .font(.system(size: 70, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.anchorIndigo,
                            Color.anchorSuccessTeal
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .rotationEffect(.degrees(anchorRotation))
        }
        .scaleEffect(showAnchor ? 1 : 0.3)
        .opacity(showAnchor ? 1 : 0)
    }
    
    // MARK: - Title Section
    
    private var titleSection: some View {
        VStack(spacing: 8) {
            Text("Anchor")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            .white,
                            Color.white.opacity(0.85)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: Color.anchorIndigo.opacity(0.3), radius: 10, x: 0, y: 4)
        }
        .scaleEffect(showTitle ? 1 : 0.8)
        .opacity(showTitle ? 1 : 0)
        .offset(y: showTitle ? 0 : 20)
    }
    
    // MARK: - Tagline Section
    
    private var taglineSection: some View {
        Text(selectedTagline)
            .font(.system(size: 18, weight: .medium, design: .rounded))
            .foregroundStyle(Color.anchorTextSecondary)
            .multilineTextAlignment(.center)
            .opacity(showTagline ? 1 : 0)
            .offset(y: showTagline ? 0 : 15)
    }
    
    // MARK: - Animation Sequence
    
    private func startAnimationSequence() {
        // Phase 1: Anchor icon appears with bounce
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            showAnchor = true
        }
        
        // Anchor settles into position
        withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.1)) {
            anchorRotation = 0
        }
        
        // Phase 2: Glow and particles
        withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
            showGlow = true
            particlesVisible = true
        }
        
        // Phase 3: Title appears
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.5)) {
            showTitle = true
        }
        
        // Phase 4: Tagline fades in
        withAnimation(.easeOut(duration: 0.6).delay(0.8)) {
            showTagline = true
        }
        
        // Phase 5: Transition to main app
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            onComplete()
        }
    }
}

#Preview {
    SplashScreenView(onComplete: {})
        .preferredColorScheme(.dark)
}

