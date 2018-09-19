import AppKit
import Carbon
import WebKit

class AppConfig {
    let arguments: [String]

    init<T: Collection>(_ arguments: T) where T.Element == String {
        let starting = 1
        let count = 4
        let arguments = arguments.dropFirst(starting)
        let argument: (Int) -> String = { (item) in
            let omitted = max(count - arguments.count, 0)
            let offset = item - omitted
            let index = arguments.index(arguments.startIndex, offsetBy: offset)
            return arguments.indices.contains(index) ? arguments[index] : ""
        }
        self.arguments = (0..<count).map(argument)
    }

    lazy var screen: NSScreen = {
        let screens = NSScreen.screens
        if let index = Int(arguments[0]), screens.startIndex..<screens.endIndex ~= index {
            return screens[index]
        } else {
            return NSScreen.main!
        }
    }()

    lazy var size: NSSize = {
        if let height = Int(arguments[1]), height > 0 {
            let width = height * 4 / 3
            return NSSize(width: width, height: height)
        } else {
            let screenSize = screen.visibleFrame.size
            let width = Int(screenSize.width)
            let height = min(Int(screenSize.height), width * 3 / 4)
            return NSSize(width: width, height: height)
        }
    }()

    lazy var origin: NSPoint = {
        let screenFrame = screen.visibleFrame
        let x = Int(screenFrame.maxX - size.width)
        let y = Int(screenFrame.minY)
        return NSPoint(x: x, y: y)
    }()

    lazy var alpha: CGFloat = {
        if let alpha = Float(arguments[2]), 0...1 ~= alpha {
            return CGFloat(alpha)
        } else {
            return 0.1
        }
    }()

    lazy var url: URL = {
        if let url = URL(string: arguments[3]), url.scheme == "http" || url.scheme == "https" {
            return url
        } else {
            return URL(string: "https://www.google.com/")!
        }
    }()
}

class AppDelegate: NSObject, NSApplicationDelegate {
    let config: AppConfig
    lazy var window: NSWindow = {
        let window = NSWindow(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false, screen: config.screen)
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.backgroundColor = NSColor.clear
        window.alphaValue = config.alpha
        return window
    }()
    lazy var webview: WKWebView = {
        let configuration = WKWebViewConfiguration()
        let webview = WKWebView(frame: .zero, configuration: configuration)
        return webview
    }()
    var eventHotkey: EventHotKeyRef?
    var eventHandler: EventHandlerRef?

    init(_ config: AppConfig) {
        self.config = config
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        window.contentView = webview
        window.setContentSize(config.size)
        window.setFrameOrigin(config.origin)
        window.makeKeyAndOrderFront(self)
        webview.load(URLRequest(url: config.url))
        setupHotkey()
    }

    func setupHotkey() {
        RegisterEventHotKey(
            UInt32(kVK_Space), UInt32(shiftKey),
            EventHotKeyID(signature: "loaf".utf8.reduce(UInt32(0)) { ($0 << 8) + UInt32($1) }, id: 0),
            GetApplicationEventTarget(), OptionBits(kEventHotKeyNoOptions), &eventHotkey)
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (eventHandlerCall: EventHandlerCallRef?, event: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus in
                guard let selfPointer = userData else { return OSStatus(eventNotHandledErr) }
                Unmanaged<AppDelegate>.fromOpaque(selfPointer).takeUnretainedValue().handleHotkey()
                return noErr
            },
            1, [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))],
            Unmanaged.passUnretained(self).toOpaque(), &eventHandler)
    }

    func handleHotkey() {
        window.ignoresMouseEvents = true
        window.alphaValue = window.alphaValue != config.alpha ? config.alpha : 0
    }
}

autoreleasepool {
    let app = NSApplication.shared
    let config = AppConfig(CommandLine.arguments)
    let delegate = AppDelegate(config)
    app.setActivationPolicy(.accessory)
    app.delegate = delegate
    app.run()
}
