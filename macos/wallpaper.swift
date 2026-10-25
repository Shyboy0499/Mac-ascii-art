// wallpaper: shows a web page as the desktop wallpaper on every display, edge
// to edge, behind the menu bar too, under the desktop icons, on every Space.
// Clicks go straight through to the desktop.
//
//   swiftc -O macos/wallpaper.swift -o ascii-wallpaper
//   ./ascii-wallpaper                        # ./index.html
//   ./ascii-wallpaper "index.html?fps=10"    # with options
//   ./ascii-wallpaper https://shyboy0499.github.io/Mac-ascii-art/
//
// Quit with Ctrl-C, or `pkill ascii-wallpaper` when it runs in the background.

import Cocoa
import WebKit

// A URL, or a path to a local page with an optional ?query after it.
func target(_ arg: String) -> URL? {
    if arg.hasPrefix("http://") || arg.hasPrefix("https://") || arg.hasPrefix("file://") { return URL(string: arg) }
    let parts = arg.split(separator: "?", maxSplits: 1).map(String.init)
    let file = URL(fileURLWithPath: (parts[0] as NSString).expandingTildeInPath).standardizedFileURL
    guard FileManager.default.fileExists(atPath: file.path) else { return nil }
    var c = URLComponents(url: file, resolvingAgainstBaseURL: false)
    if parts.count > 1 { c?.query = parts[1] }
    return c?.url
}

final class Wallpaper: NSObject, NSApplicationDelegate, WKNavigationDelegate {
    let url: URL
    // one window a display, by its display ID
    var windows: [CGDirectDisplayID: NSWindow] = [:]

    init(url: URL) { self.url = url }

    func applicationDidFinishLaunching(_ notification: Notification) {
        update()
        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    // macOS sends this for far more than displays coming and going: waking
    // from sleep, the menu bar or the Dock showing. So wait for it to settle,
    // then touch only what really changed, and never reload a page that's
    // already showing: that's what made the wallpaper blink and start over.
    @objc func screensChanged() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(update), object: nil)
        perform(#selector(update), with: nil, afterDelay: 0.5)
    }

    @objc func update() {
        var seen = Set<CGDirectDisplayID>()
        for screen in NSScreen.screens {
            guard let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value else { continue }
            seen.insert(id)
            if let window = windows[id] {
                if window.frame != screen.frame { window.setFrame(screen.frame, display: true) }
            } else {
                windows[id] = makeWindow(for: screen)
            }
        }
        for (id, window) in windows where !seen.contains(id) {
            NotificationCenter.default.removeObserver(self, name: NSWindow.didChangeOcclusionStateNotification, object: window)
            window.close()
            windows[id] = nil
        }
    }

    func makeWindow(for screen: NSScreen) -> NSWindow {
        // the whole screen, not just the part below the menu bar
        let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        // just above the system wallpaper, below the desktop icons
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.backgroundColor = NSColor(srgbRed: 0.043, green: 0.059, blue: 0.098, alpha: 1)
        // hidden until the page has drawn, so it never flashes white
        window.alphaValue = 0

        let web = WKWebView(frame: NSRect(origin: .zero, size: screen.frame.size), configuration: WKWebViewConfiguration())
        web.autoresizingMask = [.width, .height]
        web.navigationDelegate = self
        // WebKit treats a page whose window is covered by other windows as
        // hidden: it stops drawing it, and when the window is uncovered it
        // shows the empty window for a few frames before the page paints
        // again. Under a tiling window manager the wallpaper is nearly always
        // covered, so that was a blink on every workspace switch. This private
        // switch turns that off; it only takes effect before the view goes in
        // its window, and is checked first in case a macOS drops it.
        if web.responds(to: Selector(("_setWindowOcclusionDetectionEnabled:"))) {
            web.setValue(false, forKey: "windowOcclusionDetectionEnabled")
        }
        window.contentView = web
        loadPage(web)
        window.setFrame(screen.frame, display: false)
        window.orderFront(nil)
        // pause the animation ourselves while covered, keeping what's drawn
        NotificationCenter.default.addObserver(
            self, selector: #selector(occlusionChanged(_:)),
            name: NSWindow.didChangeOcclusionStateNotification, object: window)
        return window
    }

    @objc func occlusionChanged(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, let web = window.contentView as? WKWebView else { return }
        syncPause(web)
    }

    // Tell the page whether anyone can see it. Its animation stops while it's
    // covered, but WebKit keeps the last frame, so it's there the moment the
    // windows move away. Pages without the hook just keep running.
    func syncPause(_ web: WKWebView) {
        guard let window = web.window else { return }
        let covered = !window.occlusionState.contains(.visible)
        web.evaluateJavaScript("window.__setPaused && window.__setPaused(\(covered))", completionHandler: nil)
    }

    func loadPage(_ web: WKWebView) {
        if url.isFileURL {
            web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            web.load(URLRequest(url: url))
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // match the window to the page's own background, so if anything ever
        // does show through for a frame it's the same colour
        webView.evaluateJavaScript("getComputedStyle(document.body).backgroundColor") { result, _ in
            guard let css = result as? String else { return }
            let n = css.split(whereSeparator: { !"0123456789.".contains($0) }).compactMap { Double($0) }
            guard n.count >= 3 else { return }
            let color = NSColor(srgbRed: n[0] / 255, green: n[1] / 255, blue: n[2] / 255, alpha: 1)
            webView.window?.backgroundColor = color
            if #available(macOS 12.0, *) { webView.underPageBackgroundColor = color }
        }
        syncPause(webView)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { webView.window?.alphaValue = 1 }
    }

    // if macOS stops the page's process (low memory, say), bring it back
    // instead of leaving the screen blank
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.window?.alphaValue = 0
        loadPage(webView)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        FileHandle.standardError.write("wallpaper: \(error.localizedDescription)\n".data(using: .utf8)!)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        FileHandle.standardError.write("wallpaper: \(error.localizedDescription)\n".data(using: .utf8)!)
    }
}

let arg = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "index.html"
guard let url = target(arg) else {
    FileHandle.standardError.write("wallpaper: can't find \(arg)\nusage: ascii-wallpaper [URL | path/to/index.html[?options]]\n".data(using: .utf8)!)
    exit(1)
}

signal(SIGINT) { _ in exit(0) }
let app = NSApplication.shared
app.setActivationPolicy(.accessory) // no Dock icon, no menu bar
let wallpaper = Wallpaper(url: url)
app.delegate = wallpaper
app.run()
