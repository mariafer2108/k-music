import SwiftUI

struct FullPlayerView: View {
    @ObservedObject var playerManager = PlayerManager.shared
    #if os(iOS)
    @Environment(\.horizontalSizeClass) var sizeClass
    #endif
    @State private var dragOffset: CGFloat = 0
    @State private var isScrubbing = false
    @State private var scrubValue: Double = 0
    
    var body: some View {
        GeometryReader { geometry in
            let screenHeight = geometry.size.height
            let screenWidth = geometry.size.width
            
            ZStack {
                // Capa 0: Fondo Oscuro e Inmersivo
                Color.black.ignoresSafeArea()
                
                if let song = playerManager.currentSong {
                    // Capa 1: Fondo Difuminado con tonos morados y rosados
                    AsyncImage(url: URL(string: song.thumbnailURL)) { phase in
                        switch phase {
                        case .empty:
                            Color.purple.opacity(0.25)
                        case .success(let image):
                            image.resizable()
                        case .failure:
                            LinearGradient(colors: [.purple.opacity(0.35), .cyan.opacity(0.2), .pink.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        @unknown default:
                            Color.purple.opacity(0.25)
                        }
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: screenWidth, height: screenHeight)
                    .blur(radius: 60)
                    .opacity(0.4)
                    .ignoresSafeArea()
                    
                    // Degradado K-Pop Style (Morado y Rosado)
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.3, green: 0.0, blue: 0.5).opacity(0.6), // Morado profundo
                            Color(red: 1.0, green: 0.2, blue: 0.6).opacity(0.4), // Rosado vibrante
                            Color.black.opacity(0.9)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                    
                    // Capa 2: Contenido Principal
                    VStack(spacing: 0) {
                        // Barra de arrastre
                        Capsule()
                            .fill(Color.white.opacity(0.4))
                            .frame(width: 40, height: 5)
                            .padding(.top, geometry.safeAreaInsets.top + 12)
                        
                        // 2.1 Cabecera
                        HStack {
                            Button(action: { dismissPlayer() }) {
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .background(Color.purple.opacity(0.3))
                                    .clipShape(Circle())
                            }
                            Spacer()
                            VStack(spacing: 2) {
                                Text("REPRODUCIENDO DESDE")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white.opacity(0.7))
                                Text(song.artist)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.pink) 
                                    .lineLimit(1) // CRÍTICO: Evitar que el texto crezca y desplace el video
                            }
                            .frame(height: 40) // Altura FIJA para la zona del artista
                            Spacer()
                            Button(action: {}) {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(10)
                            }
                        }
                        .frame(height: 50)
                        .padding(.top, 10)
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 30) // Más espacio para bajar el video
                        
                        // 2.2 Espacio para el Video (El video se inyecta desde ContentView para persistencia)
                        VStack {
                            GeometryReader { videoGeo in
                                ZStack {
                                    Rectangle()
                                        .fill(Color.black.opacity(0.1))
                                        .cornerRadius(20)
                                }
                                .onAppear { updateVideoPosition(geo: videoGeo) }
                                .onChange(of: videoGeo.frame(in: .global)) { _, _ in updateVideoPosition(geo: videoGeo) }
                            }
                        }
                        .frame(width: screenWidth - 40, height: (screenWidth - 40) * 0.5625)
                        .padding(.vertical, 10)
                        
                        Spacer(minLength: 20) // Espacio entre video y controles
                        
                        // 2.3 Info y Controles
                        VStack(spacing: screenHeight * 0.02) {
                            // Título y Like
                            HStack(alignment: .center) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(song.title)
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    Text(song.artist)
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.pink.opacity(0.8))
                                }
                                Spacer()
                                Menu {
                                    ForEach(PlaylistStore.shared.playlists) { p in
                                        Button(p.name) {
                                            PlaylistStore.shared.add(song: song, to: p.id)
                                        }
                                    }
                                    Button("Nueva lista…") {
                                        PlaylistStore.shared.createPlaylist(name: "Mi lista")
                                        if let first = PlaylistStore.shared.playlists.first {
                                            PlaylistStore.shared.add(song: song, to: first.id)
                                        }
                                    }
                                } label: {
                                    Image(systemName: "plus.circle")
                                        .font(.system(size: 26))
                                        .foregroundColor(.white)
                                }
                                Button(action: {
                                    withAnimation(.spring()) {
                                        playerManager.toggleLike(songID: song.youtubeID)
                                    }
                                }) {
                                    Image(systemName: playerManager.likedSongs.contains(song.youtubeID) ? "heart.fill" : "heart")
                                        .font(.system(size: 26))
                                        .foregroundColor(playerManager.likedSongs.contains(song.youtubeID) ? .pink : .white)
                                }
                            }
                            .padding(.horizontal, 24)
                            
                            // Barra de Progreso
                            VStack(spacing: 4) {
                                Slider(
                                    value: Binding(
                                        get: { isScrubbing ? scrubValue : playerManager.currentTime },
                                        set: { newValue in
                                            scrubValue = newValue
                                            if !isScrubbing {
                                                playerManager.currentTime = newValue
                                            }
                                        }
                                    ),
                                    in: 0...max(1, playerManager.totalTime),
                                    onEditingChanged: { editing in
                                        isScrubbing = editing
                                        if editing {
                                            scrubValue = playerManager.currentTime
                                        } else {
                                            playerManager.requestSeek(to: scrubValue)
                                        }
                                    }
                                )
                                .accentColor(.pink) // Barra en rosado
                                
                                HStack {
                                    Text(playerManager.formatTime(playerManager.currentTime))
                                    Spacer()
                                    Text(playerManager.formatTime(max(0, playerManager.totalTime)))
                                }
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(.pink.opacity(0.6))
                            }
                            .padding(.horizontal, 24)
                            
                            // Controles de Reproducción
                            HStack(spacing: screenWidth * 0.08) {
                                Button(action: { playerManager.toggleShuffle() }) {
                                    Image(systemName: "shuffle")
                                        .font(.system(size: 18))
                                        .foregroundColor(playerManager.isShuffleEnabled ? .pink : .white.opacity(0.5))
                                }
                                Button(action: { playerManager.previousTrack() }) { Image(systemName: "backward.fill").font(.system(size: 28)).foregroundColor(.purple) }
                                Button(action: { playerManager.togglePlayPause() }) {
                                    ZStack {
                                        Circle()
                                            .fill(LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                                            .frame(width: 80, height: 80)
                                            .shadow(color: .pink.opacity(0.4), radius: 10)
                                        
                                        Image(systemName: playerManager.webIsPaused ? "play.fill" : "pause.fill")
                                            .font(.system(size: 30))
                                            .foregroundColor(.white)
                                    }
                                }
                                Button(action: { playerManager.nextTrack() }) { Image(systemName: "forward.fill").font(.system(size: 28)).foregroundColor(.purple) }
                                Button(action: { playerManager.cycleRepeatMode() }) {
                                    Image(systemName: playerManager.repeatMode == .one ? "repeat.1" : "repeat")
                                        .font(.system(size: 18))
                                        .foregroundColor(playerManager.repeatMode == .off ? .white.opacity(0.5) : .pink)
                                }
                            }
                            .foregroundColor(.white)
                            
                            // Fila de Utilidades
                            HStack {
                                Spacer()
                            }
                            .padding(.horizontal, 24)
                            
                            HStack(spacing: 0) {
                                Button(action: {
                                    playerManager.selectedTab = 0
                                    dismissPlayer()
                                }) {
                                    VStack(spacing: 6) {
                                        Image(systemName: "house.fill")
                                            .font(.system(size: 18, weight: .semibold))
                                        Text("Inicio")
                                            .font(.system(size: 10, weight: .semibold))
                                    }
                                    .foregroundColor(.white.opacity(0.9))
                                    .frame(maxWidth: .infinity)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: {
                                    playerManager.selectedTab = 1
                                    dismissPlayer()
                                }) {
                                    VStack(spacing: 6) {
                                        Image(systemName: "magnifyingglass")
                                            .font(.system(size: 18, weight: .semibold))
                                        Text("Buscar")
                                            .font(.system(size: 10, weight: .semibold))
                                    }
                                    .foregroundColor(.white.opacity(0.9))
                                    .frame(maxWidth: .infinity)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: {
                                    playerManager.selectedTab = 2
                                    dismissPlayer()
                                }) {
                                    VStack(spacing: 6) {
                                        Image(systemName: "music.note.list")
                                            .font(.system(size: 18, weight: .semibold))
                                        Text("Biblioteca")
                                            .font(.system(size: 10, weight: .semibold))
                                    }
                                    .foregroundColor(.white.opacity(0.9))
                                    .frame(maxWidth: .infinity)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 10)
                        }
                        .padding(.bottom, geometry.safeAreaInsets.bottom + 10)
                    }
                }
            }
            .offset(y: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.height > 0 { dragOffset = value.translation.height }
                    }
                    .onEnded { value in
                        if value.translation.height > 150 { dismissPlayer() }
                        else { withAnimation(.spring()) { dragOffset = 0 } }
                    }
            )
        }
    }
    
    private func dismissPlayer() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            dragOffset = 0
            playerManager.showFullPlayer = false
        }
    }

    private func updateVideoPosition(geo: GeometryProxy) {
        let frame = geo.frame(in: .global)
        let center = CGPoint(x: frame.midX, y: frame.midY)
        if playerManager.videoCenter != center {
            playerManager.videoCenter = center
            playerManager.videoSize = frame.size
        }
    }
}
