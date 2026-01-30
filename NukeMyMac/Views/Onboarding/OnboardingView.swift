import SwiftUI
import AppKit

/// Onboarding/Welcome flow shown on first launch
struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0
    @State private var isAnimating = false

    private let pages = OnboardingPage.allPages

    var body: some View {
        ZStack {
            // Animated background
            AnimatedOnboardingBackground()

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    Button("Skip") {
                        completeOnboarding()
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.nukeTextTertiary)
                    .padding()
                }

                // Page content
                ZStack {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(page: page, isActive: currentPage == index, isFirstPage: index == 0)
                            .opacity(currentPage == index ? 1 : 0)
                            .offset(x: CGFloat(index - currentPage) * 50)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: currentPage)

                // Custom page indicator
                HStack(spacing: 6) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Capsule()
                            .fill(currentPage == index ? Color.nukeNeonRed : Color.nukeTextTertiary.opacity(0.3))
                            .frame(width: currentPage == index ? 20 : 6, height: 6)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }
                .padding(.bottom, 16)

                // Navigation buttons
                HStack(spacing: 12) {
                    if currentPage > 0 {
                        Button {
                            withAnimation { currentPage -= 1 }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.nukeTextSecondary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.nukeSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    Button {
                        if currentPage < pages.count - 1 {
                            withAnimation { currentPage += 1 }
                        } else {
                            completeOnboarding()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(currentPage == pages.count - 1 ? "Get Started" : "Next")
                            Image(systemName: currentPage == pages.count - 1 ? "bolt.fill" : "chevron.right")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [.nukeNeonRed, .nukeNeonOrange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .nukeNeonRed.opacity(0.4), radius: 10, y: 4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 24)
            }
        }
        .frame(minWidth: 800, minHeight: 550)
    }

    private func completeOnboarding() {
        withAnimation(.easeOut(duration: 0.3)) {
            hasCompletedOnboarding = true
        }
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
}

// MARK: - Onboarding Page Model

struct OnboardingPage {
    let icon: String
    let title: String
    let subtitle: String
    let description: String
    let color: Color
    let features: [String]

    static var allPages: [OnboardingPage] {
        [
            OnboardingPage(
                icon: "bolt.shield.fill",
                title: "Welcome to",
                subtitle: "NUKE MY MAC",
                description: "The most powerful system cleaner for macOS. Reclaim disk space and boost performance.",
                color: .nukeNeonRed,
                features: []
            ),
            OnboardingPage(
                icon: "magnifyingglass.circle.fill",
                title: "Smart Scanning",
                subtitle: "FIND THE JUNK",
                description: "Deep scan your system to find caches, logs, old downloads, and other space-wasting files.",
                color: .nukeNeonOrange,
                features: [
                    "System & app caches",
                    "Xcode derived data",
                    "Log files & crash reports",
                    "Old downloads & trash"
                ]
            ),
            OnboardingPage(
                icon: "hammer.fill",
                title: "Power Tools",
                subtitle: "ADVANCED FEATURES",
                description: "Professional-grade utilities to keep your Mac running at peak performance.",
                color: .nukeCyan,
                features: [
                    "Duplicate file finder",
                    "App uninstaller",
                    "Startup manager",
                    "Disk space visualizer"
                ]
            ),
            OnboardingPage(
                icon: "shield.checkerboard",
                title: "Stay Protected",
                subtitle: "SAFE & SECURE",
                description: "Whitelist important files, schedule automatic scans, and always preview before deleting.",
                color: .nukeToxicGreen,
                features: [
                    "Whitelist protection",
                    "Scheduled cleanup",
                    "Preview before delete",
                    "Move to trash first"
                ]
            ),
            OnboardingPage(
                icon: "flame.fill",
                title: "Ready to Nuke?",
                subtitle: "LET'S GO",
                description: "Start your 7-day free trial and experience the full power of NukeMyMac.",
                color: .nukeNeonRed,
                features: [
                    "7-day free trial",
                    "All features unlocked",
                    "No credit card required",
                    "Cancel anytime"
                ]
            )
        ]
    }
}

// MARK: - Page View

struct OnboardingPageView: View {
    let page: OnboardingPage
    let isActive: Bool
    let isFirstPage: Bool

    @State private var iconScale: CGFloat = 0.5
    @State private var iconRotation: Double = -30
    @State private var iconTilt: Double = 0
    @State private var textOpacity: Double = 0
    @State private var featuresOffset: CGFloat = 30
    @State private var floatOffset: CGFloat = 0

    init(page: OnboardingPage, isActive: Bool, isFirstPage: Bool = false) {
        self.page = page
        self.isActive = isActive
        self.isFirstPage = isFirstPage
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Animated icon
            ZStack {
                // Glow rings (smaller)
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(page.color.opacity(0.1 - Double(i) * 0.03), lineWidth: 2)
                        .frame(width: 140 + CGFloat(i * 30), height: 140 + CGFloat(i * 30))
                        .scaleEffect(isActive ? 1 : 0.8)
                        .animation(.easeOut(duration: 0.6).delay(Double(i) * 0.1), value: isActive)
                }

                // Icon container - use app icon for first page
                if isFirstPage {
                    // App Icon with 3D tilt effect
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                        .shadow(color: page.color.opacity(0.6), radius: 25, x: 0, y: 15)
                        .rotation3DEffect(
                            .degrees(iconTilt),
                            axis: (x: 0.1, y: 1, z: 0.05)
                        )
                        .offset(y: floatOffset)
                        .scaleEffect(iconScale)
                } else {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [page.color.opacity(0.3), page.color.opacity(0.1)],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 70
                                )
                            )
                            .frame(width: 120, height: 120)

                        Image(systemName: page.icon)
                            .font(.system(size: 50, weight: .medium))
                            .foregroundStyle(page.color)
                            .shadow(color: page.color.opacity(0.5), radius: 20)
                    }
                    .scaleEffect(iconScale)
                    .rotationEffect(.degrees(iconRotation))
                }
            }

            // Text content
            VStack(spacing: 8) {
                Text(page.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.nukeTextSecondary)

                Text(page.subtitle)
                    .font(.system(size: 32, weight: .black))
                    .tracking(2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [page.color, page.color.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text(page.description)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.nukeTextSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
                    .padding(.top, 4)
            }
            .opacity(textOpacity)

            // Feature list - horizontal grid for compactness
            if !page.features.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(Array(page.features.enumerated()), id: \.offset) { index, feature in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(page.color)

                            Text(feature)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.nukeTextPrimary)

                            Spacer()
                        }
                        .offset(y: isActive ? 0 : featuresOffset)
                        .opacity(isActive ? 1 : 0)
                        .animation(.spring(response: 0.5).delay(Double(index) * 0.08 + 0.2), value: isActive)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(Color.nukeSurface.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .frame(maxWidth: 450)
            }

            Spacer()
        }
        .padding(.horizontal, 30)
        .onChange(of: isActive) { active in
            if active {
                animateIn()
            } else {
                resetAnimations()
            }
        }
        .onAppear {
            if isActive {
                animateIn()
            }
        }
    }

    private func animateIn() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            iconScale = 1.0
            iconRotation = 0
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
            textOpacity = 1
        }

        // Continuous tilt animation for first page
        if isFirstPage {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                iconTilt = 15
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                floatOffset = -10
            }
        }
    }

    private func resetAnimations() {
        iconScale = 0.5
        iconRotation = -30
        iconTilt = -15
        floatOffset = 0
        textOpacity = 0
    }
}

// MARK: - Animated Background

struct AnimatedOnboardingBackground: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            Color.nukeBackground

            // Floating orbs
            ForEach(0..<5) { i in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                [Color.nukeNeonRed, Color.nukeNeonOrange, Color.nukeCyan, Color.nukeToxicGreen, Color.nukeNeonRed][i].opacity(0.08),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    .offset(
                        x: animate ? CGFloat.random(in: -300...300) : CGFloat.random(in: -300...300),
                        y: animate ? CGFloat.random(in: -200...200) : CGFloat.random(in: -200...200)
                    )
                    .animation(
                        .easeInOut(duration: Double.random(in: 15...25))
                        .repeatForever(autoreverses: true),
                        value: animate
                    )
            }

            // Grid overlay
            GridPattern()
                .stroke(Color.nukeNeonRed.opacity(0.03), lineWidth: 1)
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .onAppear {
            animate = true
        }
    }
}

// MARK: - Grid Pattern

struct GridPattern: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let spacing: CGFloat = 40

        // Vertical lines
        for x in stride(from: 0, through: rect.width, by: spacing) {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
        }

        // Horizontal lines
        for y in stride(from: 0, through: rect.height, by: spacing) {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
        }

        return path
    }
}

// MARK: - Preview

#Preview("Onboarding") {
    OnboardingView(hasCompletedOnboarding: .constant(false))
        .frame(width: 800, height: 600)
}
