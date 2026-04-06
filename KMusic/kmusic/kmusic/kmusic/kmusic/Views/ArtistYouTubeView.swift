import SwiftUI

struct ArtistYouTubeView: View {
    let artistName: String
    
    @AppStorage("youtubeApiKey") private var youtubeApiKey: String = ""
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var playerManager = PlayerManager.shared
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var videos: [YouTubeVideo] = []
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color.purple.opacity(0.45),
                        Color.black,
                        Color.cyan.opacity(0.25),
                        Color.pink.opacity(0.35)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                if isLoading && videos.isEmpty {
                    ProgressView()
                        .tint(.pink)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            if let errorText {
                                Text(errorText)
                                    .font(.footnote)
                                    .foregroundColor(.pink.opacity(0.9))
                                    .padding(.horizontal, 16)
                            }
                            
                            LazyVStack(spacing: 12) {
                                ForEach(videos) { video in
                                    Button(action: { play(video) }) {
                                        HStack(spacing: 12) {
                                            AsyncImage(url: URL(string: video.thumbnailURL)) { phase in
                                                switch phase {
                                                case .empty:
                                                    ZStack {
                                                        Color.white.opacity(0.08)
                                                        ProgressView().tint(.pink)
                                                    }
                                                case .success(let image):
                                                    image
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                case .failure:
                                                    ZStack {
                                                        LinearGradient(
                                                            colors: [.purple.opacity(0.35), .pink.opacity(0.25)],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        )
                                                        Image(systemName: "music.note")
                                                            .foregroundColor(.white.opacity(0.6))
                                                    }
                                                @unknown default:
                                                    Color.white.opacity(0.08)
                                                }
                                            }
                                            .frame(width: 96, height: 54)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(video.title)
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundColor(.white)
                                                    .lineLimit(2)
                                                Text(video.channelTitle)
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.white.opacity(0.6))
                                                    .lineLimit(1)
                                            }
                                            
                                            Spacer()
                                            
                                            Image(systemName: "play.circle.fill")
                                                .foregroundColor(.pink.opacity(0.9))
                                                .font(.system(size: 22))
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.04),
                                                    Color.cyan.opacity(0.06)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                            
                            Spacer(minLength: 40)
                        }
                        .padding(.top, 14)
                    }
                }
            }
            .navigationTitle(artistName)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.down")
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { Task { await load() } }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.down")
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                ToolbarItem(placement: .automatic) {
                    Button(action: { Task { await load() } }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                #endif
            }
            .task {
                await load()
            }
        }
    }
    
    @MainActor
    private func load() async {
        let key = effectiveYouTubeApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            errorText = "Falta configurar YouTube API Key. Ponla en Xcode: Product → Scheme → Edit Scheme… → Run → Arguments → Environment Variables → YOUTUBE_API_KEY."
            videos = []
            isLoading = false
            return
        }
        
        isLoading = true
        errorText = nil
        do {
            let fetched = try await YouTubeAPI.searchArtistVideos(artist: artistName, apiKey: key)
            videos = fetched
            isLoading = false
        } catch {
            isLoading = false
            errorText = "No se pudo cargar canciones del artista."
        }
    }
    
    private var effectiveYouTubeApiKey: String {
        let env = ProcessInfo.processInfo.environment["YOUTUBE_API_KEY"] ?? ""
        if !env.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return env
        }
        return youtubeApiKey
    }
    
    private func play(_ video: YouTubeVideo) {
        let queue = videos.map { Song(title: $0.title, artist: artistName, artwork: "", youtubeID: $0.youtubeID) }
        let song = Song(title: video.title, artist: artistName, artwork: "", youtubeID: video.youtubeID)
        playerManager.play(song: song, in: queue)
        dismiss()
    }
}

private struct YouTubeVideo: Identifiable {
    var id: String { youtubeID }
    let youtubeID: String
    let title: String
    let channelTitle: String
    let thumbnailURL: String
}

private enum YouTubeAPI {
    static func searchArtistVideos(artist: String, apiKey: String) async throws -> [YouTubeVideo] {
        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/search")
        components?.queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "type", value: "video"),
            URLQueryItem(name: "maxResults", value: "25"),
            URLQueryItem(name: "q", value: "\(artist) kpop official"),
            URLQueryItem(name: "key", value: apiKey)
        ]
        
        guard let url = components?.url else { return [] }
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw URLError(.badServerResponse)
        }
        
        let decoded = try JSONDecoder().decode(YouTubeSearchResponse.self, from: data)
        return decoded.items.compactMap { item in
            guard let videoId = item.id.videoId, !videoId.isEmpty else { return nil }
            let title = item.snippet.title
                .replacingOccurrences(of: "&#39;", with: "'")
                .replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&amp;", with: "&")
            let thumb = item.snippet.thumbnails.high.url
            return YouTubeVideo(
                youtubeID: videoId,
                title: title,
                channelTitle: item.snippet.channelTitle,
                thumbnailURL: thumb
            )
        }
    }
}

private struct YouTubeSearchResponse: Decodable {
    let items: [YouTubeSearchItem]
}

private struct YouTubeSearchItem: Decodable {
    let id: YouTubeSearchID
    let snippet: YouTubeSearchSnippet
}

private struct YouTubeSearchID: Decodable {
    let videoId: String?
}

private struct YouTubeSearchSnippet: Decodable {
    let title: String
    let channelTitle: String
    let thumbnails: YouTubeThumbnails
}

private struct YouTubeThumbnails: Decodable {
    let high: YouTubeThumbnail
}

private struct YouTubeThumbnail: Decodable {
    let url: String
}
