import SwiftUI
import UIKit

/// Light, minimal Apple-like theme.
enum Theme {
    static let accent = Color(red: 0.04, green: 0.52, blue: 1.00)
    static let background = Color(uiColor: .systemGroupedBackground)
    static let cardBackground = Color(uiColor: .secondarySystemGroupedBackground)
    static let success = Color(uiColor: .systemGreen)
    static let danger = Color(uiColor: .systemRed)
}

extension View {
    /// White rounded card used across the app.
    func cardStyle() -> some View {
        self
            .padding(16)
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
