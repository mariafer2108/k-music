import Foundation

struct Song: Identifiable {
    let id = UUID()
    let title: String
    let artist: String
    let artwork: String
    let youtubeID: String
}
