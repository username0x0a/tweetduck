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

    var appearanceObservation: NSKeyValueObservation?
    var progressObservation: NSKeyValueObservation?

    func applicationDidFinishLaunching(_ aNotification: Notification) {

        UserDefaults.standard.set(true, forKey: "NSApplicationCrashOnExceptions")

        webView.navigationDelegate = self
        webView.uiDelegate = self

        webView.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")

        appearanceObservation = webView.observe(\.effectiveAppearance) { _,_ in self.checkCurrentAppearance() }
        progressObservation = webView.observe(\.estimatedProgress) { _,_ in self.onProgressUpdate() }

        webView.load(URLRequest(url: URL(string: "https://tweetdeck.twitter.com")!))
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

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
        let script = "new TD.components.GlobalSettings"
        webView.evaluateJavaScript(script)
    }

    func clickFindButton() {
        let script = "document.querySelector('button.app-search-fake').click()"
        webView.evaluateJavaScript(script)
    }

    func checkCurrentAppearance() {

        let script = """
            (function loop_currentAppearance(){
                setTimeout(function() {
                    if (TD && TD.ready) {
                        var mode = TD.settings.getTheme()
                        var desiredMode = window.matchMedia('(prefers-color-scheme: dark)').matches ? "dark" : "light"
                        if (mode != desiredMode) { TD.settings.setTheme(desiredMode) }
                    } else loop_currentAppearance()
              }, 500)
            })()
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
            (function loop_injectLogo(){
                setTimeout(function() {
                    var logoElm = document.getElementsByClassName('tweetdeck-logo')[0]
                    if (logoElm != null) {
                        logoElm.style = "background: none"
                        logoElm.classList.toggle('width--26', false)
                        logoElm.classList.toggle('height--24', false)
                        logoElm.innerHTML = "<img src='\(htmlString)' style='width: 36px; height: 36px'>"
                    } else loop_injectLogo()
              }, 500)
            })()
            """

        webView.evaluateJavaScript(script)
    }

    func onProgressUpdate() {
        if webView.url?.host == "tweetdeck.twitter.com" && webView.estimatedProgress >= 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.checkCurrentAppearance()
                self.injectLogo()
            }
        }
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

