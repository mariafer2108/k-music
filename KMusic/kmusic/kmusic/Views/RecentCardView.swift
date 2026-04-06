import SwiftUI

struct RecentCardView: View {
    let song: Song

    var body: some View {
        VStack(alignment: .leading) {
            Image(song.artwork)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 140, height: 140)
                .background(Color.purple.opacity(0.3))
                .cornerRadius(10)
                .clipped()

            Text(song.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .frame(width: 140)
        .onTapGesture {
            PlayerManager.shared.play(song: song)
        }
    }
}
