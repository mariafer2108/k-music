import SwiftUI

struct DesktopPlayerView: View {
    @ObservedObject var playerManager = PlayerManager.shared
    
    var body: some View {
        if let song = playerManager.currentSong {
            VStack(spacing: 0) {
                Divider().background(Color.white.opacity(0.1))
                
                HStack(spacing: 0) {
                    // INFO CANCIÓN
                    HStack(spacing: 12) {
                        AsyncImage(url: URL(string: song.thumbnailURL)) { phase in
                            switch phase {
                            case .empty:
                                ZStack {
                                    Color.white.opacity(0.08)
                                    ProgressView().tint(.pink)
                                }
                            case .success(let image):
                                image.resizable()
                            case .failure:
                                ZStack {
                                    LinearGradient(colors: [.purple.opacity(0.35), .cyan.opacity(0.2), .pink.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    Image(systemName: "music.note")
                                        .foregroundColor(.white.opacity(0.55))
                                }
                            @unknown default:
                                Color.white.opacity(0.08)
                            }
                        }
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 56, height: 56)
                        .cornerRadius(4)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(song.title).font(.headline).foregroundColor(.white)
                            Text(song.artist).font(.subheadline).foregroundColor(.gray)
                        }
                        .lineLimit(1)
                        
                        Button(action: {
                            withAnimation(.spring()) {
                                playerManager.toggleLike(songID: song.youtubeID)
                            }
                        }) {
                            Image(systemName: playerManager.likedSongs.contains(song.youtubeID) ? "heart.fill" : "heart")
                                .font(.system(size: 20))
                                .foregroundColor(playerManager.likedSongs.contains(song.youtubeID) ? .purple : .gray)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.leading, 8)
                    }
                    .frame(width: 350, alignment: .leading) // Aumentado para que quepa todo
                    
                    Spacer()
                    
                    // CONTROLES CENTRALES
                    VStack(spacing: 8) {
                        HStack(spacing: 24) {
                            Button(action: { playerManager.toggleShuffle() }) {
                                Image(systemName: "shuffle")
                                    .foregroundColor(playerManager.isShuffleEnabled ? .purple : .gray)
                            }
                            .buttonStyle(PlainButtonStyle())
                            Button(action: { playerManager.previousTrack() }) { Image(systemName: "backward.fill").foregroundColor(.white) }.buttonStyle(PlainButtonStyle())
                            
                            Button(action: { playerManager.togglePlayPause() }) {
                                Image(systemName: playerManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 38))
                                    .foregroundColor(.white)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Button(action: { playerManager.nextTrack() }) { Image(systemName: "forward.fill").foregroundColor(.white) }.buttonStyle(PlainButtonStyle())
                            Button(action: { playerManager.cycleRepeatMode() }) {
                                Image(systemName: playerManager.repeatMode == .one ? "repeat.1" : "repeat")
                                    .foregroundColor(playerManager.repeatMode == .off ? .gray : .purple)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        // Barra de progreso REAL
                        HStack(spacing: 8) {
                            Text(playerManager.formatTime(playerManager.currentTime))
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .frame(width: 35)
                            
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.1))
                                        .frame(height: 4)
                                    
                                    Capsule()
                                        .fill(Color.purple)
                                        .frame(width: geometry.size.width * CGFloat(playerManager.currentTime / playerManager.totalTime), height: 4)
                                    
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 10, height: 10)
                                        .offset(x: (geometry.size.width * CGFloat(playerManager.currentTime / playerManager.totalTime)) - 5)
                                }
                            }
                            .frame(width: 400, height: 10)
                            
                            Text("-" + playerManager.formatTime(playerManager.totalTime - playerManager.currentTime))
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .frame(width: 35)
                        }
                    }
                    
                    Spacer()
                    
                    // VOLUMEN Y PANEL DERECHO
                    HStack(spacing: 16) {
                        Button(action: {
                            withAnimation(.spring()) {
                                playerManager.showFullPlayer.toggle()
                            }
                        }) {
                            Image(systemName: playerManager.showFullPlayer ? "chevron.down.circle.fill" : "chevron.up.circle.fill")
                                .font(.title2)
                                .foregroundColor(.purple)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Image(systemName: "speaker.wave.2").foregroundColor(.gray)
                        Slider(value: $playerManager.volume, in: 0...1)
                            .frame(width: 100)
                            .accentColor(.purple)
                    }
                    .frame(width: 300, alignment: .trailing)
                }
                .padding(.horizontal, 16)
                .frame(height: 90)
                .background(KMTheme.indigoDark.opacity(0.95))
            }
        }
    }
}
