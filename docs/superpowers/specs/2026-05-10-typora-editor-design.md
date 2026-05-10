# Typora-Style Markdown Editor Design

## Overview

将随记编辑器改造为 Typora 风格的所见即所得 markdown 编辑器：非活跃行隐藏 markdown 标记符号，只显示渲染后的富文本效果；光标所在行（活跃行）以淡色显示标记符号，方便编辑。

文本存储层始终保存原始 markdown 源码，仅在显示层控制标记可见性。

## 技术方案

使用自定义 `NSLayoutManager` 子类，重写 `setGlyphs` 方法，将非活跃行标记字符的 `glyphProperty` 设为 `.null`，使其不渲染、不占空间。

选择该方案的理由：
- 效果最彻底，标记完全不占空间
- 光标交互自然，文本存储层不需要替换内容
- macOS 14+ 完全支持 NSLayoutManager，短期无弃用风险
- 当前代码已有 MarkdownHighlighter 基础，改造成本低

## 核心组件

### 1. MarkdownHighlighter（已有，改造）

职责：解析 markdown 语法，产出两样东西：
- 富文本样式（标题大字、粗体、斜体等）应用到 NSTextStorage
- 标记符号的字符索引集合 `markerIndexes: Set<Int>`，传给 LayoutManager

改造点：
- `highlight(_:activeLineRange:)` 返回值增加 `markerIndexes: Set<Int>`
- 每种语法的正则匹配中，记录标记符号字符的位置（如 `**` 的两个字符索引）

### 2. HiddenMarkerLayoutManager: NSLayoutManager（新建）

核心类，继承 NSLayoutManager。

属性：
- `markerIndexes: Set<Int>` — 所有应隐藏的标记字符位置
- `activeLineRange: NSRange?` — 当前光标所在段落范围

重写方法：
- `setGlyphs(_:properties:characterIndexes:font:forGlyphRange:)` — 遍历每个字符，若 characterIndex 在 `markerIndexes` 内且不在 `activeLineRange` 内，将对应 glyphProperty 设为 `.null`

### 3. TyporaEditorView（已有，改造）

Coordinator 改造：
- `makeNSView` 时创建 `HiddenMarkerLayoutManager`，替换 NSTextView 默认的 layoutManager
- `textViewDidChangeSelection` — 更新活跃行，对旧/新活跃行范围调用 `invalidateGlyphs`
- `textDidChange` — 重新高亮，更新 markerIndexes，触发 glyph 重算

## 语法隐藏规则

### 标题 `## text`
- 隐藏字符：`## `（含尾随空格）
- 非活跃行：大号粗体文字，无 `#` 号
- 活跃行：`## ` 淡色显示

### 粗体 `**text**`
- 隐藏字符：前后 `**`
- 非活跃行：粗体文字
- 活跃行：`**` 淡色显示

### 斜体 `*text*`
- 隐藏字符：前后 `*`
- 非活跃行：斜体文字
- 活跃行：`*` 淡色显示

### 行内代码 `` `code` ``
- 隐藏字符：前后 `` ` ``
- 非活跃行：圆角灰底代码样式
- 活跃行：`` ` `` 淡色显示

### 删除线 `~~text~~`
- 隐藏字符：前后 `~~`
- 非活跃行：删除线文字
- 活跃行：`~~` 淡色显示

### 链接 `[text](url)`
- 隐藏字符：`[`、`]`、`(url)`
- 非活跃行：蓝色带下划线文字（只显示 text 部分）
- 活跃行：全部标记淡色显示

### 引用 `> text`
- 隐藏字符：`> `
- 非活跃行：左侧竖线装饰 + 灰色文字（通过段落样式 headIndent + 自定义绘制竖线）
- 活跃行：`> ` 淡色显示

### 无序列表 `- item`
- 隐藏字符：`- `
- 非活跃行：用 NSTextAttachment 替换为圆点 `•`
- 活跃行：`- ` 淡色显示

### 有序列表 `1. item`
- 不隐藏标记（标记本身是内容）
- 非活跃行/活跃行：保持原样

### 任务列表 `- [ ] text` / `- [x] text`
- 隐藏字符：`- [ ] ` 或 `- [x] `
- 非活跃行：用 NSTextAttachment 替换为 checkbox 图标（未勾选/已勾选）
- 活跃行：源码淡色显示

### 代码块 ` ``` `
- 隐藏字符：围栏行（` ``` ` 和 ` ``` `）整行
- 非活跃行：代码内容灰底显示，围栏行完全隐藏
- 活跃行：围栏行淡色显示
- 多行结构：光标在代码块任意行时，整个代码块算"活跃"

### 表格 `| a | b |`
- 不隐藏标记（标记本身是结构）
- 非活跃行/活跃行：保持原样对齐显示

## 光标与刷新机制

### 活跃行检测
- `textViewDidChangeSelection` 触发时，用 `paragraphRange(for:)` 获取光标所在段落
- 代码块等多行结构：若光标在围栏行或内容行内，整个代码块范围都算活跃
- 多光标/选区跨行：活跃范围取选区覆盖的所有段落

### 增量刷新（性能关键）
- 光标移动时不重新高亮整篇文档：
  1. 比较 `oldActiveLineRange` 与 `newActiveLineRange`
  2. 仅对这两个范围调用 `invalidateGlyphs(forCharacterRange:)`
  3. `setGlyphs` 只在这两个范围内重新判断 `.null` 或正常显示
- 文本编辑时（`textDidChange`）：对编辑影响的段落做完整高亮 + 更新 markerIndexes

### 边界情况
- 空文档：无标记，正常编辑
- 粘贴大段文本：走 `textDidChange` 全量高亮路径
- 连续快速输入：`textDidChange` 每次触发都做增量更新，不做防抖

## 文件变更清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `Shared/Views/TyporaEditorView.swift` | 改造 | 注入 HiddenMarkerLayoutManager，改造 Coordinator |
| `Shared/Utils/MarkdownSyntax.swift` | 改造 | MarkdownHighlighter 增加 markerIndexes 返回值 |
| `Tests/StockDiaryModelTests.swift` | 新增测试 | 验证 markerIndexes 正确性、活跃行切换行为 |

不新增文件，`HiddenMarkerLayoutManager` 放在 `TyporaEditorView.swift` 内部（仅该文件使用）。

## 平台说明

- macOS：完整实现（NSTextView + NSLayoutManager）
- iOS：暂不实现 Typora 效果，保持现有 UITextView 纯文本编辑。iOS 的 TextKit 1 LayoutManager 行为与 macOS 有差异，后续单独适配。
