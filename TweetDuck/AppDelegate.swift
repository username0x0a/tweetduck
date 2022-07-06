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

    func applicationDidFinishLaunching(_ aNotification: Notification) {

        UserDefaults.standard.set(true, forKey: "NSApplicationCrashOnExceptions")

        webView.navigationDelegate = self
        webView.uiDelegate = self

        webView.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        webView.configuration.userContentController.add(self, name: "duckDuckDo")

        appearanceObservation = webView.observe(\.effectiveAppearance) { _,_ in self.checkCurrentAppearance() }
        progressObservation = webView.observe(\.estimatedProgress) { _,_ in self.onProgressUpdate() }

        webView.load(URLRequest(url: URL(string: "https://tweetdeck.twitter.com")!))

        onUIVersionChange(.legacy) // Backup for now

        webView.alphaValue = 0
        progressView.startAnimation(nil)
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

        let script = """
            var mode = TD.settings.getTheme()
            var desiredMode = window.matchMedia('(prefers-color-scheme: dark)').matches ? "dark" : "light"
            if (mode != desiredMode) { TD.settings.setTheme(desiredMode) }
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

    func onProgressUpdate() {
        if webView.url?.host == "tweetdeck.twitter.com" && webView.estimatedProgress >= 1 {
            injectOnLoadCaller()
        }
    }

    func onTweetDeckLoad() {
        checkCurrentAppearance()
        injectLogo()

        NSAnimationContext.runAnimationGroup {
            $0.duration = 0.2
            webView.animator().alphaValue = 1
        } completionHandler: {
            self.progressView.stopAnimation(nil)
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
            (function loop_onTDReady(){
                setTimeout(function() {
                    if (TD && TD.ready) {
                        window.webkit.messageHandlers.duckDuckDo.postMessage('\(DuckDuckEvent.appLoaded.rawValue)')
                    } else loop_onTDReady()
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
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if let url = navigationAction.request.url {
            if url.absoluteString.contains("twitter.com/login") {
                decisionHandler(.allow)
            } else if url.host?.contains("tweetdeck.twitter.com") == false {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        } else {
            decisionHandler(.cancel)
        }
    }

}

extension AppDelegate: WKUIDelegate {}

extension AppDelegate: WKScriptMessageHandler {

    enum DuckDuckEvent: String {
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

            case .changeUIVersion:
                if let uiVersion = DuckDuckEvent.UIVersion(rawValue: arguments.first ?? "") {
                    onUIVersionChange(uiVersion)
                }

            case .none: break
        }
    }
}
