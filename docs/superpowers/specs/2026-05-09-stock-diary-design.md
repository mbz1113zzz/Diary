# StockDiary - 美股交易日记 App 设计文档

## 概述

个人美股交易复盘日记应用，支持 Mac 和 iOS 双端，通过 iCloud 自动同步。核心功能是交易记录复盘 + 日常状态记录（心情、天气、待办）。

## 用户画面

- 使用富途看盘、IBKR 交易、TradingView 辅助
- 交易完成后打开 StockDiary 手动记录复盘
- 偶尔记录日常状态，不强制每日
- 只在 Apple 设备间使用

## 技术栈

- **UI 框架：** SwiftUI
- **数据层：** SwiftData
- **同步方案：** CloudKit（通过 SwiftData 的 ModelConfiguration 开启）
- **最低系统要求：** iOS 17.0+ / macOS 14.0+（Sonoma）
- **开发工具：** Xcode，需要 Apple Developer 账号

## 数据模型

三个独立模型，通过 `date` 字段关联到同一天。

### DiaryEntry（日记条目）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| date | Date | 记录日期 |
| content | String | 自由文字 |
| mood | String? | 心情（枚举：😊😐😔😤🤩等） |
| weather | String? | 天气（枚举：晴/阴/雨/雪等） |
| createdAt | Date | 创建时间 |
| updatedAt | Date | 修改时间 |

### TradeEntry（交易记录）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| date | Date | 交易日期 |
| ticker | String | 股票代码（如 AAPL） |
| direction | String | 买入 / 卖出 |
| price | Double | 成交价 |
| quantity | Int | 数量 |
| entryReason | String? | 入场理由 |
| exitReason | String? | 出场理由 |
| emotion | String? | 当时情绪 |
| pnl | Double? | 盈亏金额 |
| pnlPercent | Double? | 盈亏比例 |
| notes | String? | 复盘笔记 |
| createdAt | Date | 创建时间 |

### TodoItem（待办事项）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| title | String | 内容 |
| isCompleted | Bool | 是否完成 |
| date | Date | 所属日期 |
| createdAt | Date | 创建时间 |

## 页面结构

### Mac 端 — 三栏布局（NavigationSplitView）

- **侧边栏：** 日历视图、交易列表、待办列表、搜索
- **列表栏：** 按日期倒序排列的卡片流，每张卡片显示当天摘要
- **详情区：** 选中某天后展示完整内容，可直接内联编辑

### iOS 端 — Tab 导航（TabView）

5 个 Tab：
1. **日记** — 按日期排列的日记卡片列表
2. **交易** — 交易记录列表
3. **新建（+）** — 中间突出按钮，弹出选择新建日记或交易
4. **待办** — 待办事项列表
5. **设置** — 应用设置

### 关键交互

- 首页打开即是今天，往下滑看历史
- **+** 按钮弹出选择：新建日记 / 新建交易记录
- 卡片点击进入编辑
- 日历视图可跳到特定日期

## 卡片设计

### 整体风格

- 浅色为主，支持深色模式
- 圆角卡片 + 轻微阴影，卡片间留白充足
- 系统字体 SF Pro，干净简约
- 配色以中性灰为基调，盈亏用绿/红点缀

### 日记卡片

显示：心情 emoji + 天气 icon + 日期 + 内容摘要（前两行）+ 当天交易笔数 + 待办完成进度

### 交易卡片

显示：股票代码 + 方向（买入/卖出）+ 日期 + 价格×数量 + 盈亏金额和百分比（绿盈红亏）+ 入场理由 + 情绪。卡片左侧一条细色带表示盈亏状态。

### 待办卡片

显示：标题 + 完成进度（如 2/3）+ 各条目的勾选状态

## 项目结构

```
StockDiary/
├── Shared/              # Mac 和 iOS 共享代码（~90%）
│   ├── Models/          # SwiftData 模型
│   ├── Views/           # 通用视图组件（卡片等）
│   ├── ViewModels/      # 业务逻辑
│   └── Utils/           # 工具类
├── macOS/               # Mac 专属（三栏导航壳）
├── iOS/                 # iOS 专属（Tab 导航壳）
└── StockDiary.xcodeproj
```

## 同步策略

- 使用 SwiftData 的 `ModelConfiguration` 开启 CloudKit 同步
- 自动处理：增删改同步、冲突合并（last-write-wins）、离线缓存
- iCloud 容器名：`iCloud.com.yourname.StockDiary`
- 在 Xcode 中启用 CloudKit capability 和 Background Modes（remote notifications）

## 明确不做的事情（v1）

- 不对接券商 API
- 不做数据导入/导出
- 不做统计图表
- 不做标签系统
- 不做图片附件
