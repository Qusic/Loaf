import Foundation
import AppKit
import WebKit

class AppDelegate: NSObject, NSApplicationDelegate {
    lazy var window: NSWindow = {
        let window = NSWindow(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.ignoresMouseEvents = true
        window.backgroundColor = NSColor.clear
        window.alphaValue = 0.5
        return window
    }()
    lazy var webview: WKWebView = {
        let configuration = WKWebViewConfiguration()
        let webview = WKWebView(frame: .zero, configuration: configuration)
        return webview
    }()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        window.contentView = webview
        window.setContentSize(NSMakeSize(200, 150))
        window.makeKeyAndOrderFront(self)
    }
}

autoreleasepool {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    app.delegate = AppDelegate()
    app.run()
}
