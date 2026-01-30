import SwiftUI

// MARK: - Accessibility Environment Key

private struct ReduceMotionKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var reduceMotionEnabled: Bool {
        get { self[ReduceMotionKey.self] }
        set { self[ReduceMotionKey.self] = newValue }
    }
}

// MARK: - View Modifiers

struct ShimmerEffect: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @ObservedObject private var settings = SettingsViewModel.shared
    @State private var phase: CGFloat = 0
    var duration: Double = 1.5
    var bounce: Bool = false

    private var reduceMotion: Bool {
        systemReduceMotion || settings.reduceAnimations
    }

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .overlay(
                    GeometryReader { geometry in
                        LinearGradient(
                            colors: [
                                .clear,
                                .white.opacity(0.1),
                                .white.opacity(0.4),
                                .white.opacity(0.1),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .rotationEffect(.degrees(30))
                        .offset(x: -geometry.size.width * 2 + (geometry.size.width * 4 * phase))
                    }
                )
                .mask(content)
                .onAppear {
                    withAnimation(Animation.linear(duration: duration).repeatForever(autoreverses: bounce)) {
                        phase = 1
                    }
                }
        }
    }
}

struct GlowEffect: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @ObservedObject private var settings = SettingsViewModel.shared
    var color: Color
    var radius: CGFloat
    var opacity: Double
    @State private var isPulsing: Bool = false

    private var reduceMotion: Bool {
        systemReduceMotion || settings.reduceAnimations
    }

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(reduceMotion ? opacity : (isPulsing ? opacity : opacity * 0.5)), radius: reduceMotion ? radius : (isPulsing ? radius : radius * 0.5))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

struct CRTOverlayEffect: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @ObservedObject private var settings = SettingsViewModel.shared
    @State private var flicker: Double = 0.05

    private var reduceMotion: Bool {
        systemReduceMotion || settings.reduceAnimations
    }

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            ZStack {
                content

                // Scanlines
                GeometryReader { geo in
                    VStack(spacing: 0) {
                        ForEach(0..<Int(geo.size.height / 4), id: \.self) { _ in
                            Color.black.opacity(0.15)
                                .frame(height: 2)
                            Spacer().frame(height: 2)
                        }
                    }
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)

                // Vignette
                RadialGradient(
                    colors: [.clear, .black.opacity(0.4)],
                    center: .center,
                    startRadius: 200,
                    endRadius: 800
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - Animated Background

struct AnimatedMeshBackground: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @ObservedObject private var settings = SettingsViewModel.shared
    @State private var animate = false

    private var reduceMotion: Bool {
        systemReduceMotion || settings.reduceAnimations
    }

    var body: some View {
        ZStack {
            Color.nukeBlack.ignoresSafeArea()

            if reduceMotion {
                // Static gradient for reduced motion
                RadialGradient(
                    colors: [Color.nukeNeonRed.opacity(0.1), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 400
                )
            } else {
                // Floating blobs
                ForEach(0..<3) { i in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    (i == 0 ? Color.nukeNeonRed : (i == 1 ? Color.nukeNeonOrange : Color.nukeCyan)).opacity(0.15),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 300
                            )
                        )
                        .frame(width: 600, height: 600)
                        .offset(
                            x: animate ? CGFloat.random(in: -200...200) : CGFloat.random(in: -200...200),
                            y: animate ? CGFloat.random(in: -200...200) : CGFloat.random(in: -200...200)
                        )
                        .animation(
                            .easeInOut(duration: 20 + Double(i * 5)).repeatForever(autoreverses: true),
                            value: animate
                        )
                }
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            animate = true
        }
    }
}

// MARK: - Extensions

extension View {
    func nukeShimmer(duration: Double = 1.5) -> some View {
        modifier(ShimmerEffect(duration: duration))
    }
    
    func nukeGlow(color: Color, radius: CGFloat = 10, opacity: Double = 0.8) -> some View {
        modifier(GlowEffect(color: color, radius: radius, opacity: opacity))
    }
    
    func nukeCRT() -> some View {
        modifier(CRTOverlayEffect())
    }
}

// MARK: - Advanced Components

/// Simple spinning indicator - replaces ProgressView() to avoid AppKit constraint issues
struct NukeSpinner: View {
    var size: CGFloat = 20
    var color: Color = .nukeTextSecondary
    var lineWidth: CGFloat = 2

    @State private var isAnimating = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .animation(.linear(duration: 0.8).repeatForever(autoreverses: false), value: isAnimating)
            .onAppear {
                isAnimating = true
            }
    }
}

/// A high-tech, animated reactor core loader
struct ReactorLoader: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @ObservedObject private var settings = SettingsViewModel.shared
    var size: CGFloat = 100
    var color: Color = .nukeNeonRed

    @State private var rotation: Double = 0
    @State private var pulse: Bool = false

    private var reduceMotion: Bool {
        systemReduceMotion || settings.reduceAnimations
    }

    var body: some View {
        ZStack {
            // Core
            Circle()
                .fill(
                    RadialGradient(
                        colors: [color, .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size / 2
                    )
                )
                .frame(width: size, height: size)
                .scaleEffect(reduceMotion ? 1.0 : (pulse ? 1.0 : 0.8))
                .opacity(reduceMotion ? 0.6 : (pulse ? 0.8 : 0.4))

            // Inner Ring
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(
                    AngularGradient(
                        colors: [color, color.opacity(0)],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: size * 0.7, height: size * 0.7)
                .rotationEffect(.degrees(reduceMotion ? 0 : rotation))
                .animation(reduceMotion ? nil : .linear(duration: 1).repeatForever(autoreverses: false), value: rotation)

            // Outer Ring
            Circle()
                .trim(from: 0, to: 0.6)
                .stroke(
                    AngularGradient(
                        colors: [color.opacity(0.8), color.opacity(0)],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(reduceMotion ? 0 : -rotation))
                .animation(reduceMotion ? nil : .linear(duration: 2).repeatForever(autoreverses: false), value: rotation)

            // Warning Label - positioned below the circles
            Text("LOADING")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(color)
                .tracking(2)
                .offset(y: size * 0.65)
        }
        .accessibilityLabel("Loading indicator")
        .onAppear {
            guard !reduceMotion else { return }
            rotation = 360
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

/// A "glitch" text effect that randomly offsets lines
struct GlitchReveal: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 0

    func body(content: Content) -> some View {
        content
            .offset(x: reduceMotion ? 0 : offset)
            .opacity(opacity)
            .onAppear {
                if reduceMotion {
                    opacity = 1
                } else {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                        opacity = 1
                    }

                    // Trigger glitch seq
                    let baseDelay = 0.1
                    for i in 0..<5 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + baseDelay + Double(i) * 0.05) {
                            offset = CGFloat.random(in: -5...5)
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        offset = 0
                    }
                }
            }
    }
}

extension View {
    func nukeGlitchReveal() -> some View {
        modifier(GlitchReveal())
    }
}

/// A button with a glitchy hover effect
struct GlitchButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let title: String
    let action: () -> Void
    var color: Color = .nukeNeonRed

    @State private var isHovered = false
    @State private var glitchOffset: CGFloat = 0
    @State private var glitchOpacity: Double = 1

    var body: some View {
        Button(action: action) {
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? color.opacity(0.15) : Color.nukeSurfaceHighlight.opacity(0.3))

                // Border
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        isHovered ? color.opacity(0.8) : Color.nukeSurfaceHighlight,
                        lineWidth: 1
                    )

                // Text Glitch Layers (Red/Cyan shift) - only when not reducing motion
                if isHovered && !reduceMotion {
                    Text(title)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.nukeNeonRed)
                        .offset(x: glitchOffset + 1)
                        .opacity(0.7)

                    Text(title)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.nukeCyan)
                        .offset(x: -glitchOffset - 1)
                        .opacity(0.7)
                }

                // Main Text
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(isHovered ? color : Color.nukeTextSecondary)
                    .offset(x: (isHovered && !reduceMotion) ? glitchOffset : 0)
            }
            .frame(height: 28)
            .padding(.horizontal, 12)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .onHover { hovering in
            DispatchQueue.main.async {
                isHovered = hovering
                if hovering && !reduceMotion {
                    startGlitch()
                } else {
                    glitchOffset = 0
                }
            }
        }
    }

    private func startGlitch() {
        guard isHovered && !reduceMotion else { return }

        // Random glitch jumps
        let duration = Double.random(in: 0.1...0.3)
        withAnimation(.linear(duration: 0.05)) {
            glitchOffset = CGFloat.random(in: -2...2)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.linear(duration: 0.05)) {
                glitchOffset = 0
            }
        }

        // Loop
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            startGlitch()
        }
    }
}
