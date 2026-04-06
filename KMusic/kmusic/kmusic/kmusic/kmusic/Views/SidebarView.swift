import SwiftUI

struct SidebarView: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        List {
            Group {
                SidebarItem(title: "Inicio", icon: "house.fill", isSelected: selectedTab == 0)
                    .onTapGesture { selectedTab = 0 }
                
                SidebarItem(title: "Explorar", icon: "magnifyingglass", isSelected: selectedTab == 1)
                    .onTapGesture { selectedTab = 1 }
                
                SidebarItem(title: "Biblioteca", icon: "music.note.list", isSelected: selectedTab == 2)
                    .onTapGesture { selectedTab = 2 }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            
            Section {
                SidebarItem(title: "Mix de K-Pop", icon: "music.note", isSelected: false)
                SidebarItem(title: "BTS Favorites", icon: "music.note", isSelected: false)
                SidebarItem(title: "BLACKPINK Hits", icon: "music.note", isSelected: false)
                SidebarItem(title: "NewJeans Vibes", icon: "music.note", isSelected: false)
            } header: {
                Text("Tus Listas")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                    .padding(.top, 20)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
        .listStyle(SidebarListStyle())
        .background(Color.black.opacity(0.95))
        .scrollContentBackground(.hidden)
    }
}

struct SidebarItem: View {
    let title: String
    let icon: String
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(isSelected ? .white : .gray)
                .frame(width: 24)
            
            Text(title)
                .font(.headline)
                .foregroundColor(isSelected ? .white : .gray)
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isSelected ? Color.white.opacity(0.1) : Color.clear)
        .cornerRadius(8)
        .contentShape(Rectangle())
    }
}
