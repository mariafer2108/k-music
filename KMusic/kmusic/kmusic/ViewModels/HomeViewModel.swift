import SwiftUI
import Combine

class HomeViewModel: ObservableObject {
    @Published var recentlyPlayed: [Song] = [
        Song(title: "Dynamite", artist: "BTS", artwork: "artwork-1", youtubeID: "gdZLi9jhHGs"),
        Song(title: "How You Like That", artist: "BLACKPINK", artwork: "artwork-2", youtubeID: "ioNng23DkIM"),
        Song(title: "OMG", artist: "NewJeans", artwork: "artwork-3", youtubeID: "_ZAgIHmHLdc")
    ]
    
    @Published var recommendations: [Song] = [
        Song(title: "Talk that Talk", artist: "TWICE", artwork: "rec-1", youtubeID: "k6JQ7qN8Vat"),
        Song(title: "MANIAC", artist: "Stray Kids", artwork: "rec-2", youtubeID: "Ovi_uTgU8ZE"),
        Song(title: "LOVE DIVE", artist: "IVE", artwork: "rec-3", youtubeID: "Y8JFxS1HlDo")
    ]
}
