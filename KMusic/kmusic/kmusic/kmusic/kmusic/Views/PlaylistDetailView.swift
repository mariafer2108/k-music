import SwiftUI

struct PlaylistDetailView: View {
    let playlistID: String
    @ObservedObject private var store = PlaylistStore.shared
    @ObservedObject private var player = PlayerManager.shared
    @StateObject private var home = HomeViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showingAdd = false
    @State private var showingRename = false
    @State private var renameText = ""
    @State private var showingDelete = false
    @State private var isEditing = false
    
    var body: some View {
        ZStack {
            KMTheme.background.ignoresSafeArea()
            content
        }
    }
    
    @ViewBuilder
    private var content: some View {
        if playlistID == "liked" {
            likedContent
        } else if let playlist = store.playlist(id: playlistID) {
            playlistContent(playlist)
        } else {
            Text("Lista no encontrada")
                .foregroundColor(.white.opacity(0.85))
        }
    }
    
    private var likedContent: some View {
        let liked = store.likedPlaylist(recent: player.recentlyPlayed, recs: home.recommendations, likedIDs: player.likedSongs)
        return List {
            if !liked.items.isEmpty {
                Section {
                    HStack(spacing: 12) {
                        Button(action: { playAll(liked.items, shuffle: false) }) {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                Text("Reproducir")
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)
                            .background(Color.pink.opacity(0.75))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { playAll(liked.items, shuffle: true) }) {
                            HStack(spacing: 8) {
                                Image(systemName: "shuffle")
                                Text("Aleatorio")
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)
                            .background(Color.white.opacity(0.10))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(KMTheme.indigoDark)
            }
            
            if liked.items.isEmpty {
                Text("Aún no tienes canciones con Me gusta.")
                    .foregroundColor(.white.opacity(0.7))
                    .listRowBackground(KMTheme.indigoDark)
            } else {
                ForEach(liked.items) { song in
                    PlaylistSongRow(song: song)
                        .listRowBackground(KMTheme.indigoDark)
                        .contentShape(Rectangle())
                        .onTapGesture { player.play(song: song, in: liked.items) }
                }
                #if os(iOS)
                .onDelete { idx in
                    for i in idx {
                        let id = liked.items[i].youtubeID
                        player.toggleLike(songID: id)
                    }
                }
                #endif
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .navigationTitle(liked.name)
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
            #else
            ToolbarItem(placement: .automatic) {
                Button(isEditing ? "Listo" : "Editar") { isEditing.toggle() }
            }
            #endif
        }
    }
    
    private func playlistContent(_ playlist: Playlist) -> some View {
        List {
            if !playlist.items.isEmpty {
                Section {
                    HStack(spacing: 12) {
                        Button(action: { playAll(playlist.items, shuffle: false) }) {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                Text("Reproducir")
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)
                            .background(Color.pink.opacity(0.75))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { playAll(playlist.items, shuffle: true) }) {
                            HStack(spacing: 8) {
                                Image(systemName: "shuffle")
                                Text("Aleatorio")
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)
                            .background(Color.white.opacity(0.10))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(KMTheme.indigoDark)
            }
            
            if playlist.items.isEmpty {
                Text("Lista vacía. Toca “+” para agregar canciones.")
                    .foregroundColor(.white.opacity(0.7))
                    .listRowBackground(KMTheme.indigoDark)
            } else {
                ForEach(Array(playlist.items.enumerated()), id: \.element.id) { index, song in
                    HStack(spacing: 12) {
                        PlaylistSongRow(song: song)
                        if isEditing {
                            HStack(spacing: 10) {
                                Button(action: { store.moveSong(in: playlist.id, from: index, to: index - 1) }) {
                                    Image(systemName: "chevron.up")
                                        .foregroundColor(.white.opacity(0.85))
                                }
                                .buttonStyle(.plain)
                                .disabled(index == 0)
                                
                                Button(action: { store.moveSong(in: playlist.id, from: index, to: index + 1) }) {
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.white.opacity(0.85))
                                }
                                .buttonStyle(.plain)
                                .disabled(index >= playlist.items.count - 1)
                                
                                Button(role: .destructive, action: { store.remove(songID: song.youtubeID, from: playlist.id) }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.pink.opacity(0.9))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .listRowBackground(KMTheme.indigoDark)
                    .contentShape(Rectangle())
                    .onTapGesture { player.play(song: song, in: playlist.items) }
                }
                #if os(iOS)
                .onDelete { idx in
                    for i in idx {
                        let id = playlist.items[i].youtubeID
                        store.remove(songID: id, from: playlist.id)
                    }
                }
                .onMove { s, d in
                    store.moveItem(from: s, to: d, in: playlist.id)
                }
                #endif
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .navigationTitle(playlist.name)
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .topBarLeading) { EditButton() }
            ToolbarItem(placement: .topBarTrailing) { trailingActions(playlist) }
            #else
            ToolbarItem(placement: .automatic) {
                Button(isEditing ? "Listo" : "Editar") { isEditing.toggle() }
            }
            ToolbarItem(placement: .automatic) { trailingActions(playlist) }
            #endif
        }
        .sheet(isPresented: $showingAdd) {
            PlaylistAddSongsView(playlistID: playlist.id)
        }
        .alert("Renombrar lista", isPresented: $showingRename) {
            TextField("Nombre", text: $renameText)
            Button("Cancelar", role: .cancel) {}
            Button("Guardar") {
                store.renamePlaylist(id: playlist.id, name: renameText)
            }
        }
        .alert("Eliminar lista", isPresented: $showingDelete) {
            Button("Cancelar", role: .cancel) {}
            Button("Eliminar", role: .destructive) {
                store.deletePlaylist(id: playlist.id)
                dismiss()
            }
        } message: {
            Text("Se eliminará la lista y sus canciones guardadas.")
        }
    }
    
    private func playAll(_ items: [Song], shuffle: Bool) {
        guard !items.isEmpty else { return }
        var queue = items
        if shuffle {
            queue.shuffle()
            player.isShuffleEnabled = true
        } else {
            player.isShuffleEnabled = false
        }
        player.play(song: queue[0], in: queue)
        player.showFullPlayer = true
    }
    
    private func trailingActions(_ playlist: Playlist) -> some View {
        HStack(spacing: 14) {
            Button(action: {
                showingAdd = true
            }) {
                Image(systemName: "plus")
                    .foregroundColor(.pink)
            }
            
            Menu {
                Button("Renombrar") {
                    renameText = playlist.name
                    showingRename = true
                }
                Button("Eliminar lista", role: .destructive) {
                    showingDelete = true
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.white.opacity(0.85))
            }
        }
    }
}

private struct PlaylistSongRow: View {
    let song: Song
    
    var body: some View {
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
            .frame(width: 56, height: 56)
            .cornerRadius(6)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title).foregroundColor(.white)
                Text(song.artist).foregroundColor(.white.opacity(0.7)).font(.subheadline)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
