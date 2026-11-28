import AppKit
import Foundation
import Translation
import Carbon
import ApplicationServices
import NaturalLanguage

@MainActor
final class TranslationPanel: NSPanel {
    private let visibleFrame: NSRect
    private let bodyWidth: CGFloat
    private let source: String
    private let resultFontSize: CGFloat
    private let stack = NSStackView()
    private let scroll = NSScrollView()
    private let result = NSTextView(usingTextLayoutManager: false)
    private var scrollHeight: NSLayoutConstraint!
    let copyButton: NSButton

    override var canBecomeKey: Bool { true }

    init(source: String, result initialResult: String, target: AnyObject, copyAction: Selector, permissionAction: Selector?) {
        let pointer = NSEvent.mouseLocation
        visibleFrame = NSScreen.screens.first(where: { NSMouseInRect(pointer, $0.frame, false) })?.visibleFrame
            ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let width = min(source.isEmpty ? 364 : 460, visibleFrame.width - 24)
        let inset: CGFloat = 16
        bodyWidth = width - 2 * inset
        self.source = source.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        resultFontSize = source.isEmpty ? 14 : 17
        copyButton = NSButton(title: "拷贝译文", target: target, action: copyAction)
        super.init(contentRect: NSRect(x: pointer.x - 60, y: pointer.y - 12, width: width, height: 0),
                   styleMask: .borderless, backing: .buffered, defer: false)

        title = "离线翻译为中文"
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isReleasedWhenClosed = false
        isFloatingPanel = true
        isMovableByWindowBackground = true
        level = .floating
        collectionBehavior = .fullScreenAuxiliary

        // Anchor dark ink against both light documents and dark reader backgrounds.
        let glass = NSGlassEffectView()
        glass.style = .clear
        glass.cornerRadius = 24
        let surface = NSView()
        surface.appearance = NSAppearance(named: .aqua)
        surface.wantsLayer = true
        surface.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.55).cgColor
        surface.layer?.cornerRadius = glass.cornerRadius
        surface.layer?.cornerCurve = .continuous
        glass.contentView = surface
        contentView = glass

        let heading = NSTextField(labelWithString: "离线翻译")
        heading.font = .systemFont(ofSize: 13, weight: .semibold)
        heading.textColor = NSColor(white: 0.12, alpha: 1)
        heading.setContentHuggingPriority(.required, for: .horizontal)
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        copyButton.bezelStyle = .recessed
        copyButton.controlSize = .small
        copyButton.isEnabled = false
        copyButton.isHidden = true
        let close = NSButton(image: NSImage(systemSymbolName: "xmark", accessibilityDescription: "关闭")!,
                             target: self, action: #selector(dismissPanel))
        close.bezelStyle = .recessed
        close.contentTintColor = .black
        close.isBordered = false
        close.controlSize = .small
        close.keyEquivalent = "\u{1b}"
        close.toolTip = "关闭（Esc）"
        close.setAccessibilityLabel("关闭")

        let actionButton: NSButton
        if let permissionAction {
            let settings = NSButton(title: "打开设置", target: target, action: permissionAction)
            settings.bezelStyle = .recessed
            settings.controlSize = .small
            actionButton = settings
        } else {
            actionButton = copyButton
        }

        actionButton.isBordered = false
        actionButton.attributedTitle = NSAttributedString(string: actionButton.title, attributes: [.foregroundColor: NSColor.black, .font: NSFont.systemFont(ofSize: 12, weight: .medium)])

        let header = NSStackView(views: [heading, spacer, actionButton, close])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 6
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        surface.addSubview(stack)
        stack.addArrangedSubview(header)
        header.widthAnchor.constraint(equalToConstant: bodyWidth).isActive = true

        scroll.drawsBackground = false
        scroll.scrollerStyle = .overlay
        scroll.borderType = .noBorder
        result.isEditable = false
        result.isSelectable = true
        result.isRichText = false
        result.drawsBackground = false
        result.isHorizontallyResizable = false
        result.isVerticallyResizable = false
        result.textContainerInset = .zero
        result.textContainer?.lineFragmentPadding = 0
        result.textContainer?.widthTracksTextView = false
        result.textContainer?.containerSize = NSSize(width: bodyWidth, height: .greatestFiniteMagnitude)
        result.setAccessibilityLabel("原文和译文")
        scroll.documentView = result
        stack.addArrangedSubview(scroll)
        scrollHeight = scroll.heightAnchor.constraint(equalToConstant: 1)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: surface.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: surface.leadingAnchor, constant: inset),
            stack.widthAnchor.constraint(equalToConstant: bodyWidth),
            scroll.widthAnchor.constraint(equalToConstant: bodyWidth),
            scrollHeight
        ])
        setResult(initialResult)
    }

    func setResult(_ text: String) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        paragraph.paragraphSpacing = 5
        let displayText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = NSMutableAttributedString()
        if !source.isEmpty {
            let sourceStyle = NSMutableParagraphStyle()
            sourceStyle.lineSpacing = 1
            sourceStyle.paragraphSpacing = 9
            body.append(NSAttributedString(string: source + "\n", attributes: [
                .font: NSFont.systemFont(ofSize: 13),
                .foregroundColor: NSColor(white: 0.12, alpha: 1),
                .paragraphStyle: sourceStyle
            ]))
        }
        let translationStart = body.length
        body.append(NSAttributedString(string: displayText, attributes: [
            .font: NSFont.systemFont(ofSize: resultFontSize),
            .foregroundColor: NSColor(white: 0.045, alpha: 1),
            .paragraphStyle: paragraph
        ]))
        result.textStorage?.setAttributedString(body)
        var resultHeight: CGFloat = 22
        if let layout = result.layoutManager, let container = result.textContainer {
            layout.ensureLayout(for: container)
            resultHeight = max(resultHeight, ceil(layout.usedRect(for: container).maxY) + 2)
        }

        let chromeHeight = ceil(stack.fittingSize.height - scrollHeight.constant) + 28
        let maximumHeight = min(visibleFrame.height - 24, max(180, visibleFrame.height * 0.68))
        let viewportHeight = min(resultHeight, max(44, maximumHeight - chromeHeight))
        scroll.hasVerticalScroller = viewportHeight < resultHeight
        scrollHeight.constant = viewportHeight
        result.frame = NSRect(x: 0, y: 0, width: bodyWidth, height: resultHeight)
        scroll.contentView.scroll(to: .zero)
        scroll.reflectScrolledClipView(scroll.contentView)

        var resized = frame
        resized.size.height = chromeHeight + viewportHeight
        resized.origin.y = max(visibleFrame.minY + 12, min(frame.maxY, visibleFrame.maxY - 12) - resized.height)
        resized.origin.x = min(max(frame.minX, visibleFrame.minX + 12), visibleFrame.maxX - 12 - resized.width)
        setFrame(resized, display: true)
        contentView?.layoutSubtreeIfNeeded()
        if viewportHeight < resultHeight, translationStart < body.length {
            result.scrollRangeToVisible(NSRange(location: translationStart, length: 1))
        }
        invalidateShadow()
    }

    @objc private func dismissPanel() { close() }

    override func cancelOperation(_ sender: Any?) { close() }
}

@MainActor
enum OfflineTextTranslation {
    static func translate(_ input: String, with engine: TranslationSession) async throws -> String {
        let translated = try await translatePreservingTerms(input, with: engine)
        guard translated.contains("\u{FFFD}") else { return translated }

        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.setLanguage(.english)
        tokenizer.string = input
        let tokens = tokenizer.tokens(for: input.startIndex..<input.endIndex)
        guard !tokens.isEmpty else { return "\(input)（未能完整翻译）" }

        var result = ""
        var previousEnd = input.startIndex
        for token in tokens {
            try Task.checkCancellation()
            if input[previousEnd..<token.lowerBound].contains(where: \.isNewline) {
                result += "\n"
            }
            let sentence = String(input[token])
            let retried = try await translatePreservingTerms(sentence, with: engine)
            result += retried.contains("\u{FFFD}") ? "\(sentence)（未能完整翻译）" : retried
            previousEnd = token.upperBound
        }
        return result
    }

    private static func translatePreservingTerms(_ input: String, with engine: TranslationSession) async throws -> String {
        // The offline model sometimes drops or corrupts these phase names.
        let terms = [("austenite", "奥氏体"), ("martensite", "马氏体")]
        var marked = input
        var replacements: [(token: String, chinese: String, count: Int)] = []
        for (index, term) in terms.enumerated() {
            let token = "[[\(index + 1)]]"
            guard !input.contains(token) else { continue }
            let updated = marked.replacingOccurrences(of: "\\b\(term.0)\\b", with: token, options: [.regularExpression, .caseInsensitive])
            guard updated != marked else { continue }
            replacements.append((token, term.1, updated.components(separatedBy: token).count - 1))
            marked = updated
        }
        var output = try await engine.translate(marked).targetText
        guard !replacements.isEmpty else { return output }
        guard replacements.allSatisfy({ output.components(separatedBy: $0.token).count - 1 == $0.count }) else {
            return try await engine.translate(input).targetText
        }
        for replacement in replacements {
            output = output.replacingOccurrences(of: replacement.token, with: replacement.chinese)
        }
        return output
    }
}

@MainActor
final class GlassGlossService: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var hotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var isCapturingSelection = false
    private let listensForHotKey = CommandLine.arguments.contains("--listen-hotkey")

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard listensForHotKey else { return }
        NSLog("GlassGloss listener started")
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            let provider = Unmanaged<GlassGlossService>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { provider.translateFrontmostSelection() }
            return noErr
        }, 1, &event, context, &eventHandler)
        let status = RegisterEventHotKey(UInt32(kVK_Space), UInt32(controlKey | optionKey | cmdKey), EventHotKeyID(signature: 0x4F54524E, id: 1), GetApplicationEventTarget(), 0, &hotKey)
        NSLog("GlassGloss Control+Option+Command+Space registration: %d", status)
        if status != noErr { NSLog("GlassGloss hotkey registration failed: %d", status) }
    }

    private func translateFrontmostSelection() {
        guard !isCapturingSelection else { return }
        guard let frontmost = NSWorkspace.shared.frontmostApplication,
              frontmost.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            showMessage("请回到原文，选中英文后按 ⌃⌥⌘空格。")
            return
        }
        let pid = frontmost.processIdentifier

        if AXIsProcessTrusted() {
            let app = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(app, 0.25)
            var focusedValue: CFTypeRef?
            if AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &focusedValue) == .success,
               let focusedValue, CFGetTypeID(focusedValue) == AXUIElementGetTypeID() {
                let focused = focusedValue as! AXUIElement
                var subrole: CFTypeRef?
                AXUIElementCopyAttributeValue(focused, kAXSubroleAttribute as CFString, &subrole)
                guard subrole as? String != kAXSecureTextFieldSubrole else { return }

                var selectedValue: CFTypeRef?
                if AXUIElementCopyAttributeValue(focused, kAXSelectedTextAttribute as CFString, &selectedValue) == .success,
                   let selection = selectedValue as? String,
                   !selection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    translateCapturedText(selection)
                    return
                }
            }
        }

        guard CGPreflightPostEventAccess() else {
            showMessage("请允许翻译服务读取选中的文字。", offerPermission: true)
            return
        }

        // Web and PDF readers may not expose selected text via accessibility.
        // Send the standard Copy command to the app that owned the selection.
        guard let eventSource = CGEventSource(stateID: .privateState),
              let down = CGEvent(keyboardEventSource: eventSource, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true),
              let up = CGEvent(keyboardEventSource: eventSource, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false) else {
            showMessage("无法向当前应用发送复制命令。")
            return
        }
        let pasteboard = NSPasteboard.general
        guard pasteboard.accessBehavior != .alwaysDeny else {
            showMessage("系统禁止此服务读取剪贴板。请在系统设置的“隐私与安全性 → 剪贴板”中检查“GlassGloss”的权限。")
            return
        }
        let previousChangeCount = pasteboard.changeCount
        isCapturingSelection = true
        for event in [down, up] {
            event.flags = .maskCommand
            event.postToPid(pid)
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.isCapturingSelection = false }
            for _ in 0..<30 {
                try? await Task.sleep(for: .milliseconds(35))
                guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { return }
                guard pasteboard.changeCount != previousChangeCount else { continue }
                let input = pasteboard.string(forType: .string)
                    ?? (pasteboard.readObjects(forClasses: [NSAttributedString.self], options: nil)?.first as? NSAttributedString)?.string
                if let input, !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.translateCapturedText(input)
                    return
                }
            }
            self.showMessage("没有取得选中的文字。请确认原文可以复制，再选中并按 ⌃⌥⌘空格。")
        }
    }

    @objc private func openPermissionSettings() {
        if !CGPreflightPostEventAccess() {
            _ = CGRequestPostEventAccess()
        }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private var panel: TranslationPanel?
    private var translated = ""
    private var session: TranslationSession?
    private var task: Task<Void, Never>?
    private var replacingPanel = false

    @objc func translateSelection(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        let input = (pasteboard.string(forType: .string) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else {
            error.pointee = "请先选中要翻译的英文句子。"
            return
        }
        guard input.count <= 10000 else {
            error.pointee = "一次最多翻译 10,000 个字符，请缩短选区。"
            return
        }
        translate(input)
    }

    private func translateCapturedText(_ text: String) {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        guard input.count <= 10000 else {
            showMessage("一次最多翻译 10,000 个字符。请缩短选区后再按 ⌃⌥⌘空格。")
            return
        }
        translate(input)
    }

    private func showMessage(_ message: String, offerPermission: Bool = false) {
        task?.cancel()
        session?.cancel()
        translated = ""
        showPanel(source: "", message: message, offerPermission: offerPermission)
    }

    private func translate(_ input: String) {
        task?.cancel()
        session?.cancel()
        translated = ""
        showPanel(source: input)
        task = Task { @MainActor [weak self] in
            guard let self else { return }
            let from = Locale.Language(identifier: "en")
            let to = Locale.Language(identifier: "zh-Hans")
            let availability = LanguageAvailability(preferredStrategy: .lowLatency)
            let status = await availability.status(from: from, to: to)
            guard !Task.isCancelled else { return }
            guard status == .installed else {
                self.panel?.setResult("英中离线语言包尚未就绪。请在系统设置 → 通用 → 语言与地区 → 翻译语言中下载英语和简体中文。")
                return
            }
            let engine = TranslationSession(installedSource: from, target: to, preferredStrategy: .lowLatency)
            self.session = engine
            do {
                let response = try await OfflineTextTranslation.translate(input, with: engine)
                guard !Task.isCancelled else { return }
                self.translated = response
                self.panel?.setResult(response)
                self.panel?.copyButton.isEnabled = true
                self.panel?.copyButton.isHidden = false
                NSLog("GlassGloss completed")
            } catch {
                guard !Task.isCancelled else { return }
                self.panel?.setResult("本次离线翻译未完成，请稍后重试。\n\(error.localizedDescription)")
            }
        }
    }

    private func showPanel(source: String, message: String = "正在使用系统离线模型翻译…", offerPermission: Bool = false) {
        replacingPanel = true
        if let panel { panel.close() }
        let window = TranslationPanel(source: source, result: message, target: self,
                                      copyAction: #selector(copyTranslation),
                                      permissionAction: offerPermission ? #selector(openPermissionSettings) : nil)
        window.delegate = self
        panel = window
        replacingPanel = false
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    @objc private func copyTranslation() {
        guard !translated.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(translated, forType: .string)
    }

    func windowWillClose(_ notification: Notification) {
        task?.cancel()
        session?.cancel()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { !listensForHotKey && !replacingPanel }
}

@main
struct ServiceMain {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let provider = GlassGlossService()
        app.delegate = provider
        let mainMenu = NSMenu()
        let editMenuItem = NSMenuItem(title: "编辑", action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(withTitle: "拷贝", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(NSMenuItem())
        mainMenu.addItem(editMenuItem)
        app.mainMenu = mainMenu
        app.servicesProvider = provider
        NSRegisterServicesProvider(provider, "GlassGlossService")
        app.run()
    }
}
