import SwiftUI
import Foundation

struct SearchView: View {
    @State private var searchText = ""
    @AppStorage("youtubeApiKey") private var youtubeApiKey: String = ""
    @AppStorage("kmusic_search_history_v1") private var searchHistoryJSON: String = "[]"
    @State private var results: [Song] = []
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var searchTask: Task<Void, Never>?
    @StateObject private var viewModel = HomeViewModel()
    private let playerManager = PlayerManager.shared
    
    var body: some View {
        ZStack {
            KMTheme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Barra de búsqueda
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Artistas, canciones o podcasts", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .foregroundColor(.white)
                        .submitLabel(.search)
                        .onSubmit {
                            commitSearch()
                        }
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(14)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 30) {
                        if searchText.isEmpty {
                            HStack {
                                Text("Historial de búsqueda")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                if !searchHistory.isEmpty {
                                    Button(action: { clearHistory() }) {
                                        Text("Borrar")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.white.opacity(0.75))
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            
                            if searchHistory.isEmpty {
                                Text("Aún no hay búsquedas.")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.6))
                                    .padding(.horizontal, 20)
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(searchHistory, id: \.self) { item in
                                        HStack(spacing: 12) {
                                            Image(systemName: "clock")
                                                .foregroundColor(.white.opacity(0.7))
                                            Text(item)
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                            Spacer()
                                            Button(action: { removeFromHistory(item) }) {
                                                Image(systemName: "xmark")
                                                    .foregroundColor(.white.opacity(0.55))
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .padding(8)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.horizontal, 20)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            searchText = item
                                        }
                                    }
                                }
                            }
                        } else {
                            Text("Mejores resultados")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                            
                            if isLoading {
                                HStack {
                                    ProgressView()
                                        .tint(.pink)
                                    Text("Buscando…")
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                .padding(.horizontal, 20)
                            }
                            
                            if let errorText {
                                Text(errorText)
                                    .font(.footnote)
                                    .foregroundColor(.pink.opacity(0.9))
                                    .padding(.horizontal, 20)
                            }
                            
                            ForEach(results) { song in
                                HStack(spacing: 16) {
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
                                                    .foregroundColor(.white.opacity(0.6))
                                            }
                                        @unknown default:
                                            Color.white.opacity(0.08)
                                        }
                                    }
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 56, height: 56)
                                    .cornerRadius(6)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(song.title)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                        Text(song.artist)
                                            .font(.system(size: 14))
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    playerManager.play(song: song, in: results)
                                }
                            }
                        }
                        
                        Spacer(minLength: 150)
                    }
                    .padding(.top, 20)
                }
            }
        }
        .onAppear {
            if results.isEmpty && !searchText.isEmpty {
                refreshResults()
            }
        }
        .onChange(of: searchText) { refreshResults() }
        .onChange(of: youtubeApiKey) { refreshResults() }
    }
    
    private func refreshResults() {
        errorText = nil
        
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            results = []
            isLoading = false
            searchTask?.cancel()
            searchTask = nil
            return
        }
        
        let apiKey = effectiveYouTubeApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if apiKey.isEmpty {
            results = localResults(for: query)
            isLoading = false
            searchTask?.cancel()
            searchTask = nil
            return
        }
        
        searchTask?.cancel()
        searchTask = Task { [query, apiKey] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            if Task.isCancelled { return }
            await MainActor.run {
                isLoading = true
            }
            do {
                let fetched = try await searchYouTube(query: query, apiKey: apiKey)
                if Task.isCancelled { return }
                await MainActor.run {
                    results = fetched
                    isLoading = false
                }
            } catch {
                if Task.isCancelled { return }
                await MainActor.run {
                    results = localResults(for: query)
                    isLoading = false
                    errorText = "YouTube no respondió. Mostrando resultados locales."
                }
            }
        }
    }
    
    private var searchHistory: [String] {
        guard let data = searchHistoryJSON.data(using: .utf8),
              let items = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return items
    }
    
    private func commitSearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        addToHistory(query)
        refreshResults()
    }
    
    private func addToHistory(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        var items = searchHistory
        items.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        items.insert(trimmed, at: 0)
        if items.count > 30 { items = Array(items.prefix(30)) }
        
        if let data = try? JSONEncoder().encode(items),
           let json = String(data: data, encoding: .utf8) {
            searchHistoryJSON = json
        }
    }
    
    private func removeFromHistory(_ item: String) {
        var items = searchHistory
        items.removeAll { $0 == item }
        if let data = try? JSONEncoder().encode(items),
           let json = String(data: data, encoding: .utf8) {
            searchHistoryJSON = json
        }
    }
    
    private func clearHistory() {
        searchHistoryJSON = "[]"
    }
    
    private var effectiveYouTubeApiKey: String {
        let env = ProcessInfo.processInfo.environment["YOUTUBE_API_KEY"] ?? ""
        if !env.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return env
        }
        return youtubeApiKey
    }
    
    private func localResults(for query: String) -> [Song] {
        let allSongs = playerManager.recentlyPlayed + viewModel.recommendations
        let lower = query.lowercased()
        return allSongs.filter {
            $0.title.lowercased().contains(lower) || $0.artist.lowercased().contains(lower)
        }
    }
    
    private func searchYouTube(query: String, apiKey: String) async throws -> [Song] {
        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/search")
        components?.queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "type", value: "video"),
            URLQueryItem(name: "maxResults", value: "25"),
            URLQueryItem(name: "q", value: "\(query) kpop"),
            URLQueryItem(name: "key", value: apiKey)
        ]
        
        guard let url = components?.url else { return [] }
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw URLError(.badServerResponse)
        }
        
        let decoded = try JSONDecoder().decode(YouTubeSearchResponse.self, from: data)
        let songs: [Song] = decoded.items.compactMap { item in
            guard let videoId = item.id.videoId, !videoId.isEmpty else { return nil }
            let title = item.snippet.title
                .replacingOccurrences(of: "&#39;", with: "'")
                .replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&amp;", with: "&")
            return Song(title: title, artist: item.snippet.channelTitle, artwork: "", youtubeID: videoId)
        }
        
        var seen = Set<String>()
        return songs.filter { song in
            if seen.contains(song.youtubeID) { return false }
            seen.insert(song.youtubeID)
            return true
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
}

struct CategoryTile: View {
    let title: String
    let color: Color
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            color.opacity(0.8)
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(12)
        }
        .frame(height: 100)
        .cornerRadius(8)
    }
}
