import SwiftUI

struct RecommendationCardView: View {
    let song: Song
    let queue: [Song]
    #if os(iOS)
    @Environment(\.horizontalSizeClass) var sizeClass
    #endif
    
    private var isCompact: Bool {
        #if os(iOS)
        return sizeClass == .compact
        #else
        return false
        #endif
    }

    var body: some View {
        VStack(alignment: .leading) {
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
                            .font(.system(size: 50))
                            .foregroundColor(.white.opacity(0.55))
                    }
                @unknown default:
                    Color.white.opacity(0.08)
                }
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: isCompact ? 160 : 180, height: isCompact ? 160 : 180)
            .cornerRadius(12)
            .clipped()

            Text(song.title)
                .font(.system(size: isCompact ? 15 : 17, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
            
            Text(song.artist)
                .font(.system(size: isCompact ? 13 : 15))
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(1)
        }
        .frame(width: isCompact ? 160 : 180)
        .onTapGesture {
            PlayerManager.shared.play(song: song, in: queue)
        }
    }
}
