import Cocoa
import Carbon.HIToolbox

private let hotKeySignature: OSType = 0x434E5244 // 'CNRD'

private func hotKeyHandler(_ nextHandler: EventHandlerCallRef?,
                           _ event: EventRef?,
                           _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let event = event else { return OSStatus(eventNotHandledErr) }
    var hkID = EventHotKeyID()
    let st = GetEventParameter(event,
                               EventParamName(kEventParamDirectObject),
                               EventParamType(typeEventHotKeyID),
                               nil,
                               MemoryLayout<EventHotKeyID>.size,
                               nil,
                               &hkID)
    if st != noErr { return st }
    DispatchQueue.main.async {
        (NSApp.delegate as? AppDelegate)?.toggleWindow()
    }
    return noErr
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var statusItem: NSStatusItem?
    private var hotKeyRef: EventHotKeyRef?
    private let store = StationStore()
    private let player = PlayerEngine()
    private var mainVC: MainViewController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        buildMenu()
        buildWindow()
        buildStatusItem()
        installHotKey()
        showWindow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showWindow() }
        return true
    }

    private func buildMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "关于 城市电台",
                        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                        keyEquivalent: "")
        appMenu.addItem(.separator())
        let hideItem = NSMenuItem(title: "隐藏窗口", action: #selector(hideWindow), keyEquivalent: "w")
        hideItem.target = self
        appMenu.addItem(hideItem)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "退出 城市电台", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenu.addItem(withTitle: "拷贝", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        let playItem = NSMenuItem()
        let playMenu = NSMenu(title: "播放")
        let playPause = NSMenuItem(title: "播放 / 暂停", action: #selector(togglePlay), keyEquivalent: "p")
        playPause.target = self
        playMenu.addItem(playPause)
        let stopItem = NSMenuItem(title: "停止", action: #selector(stopPlay), keyEquivalent: ".")
        stopItem.target = self
        playMenu.addItem(stopItem)
        playItem.submenu = playMenu
        mainMenu.addItem(playItem)

        NSApp.mainMenu = mainMenu
    }

    private func buildWindow() {
        let vc = MainViewController(store: store, player: player)
        mainVC = vc
        player.onChange = { [weak self] in
            self?.mainVC?.updatePlayerUI()
        }
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
                         styleMask: [.titled, .closable, .miniaturizable, .resizable],
                         backing: .buffered,
                         defer: false)
        w.title = "城市电台"
        vc.view.frame = NSRect(x: 0, y: 0, width: 900, height: 600)
        w.contentView = vc.view
        w.setFrame(NSRect(x: 0, y: 0, width: 900, height: 640), display: true)
        w.isReleasedWhenClosed = false
        w.setContentSize(NSSize(width: 900, height: 600))
        w.center()
        w.minSize = NSSize(width: 780, height: 480)
        window = w
        // 启动即续播上次关闭前的电台
        DispatchQueue.main.async { vc.autoResumeLast() }
    }

    private func buildStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            if let p = Bundle.main.path(forResource: "menuicon", ofType: "png"),
               let img = NSImage(contentsOfFile: p) {
                img.size = NSSize(width: 18, height: 18)
                button.image = img
            } else {
                let cfg = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
                let img = NSImage(systemSymbolName: "radio", accessibilityDescription: "城市电台")?
                    .withSymbolConfiguration(cfg)
                img?.isTemplate = true
                button.image = img
            }
            button.toolTip = "城市电台 · ⌃⌥⌘F 唤出"
        }
        let menu = NSMenu()
        let showItem = NSMenuItem(title: "显示窗口（⌃⌥⌘F）", action: #selector(showWindow), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)
        menu.addItem(.separator())
        let pp = NSMenuItem(title: "播放 / 暂停", action: #selector(togglePlay), keyEquivalent: "")
        pp.target = self
        menu.addItem(pp)
        let stopItem = NSMenuItem(title: "停止", action: #selector(stopPlay), keyEquivalent: "")
        stopItem.target = self
        menu.addItem(stopItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        item.menu = menu
        statusItem = item
    }

    private func installHotKey() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), hotKeyHandler, 1, &spec, nil, nil)

        var ref: EventHotKeyRef?
        let hkID = EventHotKeyID(signature: hotKeySignature, id: 1)
        let mods = UInt32(controlKey | optionKey | cmdKey)
        let status = RegisterEventHotKey(UInt32(kVK_ANSI_F), mods, hkID,
                                         GetApplicationEventTarget(), 0, &ref)
        if status == noErr { hotKeyRef = ref }
    }

    private var firstShow = true

    @objc private func showWindow() {
        guard let w = window else { return }
        if firstShow {
            firstShow = false
            w.setFrame(NSRect(x: 0, y: 0, width: 900, height: 640), display: true)
            w.center()
        }
        w.makeKeyAndOrderFront(nil)
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func toggleWindow() {
        guard let w = window else { return }
        if w.isVisible && w.isKeyWindow {
            w.orderOut(nil)
            NSApp.hide(nil)
        } else {
            showWindow()
        }
    }

    @objc private func hideWindow() {
        window?.orderOut(nil)
        NSApp.hide(nil)
    }

    @objc func togglePlay() {
        mainVC?.playPause()
    }

    @objc private func stopPlay() {
        mainVC?.stopPlay()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
