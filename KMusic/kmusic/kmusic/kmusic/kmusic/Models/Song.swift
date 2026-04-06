import Foundation

struct Song: Identifiable, Codable {
    var id: String { youtubeID }
    let title: String
    let artist: String
    let artwork: String
    let youtubeID: String
    
    var thumbnailURL: String {
        "https://img.youtube.com/vi/\(youtubeID)/hqdefault.jpg"
    }
}
