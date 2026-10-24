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
    var windows: [NSWindow] = []

    init(url: URL) { self.url = url }

    func applicationDidFinishLaunching(_ notification: Notification) {
        show()
        // displays plugged in, unplugged or rearranged
        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    @objc func screensChanged() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(show), object: nil)
        perform(#selector(show), with: nil, afterDelay: 1)
    }

    @objc func show() {
        windows.forEach { $0.close() }
        windows = NSScreen.screens.map { screen in
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
            window.contentView = web
            if url.isFileURL {
                web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
            } else {
                web.load(URLRequest(url: url))
            }
            window.setFrame(screen.frame, display: false)
            window.orderFront(nil)
            return window
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { webView.window?.alphaValue = 1 }
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
