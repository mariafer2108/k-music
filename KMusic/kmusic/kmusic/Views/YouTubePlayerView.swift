import SwiftUI
import WebKit

#if os(iOS)
struct YouTubePlayerView: UIViewRepresentable {
    let videoID: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.allowsInlineMediaPlayback = true
        webConfiguration.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard let url = URL(string: "https://www.youtube.com/embed/\(videoID)?autoplay=1&mute=0&playsinline=1&enablejsapi=1&origin=https://www.youtube.com&rel=0&modestbranding=1&controls=0&showinfo=0&iv_load_policy=3") else { return }
        let request = URLRequest(url: url)
        uiView.load(request)
    }
}
#elseif os(macOS)
struct YouTubePlayerView: NSViewRepresentable {
    let videoID: String
    
    func makeNSView(context: Context) -> WKWebView {
        let webConfiguration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: webConfiguration)
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        guard let url = URL(string: "https://www.youtube.com/embed/\(videoID)?autoplay=1") else { return }
        let request = URLRequest(url: url)
        nsView.load(request)
    }
}
#endif
