import Foundation
import SwiftUI
import Combine

class HomeViewModel: ObservableObject {
    @Published var aiBandRecommendations: [String] = []
    @Published var aiIsLoading: Bool = false
    @Published var aiErrorMessage: String?
    
    @Published var recommendations: [Song] = [
        // FIFTY FIFTY
        Song(title: "Cupid", artist: "FIFTY FIFTY", artwork: "fifty_cupid", youtubeID: "Qc7_zRjH808"), // Versión Twin Ver. que suele ser más permisiva
        
        // JISOO (Solo)
        Song(title: "FLOWER", artist: "JISOO", artwork: "jisoo_flower", youtubeID: "YudHcBIxlYw"),
        
        // Jung Kook (Solo)
        Song(title: "Seven", artist: "Jung Kook", artwork: "jk_seven", youtubeID: "QU9c0053UAU"),
        
        // Jimin (Solo)
        Song(title: "Like Crazy", artist: "Jimin", artwork: "jimin_likecrazy", youtubeID: "n9m66P_L698"),
        
        // SEVENTEEN
        Song(title: "Super", artist: "SEVENTEEN", artwork: "svt_super", youtubeID: "wkRAt8Z9Ghw"),
        Song(title: "Hot", artist: "SEVENTEEN", artwork: "svt_hot", youtubeID: "gRnuFC4Ualw"),
        
        // aespa
        Song(title: "Spicy", artist: "aespa", artwork: "aespa_spicy", youtubeID: "Os_heh8vPfs"),
        Song(title: "Next Level", artist: "aespa", artwork: "aespa_nextlevel", youtubeID: "4TWR90KJl84"),
        
        // TXT
        Song(title: "Sugar Rush Ride", artist: "TXT", artwork: "txt_sugarrush", youtubeID: "P9tKTxbgdkk"),
        
        // ITZY
        Song(title: "WANNABE", artist: "ITZY", artwork: "itzy_wannabe", youtubeID: "fE2h3lGlOsk"),
        Song(title: "LOCO", artist: "ITZY", artwork: "itzy_loco", youtubeID: "vLYS6qG7Nsc")
    ]
    
    @MainActor
    func refreshAIBandRecommendations(recentlyPlayed: [Song], likedSongIDs: Set<String>) async {
        aiIsLoading = true
        aiErrorMessage = nil
        
        do {
            let bands = try await DeepSeekRecommender.fetchBands(recentlyPlayed: recentlyPlayed, likedSongIDs: likedSongIDs)
            aiBandRecommendations = bands
            aiIsLoading = false
        } catch {
            aiIsLoading = false
            if DeepSeekRecommender.shouldFallbackToLocal(error) {
                aiBandRecommendations = LocalBandRecommender.recommend(recentlyPlayed: recentlyPlayed)
                aiErrorMessage = "Recomendaciones locales."
            } else {
                aiBandRecommendations = LocalBandRecommender.recommend(recentlyPlayed: recentlyPlayed)
                aiErrorMessage = "No se pudo usar DeepSeek. Mostrando recomendaciones locales."
            }
        }
    }
}

private enum DeepSeekRecommender {
    private static let endpoint = URL(string: "https://api.deepseek.com/v1/chat/completions")!
    
    static func fetchBands(recentlyPlayed: [Song], likedSongIDs: Set<String>) async throws -> [String] {
        let apiKey = deepSeekAPIKey()
        guard !apiKey.isEmpty else { throw DeepSeekError.missingAPIKey }
        
        let lastArtists = Array(LinkedHashSet(recentlyPlayed.map { $0.artist })).prefix(8)
        let lastTitles = recentlyPlayed.prefix(8).map { "\($0.artist) — \($0.title)" }
        let likedCount = likedSongIDs.count
        
        let system = """
        Eres un recomendador experto de K-Pop. Recomiendas BANDAS/GRUPOS (no canciones) y adaptas al gusto del usuario.
        Responde SOLO como JSON válido con esta forma:
        {"bands":["Banda 1","Banda 2","Banda 3","Banda 4","Banda 5","Banda 6"]}
        """
        
        let user = """
        Historial reciente (máximo 8):
        \(lastTitles.joined(separator: "\n"))
        
        Artistas recientes:
        \(lastArtists.joined(separator: ", "))
        
        Cantidad de likes: \(likedCount)
        
        Devuelve 6 bandas de K-Pop recomendadas. Evita repetir bandas ya presentes en los artistas recientes.
        """
        
        let body = DeepSeekChatRequest(
            model: "deepseek-chat",
            messages: [
                DeepSeekMessage(role: "system", content: system),
                DeepSeekMessage(role: "user", content: user)
            ],
            stream: false,
            temperature: 0.7,
            max_tokens: 300
        )
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw DeepSeekError.badResponse }
        guard http.statusCode == 200 else {
            let bodySnippet = String(data: data, encoding: .utf8)
                .map { String($0.prefix(300)) }
            throw DeepSeekError.http(http.statusCode, body: bodySnippet)
        }
        
        let decoded = try JSONDecoder().decode(DeepSeekChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content, !content.isEmpty else {
            throw DeepSeekError.empty
        }
        
        if let jsonData = content.data(using: .utf8),
           let parsed = try? JSONDecoder().decode(DeepSeekBandsJSON.self, from: jsonData),
           !parsed.bands.isEmpty {
            return sanitizeBands(parsed.bands)
        }
        
        return sanitizeBands(parseBandsFallback(from: content))
    }
    
    static func shouldFallbackToLocal(_ error: Error) -> Bool {
        if let ds = error as? DeepSeekError {
            switch ds {
            case .missingAPIKey:
                return true
            case .http(let code, _):
                return code == 402
            case .badResponse, .empty:
                return false
            }
        }
        return false
    }
    
    private static func deepSeekAPIKey() -> String {
        if let env = ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"], !env.isEmpty {
            return env
        }
        if let stored = UserDefaults.standard.string(forKey: "deepseekApiKey"), !stored.isEmpty {
            return stored
        }
        return ""
    }
    
    private static func sanitizeBands(_ raw: [String]) -> [String] {
        var seen = Set<String>()
        return raw
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { band in
                let key = band.lowercased()
                if seen.contains(key) { return false }
                seen.insert(key)
                return true
            }
            .prefix(12)
            .map { String($0) }
    }
    
    private static func parseBandsFallback(from content: String) -> [String] {
        let lines = content
            .split(whereSeparator: \.isNewline)
            .map { String($0) }
        let candidates = lines.map { line -> String in
            var v = line
            if v.hasPrefix("-") { v.removeFirst() }
            if v.hasPrefix("•") { v.removeFirst() }
            return v.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return candidates.filter { !$0.isEmpty }
    }
    
    private struct LinkedHashSet<Element: Hashable>: Sequence {
        private var set = Set<Element>()
        private var array: [Element] = []
        
        init(_ elements: [Element]) {
            for e in elements {
                if set.insert(e).inserted {
                    array.append(e)
                }
            }
        }
        
        func makeIterator() -> Array<Element>.Iterator { array.makeIterator() }
    }
    
    static func userFacingError(_ error: Error) -> String {
        if let ds = error as? DeepSeekError {
            switch ds {
            case .missingAPIKey:
                return "No detecté DEEPSEEK_API_KEY en Xcode → Product → Scheme → Edit Scheme… → Run → Arguments → Environment Variables."
            case .badResponse:
                return "DeepSeek devolvió una respuesta inválida."
            case .empty:
                return "DeepSeek respondió vacío. Intenta de nuevo."
            case .http(let code, let body):
                if code == 401 {
                    return "DeepSeek: API Key inválida o no autorizada (401)."
                }
                if code == 402 {
                    return "DeepSeek: sin saldo/créditos o requiere facturación (402)."
                }
                if code == 429 {
                    return "DeepSeek: demasiadas solicitudes (429). Intenta en unos segundos."
                }
                if let body, !body.isEmpty {
                    return "DeepSeek error HTTP \(code)."
                }
                return "DeepSeek error HTTP \(code)."
            }
        }
        
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return "Sin internet. Conéctate y vuelve a intentar."
            case .timedOut:
                return "La solicitud a DeepSeek tardó demasiado. Intenta de nuevo."
            default:
                return "Error de red: \(urlError.localizedDescription)"
            }
        }
        
        return "No se pudo generar recomendaciones con IA."
    }
}

private enum LocalBandRecommender {
    private struct Band {
        let name: String
        let tags: Set<String>
        let base: Double
    }
    
    private static let catalog: [Band] = [
        Band(name: "BTS", tags: ["boy", "global", "pop"], base: 2.0),
        Band(name: "BLACKPINK", tags: ["girl", "global", "pop"], base: 2.0),
        Band(name: "TWICE", tags: ["girl", "pop"], base: 1.8),
        Band(name: "Stray Kids", tags: ["boy", "performance", "edm"], base: 1.8),
        Band(name: "SEVENTEEN", tags: ["boy", "performance", "pop"], base: 1.8),
        Band(name: "NewJeans", tags: ["girl", "new", "chill"], base: 1.9),
        Band(name: "LE SSERAFIM", tags: ["girl", "performance", "new"], base: 1.8),
        Band(name: "IVE", tags: ["girl", "pop", "new"], base: 1.7),
        Band(name: "aespa", tags: ["girl", "edm", "new"], base: 1.7),
        Band(name: "(G)I-DLE", tags: ["girl", "bold", "pop"], base: 1.6),
        Band(name: "ITZY", tags: ["girl", "performance"], base: 1.6),
        Band(name: "TXT", tags: ["boy", "pop", "new"], base: 1.6),
        Band(name: "ENHYPEN", tags: ["boy", "pop", "new"], base: 1.6),
        Band(name: "NCT 127", tags: ["boy", "edm", "performance"], base: 1.5),
        Band(name: "NCT DREAM", tags: ["boy", "pop"], base: 1.5),
        Band(name: "EXO", tags: ["boy", "vocal", "pop"], base: 1.5),
        Band(name: "Red Velvet", tags: ["girl", "vocal", "pop"], base: 1.5),
        Band(name: "MAMAMOO", tags: ["girl", "vocal"], base: 1.4),
        Band(name: "ATEEZ", tags: ["boy", "performance", "edm"], base: 1.5),
        Band(name: "SHINee", tags: ["boy", "vocal", "pop"], base: 1.4),
        Band(name: "IU", tags: ["solo", "vocal", "chill"], base: 1.5),
        Band(name: "Taeyeon", tags: ["solo", "vocal"], base: 1.4),
        Band(name: "Jung Kook", tags: ["solo", "pop"], base: 1.4),
        Band(name: "Jimin", tags: ["solo", "pop"], base: 1.3),
        Band(name: "JISOO", tags: ["solo", "pop"], base: 1.3),
        Band(name: "Lisa", tags: ["solo", "pop"], base: 1.3),
        Band(name: "ROSÉ", tags: ["solo", "vocal"], base: 1.2),
        Band(name: "STAYC", tags: ["girl", "pop", "new"], base: 1.3),
        Band(name: "KISS OF LIFE", tags: ["girl", "new", "bold"], base: 1.2),
        Band(name: "ILLIT", tags: ["girl", "new", "chill"], base: 1.2),
        Band(name: "BABYMONSTER", tags: ["girl", "new", "performance"], base: 1.2),
        Band(name: "RIIZE", tags: ["boy", "new", "pop"], base: 1.2),
        Band(name: "ZEROBASONE", tags: ["boy", "new", "pop"], base: 1.2),
        Band(name: "IVE", tags: ["girl", "pop", "new"], base: 1.0)
    ]
    
    static func recommend(recentlyPlayed: [Song]) -> [String] {
        let recentArtists = Set(recentlyPlayed.map { normalize($0.artist) })
        let taste = buildTaste(from: recentlyPlayed)
        
        let ranked = catalog
            .filter { !recentArtists.contains(normalize($0.name)) }
            .map { band -> (String, Double) in
                let score = band.base + overlapScore(tags: band.tags, taste: taste)
                return (band.name, score)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(8)
            .map { $0.0 }
        
        if ranked.isEmpty {
            return ["BTS", "BLACKPINK", "TWICE", "SEVENTEEN", "Stray Kids", "NewJeans"]
        }
        return Array(ranked)
    }
    
    private static func buildTaste(from recentlyPlayed: [Song]) -> [String: Int] {
        var counts: [String: Int] = [:]
        let artistNames = recentlyPlayed.map { normalize($0.artist) }
        
        for a in artistNames {
            for band in catalog {
                if normalize(band.name) == a {
                    for t in band.tags {
                        counts[t, default: 0] += 2
                    }
                }
            }
        }
        
        if counts.isEmpty {
            counts["pop", default: 0] += 1
            counts["new", default: 0] += 1
        }
        
        return counts
    }
    
    private static func overlapScore(tags: Set<String>, taste: [String: Int]) -> Double {
        var score: Double = 0
        for t in tags {
            if let v = taste[t] {
                score += Double(v) * 0.25
            }
        }
        return score
    }
    
    private static func normalize(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

private struct DeepSeekChatRequest: Encodable {
    let model: String
    let messages: [DeepSeekMessage]
    let stream: Bool
    let temperature: Double
    let max_tokens: Int
}

private struct DeepSeekMessage: Codable {
    let role: String
    let content: String
}

private struct DeepSeekChatResponse: Decodable {
    let choices: [DeepSeekChoice]
}

private struct DeepSeekChoice: Decodable {
    let message: DeepSeekMessage
}

private struct DeepSeekBandsJSON: Decodable {
    let bands: [String]
}

private enum DeepSeekError: Error, Equatable {
    case missingAPIKey
    case badResponse
    case http(Int, body: String?)
    case empty
}
