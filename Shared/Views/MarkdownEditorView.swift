import SwiftUI

enum MarkdownCommand {
    case heading
    case bold
    case italic
    case bullet
    case orderedList
    case taskList
    case quote
    case inlineCode
    case codeBlock
    case link
    case table
}

final class MarkdownEditorCommands: ObservableObject {
    internal var handler: ((MarkdownCommand) -> Void)?

    func apply(_ command: MarkdownCommand) {
        handler?(command)
    }
}

#if os(macOS)
import AppKit

struct MarkdownEditorView: NSViewRepresentable {
    @Binding var text: String
    var commands: MarkdownEditorCommands?

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.font = .monospacedSystemFont(ofSize: 15, weight: .regular)
        textView.textColor = .labelColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 14, height: 14)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.string = text
        textView.delegate = context.coordinator

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
        guard !context.coordinator.isUpdatingFromView else { return }
        if textView.string != text {
            textView.string = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        weak var textView: NSTextView?
        weak var commands: MarkdownEditorCommands?
        var isUpdatingFromView = false

        init(text: Binding<String>) {
            _text = text
        }

        func installCommandHandler() {
            commands?.handler = { [weak self] command in
                self?.apply(command)
            }
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            isUpdatingFromView = true
            text = textView.string
            isUpdatingFromView = false
        }

        private func apply(_ command: MarkdownCommand) {
            guard let textView else { return }
            let result = MarkdownEditing.apply(command, to: textView.string, selectedRange: textView.selectedRange())
            textView.string = result.text
            textView.setSelectedRange(result.selectedRange)
            textView.window?.makeFirstResponder(textView)
            text = result.text
        }
    }
}

#else
import UIKit

struct MarkdownEditorView: UIViewRepresentable {
    @Binding var text: String
    var commands: MarkdownEditorCommands?

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.font = .monospacedSystemFont(ofSize: 15, weight: .regular)
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 14, left: 10, bottom: 14, right: 10)
        textView.autocorrectionType = .yes
        textView.smartDashesType = .no
        textView.smartQuotesType = .no
        textView.text = text
        textView.delegate = context.coordinator
        context.coordinator.textView = textView
        context.coordinator.commands = commands
        context.coordinator.installCommandHandler()
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.commands = commands
        context.coordinator.installCommandHandler()
        guard !context.coordinator.isUpdatingFromView else { return }
        if textView.text != text {
            textView.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        weak var textView: UITextView?
        weak var commands: MarkdownEditorCommands?
        var isUpdatingFromView = false

        init(text: Binding<String>) {
            _text = text
        }

        func installCommandHandler() {
            commands?.handler = { [weak self] command in
                self?.apply(command)
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            isUpdatingFromView = true
            text = textView.text
            isUpdatingFromView = false
        }

        private func apply(_ command: MarkdownCommand) {
            guard let textView else { return }
            let result = MarkdownEditing.apply(command, to: textView.text, selectedRange: textView.selectedRange)
            textView.text = result.text
            textView.selectedRange = result.selectedRange
            textView.becomeFirstResponder()
            text = result.text
        }
    }
}
#endif

enum MarkdownEditing {
    static func apply(_ command: MarkdownCommand, to text: String, selectedRange: NSRange) -> (text: String, selectedRange: NSRange) {
        switch command {
        case .heading:
            return prefixSelectedLines("# ", in: text, selectedRange: selectedRange)
        case .bullet:
            return prefixSelectedLines("- ", in: text, selectedRange: selectedRange)
        case .orderedList:
            return prefixSelectedLines("1. ", in: text, selectedRange: selectedRange)
        case .taskList:
            return prefixSelectedLines("- [ ] ", in: text, selectedRange: selectedRange)
        case .quote:
            return prefixSelectedLines("> ", in: text, selectedRange: selectedRange)
        case .bold:
            return wrapSelection("**", in: text, selectedRange: selectedRange, placeholder: "加粗文字")
        case .italic:
            return wrapSelection("*", in: text, selectedRange: selectedRange, placeholder: "斜体文字")
        case .inlineCode:
            return wrapSelection("`", in: text, selectedRange: selectedRange, placeholder: "code")
        case .codeBlock:
            return wrapBlock(prefix: "```swift\n", suffix: "\n```", in: text, selectedRange: selectedRange, placeholder: "代码")
        case .link:
            return wrapSelection("[", suffix: "](https://)", in: text, selectedRange: selectedRange, placeholder: "链接文字")
        case .table:
            return insertTable(in: text, selectedRange: selectedRange)
        }
    }

    static func returnContinuation(in text: String, selectedRange: NSRange) -> (text: String, selectedRange: NSRange)? {
        guard selectedRange.length == 0 else { return nil }

        let nsText = text as NSString
        guard nsText.length > 0, selectedRange.location <= nsText.length else { return nil }

        let probeLocation: Int
        if selectedRange.location == nsText.length {
            probeLocation = max(nsText.length - 1, 0)
        } else {
            probeLocation = selectedRange.location
        }

        let paragraphRange = nsText.paragraphRange(for: NSRange(location: probeLocation, length: 0))
        let rawParagraph = nsText.substring(with: paragraphRange)
        let paragraph = rawParagraph.trimmingCharacters(in: .newlines)
        let paragraphEnd = paragraphRange.location + (paragraph as NSString).length
        guard selectedRange.location == paragraphEnd else { return nil }

        if let result = taskListContinuation(in: text, paragraph: paragraph, paragraphRange: paragraphRange, selectedRange: selectedRange) {
            return result
        }
        if let result = unorderedListContinuation(in: text, paragraph: paragraph, paragraphRange: paragraphRange, selectedRange: selectedRange) {
            return result
        }
        if let result = orderedListContinuation(in: text, paragraph: paragraph, paragraphRange: paragraphRange, selectedRange: selectedRange) {
            return result
        }
        return nil
    }

    static func indentListItem(in text: String, selectedRange: NSRange) -> (text: String, selectedRange: NSRange)? {
        adjustCurrentListItemIndent(in: text, selectedRange: selectedRange, isOutdent: false)
    }

    static func outdentListItem(in text: String, selectedRange: NSRange) -> (text: String, selectedRange: NSRange)? {
        adjustCurrentListItemIndent(in: text, selectedRange: selectedRange, isOutdent: true)
    }

    private static func wrapSelection(
        _ marker: String,
        suffix: String? = nil,
        in text: String,
        selectedRange: NSRange,
        placeholder: String
    ) -> (text: String, selectedRange: NSRange) {
        let replacementSuffix = suffix ?? marker
        let selectedText = substring(text, in: selectedRange)
        let content = selectedText.isEmpty ? placeholder : selectedText
        let replacement = marker + content + replacementSuffix
        let updated = replace(text, range: selectedRange, with: replacement)
        let selectionStart = selectedRange.location + marker.utf16.count
        return (updated, NSRange(location: selectionStart, length: content.utf16.count))
    }

    private static func wrapBlock(
        prefix: String,
        suffix: String,
        in text: String,
        selectedRange: NSRange,
        placeholder: String
    ) -> (text: String, selectedRange: NSRange) {
        let selectedText = substring(text, in: selectedRange)
        let content = selectedText.isEmpty ? placeholder : selectedText
        let needsLeadingBreak = selectedRange.location > 0 && !(text as NSString).substring(to: selectedRange.location).hasSuffix("\n")
        let needsTrailingBreak = selectedRange.location + selectedRange.length < (text as NSString).length
        let leadingBreak = needsLeadingBreak ? "\n" : ""
        let trailingBreak = needsTrailingBreak ? "\n" : ""
        let replacement = "\(leadingBreak)\(prefix)\(content)\(suffix)\(trailingBreak)"
        let updated = replace(text, range: selectedRange, with: replacement)
        let selectionStart = selectedRange.location + leadingBreak.utf16.count + prefix.utf16.count
        return (updated, NSRange(location: selectionStart, length: content.utf16.count))
    }

    private static func insertTable(in text: String, selectedRange: NSRange) -> (text: String, selectedRange: NSRange) {
        let table = """
        | 项目 | 内容 |
        | --- | --- |
        |  |  |
        """
        let needsLeadingBreak = selectedRange.location > 0 && !(text as NSString).substring(to: selectedRange.location).hasSuffix("\n")
        let needsTrailingBreak = selectedRange.location + selectedRange.length < (text as NSString).length
        let leadingBreak = needsLeadingBreak ? "\n" : ""
        let trailingBreak = needsTrailingBreak ? "\n" : ""
        let replacement = leadingBreak + table + trailingBreak
        let updated = replace(text, range: selectedRange, with: replacement)
        let selectionStart = selectedRange.location + leadingBreak.utf16.count + "| ".utf16.count
        return (updated, NSRange(location: selectionStart, length: "项目".utf16.count))
    }

    private static func prefixSelectedLines(
        _ prefix: String,
        in text: String,
        selectedRange: NSRange
    ) -> (text: String, selectedRange: NSRange) {
        let nsText = text as NSString
        let lineRange = nsText.lineRange(for: selectedRange)
        let selectedBlock = nsText.substring(with: lineRange)
        let lines = selectedBlock.split(separator: "\n", omittingEmptySubsequences: false)
        let prefixed = lines.map { line -> String in
            let value = String(line)
            return value.hasPrefix(prefix) ? value : prefix + value
        }.joined(separator: "\n")
        let updated = nsText.replacingCharacters(in: lineRange, with: prefixed)
        return (updated, NSRange(location: lineRange.location, length: prefixed.utf16.count))
    }

    private static func adjustCurrentListItemIndent(
        in text: String,
        selectedRange: NSRange,
        isOutdent: Bool
    ) -> (text: String, selectedRange: NSRange)? {
        let nsText = text as NSString
        guard nsText.length > 0, selectedRange.location <= nsText.length else { return nil }

        let probeLocation = min(selectedRange.location, max(nsText.length - 1, 0))
        let lineRange = nsText.lineRange(for: NSRange(location: probeLocation, length: 0))
        let line = nsText.substring(with: lineRange).trimmingCharacters(in: .newlines)
        guard isListLine(line) else { return nil }

        if isOutdent {
            let removalLength: Int
            if line.hasPrefix("\t") {
                removalLength = 1
            } else {
                removalLength = min(line.prefix(4).filter { $0 == " " }.count, 4)
            }

            guard removalLength > 0 else { return nil }
            let removeRange = NSRange(location: lineRange.location, length: removalLength)
            let updated = replace(text, range: removeRange, with: "")
            let adjustedLocation = max(lineRange.location, selectedRange.location - removalLength)
            return (updated, NSRange(location: adjustedLocation, length: selectedRange.length))
        }

        let updated = replace(text, range: NSRange(location: lineRange.location, length: 0), with: "    ")
        return (updated, NSRange(location: selectedRange.location + 4, length: selectedRange.length))
    }

    private static func isListLine(_ line: String) -> Bool {
        firstMatch(#"^\s*(?:[-*+](?:\s+\[[ xX]\])?|\d+\.)(?:\s|$)"#, in: line) != nil
    }

    private static func substring(_ text: String, in range: NSRange) -> String {
        (text as NSString).substring(with: range)
    }

    private static func replace(_ text: String, range: NSRange, with replacement: String) -> String {
        (text as NSString).replacingCharacters(in: range, with: replacement)
    }

    private static func taskListContinuation(
        in text: String,
        paragraph: String,
        paragraphRange: NSRange,
        selectedRange: NSRange
    ) -> (text: String, selectedRange: NSRange)? {
        guard let match = firstMatch(#"^(\s*)([-*+])(\s+)\[( |x|X)\](\s+)(.*)$"#, in: paragraph) else { return nil }
        let content = capturedString(paragraph, match: match, index: 6)
        let prefixLength = match.range(at: 1).length + match.range(at: 2).length + match.range(at: 3).length + 3 + match.range(at: 5).length

        if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return removeListPrefix(from: text, paragraphRange: paragraphRange, prefixLength: prefixLength)
        }

        let indent = capturedString(paragraph, match: match, index: 1)
        let marker = capturedString(paragraph, match: match, index: 2)
        let spacing = capturedString(paragraph, match: match, index: 3)
        let afterCheckbox = capturedString(paragraph, match: match, index: 5)
        return insert("\n\(indent)\(marker)\(spacing)[ ]\(afterCheckbox)", in: text, selectedRange: selectedRange)
    }

    private static func unorderedListContinuation(
        in text: String,
        paragraph: String,
        paragraphRange: NSRange,
        selectedRange: NSRange
    ) -> (text: String, selectedRange: NSRange)? {
        guard let match = firstMatch(#"^(\s*)([-*+])(\s+)(.*)$"#, in: paragraph) else { return nil }
        let content = capturedString(paragraph, match: match, index: 4)
        let prefixLength = match.range(at: 1).length + match.range(at: 2).length + match.range(at: 3).length

        if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return removeListPrefix(from: text, paragraphRange: paragraphRange, prefixLength: prefixLength)
        }

        let indent = capturedString(paragraph, match: match, index: 1)
        let marker = capturedString(paragraph, match: match, index: 2)
        let spacing = capturedString(paragraph, match: match, index: 3)
        return insert("\n\(indent)\(marker)\(spacing)", in: text, selectedRange: selectedRange)
    }

    private static func orderedListContinuation(
        in text: String,
        paragraph: String,
        paragraphRange: NSRange,
        selectedRange: NSRange
    ) -> (text: String, selectedRange: NSRange)? {
        guard let match = firstMatch(#"^(\s*)(\d+)\.(\s+)(.*)$"#, in: paragraph) else { return nil }
        let content = capturedString(paragraph, match: match, index: 4)
        let prefixLength = match.range(at: 1).length + match.range(at: 2).length + 1 + match.range(at: 3).length

        if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return removeListPrefix(from: text, paragraphRange: paragraphRange, prefixLength: prefixLength)
        }

        let indent = capturedString(paragraph, match: match, index: 1)
        let number = Int(capturedString(paragraph, match: match, index: 2)) ?? 1
        let spacing = capturedString(paragraph, match: match, index: 3)
        return insert("\n\(indent)\(number + 1).\(spacing)", in: text, selectedRange: selectedRange)
    }

    private static func insert(_ insertion: String, in text: String, selectedRange: NSRange) -> (text: String, selectedRange: NSRange) {
        let updated = replace(text, range: selectedRange, with: insertion)
        return (updated, NSRange(location: selectedRange.location + insertion.utf16.count, length: 0))
    }

    private static func removeListPrefix(from text: String, paragraphRange: NSRange, prefixLength: Int) -> (text: String, selectedRange: NSRange) {
        let removeRange = NSRange(location: paragraphRange.location, length: prefixLength)
        let updated = replace(text, range: removeRange, with: "")
        return (updated, NSRange(location: paragraphRange.location, length: 0))
    }

    private static func firstMatch(_ pattern: String, in text: String) -> NSTextCheckingResult? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        return regex.firstMatch(in: text, range: NSRange(location: 0, length: (text as NSString).length))
    }

    private static func capturedString(_ text: String, match: NSTextCheckingResult, index: Int) -> String {
        guard match.range(at: index).location != NSNotFound else { return "" }
        return (text as NSString).substring(with: match.range(at: index))
    }
}
