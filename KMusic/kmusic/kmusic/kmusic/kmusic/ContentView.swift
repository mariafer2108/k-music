import SwiftUI
import Combine
#if os(iOS)
import UIKit
#endif

// Vista principal de la aplicación K-Music
struct ContentView: View {
    #if os(iOS)
    @Environment(\.horizontalSizeClass) var sizeClass
    #endif
    private let playerManager = PlayerManager.shared
    @State private var showFullPlayer = PlayerManager.shared.showFullPlayer
    @State private var hasSong = PlayerManager.shared.currentSong != nil
    
    private var isCompact: Bool {
        #if os(iOS)
        return sizeClass == .compact
        #else
        return false
        #endif
    }

    var body: some View {
        GeometryReader { fullScreenGeometry in
            ZStack {
                KMTheme.background.ignoresSafeArea()
                
                // Capa 0: Motor de video persistente (no interfiere con los controles)
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: 5)
                        .padding(.top, fullScreenGeometry.safeAreaInsets.top + 12)
                        .allowsHitTesting(false)
                    
                    Color.clear
                        .frame(height: 50)
                        .padding(.top, 10)
                        .allowsHitTesting(false)
                    Color.clear.frame(height: 30).allowsHitTesting(false)
                    
                    YouTubePlayerView()
                        .id("kmusic_persistent_video_engine")
                        .frame(
                            width: fullScreenGeometry.size.width - 40,
                            height: (fullScreenGeometry.size.width - 40) * 0.5625
                        )
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(showFullPlayer ? 0.6 : 0), radius: 25, x: 0, y: 15)
                        .padding(.vertical, 10)
                        .opacity(showFullPlayer ? 1.0 : 0.01)
                        .allowsHitTesting(showFullPlayer)
                    
                    Spacer().allowsHitTesting(false)
                }
                .zIndex(60)
                .ignoresSafeArea()
                .offset(x: showFullPlayer ? 0 : -fullScreenGeometry.size.width)
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showFullPlayer)
                
                // Capa 1: Layout Principal (Home, Search, Library)
                Group {
                    if isCompact {
                        iPhoneLayout()
                    } else {
                        MaciPadLayout()
                    }
                }
                .zIndex(1)
                
                // Capa 2: Full Player Overlay (Fondo y Controles)
                if showFullPlayer && isCompact {
                    let tabBarHeight: CGFloat = 49 + fullScreenGeometry.safeAreaInsets.bottom
                    let availableHeight = max(0, fullScreenGeometry.size.height - tabBarHeight)
                    FullPlayerView()
                        .frame(width: fullScreenGeometry.size.width, height: availableHeight)
                        .position(x: fullScreenGeometry.size.width / 2, y: availableHeight / 2)
                        .zIndex(50)
                        .transition(.move(edge: .bottom))
                }
                
                // Capa 4: Mini Player (Solo para iPhone)
                if isCompact && hasSong && !showFullPlayer {
                    VStack {
                        Spacer()
                        MiniPlayerView()
                            .padding(.bottom, 52)
                    }
                    .zIndex(20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .preferredColorScheme(.dark)
        .onReceive(playerManager.$showFullPlayer) { newValue in
            showFullPlayer = newValue
        }
        .onReceive(playerManager.$currentSong) { song in
            hasSong = song != nil
        }
        #if os(iOS)
        .onChange(of: showFullPlayer) { newValue in
            let appearance = UITabBarAppearance()
            if newValue {
                appearance.configureWithOpaqueBackground()
                appearance.backgroundColor = UIColor.black
            } else {
                appearance.configureWithDefaultBackground()
            }
            UITabBar.appearance().standardAppearance = appearance
            if #available(iOS 15.0, *) {
                UITabBar.appearance().scrollEdgeAppearance = appearance
            }
        }
        #endif
    }
}

// Layout para iPhone
struct iPhoneLayout: View {
    @ObservedObject private var playerManager = PlayerManager.shared
    var body: some View {
        TabView(selection: $playerManager.selectedTab) {
            HomeView().tabItem { Label("Inicio", systemImage: "house.fill") }.tag(0)
            SearchView().tabItem { Label("Buscar", systemImage: "magnifyingglass") }.tag(1)
            LibraryView().tabItem { Label("Biblioteca", systemImage: "music.note.list") }.tag(2)
        }
        .accentColor(.purple)
        .onChange(of: playerManager.selectedTab) { _ in
            if playerManager.showFullPlayer {
                playerManager.showFullPlayer = false
            }
        }
    }
}

// Layout para iPad y Mac
struct MaciPadLayout: View {
    @State private var selectedTab = 0
    @ObservedObject var playerManager = PlayerManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                NavigationSplitView {
                    SidebarView(selectedTab: $selectedTab)
                } detail: {
                    ZStack {
                        KMTheme.background.edgesIgnoringSafeArea(.all)
                        if selectedTab == 0 { HomeView() }
                        else if selectedTab == 1 { SearchView() }
                        else if selectedTab == 2 { LibraryView() }
                    }
                }
                
                if playerManager.showFullPlayer && playerManager.currentSong != nil {
                    FullPlayerView()
                        .frame(width: 350)
                }
            }
            
            if playerManager.currentSong != nil {
                DesktopPlayerView()
            }
        }
        .background(KMTheme.background)
    }
}
