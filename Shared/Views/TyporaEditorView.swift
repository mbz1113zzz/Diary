import SwiftUI

// MARK: - Markdown Highlighter

enum MarkdownHighlighter {

    #if os(macOS)
    typealias PlatformFont = NSFont
    typealias PlatformColor = NSColor
    #else
    typealias PlatformFont = UIFont
    typealias PlatformColor = UIColor
    #endif

    // MARK: - Fonts

    static var bodyFont: PlatformFont { .systemFont(ofSize: 16, weight: .regular) }
    static var h1Font: PlatformFont { .systemFont(ofSize: 32, weight: .heavy) }
    static var h2Font: PlatformFont { .systemFont(ofSize: 26, weight: .bold) }
    static var h3Font: PlatformFont { .systemFont(ofSize: 21, weight: .semibold) }
    static var h4Font: PlatformFont { .systemFont(ofSize: 18, weight: .semibold) }
    static var codeFont: PlatformFont { .monospacedSystemFont(ofSize: 14, weight: .regular) }
    static var tinyFont: PlatformFont { .systemFont(ofSize: 0.1) }

    // MARK: - Colors

    #if os(macOS)
    static var textColor: PlatformColor { .labelColor }
    static var dimColor: PlatformColor { .tertiaryLabelColor }
    static var quoteTextColor: PlatformColor { .secondaryLabelColor }
    static var linkTextColor: PlatformColor { .systemBlue }
    static var codeBgColor: PlatformColor { PlatformColor(white: 0.5, alpha: 0.1) }
    static var quoteBgColor: PlatformColor { PlatformColor.controlAccentColor.withAlphaComponent(0.08) }
    static var tableBgColor: PlatformColor { PlatformColor(white: 0.5, alpha: 0.08) }
    static var taskDoneColor: PlatformColor { .secondaryLabelColor }
    static var hiddenColor: PlatformColor { .clear }
    #else
    static var textColor: PlatformColor { .label }
    static var dimColor: PlatformColor { .tertiaryLabel }
    static var quoteTextColor: PlatformColor { .secondaryLabel }
    static var linkTextColor: PlatformColor { .systemBlue }
    static var codeBgColor: PlatformColor { .tertiarySystemFill }
    static var quoteBgColor: PlatformColor { PlatformColor.systemBlue.withAlphaComponent(0.08) }
    static var tableBgColor: PlatformColor { .tertiarySystemFill }
    static var taskDoneColor: PlatformColor { .secondaryLabel }
    static var hiddenColor: PlatformColor { .clear }
    #endif

    // MARK: - Base Style

    static var bodyAttributes: [NSAttributedString.Key: Any] {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 6
        style.paragraphSpacing = 4
        return [
            .font: bodyFont,
            .foregroundColor: textColor,
            .paragraphStyle: style
        ]
    }

    static func bulletAttachment() -> NSTextAttachment {
        let size = CGSize(width: 6, height: 6)
        let attachment = NSTextAttachment()

        #if os(macOS)
        let image = NSImage(size: size)
        image.lockFocus()
        linkTextColor.setFill()
        NSBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()
        image.unlockFocus()
        attachment.image = image
        #else
        let renderer = UIGraphicsImageRenderer(size: size)
        attachment.image = renderer.image { context in
            linkTextColor.setFill()
            context.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
        }
        #endif

        attachment.bounds = CGRect(x: 0, y: 2, width: size.width, height: size.height)
        return attachment
    }

    // MARK: - Highlight Entry Point

    /// Highlight markdown in the text storage.
    /// - `activeLineRange`: the paragraph where the cursor is — shows raw markdown markers dimmed.
    ///   All other lines hide markers for a Typora-like rendered look.
    ///   Pass `nil` to render all lines in preview mode (markers hidden).
    @discardableResult
    static func highlight(_ storage: NSMutableAttributedString, activeLineRange: NSRange? = nil) -> Set<Int> {
        let length = storage.length
        guard length > 0 else { return [] }

        let fullRange = NSRange(location: 0, length: length)
        let text = storage.string
        var markerIndexes = Set<Int>()

        // Reset to body style
        storage.setAttributes(bodyAttributes, range: fullRange)

        // Check if a match range overlaps the active (editing) line
        func isActive(_ range: NSRange) -> Bool {
            guard let active = activeLineRange else { return false }
            return NSIntersectionRange(active, range).length > 0
        }

        // Hide a marker: invisible + near-zero size so it takes no visual space
        func hideMarker(_ range: NSRange) {
            collectMarkers(range)
            guard range.location != NSNotFound, range.length > 0 else { return }
            storage.addAttributes([
                .foregroundColor: hiddenColor,
                .font: tinyFont
            ], range: range)
        }

        // Dim a marker: visible but light gray (shown on active line)
        func dimMarker(_ range: NSRange) {
            guard range.location != NSNotFound, range.length > 0 else { return }
            storage.addAttribute(.foregroundColor, value: dimColor, range: range)
        }

        func drawBulletMarker(_ range: NSRange) {
            collectMarkers(range)
            guard range.location != NSNotFound, range.length > 0 else { return }
            storage.addAttributes([
                .attachment: bulletAttachment(),
                .foregroundColor: hiddenColor
            ], range: range)
        }

        func collectMarkers(_ range: NSRange) {
            guard range.location != NSNotFound, range.length > 0 else { return }
            for i in range.location..<(range.location + range.length) {
                markerIndexes.insert(i)
            }
        }

        // Style a marker: hide it on non-active lines, dim it on the active line
        func styleMarker(_ range: NSRange, forMatch matchRange: NSRange) {
            collectMarkers(range)
            if isActive(matchRange) {
                dimMarker(range)
            } else {
                hideMarker(range)
            }
        }

        func optionalRange(_ range: NSRange) -> NSRange? {
            guard range.location != NSNotFound, range.length > 0 else { return nil }
            return range
        }

        func indentationLevel(_ indentation: String) -> Int {
            indentation.reduce(0) { partialResult, character in
                partialResult + (character == "\t" ? 4 : 1)
            } / 4
        }

        func listStyle(level: Int, markerWidth: CGFloat = 22) -> NSMutableParagraphStyle {
            let style = NSMutableParagraphStyle()
            let offset = CGFloat(level) * 22
            style.lineSpacing = 5
            style.firstLineHeadIndent = offset
            style.headIndent = offset + markerWidth
            return style
        }

        let syntaxSpans = MarkdownSyntaxParser.spans(in: text)

        // Collect code block ranges to skip them in inline rules
        var codeBlockRanges: [NSRange] = syntaxSpans.compactMap { span in
            if case .codeBlock = span.kind {
                return span.range
            }
            return nil
        }

        func inCodeBlock(_ range: NSRange) -> Bool {
            codeBlockRanges.contains { NSIntersectionRange($0, range).length > 0 }
        }

        func applyParserStyles() {
            for span in syntaxSpans {
                guard span.range.location != NSNotFound,
                      span.range.location + span.range.length <= storage.length else { continue }

                switch span.kind {
                case .heading(let level):
                    let font: PlatformFont
                    let extraSpacing: CGFloat
                    switch level {
                    case 1: font = h1Font; extraSpacing = 14
                    case 2: font = h2Font; extraSpacing = 10
                    case 3: font = h3Font; extraSpacing = 8
                    default: font = h4Font; extraSpacing = 6
                    }

                    let style = NSMutableParagraphStyle()
                    style.lineSpacing = 4
                    style.paragraphSpacingBefore = extraSpacing
                    style.paragraphSpacing = 6
                    storage.addAttributes([.font: font, .paragraphStyle: style], range: span.range)

                case .blockQuote:
                    let style = NSMutableParagraphStyle()
                    style.lineSpacing = 5
                    style.headIndent = 20
                    style.firstLineHeadIndent = 20
                    style.paragraphSpacing = 6
                    storage.addAttributes([
                        .foregroundColor: quoteTextColor,
                        .backgroundColor: quoteBgColor,
                        .paragraphStyle: style
                    ], range: span.range)

                case .codeBlock:
                    storage.addAttributes([.font: codeFont, .backgroundColor: codeBgColor], range: span.range)

                case .thematicBreak:
                    storage.addAttribute(.foregroundColor, value: dimColor, range: span.range)

                case .unorderedList, .orderedList:
                    storage.addAttribute(.paragraphStyle, value: listStyle(level: 0), range: span.range)

                case .listItem(let checkbox):
                    storage.addAttribute(.paragraphStyle, value: listStyle(level: 0, markerWidth: checkbox == nil ? 22 : 34), range: span.range)
                    if checkbox == .checked {
                        storage.addAttributes([
                            .foregroundColor: taskDoneColor,
                            .strikethroughStyle: NSUnderlineStyle.single.rawValue
                        ], range: span.range)
                    }

                case .strong:
                    if let currentFont = storage.attribute(.font, at: span.range.location, effectiveRange: nil) as? PlatformFont {
                        storage.addAttribute(.font, value: PlatformFont.systemFont(ofSize: currentFont.pointSize, weight: .bold), range: span.range)
                    }

                case .emphasis:
                    if let currentFont = storage.attribute(.font, at: span.range.location, effectiveRange: nil) as? PlatformFont {
                        #if os(macOS)
                        let italic = NSFontManager.shared.convert(currentFont, toHaveTrait: .italicFontMask)
                        #else
                        let descriptor = currentFont.fontDescriptor.withSymbolicTraits(.traitItalic) ?? currentFont.fontDescriptor
                        let italic = UIFont(descriptor: descriptor, size: currentFont.pointSize)
                        #endif
                        storage.addAttribute(.font, value: italic, range: span.range)
                    }

                case .strikethrough:
                    storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: span.range)

                case .inlineCode:
                    storage.addAttributes([.font: codeFont, .backgroundColor: codeBgColor], range: span.range)

                case .link:
                    storage.addAttributes([
                        .foregroundColor: linkTextColor,
                        .underlineStyle: NSUnderlineStyle.single.rawValue
                    ], range: span.range)

                case .image:
                    storage.addAttribute(.foregroundColor, value: linkTextColor, range: span.range)

                case .htmlBlock:
                    storage.addAttributes([
                        .font: codeFont,
                        .foregroundColor: quoteTextColor,
                        .backgroundColor: codeBgColor
                    ], range: span.range)

                case .inlineHTML:
                    storage.addAttributes([
                        .font: codeFont,
                        .foregroundColor: quoteTextColor,
                        .backgroundColor: codeBgColor
                    ], range: span.range)

                case .table:
                    let style = NSMutableParagraphStyle()
                    style.lineSpacing = 6
                    style.paragraphSpacing = 6
                    style.headIndent = 8
                    style.firstLineHeadIndent = 8
                    storage.addAttributes([
                        .font: codeFont,
                        .backgroundColor: tableBgColor,
                        .paragraphStyle: style
                    ], range: span.range)

                case .tableCell:
                    storage.addAttribute(.foregroundColor, value: textColor, range: span.range)
                }
            }
        }

        applyParserStyles()

        // =====================================================================
        // BLOCK LEVEL
        // =====================================================================

        // --- Fenced code blocks ```...``` ---
        applyRegex("(```)(\\w*\\n)?([\\s\\S]*?)(```)", in: text, to: storage) { m in
            codeBlockRanges.append(m.range)
            storage.addAttributes([.font: codeFont, .backgroundColor: codeBgColor], range: m.range)
            if isActive(m.range) {
                collectMarkers(m.range(at: 1))
                if let languageRange = optionalRange(m.range(at: 2)) {
                    collectMarkers(languageRange)
                }
                collectMarkers(m.range(at: 4))
                dimMarker(m.range(at: 1))
                dimMarker(m.range(at: 4))
            } else {
                hideMarker(m.range(at: 1))
                if let languageRange = optionalRange(m.range(at: 2)) {
                    hideMarker(languageRange)
                }
                hideMarker(m.range(at: 4))
            }
        }

        // --- Headings ---
        applyRegex("^(#{1,6})( +)(.+)$", options: .anchorsMatchLines, in: text, to: storage) { m in
            guard !inCodeBlock(m.range) else { return }
            let hashRange = m.range(at: 1)
            let spaceRange = m.range(at: 2)
            let contentRange = m.range(at: 3)
            let level = hashRange.length

            let font: PlatformFont
            let extraSpacing: CGFloat
            switch level {
            case 1: font = h1Font; extraSpacing = 14
            case 2: font = h2Font; extraSpacing = 10
            case 3: font = h3Font; extraSpacing = 8
            default: font = h4Font; extraSpacing = 6
            }

            let style = NSMutableParagraphStyle()
            style.lineSpacing = 4
            style.paragraphSpacingBefore = extraSpacing
            style.paragraphSpacing = 6

            if isActive(m.range) {
                // Active line: show everything in heading font, dim markers
                storage.addAttributes([.font: font, .paragraphStyle: style], range: m.range)
                collectMarkers(hashRange)
                collectMarkers(spaceRange)
                dimMarker(hashRange)
            } else {
                // Non-active: hide markers, heading font only on content
                storage.addAttributes([.font: font, .paragraphStyle: style], range: contentRange)
                // Set paragraph style on full range so spacing applies
                storage.addAttribute(.paragraphStyle, value: style, range: m.range)
                hideMarker(hashRange)
                hideMarker(spaceRange)
            }
        }

        // --- Block quotes ---
        applyRegex("^(>)( ?)(.*)$", options: .anchorsMatchLines, in: text, to: storage) { m in
            guard !inCodeBlock(m.range) else { return }
            let markerRange = m.range(at: 1)
            let spaceRange = m.range(at: 2)

            let style = NSMutableParagraphStyle()
            style.lineSpacing = 5
            style.headIndent = 20
            style.firstLineHeadIndent = 20

            storage.addAttributes([
                .foregroundColor: quoteTextColor,
                .backgroundColor: quoteBgColor,
                .paragraphStyle: style
            ], range: m.range)

            if isActive(m.range) {
                collectMarkers(markerRange)
                if spaceRange.length > 0 { collectMarkers(spaceRange) }
                dimMarker(markerRange)
            } else {
                hideMarker(markerRange)
                if spaceRange.length > 0 { hideMarker(spaceRange) }
            }
        }

        // --- Horizontal rules ---
        applyRegex("^[-*_]{3,}\\s*$", options: .anchorsMatchLines, in: text, to: storage) { m in
            guard !inCodeBlock(m.range) else { return }
            storage.addAttribute(.foregroundColor, value: dimColor, range: m.range)
        }

        // --- Task list markers ---
        applyRegex("^(\\s*)([-*+]\\s+)(\\[( |x|X)\\])(\\s+)(.*)$", options: .anchorsMatchLines, in: text, to: storage) { m in
            guard !inCodeBlock(m.range) else { return }
            let style = NSMutableParagraphStyle()
            let level = indentationLevel((text as NSString).substring(with: m.range(at: 1)))
            style.lineSpacing = 5
            style.headIndent = CGFloat(level) * 22 + 34
            style.firstLineHeadIndent = CGFloat(level) * 22
            storage.addAttribute(.paragraphStyle, value: style, range: (text as NSString).paragraphRange(for: m.range))
            let markerRange = m.range(at: 2)
            let checkboxRange = m.range(at: 3)
            let isChecked = (text as NSString).substring(with: m.range(at: 4)).lowercased() == "x"

            if isActive(m.range) {
                collectMarkers(markerRange)
                dimMarker(markerRange)
            } else {
                hideMarker(markerRange)
            }

            storage.addAttribute(.foregroundColor, value: isChecked ? PlatformColor.systemGreen : linkTextColor, range: checkboxRange)

            if isChecked {
                let contentRange = m.range(at: 6)
                if contentRange.location != NSNotFound, contentRange.length > 0 {
                    storage.addAttributes([
                        .foregroundColor: taskDoneColor,
                        .strikethroughStyle: NSUnderlineStyle.single.rawValue
                    ], range: contentRange)
                }
            }
        }

        // --- Unordered list markers ---
        applyRegex("^(\\s*)([-*+])(?!\\s+\\[[ xX]\\])(\\s+)", options: .anchorsMatchLines, in: text, to: storage) { m in
            guard !inCodeBlock(m.range) else { return }
            let style = NSMutableParagraphStyle()
            let level = indentationLevel((text as NSString).substring(with: m.range(at: 1)))
            style.lineSpacing = 5
            style.headIndent = CGFloat(level) * 22 + 22
            style.firstLineHeadIndent = CGFloat(level) * 22
            storage.addAttribute(.paragraphStyle, value: style, range: (text as NSString).paragraphRange(for: m.range))
            if isActive(m.range) {
                dimMarker(m.range(at: 2))
            } else {
                drawBulletMarker(m.range(at: 2))
            }
        }

        // --- Ordered list markers ---
        applyRegex("^(\\s*)(\\d+\\.)(?=\\s)", options: .anchorsMatchLines, in: text, to: storage) { m in
            guard !inCodeBlock(m.range) else { return }
            let style = NSMutableParagraphStyle()
            let level = indentationLevel((text as NSString).substring(with: m.range(at: 1)))
            style.lineSpacing = 5
            style.headIndent = CGFloat(level) * 22 + 28
            style.firstLineHeadIndent = CGFloat(level) * 22
            storage.addAttribute(.paragraphStyle, value: style, range: (text as NSString).paragraphRange(for: m.range))
            storage.addAttribute(.foregroundColor, value: linkTextColor, range: m.range(at: 2))
        }

        // --- Tables ---
        applyRegex("^\\s*\\|?\\s*:?-{3,}:?\\s*(\\|\\s*:?-{3,}:?\\s*)+\\|?\\s*$", options: .anchorsMatchLines, in: text, to: storage) { m in
            guard !inCodeBlock(m.range) else { return }
            let nsText = text as NSString
            let delimiterRange = nsText.paragraphRange(for: m.range)
            storage.addAttributes([
                .font: codeFont,
                .foregroundColor: dimColor,
                .backgroundColor: tableBgColor
            ], range: delimiterRange)

            guard delimiterRange.location > 0 else { return }
            let headerProbe = max(delimiterRange.location - 1, 0)
            let headerRange = nsText.paragraphRange(for: NSRange(location: headerProbe, length: 0))
            guard headerRange.location != delimiterRange.location else { return }
            storage.addAttributes([
                .font: PlatformFont.monospacedSystemFont(ofSize: 14, weight: .semibold),
                .backgroundColor: tableBgColor
            ], range: headerRange)
        }

        // =====================================================================
        // INLINE
        // =====================================================================

        // --- Bold **text** or __text__ ---
        applyRegex("(\\*\\*|__)(.+?)(\\*\\*|__)", in: text, to: storage) { m in
            guard !inCodeBlock(m.range) else { return }
            let contentRange = m.range(at: 2)
            if let currentFont = storage.attribute(.font, at: contentRange.location, effectiveRange: nil) as? PlatformFont {
                let bold = PlatformFont.systemFont(ofSize: currentFont.pointSize, weight: .bold)
                storage.addAttribute(.font, value: bold, range: contentRange)
            }
            styleMarker(m.range(at: 1), forMatch: m.range)
            styleMarker(m.range(at: 3), forMatch: m.range)
        }

        // --- Italic *text* (not bold) ---
        applyRegex("(?<!\\*)(\\*)(?!\\*)(.+?)(?<!\\*)(\\*)(?!\\*)", in: text, to: storage) { m in
            guard !inCodeBlock(m.range) else { return }
            let contentRange = m.range(at: 2)
            if let currentFont = storage.attribute(.font, at: contentRange.location, effectiveRange: nil) as? PlatformFont {
                #if os(macOS)
                let italic = NSFontManager.shared.convert(currentFont, toHaveTrait: .italicFontMask)
                #else
                let desc = currentFont.fontDescriptor.withSymbolicTraits(.traitItalic) ?? currentFont.fontDescriptor
                let italic = UIFont(descriptor: desc, size: currentFont.pointSize)
                #endif
                storage.addAttribute(.font, value: italic, range: contentRange)
            }
            styleMarker(m.range(at: 1), forMatch: m.range)
            styleMarker(m.range(at: 3), forMatch: m.range)
        }

        // --- Strikethrough ~~text~~ ---
        applyRegex("(~~)(.+?)(~~)", in: text, to: storage) { m in
            guard !inCodeBlock(m.range) else { return }
            storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: m.range(at: 2))
            styleMarker(m.range(at: 1), forMatch: m.range)
            styleMarker(m.range(at: 3), forMatch: m.range)
        }

        // --- Inline code `text` ---
        applyRegex("(?<!`)(`)([^`]+?)(`)(?!`)", in: text, to: storage) { m in
            guard !inCodeBlock(m.range) else { return }
            // Always style the content with code appearance
            storage.addAttributes([.font: codeFont, .backgroundColor: codeBgColor], range: m.range(at: 2))
            if isActive(m.range) {
                // Active: show backticks dimmed, with code background
                collectMarkers(m.range(at: 1))
                collectMarkers(m.range(at: 3))
                storage.addAttributes([.font: codeFont, .backgroundColor: codeBgColor], range: m.range(at: 1))
                storage.addAttributes([.font: codeFont, .backgroundColor: codeBgColor], range: m.range(at: 3))
                dimMarker(m.range(at: 1))
                dimMarker(m.range(at: 3))
            } else {
                // Non-active: hide backticks
                hideMarker(m.range(at: 1))
                hideMarker(m.range(at: 3))
            }
        }

        // --- Links [text](url) ---
        applyRegex("(\\[)(.+?)(\\])(\\()(.+?)(\\))", in: text, to: storage) { m in
            guard !inCodeBlock(m.range) else { return }
            // Always style link text blue + underlined
            storage.addAttributes([
                .foregroundColor: linkTextColor,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ], range: m.range(at: 2))

            if isActive(m.range) {
                // Active: dim brackets and URL
                for i in [1, 3, 4, 5, 6] {
                    let r = m.range(at: i)
                    if r.location != NSNotFound { collectMarkers(r) }
                }
                for i in [1, 3, 4, 5, 6] {
                    let r = m.range(at: i)
                    if r.location != NSNotFound { dimMarker(r) }
                }
            } else {
                // Non-active: hide brackets and URL, show only link text
                for i in [1, 3, 4, 5, 6] {
                    let r = m.range(at: i)
                    if r.location != NSNotFound { hideMarker(r) }
                }
            }
        }

        // --- Images ![alt](url) ---
        applyRegex("(!)\\[(.+?)\\]\\((.+?)\\)", in: text, to: storage) { m in
            guard !inCodeBlock(m.range) else { return }
            collectMarkers(NSRange(location: m.range.location, length: 1))  // !
            collectMarkers(NSRange(location: m.range.location + 1, length: 1))  // [
            let afterAlt = m.range(at: 2).location + m.range(at: 2).length
            let tailLen = m.range.location + m.range.length - afterAlt
            if tailLen > 0 { collectMarkers(NSRange(location: afterAlt, length: tailLen)) }
            if isActive(m.range) {
                storage.addAttribute(.foregroundColor, value: dimColor, range: m.range)
                storage.addAttribute(.foregroundColor, value: linkTextColor, range: m.range(at: 2))
            } else {
                storage.addAttribute(.foregroundColor, value: linkTextColor, range: m.range(at: 2))
                // Hide everything except alt text
                hideMarker(NSRange(location: m.range.location, length: 1)) // !
                let bracketOpen = NSRange(location: m.range.location + 1, length: 1) // [
                hideMarker(bracketOpen)
                let afterAlt2 = m.range(at: 2).location + m.range(at: 2).length
                let tailLength = m.range.location + m.range.length - afterAlt2
                if tailLength > 0 {
                    hideMarker(NSRange(location: afterAlt2, length: tailLength)) // ](url)
                }
            }
        }
        return markerIndexes
    }

    // MARK: - Helpers

    private static func applyRegex(
        _ pattern: String,
        options: NSRegularExpression.Options = [],
        in text: String,
        to storage: NSMutableAttributedString,
        handler: (NSTextCheckingResult) -> Void
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return }
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
        regex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
            guard let match else { return }
            handler(match)
        }
    }
}

// MARK: - Active Line Helper

private func computeActiveLineRange(cursorLocation: Int, in text: String) -> NSRange? {
    let nsText = text as NSString
    guard nsText.length > 0 else { return nil }
    let safeLoc = min(max(cursorLocation, 0), nsText.length)
    return nsText.paragraphRange(for: NSRange(location: safeLoc, length: 0))
}

// MARK: - macOS Editor

#if os(macOS)
import AppKit

final class HiddenMarkerLayoutManager: NSLayoutManager {
    var markerIndexes: Set<Int> = []
    var activeLineRange: NSRange?

    override func setGlyphs(
        _ glyphs: UnsafePointer<CGGlyph>,
        properties props: UnsafePointer<NSLayoutManager.GlyphProperty>,
        characterIndexes charIndexes: UnsafePointer<Int>,
        font aFont: NSFont,
        forGlyphRange glyphRange: NSRange
    ) {
        let buffer = UnsafeMutablePointer<NSLayoutManager.GlyphProperty>.allocate(capacity: glyphRange.length)
        defer { buffer.deallocate() }

        for i in 0..<glyphRange.length {
            let charIndex = charIndexes[i]
            if markerIndexes.contains(charIndex) && !isInActiveRange(charIndex) {
                buffer[i] = .null
            } else {
                buffer[i] = props[i]
            }
        }

        super.setGlyphs(glyphs, properties: buffer, characterIndexes: charIndexes, font: aFont, forGlyphRange: glyphRange)
    }

    private func isInActiveRange(_ charIndex: Int) -> Bool {
        guard let active = activeLineRange else { return false }
        return charIndex >= active.location && charIndex < active.location + active.length
    }
}

struct TyporaEditorView: NSViewRepresentable {
    @Binding var text: String
    var commands: MarkdownEditorCommands?

    func makeNSView(context: Context) -> NSScrollView {
        let textStorage = NSTextStorage(string: text)
        let layoutManager = HiddenMarkerLayoutManager()
        let container = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layoutManager.addTextContainer(container)
        textStorage.addLayoutManager(layoutManager)

        let textView = NSTextView(frame: .zero, textContainer: container)
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.font = MarkdownHighlighter.bodyFont
        textView.textColor = .labelColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 28, height: 20)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.delegate = context.coordinator

        // Initial highlighting — no active line, full preview mode
        if !text.isEmpty {
            textStorage.beginEditing()
            let indexes = MarkdownHighlighter.highlight(textStorage, activeLineRange: nil)
            textStorage.endEditing()
            layoutManager.markerIndexes = indexes
            layoutManager.activeLineRange = nil
        }

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.documentView = textView

        context.coordinator.textView = textView
        context.coordinator.commands = commands
        context.coordinator.installCommandHandler()

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }
        context.coordinator.commands = commands
        context.coordinator.installCommandHandler()
        guard !context.coordinator.isUpdating else { return }
        if textView.string != text {
            textView.string = text
            context.coordinator.rehighlight(textView)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        weak var textView: NSTextView?
        weak var commands: MarkdownEditorCommands?
        var isUpdating = false
        var hasFocus = false

        init(text: Binding<String>) { _text = text }

        func installCommandHandler() {
            commands?.handler = { [weak self] cmd in self?.applyCommand(cmd) }
        }

        // Re-highlight: when focused, show markdown markers only for the current paragraph.
        // Pressing Return moves the cursor to a new paragraph, so the previous paragraph
        // naturally falls back to preview styling.
        func rehighlight(_ textView: NSTextView) {
            guard let storage = textView.textStorage else { return }
            let activeRange: NSRange? = hasFocus
                ? computeActiveLineRange(cursorLocation: textView.selectedRange().location, in: textView.string)
                : nil

            let selectedRanges = textView.selectedRanges
            storage.beginEditing()
            let indexes = MarkdownHighlighter.highlight(storage, activeLineRange: activeRange)
            storage.endEditing()
            textView.selectedRanges = selectedRanges

            // Update layout manager with new marker data
            if let layoutManager = textView.layoutManager as? HiddenMarkerLayoutManager {
                layoutManager.markerIndexes = indexes
                layoutManager.activeLineRange = activeRange
                layoutManager.invalidateGlyphs(forCharacterRange: NSRange(location: 0, length: storage.length), changeInLength: 0, actualCharacterRange: nil)
            }
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            guard !isUpdating else { return }
            isUpdating = true
            text = textView.string
            rehighlight(textView)
            isUpdating = false
        }

        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            guard replacementString == "\n",
                  let result = MarkdownEditing.returnContinuation(in: textView.string, selectedRange: affectedCharRange) else {
                return true
            }

            isUpdating = true
            textView.string = result.text
            textView.setSelectedRange(result.selectedRange)
            text = result.text
            hasFocus = true
            rehighlight(textView)
            isUpdating = false
            return false
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                return applyListIndent(in: textView, isOutdent: false)
            }
            if commandSelector == #selector(NSResponder.insertBacktab(_:)) {
                return applyListIndent(in: textView, isOutdent: true)
            }
            return false
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            guard !isUpdating else { return }
            guard let layoutManager = textView.layoutManager as? HiddenMarkerLayoutManager else { return }

            let oldActiveRange = layoutManager.activeLineRange
            let newActiveRange: NSRange? = hasFocus
                ? computeActiveLineRange(cursorLocation: textView.selectedRange().location, in: textView.string)
                : nil

            // Skip if active line hasn't changed
            if oldActiveRange == newActiveRange { return }

            isUpdating = true

            let storage = textView.textStorage!
            let selectedRanges = textView.selectedRanges

            storage.beginEditing()
            let indexes = MarkdownHighlighter.highlight(storage, activeLineRange: newActiveRange)
            storage.endEditing()
            textView.selectedRanges = selectedRanges

            layoutManager.markerIndexes = indexes
            layoutManager.activeLineRange = newActiveRange

            // Incremental invalidation: only re-layout the old and new active ranges
            let fullRange = NSRange(location: 0, length: storage.length)
            if let old = oldActiveRange, old.location + old.length <= storage.length {
                layoutManager.invalidateGlyphs(forCharacterRange: old, changeInLength: 0, actualCharacterRange: nil)
            }
            if let new = newActiveRange {
                layoutManager.invalidateGlyphs(forCharacterRange: new, changeInLength: 0, actualCharacterRange: nil)
            }
            if oldActiveRange == nil && newActiveRange == nil {
                layoutManager.invalidateGlyphs(forCharacterRange: fullRange, changeInLength: 0, actualCharacterRange: nil)
            }

            isUpdating = false
        }

        func textDidBeginEditing(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            hasFocus = true
            isUpdating = true
            rehighlight(textView)
            isUpdating = false
        }

        func textDidEndEditing(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            hasFocus = false
            isUpdating = true
            rehighlight(textView)
            isUpdating = false
        }

        private func applyCommand(_ command: MarkdownCommand) {
            guard let textView else { return }
            let result = MarkdownEditing.apply(command, to: textView.string, selectedRange: textView.selectedRange())
            textView.string = result.text
            textView.setSelectedRange(result.selectedRange)

            isUpdating = true
            text = result.text
            // Toolbar commands always indicate an editing intent; treat as focused
            hasFocus = true
            rehighlight(textView)
            isUpdating = false

            textView.window?.makeFirstResponder(textView)
        }

        private func applyListIndent(in textView: NSTextView, isOutdent: Bool) -> Bool {
            let selectedRange = textView.selectedRange()
            let result = isOutdent
                ? MarkdownEditing.outdentListItem(in: textView.string, selectedRange: selectedRange)
                : MarkdownEditing.indentListItem(in: textView.string, selectedRange: selectedRange)

            guard let result else { return false }

            isUpdating = true
            textView.string = result.text
            textView.setSelectedRange(result.selectedRange)
            text = result.text
            hasFocus = true
            rehighlight(textView)
            isUpdating = false
            return true
        }
    }
}

#else
import UIKit

struct TyporaEditorView: UIViewRepresentable {
    @Binding var text: String
    var commands: MarkdownEditorCommands?

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.font = MarkdownHighlighter.bodyFont
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        textView.autocorrectionType = .yes
        textView.smartDashesType = .no
        textView.smartQuotesType = .no
        textView.text = text
        textView.delegate = context.coordinator

        if !text.isEmpty {
            let storage = textView.textStorage
            storage.beginEditing()
            MarkdownHighlighter.highlight(storage, activeLineRange: nil)
            storage.endEditing()
        }

        context.coordinator.textView = textView
        context.coordinator.commands = commands
        context.coordinator.installCommandHandler()

        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.commands = commands
        context.coordinator.installCommandHandler()
        guard !context.coordinator.isUpdating else { return }
        if textView.text != text {
            textView.text = text
            context.coordinator.rehighlight(textView)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        weak var textView: UITextView?
        weak var commands: MarkdownEditorCommands?
        var isUpdating = false
        var hasFocus = false

        init(text: Binding<String>) { _text = text }

        func installCommandHandler() {
            commands?.handler = { [weak self] cmd in self?.applyCommand(cmd) }
        }

        func rehighlight(_ textView: UITextView) {
            let storage = textView.textStorage
            let activeRange: NSRange? = hasFocus
                ? computeActiveLineRange(cursorLocation: textView.selectedRange.location, in: textView.text)
                : nil
            let selectedRange = textView.selectedRange
            storage.beginEditing()
            MarkdownHighlighter.highlight(storage, activeLineRange: activeRange)
            storage.endEditing()
            textView.selectedRange = selectedRange
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isUpdating else { return }
            isUpdating = true
            text = textView.text
            rehighlight(textView)
            isUpdating = false
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText replacement: String) -> Bool {
            if replacement == "\t" {
                return !applyListIndent(in: textView, range: range, isOutdent: false)
            }

            guard replacement == "\n",
                  let result = MarkdownEditing.returnContinuation(in: textView.text, selectedRange: range) else {
                return true
            }

            isUpdating = true
            textView.text = result.text
            textView.selectedRange = result.selectedRange
            self.text = result.text
            hasFocus = true
            rehighlight(textView)
            isUpdating = false
            return false
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !isUpdating else { return }
            isUpdating = true
            rehighlight(textView)
            isUpdating = false
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            hasFocus = true
            isUpdating = true
            rehighlight(textView)
            isUpdating = false
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            hasFocus = false
            isUpdating = true
            rehighlight(textView)
            isUpdating = false
        }

        private func applyCommand(_ command: MarkdownCommand) {
            guard let textView else { return }
            let result = MarkdownEditing.apply(command, to: textView.text, selectedRange: textView.selectedRange)
            textView.text = result.text
            textView.selectedRange = result.selectedRange

            isUpdating = true
            text = result.text
            hasFocus = true
            rehighlight(textView)
            isUpdating = false

            textView.becomeFirstResponder()
        }

        private func applyListIndent(in textView: UITextView, range: NSRange, isOutdent: Bool) -> Bool {
            let result = isOutdent
                ? MarkdownEditing.outdentListItem(in: textView.text, selectedRange: range)
                : MarkdownEditing.indentListItem(in: textView.text, selectedRange: range)

            guard let result else { return false }

            isUpdating = true
            textView.text = result.text
            textView.selectedRange = result.selectedRange
            text = result.text
            hasFocus = true
            rehighlight(textView)
            isUpdating = false
            return true
        }
    }
}
#endif
