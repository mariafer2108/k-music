import SwiftUI

struct LibraryView: View {
    private let playerManager = PlayerManager.shared
    @StateObject private var viewModel = HomeViewModel()
    @ObservedObject private var playlistStore = PlaylistStore.shared
    @State private var likedSongIDs: Set<String> = PlayerManager.shared.likedSongs
    @State private var recentlyPlayed: [Song] = PlayerManager.shared.recentlyPlayed
    @State private var showingCreate = false
    @State private var newName = ""
    
    private var likedPlaylist: Playlist {
        playlistStore.likedPlaylist(recent: recentlyPlayed, recs: viewModel.recommendations, likedIDs: likedSongIDs)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                KMTheme.background.ignoresSafeArea()
                
                List {
                    Section {
                        NavigationLink(destination: PlaylistDetailView(playlistID: likedPlaylist.id)) {
                            HStack(spacing: 12) {
                                Image(systemName: "heart.fill")
                                    .foregroundColor(.pink)
                                Text(likedPlaylist.name)
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(likedPlaylist.items.count)")
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding(.vertical, 6)
                        }
                        .listRowBackground(KMTheme.indigoDark)
                    }
                    
                    Section {
                        ForEach(playlistStore.playlists) { p in
                            NavigationLink(destination: PlaylistDetailView(playlistID: p.id)) {
                                HStack(spacing: 12) {
                                    Image(systemName: "music.note.list")
                                        .foregroundColor(.purple)
                                    Text(p.name)
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("\(p.items.count)")
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                .padding(.vertical, 6)
                            }
                            .listRowBackground(KMTheme.indigoDark)
                        }
                        .onDelete { idx in
                            for i in idx {
                                let id = playlistStore.playlists[i].id
                                playlistStore.deletePlaylist(id: id)
                            }
                        }
                    } header: {
                        Text("Listas de reproducción")
                            .foregroundColor(.white.opacity(0.75))
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Tu Biblioteca")
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingCreate = true }) {
                        Image(systemName: "plus")
                            .foregroundColor(.pink)
                    }
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button(action: { showingCreate = true }) {
                        Image(systemName: "plus")
                            .foregroundColor(.pink)
                    }
                }
                #endif
            }
            .sheet(isPresented: $showingCreate) {
                ZStack {
                    LinearGradient(
                        colors: [Color.purple.opacity(0.5), Color.black, Color.cyan.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        Text("Nueva lista").foregroundColor(.white).font(.headline)
                        TextField("Nombre", text: $newName)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal, 20)
                        
                        HStack {
                            Button("Cancelar") { showingCreate = false }
                                .foregroundColor(.white.opacity(0.85))
                            Spacer()
                            Button("Crear") {
                                let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !name.isEmpty {
                                    playlistStore.createPlaylist(name: name)
                                }
                                newName = ""
                                showingCreate = false
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 18)
                            .background(
                                LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .cornerRadius(10)
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding()
                }
            }
        }
        .onReceive(playerManager.$likedSongs) { newValue in
            likedSongIDs = newValue
        }
        .onReceive(playerManager.$recentlyPlayed) { newValue in
            recentlyPlayed = newValue
        }
    }
}
