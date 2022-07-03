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

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        webView.navigationDelegate = self
        webView.uiDelegate = self
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
}

extension AppDelegate {

    @IBAction func showWindow(_ sender: Any?) {
        window.makeKeyAndOrderFront(sender)
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

