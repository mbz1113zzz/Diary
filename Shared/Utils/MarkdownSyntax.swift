import Foundation
import Markdown

enum MarkdownSyntaxKind: Equatable {
    case heading(level: Int)
    case blockQuote
    case codeBlock
    case thematicBreak
    case unorderedList
    case orderedList
    case listItem(checkbox: MarkdownTaskState?)
    case strong
    case emphasis
    case strikethrough
    case inlineCode
    case link
    case image
    case htmlBlock
    case inlineHTML
    case table
    case tableCell
}

enum MarkdownTaskState: Equatable {
    case checked
    case unchecked
}

struct MarkdownSyntaxSpan: Equatable {
    let kind: MarkdownSyntaxKind
    let range: NSRange
}

enum MarkdownSyntaxParser {
    static func spans(in text: String) -> [MarkdownSyntaxSpan] {
        guard !text.isEmpty else { return [] }

        let document = Document(parsing: text)
        let mapper = SourceRangeMapper(text: text)
        var collector = MarkdownSyntaxCollector(mapper: mapper)
        collector.visit(document)
        return collector.spans.sorted {
            if $0.range.location == $1.range.location {
                return $0.range.length > $1.range.length
            }
            return $0.range.location < $1.range.location
        }
    }
}

private struct MarkdownSyntaxCollector: MarkupWalker {
    let mapper: SourceRangeMapper
    var spans: [MarkdownSyntaxSpan] = []

    mutating func visitHeading(_ heading: Heading) {
        add(.heading(level: heading.level), range: heading.range)
        descendInto(heading)
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) {
        add(.blockQuote, range: blockQuote.range)
        descendInto(blockQuote)
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) {
        add(.codeBlock, range: codeBlock.range)
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) {
        add(.thematicBreak, range: thematicBreak.range)
    }

    mutating func visitUnorderedList(_ unorderedList: UnorderedList) {
        add(.unorderedList, range: unorderedList.range)
        descendInto(unorderedList)
    }

    mutating func visitOrderedList(_ orderedList: OrderedList) {
        add(.orderedList, range: orderedList.range)
        descendInto(orderedList)
    }

    mutating func visitListItem(_ listItem: ListItem) {
        let checkbox: MarkdownTaskState?
        switch listItem.checkbox {
        case .checked:
            checkbox = .checked
        case .unchecked:
            checkbox = .unchecked
        case .none:
            checkbox = nil
        }

        add(.listItem(checkbox: checkbox), range: listItem.range)
        descendInto(listItem)
    }

    mutating func visitStrong(_ strong: Strong) {
        add(.strong, range: strong.range)
        descendInto(strong)
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) {
        add(.emphasis, range: emphasis.range)
        descendInto(emphasis)
    }

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) {
        add(.strikethrough, range: strikethrough.range)
        descendInto(strikethrough)
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) {
        add(.inlineCode, range: inlineCode.range)
    }

    mutating func visitLink(_ link: Link) {
        add(.link, range: link.range)
        descendInto(link)
    }

    mutating func visitImage(_ image: Image) {
        add(.image, range: image.range)
        descendInto(image)
    }

    mutating func visitHTMLBlock(_ html: HTMLBlock) {
        add(.htmlBlock, range: html.range)
    }

    mutating func visitInlineHTML(_ inlineHTML: InlineHTML) {
        add(.inlineHTML, range: inlineHTML.range)
    }

    mutating func visitTable(_ table: Table) {
        add(.table, range: table.range)
        descendInto(table)
    }

    mutating func visitTableCell(_ tableCell: Table.Cell) {
        add(.tableCell, range: tableCell.range)
        descendInto(tableCell)
    }

    private mutating func add(_ kind: MarkdownSyntaxKind, range: SourceRange?) {
        guard let range, let nsRange = mapper.nsRange(for: range), nsRange.length > 0 else { return }
        spans.append(MarkdownSyntaxSpan(kind: kind, range: nsRange))
    }
}

private struct SourceRangeMapper {
    let text: String
    let lineStartByteOffsets: [Int]

    init(text: String) {
        self.text = text

        var starts = [0]
        var offset = 0
        for byte in text.utf8 {
            offset += 1
            if byte == 10 {
                starts.append(offset)
            }
        }
        lineStartByteOffsets = starts
    }

    func nsRange(for sourceRange: SourceRange) -> NSRange? {
        guard let lowerByteOffset = byteOffset(for: sourceRange.lowerBound),
              let upperByteOffset = byteOffset(for: sourceRange.upperBound),
              lowerByteOffset <= upperByteOffset,
              let lowerIndex = stringIndex(forUTF8Offset: lowerByteOffset),
              let upperIndex = stringIndex(forUTF8Offset: upperByteOffset) else {
            return nil
        }

        return NSRange(lowerIndex..<upperIndex, in: text)
    }

    private func byteOffset(for location: SourceLocation) -> Int? {
        let lineIndex = location.line - 1
        guard lineIndex >= 0, lineIndex < lineStartByteOffsets.count else { return nil }
        return lineStartByteOffsets[lineIndex] + max(location.column - 1, 0)
    }

    private func stringIndex(forUTF8Offset offset: Int) -> String.Index? {
        guard offset >= 0,
              let utf8Index = text.utf8.index(text.utf8.startIndex, offsetBy: offset, limitedBy: text.utf8.endIndex) else {
            return nil
        }
        return String.Index(utf8Index, within: text)
    }
}
