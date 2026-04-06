import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    private let playerManager = PlayerManager.shared
    @State private var recentlyPlayed: [Song] = PlayerManager.shared.recentlyPlayed
    #if os(iOS)
    @Environment(\.horizontalSizeClass) var sizeClass
    #endif
    @State private var artistSheet: ArtistSheetItem?
    
    private var isCompact: Bool {
        #if os(iOS)
        return sizeClass == .compact
        #else
        return false
        #endif
    }
    
    private var bottomSafePadding: CGFloat {
        #if os(macOS)
        return playerManager.currentSong == nil ? 20 : 130
        #else
        return isCompact ? 0 : 20
        #endif
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: isCompact ? 24 : 32) {
                // Title
                HStack {
                    Text("Buenas Tardes")
                        .font(.system(size: isCompact ? 32 : 40, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, isCompact ? 20 : 40)

                // Recently Played
                VStack(alignment: .leading, spacing: 16) {
                    Text("Escuchado Recientemente")
                        .font(.system(size: isCompact ? 22 : 26, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)

                    if recentlyPlayed.isEmpty {
                        Text("Tus canciones aparecerán aquí")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 20)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(recentlyPlayed) { song in
                                    RecentCardView(song: song, queue: recentlyPlayed)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
                
                // Recomendaciones (Bandas)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Bandas recomendadas")
                            .font(.system(size: isCompact ? 22 : 26, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                        Button(action: {
                            Task {
                                await viewModel.refreshAIBandRecommendations(
                                    recentlyPlayed: recentlyPlayed,
                                    likedSongIDs: playerManager.likedSongs
                                )
                            }
                        }) {
                            if viewModel.aiIsLoading {
                                ProgressView()
                                    .tint(.pink)
                            } else {
                                Text("Actualizar")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.pink)
                            }
                        }
                        .disabled(viewModel.aiIsLoading)
                    }
                    .padding(.horizontal, 20)
                    
                    if let msg = viewModel.aiErrorMessage {
                        Text(msg)
                            .font(.footnote)
                            .foregroundColor(.pink.opacity(0.9))
                            .padding(.horizontal, 20)
                    }
                    
                    if viewModel.aiBandRecommendations.isEmpty {
                        Text("Toca “Actualizar” para obtener sugerencias personalizadas.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 20)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(viewModel.aiBandRecommendations, id: \.self) { band in
                                    Button(action: { artistSheet = ArtistSheetItem(id: band, name: band) }) {
                                        Text(band)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.white)
                                            .padding(.vertical, 10)
                                            .padding(.horizontal, 14)
                                            .background(
                                                LinearGradient(
                                                    colors: [.purple.opacity(0.35), .pink.opacity(0.25)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .cornerRadius(14)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }

                // Recommended for you
                VStack(alignment: .leading, spacing: 16) {
                    Text("Recomendado para ti")
                        .font(.system(size: isCompact ? 22 : 26, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)

                    #if os(macOS)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 16)], spacing: 16) {
                        ForEach(viewModel.recommendations) { song in
                            RecommendationCardView(song: song, queue: viewModel.recommendations)
                        }
                    }
                    .padding(.horizontal, 20)
                    #else
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(viewModel.recommendations) { song in
                                RecommendationCardView(song: song, queue: viewModel.recommendations)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    #endif
                }

                Spacer(minLength: isCompact ? 120 : 150)
            }
        }
        .background(KMTheme.background.ignoresSafeArea())
        .padding(.bottom, bottomSafePadding)
        .onReceive(playerManager.$recentlyPlayed) { newValue in
            recentlyPlayed = newValue
        }
        .task {
            #if os(macOS)
            if viewModel.aiBandRecommendations.isEmpty && !viewModel.aiIsLoading {
                await viewModel.refreshAIBandRecommendations(recentlyPlayed: recentlyPlayed, likedSongIDs: playerManager.likedSongs)
            }
            #endif
        }
        .sheet(item: $artistSheet) { item in
            ArtistYouTubeView(artistName: item.name)
        }
    }
}

private struct ArtistSheetItem: Identifiable {
    let id: String
    let name: String
}
