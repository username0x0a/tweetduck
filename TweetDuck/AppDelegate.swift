//
//  AppDelegate.swift
//  TweetDuck
//
//  Created by Michal Zelinka on 03/07/2022.
//

import Cocoa
import WebKit

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet var window: NSWindow!
    @IBOutlet var webView: WKWebView!
    @IBOutlet var progressView: NSProgressIndicator!
    @IBOutlet var duckyImage: NSImageView!

    var appearanceObservation: NSKeyValueObservation?
    var progressObservation: NSKeyValueObservation?
    var urlObservation: NSKeyValueObservation?

    var updateAvailable: Bool = false

    func applicationDidFinishLaunching(_ aNotification: Notification) {

        checkUpdate { self.updateAvailable = true }

        UserDefaults.standard.set(true, forKey: "NSApplicationCrashOnExceptions")

        URLCache.shared.removeAllCachedResponses()
        URLCache.shared.diskCapacity = 0
        URLCache.shared.memoryCapacity = 0

        WKWebsiteDataStore.default().removeData(ofTypes: [
            WKWebsiteDataTypeFetchCache,
            WKWebsiteDataTypeDiskCache,
            WKWebsiteDataTypeMemoryCache,
            WKWebsiteDataTypeOfflineWebApplicationCache,
        ], modifiedSince: .distantPast) { }

        webView.navigationDelegate = self
        webView.uiDelegate = self

        webView.configuration.websiteDataStore = .nonPersistent()
        webView.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        webView.configuration.userContentController.add(self, name: "duckDuckDo")

        appearanceObservation = webView.observe(\.effectiveAppearance) { [weak self] _,_ in self?.checkCurrentAppearance() }
        progressObservation = webView.observe(\.estimatedProgress) { [weak self] _,_ in self?.onProgressUpdate() }
        urlObservation = webView.observe(\.url) { [weak self] _,_ in self?.onURLUpdate() }

        webView.load(URLRequest(url: URL(string: "https://tweetdeck.twitter.com")!))

        toggleContent(visible: false)
    }

    func applicationWillTerminate(_ aNotification: Notification) { }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow(nil)
        return true
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        guard window.isKeyWindow == false else { return nil }
        let menu = NSMenu(title: "Dock menu")
        menu.addItem(
            withTitle: NSLocalizedString("Open", comment: "Open action"),
            action: #selector(dockOpen),
            keyEquivalent: "n"
        )
        return menu
    }
}

extension AppDelegate {

    func showSettings() {
        let script = "if (TD.ready) { new TD.components.GlobalSettings() }"
        webView.evaluateJavaScript(script)
    }

    func clickFindButton() {
        let script = "document.querySelector('button.app-search-fake').click()"
        webView.evaluateJavaScript(script)
    }

    func checkCurrentAppearance() {

        let appearanceOverride: NSAppearance.Name?

        let appearance = Appearance(
            rawValue: UserDefaults.standard.integer(forKey: "_uiAppearance")
        )

        switch appearance {
            case .light: appearanceOverride = .aqua
            case .dark:  appearanceOverride = .darkAqua
            default:     appearanceOverride = nil
        }

        self.window.appearance = appearanceOverride.flatMap { .init(named: $0) }

        let desiredMode = webView.effectiveAppearance.name == .darkAqua ? "dark" : "light"

        let script = """
            var mode = TD.settings.getTheme()
            var desiredMode = '\(desiredMode)'
            console.log(desiredMode)
            if (mode != desiredMode) { TD.settings.setTheme(desiredMode) }
            """

        webView.evaluateJavaScript(script)
    }

    func checkUpdateIndication() {

        guard updateAvailable else { return }

        let script = """
            var template = document.createElement('template');
            template.innerHTML = "\
            <style>\
                a.tweetDuckUpdate {\
                    z-index: 10; padding: 3px 24px; height: 44px; position: absolute; background: #f2b64a;\
                    text-align: center; display: inline-block; line-height: 44px; bottom: 24px; left: 50%;\
                    transform: translate(-50%,0); color: white; border-radius: 44px;\
                    box-shadow: 0 1px 1px rgba(255, 255, 255, 0.52) inset, 0 8px 50px rgba(0, 0, 0, 0.26);\
                    font-size: 1.1em; text-decoration: none; background-image: linear-gradient(#f2c447, #f18e51);\
                    text-shadow: 0 -1px 0 rgba(14, 14, 14, 0.3); text-transform: uppercase; letter-spacing: 2px;\
                    font-weight: 600; cursor: pointer;\
                }\
                a.tweetDuckUpdate:hover {\
                    background-image: linear-gradient(#f7d067, #eeaa33);\
                }\
                a.tweetDuckUpdate:active {\
                    transform: translate(-50%,0) scale(0.98);\
                }\
            </style>\
            <script>\
            function updateAppCallback() {\
            }\
            </script>\
            <a class='tweetDuckUpdate' href='https://tweetduck.update'>Update TweetDuck 🐤</a>\
            "
            template.content.childNodes.forEach(e => document.querySelector('div.application').appendChild(e))
            """

        webView.evaluateJavaScript(script)
    }

    func injectLogo() {

        var imageRect = NSRect(origin: .zero, size: .init(width: 36, height: 36))
        let image = NSApp.applicationIconImage!
        let imageRep = NSBitmapImageRep(cgImage: image.cgImage(forProposedRect: &imageRect, context: nil, hints: nil)!)
        imageRep.size = imageRect.size

        let imageData = imageRep.representation(using: .png, properties: [:])!

        let base64String = imageData.base64EncodedString()
        let htmlString = "data:image/png;base64,\(base64String)"

        let script = """
            var logoElm = document.getElementsByClassName('tweetdeck-logo')[0]
            logoElm.style = "background: none"
            logoElm.classList.toggle('width--26', false)
            logoElm.classList.toggle('height--24', false)
            logoElm.innerHTML = "<img src='\(htmlString)' style='width: 36px; height: 36px'>"
            """

        webView.evaluateJavaScript(script)
    }

    func toggleContent(visible: Bool) {

        let duration = visible ? 0.2 : 0.1
        let alpha = visible ? 1.0 : 0

        if !visible { progressView.startAnimation(nil) }

        NSAnimationContext.runAnimationGroup {
            $0.duration = duration
            webView.animator().alphaValue = alpha
        } completionHandler: {
            if visible { self.progressView.stopAnimation(nil) }
        }
    }

    func onProgressUpdate() {
        if webView.url?.host == "tweetdeck.twitter.com" && webView.estimatedProgress >= 1 {
            injectOnLoadCaller()
        }
    }

    func onTweetDeckLoad() {
        checkCurrentAppearance()
        checkUpdateIndication()
        injectLogo()
        toggleContent(visible: true)
    }

    func onURLUpdate() {
        guard let url = webView.url else { return }
        let urlString = url.absoluteString

        if urlString ~= "twitter.com" && url.path == "/" {
            webView.load(URLRequest(url: URL(string: Pages.tweetDeckHomePage.rawValue)!))
        }
    }

    func onUIVersionChange(_ version: DuckDuckEvent.UIVersion) {

        let script = """
            var uiVersion = '\(version.rawValue)'
            var expiration = (new Date(new Date().getTime()+1000*60*60*24*365)).toUTCString()
            document.cookie = 'tweetdeck_version=' + uiVersion
                            + ';expires=' + expiration
                            + ';domain=.twitter.com;path=/'
            location.reload()
            """

        webView.evaluateJavaScript(script)
    }

    func injectOnLoadCaller() {

        let script = """
            (function loop_onLoadReady(){
                setTimeout(function() {
                    if (TD && TD.ready) {
                        window.webkit.messageHandlers.duckDuckDo
                            .postMessage('\(DuckDuckEvent.appLoaded.rawValue)')
                    } else if (TD && document.cookie.match('twid=') == null) {
                        window.webkit.messageHandlers.duckDuckDo
                            .postMessage('\(DuckDuckEvent.pageLoaded.rawValue) ' + window.location.href)
                    } else if (TD == null && document.readyState == 'complete') {
                        window.webkit.messageHandlers.duckDuckDo
                            .postMessage('\(DuckDuckEvent.pageLoaded.rawValue) ' + window.location.href)
                    } else loop_onLoadReady()
              }, 100)
            })()
            """

        webView.evaluateJavaScript(script)
    }

    @objc func dockOpen() {
        window.makeKeyAndOrderFront(nil)
    }

    @IBAction func showWindow(_ sender: Any?) {
        window.makeKeyAndOrderFront(sender)
    }

    @IBAction func performFindPanelAction(_ sender: Any?) {
        clickFindButton()
    }

    @IBAction func showPreferences(_ sender: Any?) {
        showSettings()
    }

    @IBAction func reloadPage(_ sender: Any?) {
        webView.reload()
    }

    @IBAction func switchAppearance(_ sender: Any?) {
        guard let item = sender as? NSMenuItem else { return }

        let overrideAppearance: Appearance?

        if item.tag == 1 {
            overrideAppearance = .light
        } else if item.tag == 2 {
            overrideAppearance = .dark
        } else if item.tag == 3 {
            let effective = window.effectiveAppearance.name
            overrideAppearance = effective == .darkAqua ? .light : .dark
        } else {
            overrideAppearance = .none
        }

        UserDefaults.standard.set(overrideAppearance?.rawValue ?? 0, forKey: "_uiAppearance")

        checkCurrentAppearance()
    }

    @IBAction func toggleBetaUI(_ sender: Any?) {

        let script = """
            document.cookie.split(';')
                .filter(cookie => cookie.indexOf('tweetdeck_version=') == 0)
                .map(cookie => cookie.replace('tweetdeck_version=',''))[0]
            """

        webView.evaluateJavaScript(script) { result, _ in
            let string = result as? String ?? ""
            let version = DuckDuckEvent.UIVersion(rawValue: string)
            let newVersion: DuckDuckEvent.UIVersion
            switch version {
                case .legacy:             newVersion = .beta
                case .main, .beta, .none: newVersion = .legacy
            }
            self.onUIVersionChange(newVersion)
        }
    }
}

extension AppDelegate: WKNavigationDelegate {

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        decisionHandler(.allow)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else { return decisionHandler(.cancel) }

        let urlString = url.absoluteString

        if urlString ~= "twitter.com/login" || urlString ~= "twitter.com/logout" {
            // Login, Logout pages
            decisionHandler(.allow)
        } else if urlString ~= "twitter.com/.*(password_reset|signup)" {
            // Password reset page
            decisionHandler(.cancel)
            NSWorkspace.shared.open(url)
        } else if urlString ~= "twitter.com/.*(/cards/)" {
            // Cards, Polls, etc.
            decisionHandler(.allow)
        } else if urlString ~= "//accounts.google.com.*gsi.*button" {
            // Sign in with Google button
            decisionHandler(.allow)
        } else if urlString ~= "//(www.)?twitter.com" && url.path == "/" {
            // Basic Twitter homepage
            decisionHandler(.cancel)
            webView.load(URLRequest(url: URL(string: Pages.tweetDeckHomePage.rawValue)!))
        } else if urlString ~= "//tweetdeck.twitter.com" {
            // Anything TweetDeck
            decisionHandler(.allow)
        } else if urlString ~= "//tweetduck.update" {
            // TweetDuck update action
            decisionHandler(.cancel)
        } else if urlString ~= "youtube.com/embed" ||
                  urlString ~= "vine.co/v/.*/card" ||
                  urlString ~= "twitter.com/i/videos" {
            // Embed videos
            decisionHandler(.allow)
        } else if urlString ~= "twitter.com/i/safety/report_story" {
            // Tweets reporting
            decisionHandler(.allow)
        } else if urlString ~= "about:blank" {
            // O.M.G
            decisionHandler(.cancel)
        } else {
            // Anything else
            decisionHandler(.cancel)
            NSWorkspace.shared.open(url)
        }
    }
}

extension AppDelegate: WKUIDelegate {

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {

        // Open `target="_blank"` destinations via system

        if let url = navigationAction.request.url {
            let urlString = url.absoluteString
            if urlString ~= "//tweetduck.update" {
                let githubURL = URL(string: "https://github.com/username0x0a/tweetduck/releases").unsafelyUnwrapped
                NSWorkspace.shared.open(githubURL)
            } else {
                NSWorkspace.shared.open(url)
            }
        }

        return nil
    }
}

extension AppDelegate: WKScriptMessageHandler {

    enum Pages: String {
        case tweetDeckHomePage = "https://tweetdeck.twitter.com"
    }

    enum DuckDuckEvent: String {
        case pageLoaded
        case appLoaded
        case changeUIVersion

        enum UIVersion: String {
            case legacy
            case main
            case beta
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {

        // Example: window.webkit.messageHandlers.duckDuckDo.postMessage('changeUIVersion beta')

        guard message.name == "duckDuckDo", let body = message.body as? String else { return }

        var arguments = body.components(separatedBy: " ").filter { $0.count > 0 }
        let command = DuckDuckEvent(rawValue: arguments.first ?? "")
        arguments.removeFirst()

        switch command {

            case .appLoaded:
                onTweetDeckLoad()

            case .pageLoaded:
                toggleContent(visible: true)

            case .changeUIVersion:
                if let uiVersion = DuckDuckEvent.UIVersion(rawValue: arguments.first ?? "") {
                    onUIVersionChange(uiVersion)
                }

            case .none: break
        }
    }
}

extension AppDelegate: NSMenuItemValidation {

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        let mapping: [String: NSAppearance.Name?] = [
            "appearanceAuto":  .none,
            "appearanceLight": .aqua,
            "appearanceDark":  .darkAqua,
        ]

        let itemID = menuItem.accessibilityIdentifier()

        guard mapping.keys.contains(itemID) else { return true }

        let windowAppearance = window.appearance?.name
        let desiredAppearance = mapping[itemID]

        menuItem.state = windowAppearance == desiredAppearance ? .on : .off

        return true
    }
}

extension AppDelegate {

    func checkUpdate(onUpdateAvailable: @escaping () -> Void) {

        let lastUpdateKey = "_LastUpdate"
        let defaults = UserDefaults.standard

        let currentTimestamp = Date().timeIntervalSince1970

        guard let currentVersionString =
                Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
              let url = URL(string: "https://api.github.com/repos/username0x0a/tweetduck/releases")
        else { return }

        func stringToIntVersion(_ str: String) -> Int {
            var version = 0
            let steppers = [1000000, 1000, 1]
            let comps = str.components(separatedBy: ".")
            for comp in comps.enumerated() {
                guard let compInt = Int(comp.element),
                      comp.offset < steppers.count
                else { break }
                version += steppers[comp.offset] * compInt
            }
            return version
        }

        let currentVersion = stringToIntVersion(currentVersionString)

        if let lastUpdateInfo = defaults.string(forKey: lastUpdateKey) {

            let scanner = Scanner(string: lastUpdateInfo)
            scanner.charactersToBeSkipped = CharacterSet(charactersIn: "|")

            if let tag = scanner.scanUpTo("|"),
               let timestamp = scanner.scanDouble() {

                let lastVersion = stringToIntVersion(tag)

                if lastVersion > currentVersion {
                    onUpdateAvailable()
                    return
                } else if timestamp > currentTimestamp - 2 * 86400 {
                    return
                }
            }
        }

        struct Release: Decodable {
            let tagName: String
            let url: URL
        }

        URLSession.shared.dataTask(with: url) { data, response, error in

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            guard
                let data = data,
                data.count > 0,
                let releases = try? decoder.decode([Release].self, from: data),
                let latestRelease = releases.first
            else { return }

            let latestTag = latestRelease.tagName.replacingOccurrences(of: "v", with: "")
            let latestVersion = stringToIntVersion(latestTag)

            if latestVersion <= currentVersion { return }

            OperationQueue.main.addOperation {
                defaults.set("\(latestTag)|\(floor(currentTimestamp))", forKey: lastUpdateKey)
                onUpdateAvailable()
            }

        }.resume()
    }
}

enum Appearance: Int {
    case auto
    case light
    case dark
}

extension String {
    static func ~= (lhs: String, rhs: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: rhs) else { return false }
        let range = NSRange(location: 0, length: lhs.utf16.count)
        return regex.firstMatch(in: lhs, options: [], range: range) != nil
    }
}

extension Scanner {

    func scanUpToCharactersFrom(_ set: CharacterSet) -> String? {
        var result: NSString?
        return scanUpToCharacters(from: set, into: &result) ? (result as? String) : nil
    }

    func scanUpTo(_ string: String) -> String? {
        var result: NSString?
        return self.scanUpTo(string, into: &result) ? (result as? String) : nil
    }

    func scanDouble() -> Double? {
        var double: Double = 0
        return scanDouble(&double) ? double : nil
    }
}
