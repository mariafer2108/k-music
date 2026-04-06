import SwiftUI

struct RecentCardView: View {
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
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.55))
                    }
                @unknown default:
                    Color.white.opacity(0.08)
                }
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: isCompact ? 130 : 150, height: isCompact ? 130 : 150)
            .cornerRadius(8)
            .clipped()

            Text(song.title)
                .font(.system(size: isCompact ? 13 : 15, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .frame(width: isCompact ? 130 : 150)
        .onTapGesture {
            PlayerManager.shared.play(song: song, in: queue)
        }
    }
}
