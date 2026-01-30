import SwiftUI

extension Color {
    // MARK: - Core Palette
    static let nukeBlack = Color(red: 0.05, green: 0.05, blue: 0.05) // Deep background
    static let nukeDarkGray = Color(red: 0.12, green: 0.12, blue: 0.12) // Card background
    
    // MARK: - Accents (Neon/Aggressive)
    static let nukeNeonRed = Color(red: 1.0, green: 0.2, blue: 0.2)
    static let nukeNeonOrange = Color(red: 1.0, green: 0.5, blue: 0.0)
    static let nukeToxicGreen = Color(red: 0.0, green: 1.0, blue: 0.4)
    public static let nukeCyan = Color(red: 0.0, green: 0.9, blue: 1.0)
    public static let nukeBlue = Color(red: 0.2, green: 0.5, blue: 1.0)
    
    // MARK: - Semantic
    static let nukeBackground = nukeBlack
    static let nukeSurface = nukeDarkGray
    static let nukeSurfaceHighlight = Color(red: 0.18, green: 0.18, blue: 0.18)
    
    static let nukeTextPrimary = Color.white
    static let nukeTextSecondary = Color.white.opacity(0.6)
    static let nukeTextTertiary = Color.white.opacity(0.4)
    
    // MARK: - Gradients
    static let nukePrimaryGradient = LinearGradient(
        colors: [nukeNeonRed, nukeNeonOrange],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let nukeDarkGradient = LinearGradient(
        colors: [nukeDarkGray, nukeBlack],
        startPoint: .top,
        endPoint: .bottom
    )
}
