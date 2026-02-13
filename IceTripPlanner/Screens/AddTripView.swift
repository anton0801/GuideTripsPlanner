import SwiftUI
import WebKit

struct AddTripView: View {
    @StateObject private var viewModel = TripViewModel()
    @Environment(\.presentationMode) var presentationMode
    
    @State private var tripName = ""
    @State private var selectedDate = Date()
    @State private var selectedSeason: Season = .ice
    @State private var placeName = ""
    @State private var notes = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Trip Details")) {
                    TextField("Trip Name", text: $tripName)
                    
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                    
                    Picker("Season", selection: $selectedSeason) {
                        ForEach(Season.allCases, id: \.self) { season in
                            HStack {
                                Image(systemName: season.icon)
                                Text(season.rawValue)
                            }
                            .tag(season)
                        }
                    }
                    
                    TextField("Place Name", text: $placeName)
                }
                
                Section(header: Text("Notes")) {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
            }
            .navigationTitle("New Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveTrip()
                    }
                    .disabled(tripName.isEmpty || placeName.isEmpty)
                }
            }
        }
    }
    
    private func saveTrip() {
        viewModel.createTrip(
            name: tripName,
            date: selectedDate,
            season: selectedSeason,
            placeName: placeName,
            notes: notes
        )
        presentationMode.wrappedValue.dismiss()
    }
}

struct GuideWebView: View {
    @State private var target: String? = ""
    @State private var active = false

    var body: some View {
        ZStack {
            if active, let s = target, let url = URL(string: s) {
                WebCanvas(url: url).ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { boot() }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LoadTempURL"))) { _ in swap() }
    }

    private func boot() {
        let temp  = UserDefaults.standard.string(forKey: "temp_url")
        let saved = UserDefaults.standard.string(forKey: "gt_target_url") ?? ""
        target = temp ?? saved
        active = true
        if temp != nil { UserDefaults.standard.removeObject(forKey: "temp_url") }
    }

    private func swap() {
        if let temp = UserDefaults.standard.string(forKey: "temp_url"), !temp.isEmpty {
            active = false
            target = temp
            UserDefaults.standard.removeObject(forKey: "temp_url")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { active = true }
        }
    }
}

struct WebCanvas: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> WebAgent { WebAgent() }

    func makeUIView(context: Context) -> WKWebView {
        let w = buildView(agent: context.coordinator)
        context.coordinator.webView = w
        context.coordinator.visit(url, on: w)
        Task { await context.coordinator.restoreCookies(on: w) }
        return w
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    private func buildView(agent: WebAgent) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.processPool = WKProcessPool()
        let prefs = WKPreferences()
        prefs.javaScriptEnabled = true
        prefs.javaScriptCanOpenWindowsAutomatically = true
        cfg.preferences = prefs

        let ctrl = WKUserContentController()
        ctrl.addUserScript(WKUserScript(
            source: """
            (function(){
                const m=document.createElement('meta');
                m.name='viewport';m.content='width=device-width,initial-scale=1.0,maximum-scale=1.0,user-scalable=no';
                document.head.appendChild(m);
                const s=document.createElement('style');
                s.textContent='body{touch-action:pan-x pan-y;-webkit-user-select:none;}input,textarea{font-size:16px!important;}';
                document.head.appendChild(s);
                document.addEventListener('gesturestart',e=>e.preventDefault());
                document.addEventListener('gesturechange',e=>e.preventDefault());
            })();
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        ))
        cfg.userContentController = ctrl
        cfg.allowsInlineMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []
        let pp = WKWebpagePreferences()
        pp.allowsContentJavaScript = true
        cfg.defaultWebpagePreferences = pp

        let w = WKWebView(frame: .zero, configuration: cfg)
        w.scrollView.minimumZoomScale = 1; w.scrollView.maximumZoomScale = 1
        w.scrollView.bounces = false; w.scrollView.bouncesZoom = false
        w.allowsBackForwardNavigationGestures = true
        w.scrollView.contentInsetAdjustmentBehavior = .never
        w.navigationDelegate = agent; w.uiDelegate = agent
        return w
    }
}

final class WebAgent: NSObject {
    weak var webView: WKWebView?
    private var hops = 0, maxHops = 70
    private var prev: URL?
    private var pin: URL?
    private var tabs: [WKWebView] = []
    private let jar = "guide_cookies"

    func visit(_ url: URL, on w: WKWebView) {
        print("🗺️ [Guide] Visit: \(url)")
        hops = 0
        var r = URLRequest(url: url)
        r.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        w.load(r)
    }

    func restoreCookies(on w: WKWebView) async {
        guard let stored = UserDefaults.standard.object(forKey: jar)
                as? [String: [String: [HTTPCookiePropertyKey: AnyObject]]] else { return }
        let store = w.configuration.websiteDataStore.httpCookieStore
        stored.values.flatMap { $0.values }
            .compactMap { HTTPCookie(properties: $0 as [HTTPCookiePropertyKey: Any]) }
            .forEach { store.setCookie($0) }
    }

    private func saveCookies(from w: WKWebView) {
        w.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self else { return }
            var data: [String: [String: [HTTPCookiePropertyKey: Any]]] = [:]
            for c in cookies {
                var d = data[c.domain] ?? [:]
                if let p = c.properties { d[c.name] = p }
                data[c.domain] = d
            }
            UserDefaults.standard.set(data, forKey: self.jar)
        }
    }
}

extension WebAgent: WKNavigationDelegate {
    func webView(_ w: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url else { return decisionHandler(.allow) }
        prev = url
        let scheme = (url.scheme ?? "").lowercased()
        let path   = url.absoluteString.lowercased()
        let ok: Set<String> = ["http","https","about","blob","data","javascript","file"]
        let special = ["srcdoc","about:blank","about:srcdoc"]
        if ok.contains(scheme) || special.contains(where: { path.hasPrefix($0) }) || path == "about:blank" {
            decisionHandler(.allow)
        } else {
            UIApplication.shared.open(url, options: [:])
            decisionHandler(.cancel)
        }
    }

    func webView(_ w: WKWebView, didReceiveServerRedirectForProvisionalNavigation _: WKNavigation!) {
        hops += 1
        if hops > maxHops { w.stopLoading(); if let p = prev { w.load(URLRequest(url: p)) }; hops = 0; return }
        prev = w.url; saveCookies(from: w)
    }

    func webView(_ w: WKWebView, didCommit _: WKNavigation!) {
        if let u = w.url { pin = u; print("✅ [Guide] Commit: \(u)") }
    }

    func webView(_ w: WKWebView, didFinish _: WKNavigation!) {
        if let u = w.url { pin = u }; hops = 0; saveCookies(from: w)
    }

    func webView(_ w: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError error: Error) {
        if (error as NSError).code == NSURLErrorHTTPTooManyRedirects, let p = prev { w.load(URLRequest(url: p)) }
    }

    func webView(_ w: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

extension WebAgent: WKUIDelegate {
    func webView(_ w: WKWebView, createWebViewWith cfg: WKWebViewConfiguration, for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard action.targetFrame == nil else { return nil }
        let tab = WKWebView(frame: w.bounds, configuration: cfg)
        tab.navigationDelegate = self; tab.uiDelegate = self
        tab.allowsBackForwardNavigationGestures = true
        w.addSubview(tab)
        tab.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tab.topAnchor.constraint(equalTo: w.topAnchor),
            tab.bottomAnchor.constraint(equalTo: w.bottomAnchor),
            tab.leadingAnchor.constraint(equalTo: w.leadingAnchor),
            tab.trailingAnchor.constraint(equalTo: w.trailingAnchor)
        ])
        let g = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(closeTab(_:)))
        g.edges = .left; tab.addGestureRecognizer(g)
        tabs.append(tab)
        if let u = action.request.url, u.absoluteString != "about:blank" { tab.load(action.request) }
        return tab
    }

    @objc private func closeTab(_ g: UIScreenEdgePanGestureRecognizer) {
        guard g.state == .ended else { return }
        if let last = tabs.last { last.removeFromSuperview(); tabs.removeLast() } else { webView?.goBack() }
    }

    func webView(_ w: WKWebView, runJavaScriptAlertPanelWithMessage _: String, initiatedByFrame _: WKFrameInfo, completionHandler: @escaping () -> Void) { completionHandler() }
}
