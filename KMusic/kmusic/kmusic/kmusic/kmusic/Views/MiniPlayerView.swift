import SwiftUI

struct MiniPlayerView: View {
    @ObservedObject var playerManager = PlayerManager.shared
    @Environment(\.horizontalSizeClass) var sizeClass
    
    var body: some View {
        if let currentSong = playerManager.currentSong {
            HStack(spacing: 12) {
                // Artwork con Fallback
                AsyncImage(url: URL(string: currentSong.thumbnailURL)) { phase in
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
                            Color.purple.opacity(0.3)
                            Image(systemName: "music.note")
                                .foregroundColor(.white.opacity(0.6))
                        }
                    @unknown default:
                        Color.white.opacity(0.08)
                    }
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 44, height: 44)
                .cornerRadius(6)
                .padding(.leading, 8)
                
                // Info
                VStack(alignment: .leading, spacing: 1) {
                    Text(currentSong.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(currentSong.artist)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Controls
                HStack(spacing: 20) {
                    Button(action: {
                        withAnimation(.spring()) {
                            playerManager.toggleLike(songID: currentSong.youtubeID)
                        }
                    }) {
                        Image(systemName: playerManager.likedSongs.contains(currentSong.youtubeID) ? "heart.fill" : "heart")
                            .foregroundColor(playerManager.likedSongs.contains(currentSong.youtubeID) ? .pink : .white)
                            .font(.system(size: 18))
                    }
                    
                    Button(action: {
                        playerManager.togglePlayPause()
                    }) {
                        Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                            .foregroundColor(.pink)
                            .font(.title3)
                    }
                }
                .padding(.trailing, 16)
            }
            .frame(height: 64)
            .background(
                ZStack {
                    BlurView(style: .thinDark)
                    LinearGradient(colors: [Color.purple.opacity(0.2), Color.pink.opacity(0.1)], startPoint: .leading, endPoint: .trailing)
                }
            )
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 5)
            .padding(.horizontal, 8)
            .onTapGesture {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    playerManager.showFullPlayer = true
                }
            }
        } else {
            EmptyView()
        }
    }
}

// Ayudante para efecto de desenfoque nativo
struct BlurView: View {
    var style: BlurStyle
    
    var body: some View {
        PlatformBlurView(style: style)
    }
}

enum BlurStyle {
    case thinDark
}

#if os(iOS)
import UIKit

private struct PlatformBlurView: UIViewRepresentable {
    var style: BlurStyle
    func makeUIView(context: Context) -> UIVisualEffectView {
        let effect = UIBlurEffect(style: .systemThinMaterialDark)
        return UIVisualEffectView(effect: effect)
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}
#elseif os(macOS)
import AppKit

private struct PlatformBlurView: NSViewRepresentable {
    var style: BlurStyle
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
#else
private struct PlatformBlurView: View {
    var style: BlurStyle
    var body: some View { Color.white.opacity(0.08) }
}
#endif
