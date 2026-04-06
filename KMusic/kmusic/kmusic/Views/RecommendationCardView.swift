import SwiftUI

struct RecommendationCardView: View {
    let song: Song

    var body: some View {
        VStack(alignment: .leading) {
            Image(song.artwork)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 160, height: 160)
                .background(Color.pink.opacity(0.3))
                .cornerRadius(12)
                .clipped()

            Text(song.title)
                .font(.headline)
                .foregroundColor(.white)
                .lineLimit(1)
            
            Text(song.artist)
                .font(.subheadline)
                .foregroundColor(.gray)
                .lineLimit(1)
        }
        .frame(width: 160)
        .onTapGesture {
            PlayerManager.shared.play(song: song)
        }
    }
}
