import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    let categories = ["Éxitos", "Vibras Chill", "Entrenamiento", "Pop", "Rock"]
    @State private var selectedCategory = "Éxitos"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                HStack {
                    Text("Buenas Tardes")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(categories, id: \.self) { category in
                            CategoryPillView(categoryName: category, isSelected: category == selectedCategory)
                                .onTapGesture {
                                    selectedCategory = category
                                }
                        }
                    }
                    .padding(.horizontal)
                }

                VStack(alignment: .leading, spacing: 15) {
                    Text("Escuchado Recientemente")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 20) {
                            ForEach(viewModel.recentlyPlayed) { song in
                                RecentCardView(song: song)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                VStack(alignment: .leading, spacing: 15) {
                    Text("Recomendado para ti")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 20) {
                            ForEach(viewModel.recommendations) { song in
                                RecommendationCardView(song: song)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                Spacer(minLength: 120)
            }
        }
        .background(
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.2, green: 0, blue: 0.3), .black]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)
        )
    }
}
