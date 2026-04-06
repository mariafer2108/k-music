import SwiftUI

struct PlaylistAddSongsView: View {
    let playlistID: String
    
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = PlaylistStore.shared
    @ObservedObject private var player = PlayerManager.shared
    @StateObject private var home = HomeViewModel()
    @State private var searchText: String = ""
    
    private var playlist: Playlist? {
        store.playlist(id: playlistID)
    }
    
    private var allCandidates: [Song] {
        var map: [String: Song] = [:]
        
        for s in player.recentlyPlayed { map[s.youtubeID] = s }
        for s in home.recommendations { map[s.youtubeID] = s }
        
        for p in store.playlists {
            for s in p.items { map[s.youtubeID] = s }
        }
        
        return Array(map.values)
            .sorted { a, b in
                a.artist.lowercased() == b.artist.lowercased()
                    ? a.title.lowercased() < b.title.lowercased()
                    : a.artist.lowercased() < b.artist.lowercased()
            }
    }
    
    private var filtered: [Song] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return Array(allCandidates.prefix(50)) }
        return allCandidates.filter { $0.title.lowercased().contains(q) || $0.artist.lowercased().contains(q) }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.purple.opacity(0.45), Color.black, Color.cyan.opacity(0.25)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                List {
                    ForEach(filtered) { song in
                        Button(action: { add(song) }) {
                            HStack(spacing: 12) {
                                AsyncImage(url: URL(string: song.thumbnailURL)) { phase in
                                    switch phase {
                                    case .empty:
                                        ZStack { Color.white.opacity(0.08); ProgressView().tint(.pink) }
                                    case .success(let image):
                                        image.resizable()
                                    case .failure:
                                        ZStack { Color.purple.opacity(0.3); Image(systemName: "music.note").foregroundColor(.white.opacity(0.6)) }
                                    @unknown default:
                                        Color.white.opacity(0.08)
                                    }
                                }
                                .frame(width: 44, height: 44)
                                .cornerRadius(6)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(song.title).foregroundColor(.white).lineLimit(1)
                                    Text(song.artist).foregroundColor(.white.opacity(0.7)).font(.footnote).lineLimit(1)
                                }
                                
                                Spacer()
                                
                                if playlistContains(song) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.pink)
                                } else {
                                    Image(systemName: "plus.circle")
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(KMTheme.indigoDark)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Agregar canciones")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Buscar canción o artista")
            #else
            .searchable(text: $searchText, prompt: "Buscar canción o artista")
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cerrar") { dismiss() }
                        .foregroundColor(.white.opacity(0.9))
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button("Cerrar") { dismiss() }
                        .foregroundColor(.white.opacity(0.9))
                }
                #endif
            }
        }
    }
    
    private func playlistContains(_ song: Song) -> Bool {
        guard let playlist else { return false }
        return playlist.items.contains(where: { $0.youtubeID == song.youtubeID })
    }
    
    private func add(_ song: Song) {
        store.add(song: song, to: playlistID)
    }
}
