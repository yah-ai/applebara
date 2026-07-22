import AppKit
import Carbon.HIToolbox

// ── Hotkey config ─────────────────────────────────────────────────────────
// Default: Option+Space (no conflict with Spotlight, works immediately).
// After you free Cmd+Space (System Settings ▸ Keyboard ▸ Shortcuts ▸ Spotlight),
// change `hotMods` to UInt32(cmdKey) and rebuild to take over Cmd+Space.
let hotKeyCode: UInt32 = UInt32(kVK_Space)
let hotMods: UInt32 = UInt32(optionKey)

// ── App index ─────────────────────────────────────────────────────────────
struct App { let name: String; let path: String; let lname: String }

func scanApps() -> [App] {
    let dirs = ["/Applications", "/Applications/Utilities",
                "/System/Applications", "/System/Applications/Utilities",
                NSHomeDirectory() + "/Applications"]
    var seen = Set<String>(); var out: [App] = []
    let fm = FileManager.default
    for d in dirs {
        guard let items = try? fm.contentsOfDirectory(atPath: d) else { continue }
        for it in items where it.hasSuffix(".app") {
            let name = String(it.dropLast(4))
            if seen.contains(name) { continue }
            seen.insert(name)
            out.append(App(name: name, path: d + "/" + it, lname: name.lowercased()))
        }
    }
    return out.sorted { $0.lname < $1.lname }
}

// subsequence fuzzy match; returns score (lower = better) or nil
func score(_ query: String, _ app: App) -> Int? {
    if query.isEmpty { return 0 }
    let q = query.lowercased(); let n = app.lname
    if n.hasPrefix(q) { return 0 }
    if let r = n.range(of: q) { return 1 + n.distance(from: n.startIndex, to: r.lowerBound) }
    // subsequence
    var qi = q.startIndex
    for c in n { if qi < q.endIndex && c == q[qi] { qi = q.index(after: qi) } }
    return qi == q.endIndex ? 100 + n.count : nil
}

// ── Search field that forwards arrows / enter / esc, text vertically centered ─
final class VCenterCell: NSTextFieldCell {
    private func centered(_ rect: NSRect) -> NSRect {
        let h = cellSize(forBounds: rect).height
        guard h < rect.height else { return rect }
        var r = rect; r.origin.y += (rect.height - h) / 2; r.size.height = h; return r
    }
    override func drawingRect(forBounds rect: NSRect) -> NSRect { super.drawingRect(forBounds: centered(rect)) }
    override func titleRect(forBounds rect: NSRect) -> NSRect { super.titleRect(forBounds: centered(rect)) }
    override func edit(withFrame rect: NSRect, in view: NSView, editor: NSText, delegate: Any?, event: NSEvent?) {
        super.edit(withFrame: centered(rect), in: view, editor: editor, delegate: delegate, event: event)
    }
    override func select(withFrame rect: NSRect, in view: NSView, editor: NSText, delegate: Any?, start: Int, length: Int) {
        super.select(withFrame: centered(rect), in: view, editor: editor, delegate: delegate, start: start, length: length)
    }
}

final class SearchField: NSTextField {
    override class var cellClass: AnyClass? {
        get { VCenterCell.self }
        set { }
    }
    var onKey: ((Selector) -> Bool)?
    override func performKeyEquivalent(with e: NSEvent) -> Bool { super.performKeyEquivalent(with: e) }
}

final class Panel: NSPanel {
    override var canBecomeKey: Bool { true }
}

// ── One app tile (big icon + name) ─────────────────────────────────────────
let kMaxResults = 4
let kCellW: CGFloat = 128
let kIcon: CGFloat = 72

final class Cell: NSView {
    let icon = NSImageView()
    let label = NSTextField(labelWithString: "")
    let sel = NSView()
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        sel.wantsLayer = true
        sel.layer?.cornerRadius = 14
        sel.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.18).cgColor
        sel.isHidden = true
        addSubview(sel)
        icon.imageScaling = .scaleProportionallyUpOrDown
        addSubview(icon)
        label.alignment = .center
        label.font = .systemFont(ofSize: 12)
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 2
        label.cell?.wraps = true
        label.textColor = .labelColor
        addSubview(label)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layout() {
        sel.frame = bounds.insetBy(dx: 4, dy: 4)
        icon.frame = NSRect(x: (bounds.width - kIcon)/2, y: bounds.height - kIcon - 12, width: kIcon, height: kIcon)
        label.frame = NSRect(x: 6, y: 8, width: bounds.width - 12, height: 32)
    }
    func set(_ a: App?) {
        if let a = a {
            icon.image = NSWorkspace.shared.icon(forFile: a.path)
            label.stringValue = a.name
        } else { icon.image = nil; label.stringValue = "" }
    }
    func highlight(_ on: Bool) { sel.isHidden = !on }
}

// ── One list row (small icon + name, for the expanded list) ────────────────
let kListMax = 10
let kListRowH: CGFloat = 34

final class ListRow: NSView {
    let icon = NSImageView()
    let label = NSTextField(labelWithString: "")
    let sel = NSView()
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        sel.wantsLayer = true
        sel.layer?.cornerRadius = 8
        sel.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.18).cgColor
        sel.isHidden = true
        addSubview(sel)
        icon.imageScaling = .scaleProportionallyUpOrDown
        addSubview(icon)
        label.font = .systemFont(ofSize: 15)
        label.lineBreakMode = .byTruncatingTail
        label.textColor = .labelColor
        addSubview(label)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layout() {
        sel.frame = bounds.insetBy(dx: 6, dy: 2)
        icon.frame = NSRect(x: 16, y: (bounds.height-22)/2, width: 22, height: 22)
        label.frame = NSRect(x: 48, y: (bounds.height-20)/2, width: bounds.width - 60, height: 20)
    }
    func set(_ a: App?) {
        if let a = a {
            icon.image = NSWorkspace.shared.icon(forFile: a.path)
            label.stringValue = a.name
        } else { icon.image = nil; label.stringValue = "" }
    }
    func highlight(_ on: Bool) { sel.isHidden = !on }
}

// ── Controller ────────────────────────────────────────────────────────────
final class Controller: NSObject, NSTextFieldDelegate {
    var apps: [App] = []
    var results: [App] = []
    var sel = 0
    var expanded = false
    var topY: CGFloat = 0            // fixed top edge so the field never jumps
    var panel: Panel!
    var field: SearchField!
    var bg: NSVisualEffectView!
    var cells: [Cell] = []           // collapsed: row of 4 tiles
    var rows: [ListRow] = []         // expanded: list of 10
    var hotRef: EventHotKeyRef?

    let pad: CGFloat = 12
    let fieldH: CGFloat = 46
    var w: CGFloat { kCellW * CGFloat(kMaxResults) + pad*2 }
    var tileRowH: CGFloat { kIcon + 52 }
    var collapsedH: CGFloat { fieldH + tileRowH + pad }
    var expandedH: CGFloat { fieldH + kListRowH * CGFloat(kListMax) + pad }
    var searchOnlyH: CGFloat { fieldH + pad }

    func build() {
        apps = scanApps()
        panel = Panel(contentRect: NSRect(x: 0, y: 0, width: w, height: collapsedH),
                      styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
                      backing: .buffered, defer: false)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.hidesOnDeactivate = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true

        bg = NSVisualEffectView(frame: panel.contentView!.bounds)
        bg.autoresizingMask = [.width, .height]
        bg.material = .hudWindow; bg.state = .active; bg.blendingMode = .behindWindow
        bg.wantsLayer = true; bg.layer?.cornerRadius = 16; bg.layer?.masksToBounds = true
        panel.contentView = bg

        field = SearchField(frame: .zero)
        field.autoresizingMask = [.width, .minYMargin]
        field.font = .systemFont(ofSize: 22, weight: .light)
        field.placeholderString = "Search your apps — type 2 letters"
        field.isBezeled = false; field.drawsBackground = false; field.focusRingType = .none
        field.delegate = self
        bg.addSubview(field)

        for _ in 0..<kMaxResults { let c = Cell(frame: .zero); cells.append(c); bg.addSubview(c) }
        for _ in 0..<kListMax { let r = ListRow(frame: .zero); rows.append(r); bg.addSubview(r) }

        layoutViews()
        reload("")
    }

    func layoutViews() {
        let h = desiredH()
        field.frame = NSRect(x: pad, y: h - fieldH, width: w - pad*2, height: 34)
        for (i, c) in cells.enumerated() {
            c.frame = NSRect(x: pad + CGFloat(i)*kCellW, y: pad - 4, width: kCellW, height: tileRowH)
            c.isHidden = expanded
        }
        for (i, r) in rows.enumerated() {
            r.frame = NSRect(x: pad, y: h - fieldH - kListRowH*CGFloat(i+1), width: w - pad*2, height: kListRowH)
            r.isHidden = !expanded
        }
    }

    func desiredH() -> CGFloat {
        if results.isEmpty { return searchOnlyH }
        return expanded ? expandedH : collapsedH
    }

    func applyHeight() {
        let h = desiredH()
        var f = panel.frame
        f.origin.y = topY - h
        f.size.height = h
        panel.setFrame(f, display: true, animate: false)
        layoutViews()
        render()
    }

    func reload(_ q: String) {
        let query = q.trimmingCharacters(in: .whitespaces)
        if query.count < 2 {
            results = []; sel = 0; expanded = false; applyHeight(); return
        }
        var scored: [(app: App, s: Int)] = []
        for a in apps { if let s = score(query, a) { scored.append((a, s)) } }
        scored.sort { (l, r) in l.s != r.s ? l.s < r.s : l.app.lname < r.app.lname }
        results = scored.prefix(kListMax).map { $0.app }
        sel = 0
        applyHeight()
    }

    var visibleCount: Int { min(results.count, expanded ? kListMax : kMaxResults) }

    func render() {
        for (i, c) in cells.enumerated() {
            let has = !expanded && i < results.count
            c.set(has ? results[i] : nil)
            c.isHidden = !has
            c.highlight(has && i == sel)
        }
        for (i, r) in rows.enumerated() {
            let has = expanded && i < results.count
            r.set(has ? results[i] : nil)
            r.isHidden = !has
            r.highlight(has && i == sel)
        }
    }

    func expand()   { guard !expanded, !results.isEmpty else { return }; expanded = true;  applyHeight() }
    func collapse() { guard expanded else { return }; expanded = false; if sel >= kMaxResults { sel = kMaxResults-1 }; applyHeight() }

    // NSTextField delegate
    func controlTextDidChange(_ obj: Notification) { reload(field.stringValue) }

    func control(_ c: NSControl, textView: NSTextView, doCommandBy s: Selector) -> Bool {
        switch s {
        case #selector(NSResponder.moveDown(_:)):
            if !expanded { expand() } else { move(+1) }; return true
        case #selector(NSResponder.moveUp(_:)):
            if expanded && sel == 0 { collapse() } else { move(-1) }; return true
        case #selector(NSResponder.moveRight(_:)), #selector(NSResponder.insertTab(_:)):
            if !expanded { move(+1) }; return true
        case #selector(NSResponder.moveLeft(_:)):
            if !expanded { move(-1) }; return true
        case #selector(NSResponder.insertNewline(_:)):
            openSelected(); return true
        case #selector(NSResponder.cancelOperation(_:)):
            if expanded { collapse() } else { hide() }; return true
        default: return false
        }
    }

    func move(_ d: Int) {
        guard !results.isEmpty else { return }
        sel = max(0, min(visibleCount - 1, sel + d))
        render()
    }

    @objc func openSelected() {
        guard sel >= 0, sel < results.count else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: results[sel].path))
        hide()
    }

    func show() {
        if apps.isEmpty { apps = scanApps() }
        expanded = false
        field.stringValue = ""
        // position collapsed panel, then record its top edge
        if let scr = NSScreen.main {
            let x = scr.frame.midX - w/2
            let y = scr.frame.midY - searchOnlyH/2 + scr.frame.height*0.18
            panel.setFrame(NSRect(x: x, y: y, width: w, height: searchOnlyH), display: false)
            topY = y + searchOnlyH
        }
        layoutViews()
        reload("")
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(field)
    }
    func hide() { panel.orderOut(nil) }
    @objc func toggle() { panel.isVisible ? hide() : show() }
}

// ── Global hotkey plumbing (Carbon; no Accessibility permission needed) ────
let controller = Controller()
var gToggle: () -> Void = { }

func installHotKey() {
    let hkID = EventHotKeyID(signature: OSType(0x4150424b), id: 1) // 'APBK'
    var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    InstallEventHandler(GetApplicationEventTarget(), { _, _, _ -> OSStatus in
        DispatchQueue.main.async { gToggle() }
        return noErr
    }, 1, &spec, nil, nil)
    RegisterEventHotKey(hotKeyCode, hotMods, hkID, GetApplicationEventTarget(), 0, &controller.hotRef)
}

// ── App ────────────────────────────────────────────────────────────────────
final class AppDelegate: NSObject, NSApplicationDelegate {
    var status: NSStatusItem!
    func applicationDidFinishLaunching(_ n: Notification) {
        NSApp.setActivationPolicy(.accessory)
        controller.build()
        gToggle = { [weak controller] in controller?.toggle() }
        installHotKey()
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let url = Bundle.main.url(forResource: "menubar", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            let barH: CGFloat = 18
            let aspect = img.size.width / max(img.size.height, 1)
            img.size = NSSize(width: barH * aspect, height: barH)   // keep the wide capybara shape
            img.isTemplate = true                                    // macOS tints for light/dark menu bar
            status.button?.image = img
        } else {
            status.button?.title = "🦫"
        }
        let m = NSMenu()
        m.addItem(NSMenuItem(title: "Open Applebara  (⌥Space)", action: #selector(open), keyEquivalent: ""))
        m.items.last?.target = self
        m.addItem(.separator())
        m.addItem(NSMenuItem(title: "Quit Applebara", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        status.menu = m
    }
    @objc func open() { controller.show() }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
