import Foundation
import Combine
import SwiftUI
#if os(iOS)
import AVFoundation
import MediaPlayer
import UIKit
#endif

class PlayerManager: ObservableObject {
    static let shared = PlayerManager()
    
    enum RepeatMode: Int, CaseIterable, Codable {
        case off = 0
        case all = 1
        case one = 2
    }
    
    @Published var currentSong: Song? {
        didSet {
            updateNowPlaying()
        }
    }
    @Published var isPlaying: Bool = false {
        didSet {
            if isPlaying {
                startTimer()
                setupAudioSession()
            } else {
                stopTimer()
            }
            updateNowPlayingPlaybackState()
        }
    }
    @Published var showFullPlayer: Bool = false
    @Published var selectedTab: Int = 0
    @Published var likedSongs: Set<String> = []
    @Published var recentlyPlayed: [Song] = []
    @Published var isShuffleEnabled: Bool = false
    @Published var repeatMode: RepeatMode = .off
    @Published private(set) var playbackQueue: [Song] = []
    @Published private(set) var currentQueueIndex: Int = 0
    private var shuffleHistory: [Int] = []
    
    // Posición dinámica del video para sincronización perfecta
    @Published var videoCenter: CGPoint = .zero
    @Published var videoSize: CGSize = .zero
    
    // Progreso de la canción
    @Published var currentTime: Double = 0 {
        didSet {
            if Int(currentTime) % 5 == 0 { // Actualizar cada 5 segundos para no saturar
                updateNowPlaying()
            }
        }
    }
    @Published var isAdPlaying: Bool = false
    @Published var seekRequestID: Int = 0
    @Published var seekRequestTime: Double = 0
    @Published var playbackCommandID: Int = 0
    @Published var playbackCommandPlay: Bool = false
    @Published var totalTime: Double = 210 // 3:30 por defecto
    @Published var volume: Double = 0.8 // Volumen de 0.0 a 1.0
    @Published var webIsPaused: Bool = true
    @Published var webIsBuffering: Bool = false
    private var timer: Timer?
#if os(iOS)
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
#endif
    private var lastWebTimeUpdateAt: CFAbsoluteTime = 0
    private var lastUserPlaybackToggleAt: CFAbsoluteTime = 0
    
    private init() {
        loadLikedSongs()
        loadRecentlyPlayed()
        setupAudioSession()
        setupRemoteCommandCenter()
        setupNotificationObservers()
    }

    private func setupAudioSession() {
#if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true, options: [])
        } catch {
            print("Error al configurar AVAudioSession: \(error)")
        }
#else
        return
#endif
    }
    
    private func setupNotificationObservers() {
#if os(iOS)
        // Observamos cambios de interrupción de audio (llamadas, alarmas)
        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
            
            if type == .began {
                self?.isPlaying = false
            } else if type == .ended {
                if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume) {
                        self?.isPlaying = true
                    }
                }
            }
        }
        
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            if self.isPlaying {
                self.setupAudioSession()
            }
        }
        
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            if self.isPlaying {
                self.setupAudioSession()
            }
        }
#endif
    }
    
    private func startBackgroundTask() {}
    private func stopBackgroundTask() {}
    
    private func setupRemoteCommandCenter() {
#if os(iOS)
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [unowned self] event in
            if !self.isPlaying {
                self.togglePlayPause()
                return .success
            }
            return .commandFailed
        }
        
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [unowned self] event in
            if self.isPlaying {
                self.togglePlayPause()
                return .success
            }
            return .commandFailed
        }
        
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [unowned self] _ in
            self.nextTrack()
            return .success
        }
        
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [unowned self] _ in
            self.previousTrack()
            return .success
        }
        
        // Comando para buscar (seek) desde el centro de control
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [unowned self] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                self.currentTime = event.positionTime
                return .success
            }
            return .commandFailed
        }
#endif
    }
    
    private func updateNowPlaying() {
#if os(iOS)
        guard let song = currentSong else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = song.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = song.artist
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = totalTime
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        if !song.artwork.isEmpty, let image = UIImage(named: song.artwork) {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { size in
                return image
            }
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
#else
        return
#endif
    }
    
    private func updateNowPlayingPlaybackState() {
#if os(iOS)
        if var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo {
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        }
#else
        return
#endif
    }
    
    func play(song: Song) {
        play(song: song, in: playbackQueue.isEmpty ? [song] : playbackQueue)
    }
    
    func togglePlayPause() {
        lastUserPlaybackToggleAt = CFAbsoluteTimeGetCurrent()
        let desiredPlay = webIsPaused
        isPlaying = desiredPlay
        playbackCommandPlay = desiredPlay
        playbackCommandID += 1
    }
    
    func requestSeek(to time: Double) {
        seekRequestTime = time
        seekRequestID += 1
        currentTime = time
        updateNowPlaying()
    }
    
    
    func play(song: Song, in queue: [Song]) {
        playbackQueue = queue
        if let index = queue.firstIndex(where: { $0.youtubeID == song.youtubeID }) {
            currentQueueIndex = index
        } else {
            playbackQueue = [song]
            currentQueueIndex = 0
        }
        
        shuffleHistory.removeAll()
        setSong(at: currentQueueIndex)
        
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .phone {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showFullPlayer = true
            }
        }
        #endif
    }
    
    func toggleShuffle() {
        isShuffleEnabled.toggle()
        shuffleHistory.removeAll()
    }
    
    func cycleRepeatMode() {
        let all = RepeatMode.allCases
        if let idx = all.firstIndex(of: repeatMode) {
            repeatMode = all[(idx + 1) % all.count]
        } else {
            repeatMode = .off
        }
    }
    
    func nextTrack() {
        guard !playbackQueue.isEmpty else { return }
        
        if repeatMode == .one {
            requestSeek(to: 0)
            isPlaying = true
            return
        }
        
        if isShuffleEnabled, playbackQueue.count > 1 {
            shuffleHistory.append(currentQueueIndex)
            var nextIndex = currentQueueIndex
            while nextIndex == currentQueueIndex {
                nextIndex = Int.random(in: 0..<playbackQueue.count)
            }
            currentQueueIndex = nextIndex
            setSong(at: currentQueueIndex)
            return
        }
        
        let proposed = currentQueueIndex + 1
        if proposed < playbackQueue.count {
            setSong(at: proposed)
        } else if repeatMode == .all {
            setSong(at: 0)
        } else {
            isPlaying = false
        }
    }
    
    func previousTrack() {
        guard !playbackQueue.isEmpty else { return }
        
        if currentTime > 3 {
            requestSeek(to: 0)
            isPlaying = true
            return
        }
        
        if isShuffleEnabled, !shuffleHistory.isEmpty {
            setSong(at: shuffleHistory.removeLast())
            return
        }
        
        let proposed = currentQueueIndex - 1
        if proposed >= 0 {
            setSong(at: proposed)
        } else if repeatMode == .all {
            setSong(at: max(0, playbackQueue.count - 1))
        } else {
            requestSeek(to: 0)
            isPlaying = true
        }
    }
    
    private func setSong(at index: Int) {
        guard !playbackQueue.isEmpty else { return }
        let safeIndex = max(0, min(index, playbackQueue.count - 1))
        currentQueueIndex = safeIndex
        currentSong = playbackQueue[safeIndex]
        lastUserPlaybackToggleAt = CFAbsoluteTimeGetCurrent()
        isPlaying = true
        playbackCommandPlay = true
        playbackCommandID += 1
        currentTime = 0
        isAdPlaying = false
        addToRecentlyPlayed(song: playbackQueue[safeIndex])
    }

    func updateFromWebPlayer(currentTime: Double, duration: Double, isAd: Bool, isPaused: Bool, isBuffering: Bool) {
        let now = CFAbsoluteTimeGetCurrent()
        lastWebTimeUpdateAt = now
        isAdPlaying = isAd
        webIsPaused = isPaused
        webIsBuffering = isBuffering
        if duration.isFinite, duration > 0 {
            totalTime = duration
        }
        if currentTime.isFinite, currentTime >= 0 {
            self.currentTime = currentTime
        }

    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if !self.isPlaying { return }
            let now = CFAbsoluteTimeGetCurrent()
            if now - self.lastWebTimeUpdateAt > 3.0 { return }
            if !self.isAdPlaying, self.totalTime > 0, self.currentTime >= max(0, self.totalTime - 0.35) {
                self.nextTrack()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    // Formateador de tiempo (ej. 125 -> "2:05")
    func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    func toggleLike(songID: String) {
        if likedSongs.contains(songID) {
            likedSongs.remove(songID)
        } else {
            likedSongs.insert(songID)
        }
        saveLikedSongs()
    }
    
    private func saveLikedSongs() {
        let array = Array(likedSongs)
        UserDefaults.standard.set(array, forKey: "likedSongs")
    }
    
    private func loadLikedSongs() {
        if let array = UserDefaults.standard.stringArray(forKey: "likedSongs") {
            likedSongs = Set(array)
        }
    }
    
    // Gestión de Historial
    private func addToRecentlyPlayed(song: Song) {
        // Eliminar si ya existe para moverlo al principio
        recentlyPlayed.removeAll { $0.youtubeID == song.youtubeID }
        recentlyPlayed.insert(song, at: 0)
        
        // Limitar a los últimos 10
        if recentlyPlayed.count > 10 {
            recentlyPlayed = Array(recentlyPlayed.prefix(10))
        }
        
        saveRecentlyPlayed()
    }
    
    private func saveRecentlyPlayed() {
        if let encoded = try? JSONEncoder().encode(recentlyPlayed) {
            UserDefaults.standard.set(encoded, forKey: "recentlyPlayed")
        }
    }
    
    private func loadRecentlyPlayed() {
        if let data = UserDefaults.standard.data(forKey: "recentlyPlayed"),
           let decoded = try? JSONDecoder().decode([Song].self, from: data) {
            recentlyPlayed = decoded
        }
    }
}
