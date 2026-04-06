import SwiftUI

struct MiniPlayerView: View {
    @ObservedObject var playerManager = PlayerManager.shared
    
    var body: some View {
        if let currentSong = playerManager.currentSong {
            HStack(spacing: 15) {
                Image(currentSong.artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .background(Color.purple)
                    .cornerRadius(8)
                    .padding(.leading, 10)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(currentSong.title)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(currentSong.artist)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                }
                
                Spacer()
                
                HStack(spacing: 20) {
                    Button(action: {
                        playerManager.togglePlayPause()
                    }) {
                        Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                            .foregroundColor(.white)
                            .font(.title2)
                    }
                }
                .padding(.trailing, 15)
            }
            .frame(height: 70)
            .background(
                LinearGradient(gradient: Gradient(colors: [Color.purple, Color(red: 0.4, green: 0, blue: 0.6)]), startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(15)
            .shadow(color: .purple.opacity(0.4), radius: 10, x: 0, y: 5)
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
            .onTapGesture {
                withAnimation(.spring()) {
                    playerManager.showFullPlayer = true
                }
            }
            .sheet(isPresented: $playerManager.showFullPlayer) {
                FullPlayerView()
            }
        } else {
            EmptyView()
        }
    }
}
