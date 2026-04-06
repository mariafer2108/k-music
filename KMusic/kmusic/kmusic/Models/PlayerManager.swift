import Foundation
import Combine

class PlayerManager: ObservableObject {
    static let shared = PlayerManager()
    
    @Published var currentSong: Song?
    @Published var isPlaying: Bool = false
    @Published var showFullPlayer: Bool = false
    
    private init() {}
    
    func play(song: Song) {
        self.currentSong = song
        self.isPlaying = true
    }
    
    func togglePlayPause() {
        isPlaying.toggle()
    }
}
