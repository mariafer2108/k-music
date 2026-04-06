import SwiftUI
import WebKit

#if os(iOS)
import UIKit

struct YouTubePlayerView: UIViewRepresentable {
    @ObservedObject var playerManager = PlayerManager.shared
    
    func makeUIView(context: Context) -> WKWebView {
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.allowsInlineMediaPlayback = true
        
        // TRUCO CLAVE: Desactivamos el requisito de interacción del usuario para que el audio suene solo
        webConfiguration.mediaTypesRequiringUserActionForPlayback = [] 
        
        webConfiguration.allowsAirPlayForMediaPlayback = true
        if #available(iOS 15.0, *) {
            webConfiguration.preferences.isElementFullscreenEnabled = true
        }
        
        // CRÍTICO: Permitir que el audio siga sonando cuando la vista no está visible o el dispositivo se bloquea
        webConfiguration.allowsPictureInPictureMediaPlayback = true
        webConfiguration.userContentController.add(context.coordinator, name: "kmusicTime")
        
        let backgroundKeepAlive = WKUserScript(
            source: """
            (function() {
              if (window.__kmusicKeepAliveInstalled) return;
              window.__kmusicKeepAliveInstalled = true;
              window.kmusicDesiredPlay = true;
              function kmusicTryResume() {
                try {
                  if (!window.kmusicDesiredPlay) return;
                  var player = document.getElementById('movie_player');
                  if (player && typeof player.playVideo === 'function') { player.playVideo(); return; }
                  var v = document.getElementsByTagName('video')[0];
                  if (v) { v.play(); }
                } catch(e) {}
              }
              document.addEventListener('visibilitychange', function() {
                if (document.hidden) { setTimeout(kmusicTryResume, 120); }
              }, true);
              window.addEventListener('pagehide', function() { setTimeout(kmusicTryResume, 120); }, true);
            })();
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        webConfiguration.userContentController.addUserScript(backgroundKeepAlive)
        
        let webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.backgroundColor = .clear
        webView.isOpaque = false
        webView.isUserInteractionEnabled = false
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator
        
        // User-Agent de Mac para máxima permisividad
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36"
        
        context.coordinator.webView = webView
        context.coordinator.installLifecycleObserversIfNeeded()
        context.coordinator.startReportTimer()
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard let song = playerManager.currentSong else { return }
        let desiredInteraction = playerManager.showFullPlayer
        if context.coordinator.lastInteractionEnabled != desiredInteraction {
            context.coordinator.lastInteractionEnabled = desiredInteraction
            DispatchQueue.main.async {
                uiView.isUserInteractionEnabled = desiredInteraction
            }
        }
        let videoID = song.youtubeID
        
        if context.coordinator.lastVideoID != videoID {
            context.coordinator.lastVideoID = videoID
            context.coordinator.lastIsPlaying = nil
            context.coordinator.lastSeekRequestID = playerManager.seekRequestID
            context.coordinator.lastPlaybackCommandID = playerManager.playbackCommandID
            context.coordinator.lastEvalAt = 0
            context.coordinator.lastReportAt = 0
            
            // MÁXIMA COMPATIBILIDAD: Parámetros para evitar bloqueos por región o inserción
            let urlString = "https://www.youtube.com/embed/\(videoID)?autoplay=1&mute=0&playsinline=1&enablejsapi=1&origin=https://www.youtube.com&rel=0&modestbranding=1&controls=1&showinfo=1&widget_referrer=https://www.google.com"
            
            if let url = URL(string: urlString) {
                var request = URLRequest(url: url)
                // Usamos google.com como Referer de máxima confianza
                request.setValue("https://www.google.com", forHTTPHeaderField: "Referer")
                uiView.load(request)
            }
        }
        
        let now = CFAbsoluteTimeGetCurrent()
        var shouldEval = false
        
        if context.coordinator.lastPlaybackCommandID != playerManager.playbackCommandID {
            context.coordinator.lastPlaybackCommandID = playerManager.playbackCommandID
            context.coordinator.enforcePlayback(desiredPlay: playerManager.playbackCommandPlay)
        }
        
        let seekRequested = playerManager.seekRequestID != context.coordinator.lastSeekRequestID
        if seekRequested {
            context.coordinator.lastSeekRequestID = playerManager.seekRequestID
            shouldEval = true
        }
        
        if shouldEval, now - context.coordinator.lastEvalAt >= 0.15 {
            context.coordinator.lastEvalAt = now
            
            let seekLine: String
            if seekRequested {
                seekLine = """
                try {
                    if (player && player.seekTo) { player.seekTo(\(playerManager.seekRequestTime), true); }
                    else if (video) { video.currentTime = \(playerManager.seekRequestTime); }
                } catch(e) {}
                """
            } else {
                seekLine = ""
            }
            
            let script = """
            (function() {
                var player = document.getElementById('movie_player');
                var video = document.getElementsByTagName('video')[0];
                function doPlay() {
                    try { if (player && typeof player.playVideo === 'function') { player.playVideo(); return true; } } catch(e) {}
                    try { if (video) { video.play(); return true; } } catch(e) {}
                    return false;
                }
                function doPause() {
                    try { if (player && typeof player.pauseVideo === 'function') { player.pauseVideo(); return true; } } catch(e) {}
                    try { if (video) { video.pause(); return true; } } catch(e) {}
                    return false;
                }
                \(seekLine)
            })();
            """
            uiView.evaluateJavaScript(script, completionHandler: nil)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        weak var webView: WKWebView?
        var lastVideoID: String?
        var lastIsPlaying: Bool?
        var lastSeekRequestID: Int = 0
        var lastPlaybackCommandID: Int = 0
        var lastInteractionEnabled: Bool?
        var lastEvalAt: CFAbsoluteTime = 0
        var lastReportAt: CFAbsoluteTime = 0
        private var reportTimer: Timer?
        private var enforceToken: Int = 0
        
        private var lifecycleInstalled = false
        private var observers: [NSObjectProtocol] = []
        
        func installLifecycleObserversIfNeeded() {
            guard !lifecycleInstalled else { return }
            lifecycleInstalled = true
            
            let center = NotificationCenter.default
            observers.append(center.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
                self?.kickForBackgroundIfNeeded()
            })
            observers.append(center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
                self?.kickForBackgroundIfNeeded()
            })
        }
        
        func startReportTimer() {
            reportTimer?.invalidate()
            reportTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                guard let self, let webView = self.webView else { return }
                let desiredPlay = PlayerManager.shared.isPlaying
                let report = """
                (function() {
                    try { window.kmusicDesiredPlay = \((desiredPlay ? "true" : "false")); } catch(e) {}
                    var player = document.getElementById('movie_player');
                    var video = document.getElementsByTagName('video')[0];
                    var adNode = document.querySelector('.ad-showing,.ad-interrupting,.ytp-ad-player-overlay,.ytp-ad-module,[class*=\\"ad-showing\\"],[class*=\\"ad-interrupting\\"]');
                    var isAd = !!adNode;
                    try {
                        if (document.body && document.body.classList) {
                            if (document.body.classList.contains('ad-showing') || document.body.classList.contains('ad-interrupting')) { isAd = true; }
                        }
                    } catch(e) {}
                    try {
                        var t = 0;
                        var d = 0;
                        var paused = true;
                        var isBuffering = false;
                        if (player && player.getPlayerState) {
                            var state = player.getPlayerState();
                            paused = (state != 1);
                            isBuffering = (state == 3);
                            try { t = player.getCurrentTime() || 0; } catch(e) {}
                            try { d = player.getDuration() || 0; } catch(e) {}
                        } else if (video) {
                            try { t = video.currentTime || 0; } catch(e) {}
                            try { d = video.duration || 0; } catch(e) {}
                            try { paused = video.paused ? true : false; } catch(e) {}
                            try { if (video.readyState < 3 || video.seeking) { isBuffering = true; } } catch(e) {}
                        } else { return; }
                        window.webkit.messageHandlers.kmusicTime.postMessage({
                            t: t,
                            d: d,
                            ad: isAd,
                            paused: paused,
                            buf: isBuffering
                        });
                    } catch(e) {}
                })();
                """
                webView.evaluateJavaScript(report, completionHandler: nil)
            }
        }
        
        private func kickForBackgroundIfNeeded() {
            guard PlayerManager.shared.isPlaying else { return }
            guard let webView else { return }
            let script = """
            (function() {
              try { window.kmusicDesiredPlay = true; } catch(e) {}
              try {
                var player = document.getElementById('movie_player');
                if (player && typeof player.playVideo === 'function') { player.playVideo(); return; }
                var v = document.getElementsByTagName('video')[0];
                if (v) { v.play(); }
              } catch(e) {}
            })();
            """
            webView.evaluateJavaScript(script, completionHandler: nil)
        }
        
        func enforcePlayback(desiredPlay: Bool) {
            guard let webView else { return }
            enforceToken += 1
            let token = enforceToken
            
            func attempt(after delay: Double) {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    guard token == self.enforceToken else { return }
                    if PlayerManager.shared.isPlaying != desiredPlay { return }
                    
                    let script = """
                    (function() {
                        var player = document.getElementById('movie_player');
                        var video = document.getElementsByTagName('video')[0];
                        function doPlay() {
                            try { if (player && typeof player.playVideo === 'function') { player.playVideo(); return true; } } catch(e) {}
                            try { if (video) { video.play(); return true; } } catch(e) {}
                            return false;
                        }
                        function doPause() {
                            try { if (player && typeof player.pauseVideo === 'function') { player.pauseVideo(); return true; } } catch(e) {}
                            try { if (video) { video.pause(); return true; } } catch(e) {}
                            return false;
                        }
                        if (\(desiredPlay ? "true" : "false")) { doPlay(); } else { doPause(); }
                    })();
                    """
                    webView.evaluateJavaScript(script, completionHandler: nil)
                }
            }
            
            attempt(after: 0.0)
            attempt(after: 0.25)
            attempt(after: 0.75)
        }
        
        deinit {
            observers.forEach { NotificationCenter.default.removeObserver($0) }
            reportTimer?.invalidate()
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "kmusicTime" else { return }
            if let dict = message.body as? [String: Any] {
                let t = dict["t"] as? Double ?? 0
                let d = dict["d"] as? Double ?? 0
                let ad = dict["ad"] as? Bool ?? false
                let paused = dict["paused"] as? Bool ?? false
                let buffering = dict["buf"] as? Bool ?? false
                DispatchQueue.main.async {
                    PlayerManager.shared.updateFromWebPlayer(currentTime: t, duration: d, isAd: ad, isPaused: paused, isBuffering: buffering)
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {}
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
                if let host = url.host?.lowercased(), host.contains("youtube.com") || host.contains("youtu.be") {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    decisionHandler(.cancel)
                    return
                }
            }
            decisionHandler(.allow)
        }
    }
}
#elseif os(macOS)
struct YouTubePlayerView: NSViewRepresentable {
    @ObservedObject var playerManager = PlayerManager.shared
    
    func makeNSView(context: Context) -> WKWebView {
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.mediaTypesRequiringUserActionForPlayback = []
        webConfiguration.userContentController.add(context.coordinator, name: "kmusicTime")
        
        let webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        guard let song = playerManager.currentSong else { return }
        let videoID = song.youtubeID
        
        if context.coordinator.lastVideoID != videoID {
            context.coordinator.lastVideoID = videoID
            context.coordinator.lastIsPlaying = nil
            context.coordinator.lastSeekRequestID = playerManager.seekRequestID
            context.coordinator.lastEvalAt = 0
            context.coordinator.lastReportAt = 0
            let urlString = "https://www.youtube.com/embed/\(videoID)?autoplay=1&mute=0&playsinline=1&enablejsapi=1&rel=0&modestbranding=1"
            if let url = URL(string: urlString) {
                var request = URLRequest(url: url)
                request.setValue("https://www.youtube.com", forHTTPHeaderField: "Referer")
                nsView.load(request)
            }
        }
        
        let now = CFAbsoluteTimeGetCurrent()
        let isPlaying = playerManager.isPlaying
        var shouldEval = false
        
        if context.coordinator.lastIsPlaying != isPlaying {
            context.coordinator.lastIsPlaying = isPlaying
            shouldEval = true
        }
        
        let seekRequested = playerManager.seekRequestID != context.coordinator.lastSeekRequestID
        if seekRequested {
            context.coordinator.lastSeekRequestID = playerManager.seekRequestID
            shouldEval = true
        }
        
        if shouldEval, now - context.coordinator.lastEvalAt >= 0.15 {
            context.coordinator.lastEvalAt = now
            
            let seekLine: String
            if seekRequested {
                seekLine = "video.currentTime = \(playerManager.seekRequestTime);"
            } else {
                seekLine = ""
            }
            
            let script = """
            (function() {
                var video = document.getElementsByTagName('video')[0];
                if (!video) { return; }
                video.muted = false;
                if (\(isPlaying)) { video.play(); } else { video.pause(); }
                \(seekLine)
            })();
            """
            nsView.evaluateJavaScript(script, completionHandler: nil)
        }
        
        if now - context.coordinator.lastReportAt >= 0.8 {
            context.coordinator.lastReportAt = now
            let report = """
            (function() {
                var video = document.getElementsByTagName('video')[0];
                if (!video) { return; }
                var adNode = document.querySelector('.ad-showing,.ad-interrupting,.ytp-ad-player-overlay,.ytp-ad-module,[class*=\"ad-showing\"],[class*=\"ad-interrupting\"]');
                var isAd = !!adNode;
                try {
                    if (document.body && document.body.classList) {
                        if (document.body.classList.contains('ad-showing') || document.body.classList.contains('ad-interrupting')) { isAd = true; }
                    }
                } catch(e) {}
                try {
                    var isBuffering = false;
                    try {
                        if (video.readyState < 3 || video.seeking) { isBuffering = true; }
                    } catch(e) {}
                    window.webkit.messageHandlers.kmusicTime.postMessage({
                        t: video.currentTime || 0,
                        d: video.duration || 0,
                        ad: isAd,
                        paused: video.paused ? true : false,
                        buf: isBuffering
                    });
                } catch(e) {}
                        if (video.readyState < 3 || video.seeking) { isBuffering = true; }
                    } catch(e) {}
                    window.webkit.messageHandlers.kmusicTime.postMessage({
                        t: video.currentTime || 0,
                        d: video.duration || 0,
                        ad: isAd,
                        paused: video.paused ? true : false,
                        buf: isBuffering
                    });
                } catch(e) {}
            })();
            """
            nsView.evaluateJavaScript(report, completionHandler: nil)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKScriptMessageHandler {
        var lastVideoID: String?
        var lastIsPlaying: Bool?
        var lastSeekRequestID: Int = 0
        var lastEvalAt: CFAbsoluteTime = 0
        var lastReportAt: CFAbsoluteTime = 0
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "kmusicTime" else { return }
            if let dict = message.body as? [String: Any] {
                let t = dict["t"] as? Double ?? 0
                let d = dict["d"] as? Double ?? 0
                let ad = dict["ad"] as? Bool ?? false
                let paused = dict["paused"] as? Bool ?? false
                let buffering = dict["buf"] as? Bool ?? false
                DispatchQueue.main.async {
                    PlayerManager.shared.updateFromWebPlayer(currentTime: t, duration: d, isAd: ad, isPaused: paused, isBuffering: buffering)
                }
            }
        }
    }
}
#endif
