import Cocoa
import Foundation

// Headroom: one menu bar item per entry in accounts.json, filled by providers/<provider>.py.
// Providers report, this app only draws. No provider, plan or model name is written in this file;
// the shared output format is documented in providers/_common.py.

// Percent shown is REMAINING. Flip to true to show percent used instead.
let showUsed = false
let refreshSeconds: TimeInterval = 60

// MARK: - Where the accounts and providers live

/// User config: accounts.json and any providers you add. Override with HEADROOM_CONFIG_DIR.
let configDir: String = {
    if let d = ProcessInfo.processInfo.environment["HEADROOM_CONFIG_DIR"], !d.isEmpty { return (d as NSString).expandingTildeInPath }
    return NSHomeDirectory() + "/.config/headroom"
}()

/// Built-in providers ship inside the app (Contents/Resources/providers). Override with HEADROOM_PROVIDERS_DIR
/// to run the bare binary from a source checkout.
let bundledProvidersDir: String = {
    if let d = ProcessInfo.processInfo.environment["HEADROOM_PROVIDERS_DIR"], !d.isEmpty { return (d as NSString).expandingTildeInPath }
    return (Bundle.main.resourcePath ?? ".") + "/providers"
}()

let appVersion: String = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "dev"
let releasesURL = "https://github.com/jasherjoshuachan/headroom-bar/releases"

/// First run: a starter accounts.json with the one provider every Claude Code user has. Never overwrites a file.
func ensureConfig() {
    let fm = FileManager.default
    try? fm.createDirectory(atPath: configDir, withIntermediateDirectories: true)
    let path = configDir + "/accounts.json"
    if !fm.fileExists(atPath: path) {
        let starter = "[\n  {\"provider\": \"claude\", \"label\": \"C\"}\n]\n"
        try? starter.write(toFile: path, atomically: true, encoding: .utf8)
    }
}

/// A provider name is a file name: letters, digits, "-" and "_" only, so an accounts.json entry can't point elsewhere.
func validProviderName(_ name: String) -> Bool {
    !name.isEmpty && name.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil
}

struct Account {
    let provider: String
    let label: String
    let raw: [String: Any]
    var suffix = ""
    var id: String { "\(provider)-\(label)\(suffix)" }
    var displayName: String { (raw["name"] as? String) ?? provider.prefix(1).uppercased() + provider.dropFirst() }
}

func loadAccounts() -> [Account] {
    ensureConfig()
    let path = configDir + "/accounts.json"
    guard let data = FileManager.default.contents(atPath: path),
          let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
    var seen: [String: Int] = [:]
    return list.compactMap { entry in
        guard let p = entry["provider"] as? String, let l = entry["label"] as? String, !p.isEmpty, !l.isEmpty else { return nil }
        if entry["enabled"] as? Bool == false { return nil }
        // Two entries with the same provider and label still get their own item.
        let n = seen["\(p)-\(l)", default: 0]
        seen["\(p)-\(l)"] = n + 1
        return Account(provider: p, label: l, raw: entry, suffix: n == 0 ? "" : "#\(n + 1)")
    }
}

// MARK: - Icons (template images, loaded from the provider's installed app)

let iconHeight: CGFloat = 16
var iconCache: [String: NSImage] = [:]

func icon(from spec: [String: Any]?) -> NSImage? {
    guard let spec = spec, let path = spec["path"] as? String else { return nil }
    let style = spec["style"] as? String ?? "template"
    let key = "\(style):\(path)"
    if let hit = iconCache[key] { return hit }
    guard let img = NSImage(contentsOfFile: path) else { return nil }
    let made = style == "shape" ? shapeIcon(img) : sized(img, from: img.size)
    if let made = made { iconCache[key] = made }
    return made
}

func sized(_ img: NSImage, from size: NSSize) -> NSImage {
    img.size = NSSize(width: iconHeight * size.width / size.height, height: iconHeight)
    img.isTemplate = true
    return img
}

/// For apps that only ship a coloured icon on a white tile: everything that isn't white becomes the template shape.
func shapeIcon(_ img: NSImage) -> NSImage? {
    var full = NSRect(origin: .zero, size: img.size)
    guard let cg = img.cgImage(forProposedRect: &full, context: nil, hints: nil) else { return nil }
    let px = 128
    var buf = [UInt8](repeating: 0, count: px * px * 4)
    let cs = CGColorSpaceCreateDeviceRGB()
    let drawn: Bool = buf.withUnsafeMutableBytes { raw in
        guard let ctx = CGContext(data: raw.baseAddress, width: px, height: px, bitsPerComponent: 8,
                                  bytesPerRow: px * 4, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
        ctx.interpolationQuality = .high
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: px, height: px))
        return true
    }
    if !drawn { return nil }
    for i in 0..<(px * px) {
        let o = i * 4
        let alpha = Double(buf[o + 3]) / 255
        let rgbMin = alpha > 0 ? Double(min(buf[o], buf[o + 1], buf[o + 2])) / 255 / alpha : 1  // un-premultiply
        let a = alpha * min(1, max(0, (1 - rgbMin) / 0.35))
        buf[o] = 0; buf[o + 1] = 0; buf[o + 2] = 0
        buf[o + 3] = UInt8(max(0, min(255, a * 255)))
    }
    guard let provider = CGDataProvider(data: Data(buf) as CFData),
          let outCG = CGImage(width: px, height: px, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: px * 4,
                              space: cs, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                              provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    else { return nil }
    let result = NSImage(cgImage: outCG, size: NSSize(width: px, height: px))
    return sized(result, from: result.size)
}

// MARK: - Drawing: icon, bold label, then ALWAYS two small stacked rows

func barImage(icon: NSImage?, label: String, top: String, bottom: String) -> NSImage {
    let h: CGFloat = 22, gap: CGFloat = 4
    let labelAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12, weight: .bold), .foregroundColor: NSColor.black]
    let small: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: 9.5, weight: .regular), .foregroundColor: NSColor.black]
    let labelStr = NSAttributedString(string: label, attributes: labelAttrs)
    let rows = [NSAttributedString(string: top, attributes: small), NSAttributedString(string: bottom, attributes: small)]
    let iconW = icon.map { $0.size.width } ?? 0
    let textW = ceil(rows.map { $0.size().width }.max() ?? 0)   // width = longest row only
    let width = (iconW > 0 ? iconW + gap : 0) + ceil(labelStr.size().width) + gap + textW

    let img = NSImage(size: NSSize(width: width, height: h), flipped: false) { _ in
        var x: CGFloat = 0
        if let icon = icon {
            icon.draw(in: NSRect(x: 0, y: (h - icon.size.height) / 2, width: icon.size.width, height: icon.size.height))
            x += iconW + gap
        }
        let ls = labelStr.size()
        labelStr.draw(at: NSPoint(x: x, y: (h - ls.height) / 2))
        x += ceil(ls.width) + gap
        rows[0].draw(at: NSPoint(x: x, y: h / 2 - 1.5))
        rows[1].draw(at: NSPoint(x: x, y: -0.5))
        return true
    }
    img.isTemplate = true
    return img
}

// MARK: - Formatting

let isoPlain = ISO8601DateFormatter()

func parseDate(_ s: String?) -> Date? {
    guard let s = s else { return nil }
    // Round to the nearest minute: APIs wobble a few seconds around :00.
    // Drop any fractional seconds first: some APIs send 6 digits, which ISO8601DateFormatter rejects.
    let plain = s.replacingOccurrences(of: #"\.\d+"#, with: "", options: .regularExpression)
    guard let d = isoPlain.date(from: plain) else { return nil }
    return Date(timeIntervalSinceReferenceDate: (d.timeIntervalSinceReferenceDate / 60).rounded() * 60)
}

func fmt(_ d: Date, _ pattern: String) -> String {
    let f = DateFormatter(); f.dateFormat = pattern; f.amSymbol = "am"; f.pmSymbol = "pm"
    return f.string(from: d)
}

/// Shortest clear reset: "3:40p" within 20 hours, "Wed" within a week, else "22 Nov".
func shortReset(_ d: Date) -> String {
    let left = d.timeIntervalSinceNow
    if left < 20 * 3600 { return String(fmt(d, "h:mma").dropLast()) }
    if left < 7 * 86400 { return fmt(d, "EEE") }
    return fmt(d, "d MMM")
}

func longReset(_ d: Date) -> String { fmt(d, "EEE d MMM, h:mma") }

func pctText(_ m: [String: Any]) -> String? {
    guard let p = (m["pct"] as? NSNumber)?.intValue else { return nil }
    return "\(showUsed ? 100 - p : p)%"
}

/// One bar row from one meter: "62% 3:40p" or the meter's own short text.
func shortRow(_ m: [String: Any]) -> String {
    if let p = pctText(m) {
        if let d = parseDate(m["reset"] as? String) { return "\(p) \(shortReset(d))" }
        return p
    }
    return (m["text"] as? String) ?? "–"
}

/// One dropdown line from one meter: "5h: 62% left, resets Mon 16 Nov, 3:40pm".
func longRow(_ m: [String: Any]) -> String {
    let name = (m["name"] as? String) ?? "?"
    if let p = pctText(m) {
        var s = "\(name): \(p) \(showUsed ? "used" : "left")"
        if let d = parseDate(m["reset"] as? String) { s += ", resets \(longReset(d))" }
        return s
    }
    return "\(name): \((m["text"] as? String) ?? "–")"
}

// MARK: - App

class Headroom: NSObject, NSApplicationDelegate {
    var accounts: [Account] = []
    var items: [String: NSStatusItem] = [:]
    var timer: Timer?
    var refreshing = false
    var refreshAgainForce = false
    var refreshAgain = false   // a refresh was asked for while one was running, so run once more when it ends
    var generation = 0   // bumped on every reload, so a refresh started before a reload runs again after it
    let providerTimeout: TimeInterval = 20

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildItems()
        timer = Timer.scheduledTimer(withTimeInterval: refreshSeconds, repeats: true) { [weak self] _ in self?.refresh() }
    }

    func buildItems() {
        generation += 1
        for item in items.values { NSStatusBar.system.removeStatusItem(item) }
        items = [:]
        accounts = loadAccounts()
        if accounts.isEmpty {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            setBar(item, icon: nil, label: "H", top: "no", bottom: "accts")
            item.menu = makeMenu(header: "Headroom: no accounts in \(configDir)/accounts.json", lines: [])
            items["_none"] = item
            return
        }
        // macOS puts each new item to the LEFT of the previous one, so create right-to-left.
        for acct in accounts.reversed() {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            item.autosaveName = "headroom-\(acct.id)"
            setBar(item, icon: nil, label: acct.label, top: "…", bottom: "")
            item.menu = makeMenu(header: "\(acct.displayName) · \(acct.label)", lines: ["Loading…"])
            items[acct.id] = item
        }
        refresh()
    }

    func setBar(_ item: NSStatusItem, icon: NSImage?, label: String, top: String, bottom: String) {
        guard let b = item.button else { return }
        b.title = ""
        b.image = barImage(icon: icon, label: label, top: top, bottom: bottom)
        b.imagePosition = .imageOnly
    }

    func makeMenu(header: String, lines: [String], actions: [[String: Any]] = []) -> NSMenu {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: header, action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        for line in lines { menu.addItem(NSMenuItem(title: line, action: nil, keyEquivalent: "")) }
        menu.addItem(NSMenuItem.separator())
        // Provider actions: each is {"title": ..., "command": ...}. The app runs the command, it never interprets it.
        var added = false
        for a in actions {
            guard let title = a["title"] as? String, let command = a["command"] as? String,
                  !title.isEmpty, !command.isEmpty else { continue }
            let mi = NSMenuItem(title: title, action: #selector(actionClicked(_:)), keyEquivalent: "")
            mi.target = self
            if let checked = a["checked"] as? Bool { mi.state = checked ? .on : .off }   // a tick shows an on/off state
            mi.representedObject = ["title": title, "command": command]
            menu.addItem(mi)
            added = true
        }
        if added { menu.addItem(NSMenuItem.separator()) }
        for (title, sel, key) in [("Refresh Now", #selector(refreshClicked), "r"),
                                  ("Reload accounts.json", #selector(reloadClicked), "l"),
                                  ("Open Config Folder", #selector(openConfigClicked), ""),
                                  ("Releases and Updates…", #selector(releasesClicked), "")] {
            let mi = NSMenuItem(title: title, action: sel, keyEquivalent: key)
            mi.target = self
            menu.addItem(mi)
        }
        menu.addItem(NSMenuItem.separator())
        let version = NSMenuItem(title: "Headroom \(appVersion)", action: nil, keyEquivalent: "")
        menu.addItem(version)
        let quit = NSMenuItem(title: "Quit Headroom", action: #selector(quitClicked), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        return menu
    }

    /// Runs a provider action's shell command off the main thread. A failure is shown with the command's own output,
    /// so a guard message (for example "a job is running") reaches the user. Success refreshes the bar.
    @objc func actionClicked(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? [String: String],
              let title = info["title"], let command = info["command"] else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", command]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            var output = ""
            var ok = false
            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                ok = process.terminationStatus == 0
            } catch {
                output = "couldn't run the command: \(error.localizedDescription)"
            }
            DispatchQueue.main.async {
                if !ok {
                    NSApp.activate(ignoringOtherApps: true)   // an accessory app's alert can open behind other windows
                    let alert = NSAlert()
                    alert.messageText = "\(title) did not run"
                    alert.informativeText = String(output.suffix(600))
                    alert.runModal()
                }
                self.refresh()
            }
        }
    }

    @objc func refreshClicked() { refresh(force: true) }
    @objc func reloadClicked() { buildItems() }
    @objc func openConfigClicked() { ensureConfig(); NSWorkspace.shared.open(URL(fileURLWithPath: configDir)) }
    @objc func releasesClicked() { if let u = URL(string: releasesURL) { NSWorkspace.shared.open(u) } }
    @objc func quitClicked() { NSApplication.shared.terminate(nil) }

    func runProvider(_ acct: Account, force: Bool = false) -> [String: Any] {
        guard validProviderName(acct.provider) else {
            return ["status": "error", "error": "bad provider name \"\(acct.provider)\" (letters, digits, - and _ only)"]
        }
        // A provider you add in the config folder wins over a built-in of the same name.
        let userScript = "\(configDir)/providers/\(acct.provider).py"
        let builtIn = "\(bundledProvidersDir)/\(acct.provider).py"
        let script = FileManager.default.fileExists(atPath: userScript) ? userScript : builtIn
        guard FileManager.default.fileExists(atPath: script) else {
            return ["status": "error", "error": "no provider named \(acct.provider) (looked in \(configDir)/providers and the built-ins)"]
        }
        let arg = (try? JSONSerialization.data(withJSONObject: acct.raw)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [script, arg]
        var env = ProcessInfo.processInfo.environment
        env["PYTHONPATH"] = bundledProvidersDir   // so a provider in the config folder can `from _common import ...`
        if force { env["HEADROOM_FORCE"] = "1" }   // "Refresh Now" means a live reading: providers skip their cache
        process.environment = env
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            // A hung provider must not freeze the others: stop it after providerTimeout.
            var timedOut = false
            let killer = DispatchWorkItem { if process.isRunning { timedOut = true; process.terminate() } }
            DispatchQueue.global().asyncAfter(deadline: .now() + providerTimeout, execute: killer)
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            killer.cancel()
            if timedOut { return ["status": "error", "error": "provider took over \(Int(providerTimeout))s, stopped"] }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] { return json }
            return ["status": "error", "error": "provider printed no JSON (exit \(process.terminationStatus))"]
        } catch {
            return ["status": "error", "error": "couldn't run python3: \(error.localizedDescription)"]
        }
    }

    func refresh(force: Bool = false) {
        if refreshing { refreshAgain = true; refreshAgainForce = refreshAgainForce || force; return }
        refreshing = true
        let accts = accounts, gen = generation
        DispatchQueue.global(qos: .utility).async {
            var results: [String: [String: Any]] = [:]
            for acct in accts { results[acct.id] = self.runProvider(acct, force: force) }
            DispatchQueue.main.async {
                for acct in accts {
                    guard let item = self.items[acct.id], let r = results[acct.id] else { continue }
                    self.apply(r, to: item, acct: acct)
                }
                self.refreshing = false
                if gen != self.generation || self.refreshAgain {   // accounts reloaded, or a refresh was asked for meanwhile
                    self.refreshAgain = false
                    let again = self.refreshAgainForce
                    self.refreshAgainForce = false
                    self.refresh(force: again)
                }
            }
        }
    }

    func apply(_ r: [String: Any], to item: NSStatusItem, acct: Account) {
        let status = r["status"] as? String ?? "error"
        let meters = (r["meters"] as? [[String: Any]]) ?? []
        let hide = r["hide"] as? Bool ?? false
        if item.isVisible == hide { item.isVisible = !hide }

        let top: String, bottom: String
        switch status {
        case "ok":
            top = meters.count > 0 ? shortRow(meters[0]) : "no lim"
            bottom = meters.count > 1 ? shortRow(meters[1]) : "–"
        case "off": top = "off"; bottom = "–"
        default: top = "err"; bottom = "–"
        }
        setBar(item, icon: icon(from: r["icon"] as? [String: Any]), label: acct.label, top: top, bottom: bottom)

        var header = "\(acct.displayName) · \(acct.label)"
        if let plan = r["plan"] as? String { header += " (\(plan))" }
        if let title = r["title"] as? String { header += ": \(title)" }
        var lines = meters.map(longRow)
        if status == "ok" && meters.isEmpty { lines.append("No usage limits reported") }
        if let err = r["error"] as? String { lines.append((status == "ok" ? "Note: " : "") + err) }
        if r["stale"] as? Bool == true { lines.append("Showing the last good reading (source refused)") }
        item.menu = makeMenu(header: header + (showUsed ? " · used" : " · remaining"), lines: lines,
                             actions: (r["actions"] as? [[String: Any]]) ?? [])
    }
}

let app = NSApplication.shared
let delegate = Headroom()
app.delegate = delegate
app.setActivationPolicy(.accessory)  // menu bar only, no Dock icon
app.run()
