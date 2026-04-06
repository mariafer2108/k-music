import SwiftUI

enum KMTheme {
    static let indigoDark = Color(red: 18/255, green: 22/255, blue: 40/255)
    static let violet = Color.purple
    static let pink = Color.pink
    static let cyan = Color.cyan
    
    static var background: LinearGradient {
        LinearGradient(
            colors: [
                violet.opacity(0.45),
                indigoDark,
                cyan.opacity(0.28),
                pink.opacity(0.34)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static var card: LinearGradient {
        LinearGradient(
            colors: [Color.white.opacity(0.05), cyan.opacity(0.06)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
