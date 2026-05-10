# Typora-Style Markdown Editor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the memo editor hide markdown markers on non-active lines using `NSLayoutManager.setGlyphs` with `.null` glyph properties, achieving a Typora-like WYSIWYG experience on macOS.

**Architecture:** A custom `HiddenMarkerLayoutManager` subclass intercepts glyph generation and nullifies marker characters. `MarkdownHighlighter` is extended to return `markerIndexes: Set<Int>` alongside its existing rich-text styling. The `TyporaEditorView` Coordinator wires the two together, passing marker data to the layout manager and triggering incremental glyph invalidation on cursor movement.

**Tech Stack:** AppKit (NSLayoutManager, NSTextView, NSTextStorage), Swift regex, SwiftUI NSViewRepresentable

---

## File Structure

| File | Role |
|------|------|
| `Shared/Views/TyporaEditorView.swift` | Contains `HiddenMarkerLayoutManager` (new, internal for testability), modified `MarkdownHighlighter`, modified macOS `TyporaEditorView` + Coordinator |
| `Tests/StockDiaryModelTests.swift` | New test methods for marker index extraction and glyph nullification |

No new files. `HiddenMarkerLayoutManager` lives in `TyporaEditorView.swift` with `internal` access for testability.

---

### Task 1: MarkdownHighlighter returns markerIndexes

Extend `MarkdownHighlighter.highlight` to collect and return the character indexes of every marker character that should be hidden on non-active lines. The existing styling logic stays unchanged — we're adding a return value.

**Files:**
- Modify: `Shared/Views/TyporaEditorView.swift` (the `MarkdownHighlighter` enum, lines 5–578)
- Test: `Tests/StockDiaryModelTests.swift`

- [ ] **Step 1: Write the failing test for heading marker indexes**

Add to `Tests/StockDiaryModelTests.swift` at the end of the class, before the closing `}`:

```swift
#if os(macOS)
func testMarkerIndexesForHeading() {
    let storage = NSMutableAttributedString(string: "## Hello")
    let indexes = MarkdownHighlighter.highlight(storage, activeLineRange: nil)

    // "## " = characters 0, 1, 2 should be markers
    XCTAssertTrue(indexes.contains(0))
    XCTAssertTrue(indexes.contains(1))
    XCTAssertTrue(indexes.contains(2))
    // "Hello" characters should NOT be markers
    XCTAssertFalse(indexes.contains(3))
    XCTAssertFalse(indexes.contains(4))
}
#endif
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild -project StockDiary.xcodeproj -scheme StockDiary_macOS -destination 'platform=macOS' test 2>&1 | grep -E '(testMarkerIndexes|FAIL|error:)'`

Expected: Compilation error — `highlight` currently returns `Void`, not `Set<Int>`.

- [ ] **Step 3: Change highlight return type and collect marker indexes**

In `Shared/Views/TyporaEditorView.swift`, modify the `MarkdownHighlighter` enum:

1. Change the `highlight` signature to return `Set<Int>`:

```swift
@discardableResult
static func highlight(_ storage: NSMutableAttributedString, activeLineRange: NSRange? = nil) -> Set<Int> {
```

2. Add a mutable set at the top of the function body, right after `let text = storage.string`:

```swift
var markerIndexes = Set<Int>()
```

3. Add a helper function inside `highlight`, right after the `styleMarker` function:

```swift
func collectMarkers(_ range: NSRange) {
    guard range.location != NSNotFound, range.length > 0 else { return }
    for i in range.location..<(range.location + range.length) {
        markerIndexes.insert(i)
    }
}
```

4. Update `hideMarker` to also collect: add `collectMarkers(range)` as the first line inside `hideMarker`.

5. Update `styleMarker` to collect regardless of active state — markers are always tracked, active/inactive only changes *display*. Replace the body:

```swift
func styleMarker(_ range: NSRange, forMatch matchRange: NSRange) {
    collectMarkers(range)
    if isActive(matchRange) {
        dimMarker(range)
    } else {
        hideMarker(range)
    }
}
```

6. Update `drawBulletMarker` to also collect: add `collectMarkers(range)` as the first line inside `drawBulletMarker`.

7. For the heading regex handler (the `applyRegex("^(#{1,6})( +)(.+)$"` block), add `collectMarkers` calls. The non-active branch already calls `hideMarker` (which now collects). The active branch calls `dimMarker` but NOT `collectMarkers`. Add these lines in the active branch, right before `dimMarker(hashRange)`:

```swift
collectMarkers(hashRange)
collectMarkers(spaceRange)
```

8. For the block quote regex handler, add in the active branch before `dimMarker(markerRange)`:

```swift
collectMarkers(markerRange)
if spaceRange.length > 0 { collectMarkers(spaceRange) }
```

9. For the task list regex handler, add in the active branch before `dimMarker(markerRange)`:

```swift
collectMarkers(markerRange)
```

10. For the fenced code block regex handler, add in the active branch before the `dimMarker` calls:

```swift
collectMarkers(m.range(at: 1))
if let languageRange = optionalRange(m.range(at: 2)) {
    collectMarkers(languageRange)
}
collectMarkers(m.range(at: 4))
```

11. For the inline code regex handler, the active branch calls `dimMarker` but not `collectMarkers`. Add before the `dimMarker` calls in the active branch:

```swift
collectMarkers(m.range(at: 1))
collectMarkers(m.range(at: 3))
```

12. For the links regex handler, the active branch dims markers but doesn't collect. Add at the start of the active branch:

```swift
for i in [1, 3, 4, 5, 6] {
    let r = m.range(at: i)
    if r.location != NSNotFound { collectMarkers(r) }
}
```

13. For the images regex handler, add at the start of both branches (before any existing code):

```swift
collectMarkers(NSRange(location: m.range.location, length: 1))  // !
collectMarkers(NSRange(location: m.range.location + 1, length: 1))  // [
let afterAlt = m.range(at: 2).location + m.range(at: 2).length
let tailLen = m.range.location + m.range.length - afterAlt
if tailLen > 0 { collectMarkers(NSRange(location: afterAlt, length: tailLen)) }
```

Note: the images handler currently duplicates this range calculation in the non-active branch — you can extract it above the `if isActive` check and use it in both branches.

14. Add `return markerIndexes` as the last line of the `highlight` function.

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild -project StockDiary.xcodeproj -scheme StockDiary_macOS -destination 'platform=macOS' test 2>&1 | grep -E '(testMarkerIndexes|Test Suite|Executed)'`

Expected: `testMarkerIndexesForHeading` PASSES.

- [ ] **Step 5: Write more marker index tests**

Add to `Tests/StockDiaryModelTests.swift`:

```swift
#if os(macOS)
func testMarkerIndexesForBoldAndItalic() {
    // "**bold** and *italic*"
    let text = "**bold** and *italic*"
    let storage = NSMutableAttributedString(string: text)
    let indexes = MarkdownHighlighter.highlight(storage, activeLineRange: nil)

    // ** at 0,1 and 6,7 should be markers
    XCTAssertTrue(indexes.contains(0))
    XCTAssertTrue(indexes.contains(1))
    XCTAssertTrue(indexes.contains(6))
    XCTAssertTrue(indexes.contains(7))
    // * at 13 and 20 should be markers
    XCTAssertTrue(indexes.contains(13))
    XCTAssertTrue(indexes.contains(20))
    // content should NOT be markers
    XCTAssertFalse(indexes.contains(2))  // 'b' in bold
    XCTAssertFalse(indexes.contains(14)) // 'i' in italic
}

func testMarkerIndexesForInlineCode() {
    let text = "use `code` here"
    let storage = NSMutableAttributedString(string: text)
    let indexes = MarkdownHighlighter.highlight(storage, activeLineRange: nil)

    // backticks at 4 and 9
    XCTAssertTrue(indexes.contains(4))
    XCTAssertTrue(indexes.contains(9))
    // 'c' in code should not be marker
    XCTAssertFalse(indexes.contains(5))
}

func testMarkerIndexesForLink() {
    let text = "[click](https://example.com)"
    let storage = NSMutableAttributedString(string: text)
    let indexes = MarkdownHighlighter.highlight(storage, activeLineRange: nil)

    // [ at 0, ] at 6, (https://example.com) at 7..27
    XCTAssertTrue(indexes.contains(0))   // [
    XCTAssertTrue(indexes.contains(6))   // ]
    XCTAssertTrue(indexes.contains(7))   // (
    XCTAssertTrue(indexes.contains(27))  // )
    // "click" should NOT be markers
    XCTAssertFalse(indexes.contains(1))  // c
    XCTAssertFalse(indexes.contains(5))  // k
}

func testMarkerIndexesForStrikethrough() {
    let text = "~~deleted~~"
    let storage = NSMutableAttributedString(string: text)
    let indexes = MarkdownHighlighter.highlight(storage, activeLineRange: nil)

    // ~~ at 0,1 and 9,10
    XCTAssertTrue(indexes.contains(0))
    XCTAssertTrue(indexes.contains(1))
    XCTAssertTrue(indexes.contains(9))
    XCTAssertTrue(indexes.contains(10))
    // "deleted" not markers
    XCTAssertFalse(indexes.contains(2))
}

func testMarkerIndexesForUnorderedList() {
    let text = "- item"
    let storage = NSMutableAttributedString(string: text)
    let indexes = MarkdownHighlighter.highlight(storage, activeLineRange: nil)

    // "- " at 0,1 should be markers (dash replaced by bullet)
    XCTAssertTrue(indexes.contains(0))
    // "item" not markers
    XCTAssertFalse(indexes.contains(2))
}

func testActiveLineExcludesMarkersFromHiding() {
    let text = "## Hello"
    let storage = NSMutableAttributedString(string: text)
    let activeRange = NSRange(location: 0, length: (text as NSString).length)
    let indexes = MarkdownHighlighter.highlight(storage, activeLineRange: activeRange)

    // markers are still tracked even on the active line
    XCTAssertTrue(indexes.contains(0))
    XCTAssertTrue(indexes.contains(1))
    XCTAssertTrue(indexes.contains(2))
}
#endif
```

- [ ] **Step 6: Run all tests**

Run: `xcodebuild -project StockDiary.xcodeproj -scheme StockDiary_macOS -destination 'platform=macOS' test 2>&1 | grep -E '(testMarkerIndexes|testActiveLineExcludes|FAIL|Executed)'`

Expected: All new tests PASS.

- [ ] **Step 7: Commit**

```bash
git add Shared/Views/TyporaEditorView.swift Tests/StockDiaryModelTests.swift
git commit -m "feat: MarkdownHighlighter returns markerIndexes for all syntax types"
```

---

### Task 2: Create HiddenMarkerLayoutManager

Build the custom NSLayoutManager subclass that uses `markerIndexes` and `activeLineRange` to set marker glyphs to `.null`.

**Files:**
- Modify: `Shared/Views/TyporaEditorView.swift` (add new class before the `#if os(macOS)` editor section)
- Test: `Tests/StockDiaryModelTests.swift`

- [ ] **Step 1: Write a failing test for glyph nullification**

Add to `Tests/StockDiaryModelTests.swift`:

```swift
#if os(macOS)
func testHiddenMarkerLayoutManagerNullifiesMarkerGlyphs() {
    let storage = NSTextStorage(string: "## Hello")
    let layoutManager = HiddenMarkerLayoutManager()
    let container = NSTextContainer(size: NSSize(width: 500, height: 10000))
    container.widthTracksTextView = true
    layoutManager.addTextContainer(container)
    storage.addLayoutManager(layoutManager)

    // Get marker indexes from highlighter
    let indexes = MarkdownHighlighter.highlight(storage, activeLineRange: nil)
    layoutManager.markerIndexes = indexes
    layoutManager.activeLineRange = nil

    // Force glyph generation
    layoutManager.ensureGlyphs(forCharacterRange: NSRange(location: 0, length: storage.length))

    // Marker glyphs (chars 0,1,2) should be .null — they take no space
    var glyphRange = NSRange()
    let rect0 = layoutManager.boundingRect(forGlyphRange: NSRange(location: 0, length: 3), in: container)

    // The "## " should occupy zero or near-zero width
    XCTAssertLessThan(rect0.width, 1.0, "Hidden marker glyphs should take no visual space")
}
#endif
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild -project StockDiary.xcodeproj -scheme StockDiary_macOS -destination 'platform=macOS' test 2>&1 | grep -E '(testHiddenMarker|FAIL|error:)'`

Expected: Compilation error — `HiddenMarkerLayoutManager` is not defined.

- [ ] **Step 3: Implement HiddenMarkerLayoutManager**

Add to `Shared/Views/TyporaEditorView.swift`, inside the `#if os(macOS)` block (before the `struct TyporaEditorView` definition). It must NOT be `private` since the test file needs to access it:

```swift
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
        // Copy the properties array so we can modify individual entries
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild -project StockDiary.xcodeproj -scheme StockDiary_macOS -destination 'platform=macOS' test 2>&1 | grep -E '(testHiddenMarker|Executed|FAIL)'`

Expected: `testHiddenMarkerLayoutManagerNullifiesMarkerGlyphs` PASSES.

- [ ] **Step 5: Write test that active line markers are NOT nullified**

Add to `Tests/StockDiaryModelTests.swift`:

```swift
#if os(macOS)
func testHiddenMarkerLayoutManagerShowsMarkersOnActiveLine() {
    let storage = NSTextStorage(string: "## Hello")
    let layoutManager = HiddenMarkerLayoutManager()
    let container = NSTextContainer(size: NSSize(width: 500, height: 10000))
    container.widthTracksTextView = true
    layoutManager.addTextContainer(container)
    storage.addLayoutManager(layoutManager)

    let indexes = MarkdownHighlighter.highlight(storage, activeLineRange: NSRange(location: 0, length: 8))
    layoutManager.markerIndexes = indexes
    layoutManager.activeLineRange = NSRange(location: 0, length: 8)

    layoutManager.ensureGlyphs(forCharacterRange: NSRange(location: 0, length: storage.length))

    // With active line covering the whole text, markers should be visible (take space)
    let rect = layoutManager.boundingRect(forGlyphRange: NSRange(location: 0, length: 3), in: container)
    XCTAssertGreaterThan(rect.width, 1.0, "Active line markers should be visible and take space")
}
#endif
```

- [ ] **Step 6: Run test to verify it passes**

Run: `xcodebuild -project StockDiary.xcodeproj -scheme StockDiary_macOS -destination 'platform=macOS' test 2>&1 | grep -E '(testHiddenMarker|Executed|FAIL)'`

Expected: Both `HiddenMarkerLayoutManager` tests PASS.

- [ ] **Step 7: Commit**

```bash
git add Shared/Views/TyporaEditorView.swift Tests/StockDiaryModelTests.swift
git commit -m "feat: add HiddenMarkerLayoutManager with glyph nullification"
```

---

### Task 3: Wire HiddenMarkerLayoutManager into TyporaEditorView

Replace the default NSLayoutManager in the NSTextView with our custom one. Update the Coordinator to pass markerIndexes and activeLineRange, and to do incremental glyph invalidation on cursor movement.

**Files:**
- Modify: `Shared/Views/TyporaEditorView.swift` (the macOS `TyporaEditorView` struct and `Coordinator` class)

- [ ] **Step 1: Modify makeNSView to inject HiddenMarkerLayoutManager**

In `TyporaEditorView.makeNSView`, replace the default text setup. Change the function body to create an NSTextView with our custom layout manager. Replace the current `makeNSView` implementation:

```swift
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
```

- [ ] **Step 2: Update the Coordinator.rehighlight method**

Replace the existing `rehighlight` method in the Coordinator class:

```swift
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
        // Invalidate all glyphs to re-run setGlyphs with updated marker/active state
        layoutManager.invalidateGlyphs(forCharacterRange: NSRange(location: 0, length: storage.length), changeInLength: 0, actualCharacterRange: nil)
    }
}
```

- [ ] **Step 3: Add incremental invalidation to textViewDidChangeSelection**

Replace the existing `textViewDidChangeSelection` method for better performance — only invalidate the old and new active line ranges instead of the full document:

```swift
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
    // If both are nil (shouldn't happen normally), invalidate everything
    if oldActiveRange == nil && newActiveRange == nil {
        layoutManager.invalidateGlyphs(forCharacterRange: fullRange, changeInLength: 0, actualCharacterRange: nil)
    }

    isUpdating = false
}
```

- [ ] **Step 4: Build and verify**

Run: `xcodebuild -project StockDiary.xcodeproj -scheme StockDiary_macOS -destination 'platform=macOS' build 2>&1 | tail -5`

Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Run all tests to verify nothing is broken**

Run: `xcodebuild -project StockDiary.xcodeproj -scheme StockDiary_macOS -destination 'platform=macOS' test 2>&1 | grep -E '(Executed|FAIL|error:)'`

Expected: All tests PASS.

- [ ] **Step 6: Commit**

```bash
git add Shared/Views/TyporaEditorView.swift
git commit -m "feat: wire HiddenMarkerLayoutManager into TyporaEditorView with incremental invalidation"
```

---

### Task 4: Handle code block multi-line active range

Code blocks are multi-line structures. When the cursor is inside any line of a code block, the entire block (including fence lines) should be treated as "active" so the user can see the ``` markers.

**Files:**
- Modify: `Shared/Views/TyporaEditorView.swift` (the `computeActiveLineRange` function)
- Test: `Tests/StockDiaryModelTests.swift`

- [ ] **Step 1: Write a failing test**

Add to `Tests/StockDiaryModelTests.swift`:

```swift
func testActiveRangeExpandsToCodeBlock() {
    let text = "# Title\n```swift\nlet x = 1\n```\nEnd"
    // Cursor at "let x = 1" (position 17)
    let nsText = text as NSString
    let cursorPos = nsText.range(of: "let").location

    let range = computeActiveLineRangeExpandingCodeBlocks(cursorLocation: cursorPos, in: text)

    // Should expand to cover the entire code block including fences
    let expectedStart = nsText.range(of: "```swift").location
    let expectedEnd = nsText.range(of: "```\n", options: [], range: NSRange(location: expectedStart + 1, length: nsText.length - expectedStart - 1))
    let fenceEndLoc = expectedEnd.location + expectedEnd.length

    XCTAssertNotNil(range)
    XCTAssertEqual(range!.location, expectedStart)
    XCTAssertEqual(range!.location + range!.length, fenceEndLoc)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild -project StockDiary.xcodeproj -scheme StockDiary_macOS -destination 'platform=macOS' test 2>&1 | grep -E '(testActiveRange|FAIL|error:)'`

Expected: Compilation error — `computeActiveLineRangeExpandingCodeBlocks` not defined.

- [ ] **Step 3: Implement the expanded active range function**

Replace the existing `computeActiveLineRange` function in `TyporaEditorView.swift` (the private free function near line 582) with two functions:

```swift
private func computeActiveLineRange(cursorLocation: Int, in text: String) -> NSRange? {
    computeActiveLineRangeExpandingCodeBlocks(cursorLocation: cursorLocation, in: text)
}

func computeActiveLineRangeExpandingCodeBlocks(cursorLocation: Int, in text: String) -> NSRange? {
    let nsText = text as NSString
    guard nsText.length > 0 else { return nil }
    let safeLoc = min(max(cursorLocation, 0), nsText.length)
    let paragraphRange = nsText.paragraphRange(for: NSRange(location: safeLoc, length: 0))

    // Check if cursor is inside a fenced code block and expand to cover the whole block
    guard let fenceRegex = try? NSRegularExpression(pattern: "^```[^`]*$", options: .anchorsMatchLines) else {
        return paragraphRange
    }

    let fullRange = NSRange(location: 0, length: nsText.length)
    let fenceMatches = fenceRegex.matches(in: text, range: fullRange)

    // Pair up fence lines: [0,1], [2,3], ...
    var i = 0
    while i + 1 < fenceMatches.count {
        let openFence = fenceMatches[i]
        let closeFence = fenceMatches[i + 1]

        let blockStart = openFence.range.location
        let blockEnd = closeFence.range.location + closeFence.range.length

        // Expand blockEnd to include the newline after closing fence if present
        let expandedEnd: Int
        if blockEnd < nsText.length {
            let charAfter = nsText.character(at: blockEnd)
            expandedEnd = (charAfter == 10) ? blockEnd + 1 : blockEnd  // 10 = \n
        } else {
            expandedEnd = blockEnd
        }

        let blockRange = NSRange(location: blockStart, length: expandedEnd - blockStart)

        if NSLocationInRange(safeLoc, blockRange) || NSIntersectionRange(paragraphRange, blockRange).length > 0 {
            return blockRange
        }

        i += 2
    }

    return paragraphRange
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild -project StockDiary.xcodeproj -scheme StockDiary_macOS -destination 'platform=macOS' test 2>&1 | grep -E '(testActiveRange|Executed|FAIL)'`

Expected: `testActiveRangeExpandsToCodeBlock` PASSES.

- [ ] **Step 5: Commit**

```bash
git add Shared/Views/TyporaEditorView.swift Tests/StockDiaryModelTests.swift
git commit -m "feat: expand active line range to cover entire code block"
```

---

### Task 5: Remove the tinyFont/foregroundColor.clear hiding approach

Now that `HiddenMarkerLayoutManager` handles hiding via `.null` glyphs, the `hideMarker` function no longer needs to apply invisible font/color attributes. These attributes were the old approach that didn't work. Clean them up.

**Files:**
- Modify: `Shared/Views/TyporaEditorView.swift`

- [ ] **Step 1: Simplify hideMarker**

In `MarkdownHighlighter.highlight`, change the `hideMarker` function. It currently applies `.foregroundColor: hiddenColor` and `.font: tinyFont`. Since `HiddenMarkerLayoutManager` now handles the visual hiding, `hideMarker` only needs to collect marker indexes (already done) and optionally keep the dim color as a visual fallback for when layout manager is not present (iOS). Change to:

```swift
func hideMarker(_ range: NSRange) {
    guard range.location != NSNotFound, range.length > 0 else { return }
    collectMarkers(range)
    // On macOS, HiddenMarkerLayoutManager handles hiding via .null glyphs.
    // Apply dim color as fallback for platforms without the custom layout manager.
    storage.addAttribute(.foregroundColor, value: hiddenColor, range: range)
}
```

- [ ] **Step 2: Remove the tinyFont property**

Delete the `tinyFont` property from `MarkdownHighlighter`:

```swift
// DELETE THIS LINE:
static var tinyFont: PlatformFont { .systemFont(ofSize: 0.1) }
```

- [ ] **Step 3: Build and run tests**

Run: `xcodebuild -project StockDiary.xcodeproj -scheme StockDiary_macOS -destination 'platform=macOS' test 2>&1 | grep -E '(Executed|FAIL|error:)'`

Expected: BUILD SUCCEEDED, all tests PASS.

- [ ] **Step 4: Commit**

```bash
git add Shared/Views/TyporaEditorView.swift
git commit -m "refactor: remove tinyFont hack, rely on HiddenMarkerLayoutManager for marker hiding"
```

---

### Task 6: Manual smoke test and edge case fixes

Verify the editor works visually and fix any edge cases.

**Files:**
- Modify: `Shared/Views/TyporaEditorView.swift` (if fixes needed)

- [ ] **Step 1: Build and launch the app**

Run: `xcodebuild -project StockDiary.xcodeproj -scheme StockDiary_macOS -destination 'platform=macOS' build 2>&1 | tail -3`

Open the app, navigate to 随记 (Memo), create a new memo or open an existing one.

- [ ] **Step 2: Test each markdown syntax**

Type or paste the following test content into the editor:

```
# 大标题

## 二级标题

This is **bold** and *italic* and ~~deleted~~ text.

Use `inline code` here.

[Link text](https://example.com)

> This is a quote

- Item one
- Item two
  - Nested item

1. First
2. Second

- [ ] Unchecked task
- [x] Checked task

```swift
let x = 1
```

| Col A | Col B |
| --- | --- |
| 1 | 2 |
```

- [ ] **Step 3: Verify behavior for each syntax**

For each syntax type, click on a line containing it and verify:
- **Non-active line:** markers are hidden, only rendered content visible
- **Active line (cursor on it):** markers appear in dim/faded color
- **Moving cursor away:** markers hide again

Check specifically:
- Heading `#` markers disappear when cursor leaves the line
- `**bold**` shows as **bold** with no asterisks on non-active lines
- Code block fence lines (```) disappear when cursor is outside the block
- Bullet `- ` is replaced by a dot on non-active lines
- Link `[text](url)` only shows the text on non-active lines

- [ ] **Step 4: Fix any issues found and commit**

If all looks good:
```bash
git add -A
git commit -m "test: verify Typora-style editor works for all markdown syntax types"
```

If fixes were needed, describe them in the commit message.
