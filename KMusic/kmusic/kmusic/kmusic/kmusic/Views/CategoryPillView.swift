import SwiftUI

struct CategoryPillView: View {
    let categoryName: String
    let isSelected: Bool

    var body: some View {
        Text(categoryName)
            .font(.headline)
            .fontWeight(.bold)
            .foregroundColor(isSelected ? .white : Color.white.opacity(0.7))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.purple.opacity(0.8) : Color.white.opacity(0.1))
            .cornerRadius(16)
    }
}
