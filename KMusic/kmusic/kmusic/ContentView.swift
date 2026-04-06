import SwiftUI

struct ContentView: View {
    @Environment(\.horizontalSizeClass) var sizeClass
    @State private var selectedTab = 0
    @ObservedObject var playerManager = PlayerManager.shared

    var body: some View {
        ZStack(alignment: .bottom) {
            if sizeClass == .compact {
                iPhoneLayout()
            } else {
                MaciPadLayout()
            }
            
            if sizeClass == .compact && playerManager.currentSong != nil {
                MiniPlayerView()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 50)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// Layout para iPhone
struct iPhoneLayout: View {
    @State private var selectedTab = 0
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView().tabItem { Label("Inicio", systemImage: "house.fill") }.tag(0)
            Text("Buscar").tabItem { Label("Buscar", systemImage: "magnifyingglass") }.tag(1)
            Text("Biblioteca").tabItem { Label("Biblioteca", systemImage: "music.note.list") }.tag(2)
        }
        .accentColor(.purple)
    }
}

// Layout para iPad y Mac
struct MaciPadLayout: View {
    @State private var selectedTab = 0
    @ObservedObject var playerManager = PlayerManager.shared
    var body: some View {
        VStack(spacing: 0) {
            NavigationSplitView {
                SidebarView(selectedTab: $selectedTab)
            } detail: {
                ZStack {
                    Color.black.edgesIgnoringSafeArea(.all)
                    if selectedTab == 0 { HomeView() }
                    else { Text("Próximamente").foregroundColor(.white) }
                }
            }
            if playerManager.currentSong != nil { DesktopPlayerView() }
        }
    }
}