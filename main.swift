import AppKit
import Carbon
import WebKit

enum AppError: Error {
    case invalidArguments
}

class AppConfig {
    let screen: NSScreen
    let size: NSSize
    let alpha: CGFloat
    let url: URL
    var origin: NSPoint {
        return NSPoint(x: screen.frame.size.width - size.width, y: 0)
    }

    init<T: Collection>(_ arguments: T) throws where T.Element == String {
        let argument: (Int, Int, String) -> String = { (item, count, fallback) in
            let omitted = max(count - arguments.count, 0)
            let offset = item - omitted
            let index = arguments.index(arguments.startIndex, offsetBy: offset)
            return arguments.indices.contains(index) ? arguments[index] : fallback
        }
        let screen: (String) throws -> NSScreen = {
            let screens = NSScreen.screens
            if let index = Int($0), screens.startIndex..<screens.endIndex ~= index {
                return screens[index]
            } else {
                throw AppError.invalidArguments
            }
        }
        let size: (String) throws -> NSSize = {
            if let height = Int($0), height >= 3 {
                return NSSize(width: height * 4 / 3, height: height)
            } else {
                throw AppError.invalidArguments
            }
        }
        let alpha: (String) throws -> CGFloat = {
            if let alpha = Float($0), 0...1 ~= alpha {
                return CGFloat(alpha)
            } else {
                throw AppError.invalidArguments
            }
        }
        let url: (String) throws -> URL = {
            if let url = URL(string: $0), url.scheme == "http" || url.scheme == "https" {
                return url
            } else {
                throw AppError.invalidArguments
            }
        }
        self.screen = try screen(argument(0, 4, "0"))
        self.size = try size(argument(1, 4, "150"))
        self.alpha = try alpha(argument(2, 4, "0.5"))
        self.url = try url(argument(3, 4, ""))
    }
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
            UInt32(kVK_Space), UInt32(optionKey),
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
        window.alphaValue = window.alphaValue != config.alpha ? config.alpha : 0
    }
}

try autoreleasepool {
    do {
        let config = try AppConfig(CommandLine.arguments.dropFirst())
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.delegate = AppDelegate(config)
        app.run()
    } catch let error as AppError {
        switch error {
        case .invalidArguments:
            print("loaf [screen] [height] [alpha] url")
        }
    }
}
