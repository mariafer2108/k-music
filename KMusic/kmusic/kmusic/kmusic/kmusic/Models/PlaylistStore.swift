import Foundation
import SwiftUI
import Combine

struct Playlist: Identifiable, Codable {
    let id: String
    var name: String
    var items: [Song]
}

class PlaylistStore: ObservableObject {
    static let shared = PlaylistStore()
    @Published var playlists: [Playlist] = []
    private let key = "kmusic.playlists"
    
    private init() {
        load()
    }
    
    func createPlaylist(name: String) {
        let p = Playlist(id: UUID().uuidString, name: name, items: [])
        playlists.insert(p, at: 0)
        save()
    }
    
    func deletePlaylist(id: String) {
        playlists.removeAll { $0.id == id }
        save()
    }
    
    func renamePlaylist(id: String, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let idx = playlists.firstIndex(where: { $0.id == id }) else { return }
        playlists[idx].name = trimmed
        save()
    }
    
    func playlist(id: String) -> Playlist? {
        playlists.first(where: { $0.id == id })
    }
    
    func add(song: Song, to playlistID: String) {
        guard let idx = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        if !playlists[idx].items.contains(where: { $0.youtubeID == song.youtubeID }) {
            playlists[idx].items.append(song)
            save()
        }
    }
    
    func remove(songID: String, from playlistID: String) {
        guard let idx = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        playlists[idx].items.removeAll { $0.youtubeID == songID }
        save()
    }
    
    func moveItem(from offsets: IndexSet, to toIndex: Int, in playlistID: String) {
        guard let idx = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        playlists[idx].items.move(fromOffsets: offsets, toOffset: toIndex)
        save()
    }
    
    func moveSong(in playlistID: String, from fromIndex: Int, to toIndex: Int) {
        guard let idx = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        guard playlists[idx].items.indices.contains(fromIndex) else { return }
        let boundedTo = max(0, min(toIndex, playlists[idx].items.count - 1))
        if fromIndex == boundedTo { return }
        let item = playlists[idx].items.remove(at: fromIndex)
        playlists[idx].items.insert(item, at: boundedTo)
        save()
    }
    
    func likedPlaylist(recent: [Song], recs: [Song], likedIDs: Set<String>) -> Playlist {
        var map: [String: Song] = [:]
        for s in recent { map[s.youtubeID] = s }
        for s in recs { map[s.youtubeID] = s }
        let recentOrder = recent.map { $0.youtubeID }
        let items = likedIDs
            .compactMap { map[$0] }
            .sorted { a, b in
                let ia = recentOrder.firstIndex(of: a.youtubeID) ?? Int.max
                let ib = recentOrder.firstIndex(of: b.youtubeID) ?? Int.max
                return ia < ib
            }
        return Playlist(id: "liked", name: "Me gusta", items: items)
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(playlists) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Playlist].self, from: data) {
            playlists = decoded
        }
    }
}
