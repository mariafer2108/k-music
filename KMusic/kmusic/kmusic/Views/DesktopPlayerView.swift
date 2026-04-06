import SwiftUI

struct DesktopPlayerView: View {
    @ObservedObject var playerManager = PlayerManager.shared
    @State private var volume: Double = 0.5
    
    var body: some View {
        if let song = playerManager.currentSong {
            VStack(spacing: 0) {
                Divider()
                    .background(Color.white.opacity(0.1))
                
                HStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Image(song.artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 56, height: 56)
                            .background(Color.purple.opacity(0.3))
                            .cornerRadius(4)
                            .shadow(color: .purple.opacity(0.3), radius: 5)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(song.title)
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(song.artist)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        
                        Button(action: {}) {
                            Image(systemName: "heart")
                                .foregroundColor(.gray)
                                .font(.title3)
                        }
                        .padding(.leading, 10)
                        .buttonStyle(PlainButtonStyle())
                    }
                    .frame(width: 300, alignment: .leading)
                    
                    Spacer()
                    
                    VStack(spacing: 8) {
                        HStack(spacing: 24) {
                            Button(action: {}) { Image(systemName: "shuffle").foregroundColor(.gray) }.buttonStyle(PlainButtonStyle())
                            Button(action: {}) { Image(systemName: "backward.fill").foregroundColor(.white) }.buttonStyle(PlainButtonStyle())
                            
                            Button(action: { playerManager.togglePlayPause() }) {
                                Image(systemName: playerManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 38))
                                    .foregroundColor(.white)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Button(action: {}) { Image(systemName: "forward.fill").foregroundColor(.white) }.buttonStyle(PlainButtonStyle())
                            Button(action: {}) { Image(systemName: "repeat").foregroundColor(.gray) }.buttonStyle(PlainButtonStyle())
                        }
                        
                        HStack(spacing: 8) {
                            Text("1:23").font(.caption2).foregroundColor(.gray)
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.1)).frame(height: 4)
                                Capsule().fill(Color.purple).frame(width: 150, height: 4)
                                Circle().fill(Color.white).frame(width: 10, height: 10).offset(x: 145)
                            }
                            .frame(width: 400)
                            Text("-2:34").font(.caption2).foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        Button(action: {}) { Image(systemName: "mic").foregroundColor(.gray) }.buttonStyle(PlainButtonStyle())
                        Button(action: {}) { Image(systemName: "list.bullet").foregroundColor(.gray) }.buttonStyle(PlainButtonStyle())
                        Button(action: {}) { Image(systemName: "speaker.wave.2").foregroundColor(.gray) }.buttonStyle(PlainButtonStyle())
                        
                        Slider(value: $volume)
                            .frame(width: 100)
                            .accentColor(.purple)
                    }
                    .frame(width: 300, alignment: .trailing)
                }
                .padding(.horizontal, 16)
                .frame(height: 90)
                .background(Color.black.opacity(0.95))
            }
        } else {
            EmptyView()
        }
    }
}
