import SwiftUI

struct FullPlayerView: View {
    @ObservedObject var playerManager = PlayerManager.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            if let song = playerManager.currentSong {
                Image(song.artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .blur(radius: 60)
                    .overlay(Color.black.opacity(0.4))
                    .edgesIgnoringSafeArea(.all)
            }
            
            VStack(spacing: 30) {
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)
                
                Spacer()
                
                if let song = playerManager.currentSong {
                    // Portada de la canción en lugar de video
                    Group {
                        if let uiImage = UIImage(named: song.artwork) {
                            Image(uiImage: uiImage)
                                .resizable()
                        } else {
                            ZStack {
                                Color.purple.opacity(0.3)
                                Image(systemName: "music.note")
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 300, height: 300)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 20)
                    .scaleEffect(playerManager.isPlaying ? 1.0 : 0.85)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: playerManager.isPlaying)
                    
                    VStack(spacing: 40) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(song.title)
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                Text(song.artist)
                                    .font(.title3)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            Spacer()
                            Button(action: {}) {
                                Image(systemName: "ellipsis.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        .padding(.horizontal, 40)
                        
                        VStack(spacing: 8) {
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.1)).frame(height: 6)
                                Capsule().fill(Color.white.opacity(0.8)).frame(width: 120, height: 6)
                            }
                            HStack {
                                Text("1:23").font(.caption).foregroundColor(.white.opacity(0.5))
                                Spacer()
                                Text("-2:34").font(.caption).foregroundColor(.white.opacity(0.5))
                            }
                        }
                        .padding(.horizontal, 40)
                        
                        HStack(spacing: 50) {
                            Button(action: {}) {
                                Image(systemName: "backward.fill")
                                    .font(.system(size: 35))
                                    .foregroundColor(.white)
                            }
                            
                            Button(action: {
                                withAnimation(.spring()) {
                                    playerManager.togglePlayPause()
                                }
                            }) {
                                Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 55))
                                    .foregroundColor(.white)
                            }
                            
                            Button(action: {}) {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 35))
                                    .foregroundColor(.white)
                            }
                        }
                        
                        HStack(spacing: 15) {
                            Image(systemName: "speaker.fill").foregroundColor(.white.opacity(0.5))
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.1)).frame(height: 6)
                                Capsule().fill(Color.white.opacity(0.8)).frame(width: 200, height: 6)
                            }
                            Image(systemName: "speaker.wave.3.fill").foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.horizontal, 40)
                    }
                }
                
                Spacer()
            }
        }
    }
}
