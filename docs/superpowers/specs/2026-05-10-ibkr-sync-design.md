# IBKR 交易同步设计文档

## 概述

通过 IBKR Client Portal Gateway 的 REST API，将 Interactive Brokers 的交易记录自动同步到 StockDiary，省去手动录入基础交易数据的步骤。用户只需手动填写复盘字段。

## 前置条件

- 用户需下载并运行 [IBKR Client Portal Gateway](https://www.interactivebrokers.com/en/trading/ib-api.php)
- Gateway 默认运行在 `https://localhost:5000`
- 每次启动 Gateway 需在浏览器中登录 IBKR 账号（session 有效期约 24 小时）

## 架构

```
StockDiary App
  ├── Shared/Services/IBKRService.swift (网络层)
  │   ├── 检测 Gateway 运行状态与认证状态
  │   ├── 拉取交易记录
  │   └── 拉取账户信息
  ├── Shared/Services/IBKRSyncManager.swift (同步逻辑)
  │   ├── 去重：按 IBKR executionId 判断是否已导入
  │   ├── 映射：IBKR 字段 → TradeEntry 模型
  │   └── 触发：手动按钮 + 启动时自动
  └── Shared/Views/IBKRSettingsView.swift (设置 UI)
      ├── Gateway 连接状态显示
      ├── Gateway 地址配置（默认 https://localhost:5000）
      ├── 打开浏览器登录按钮
      └── 手动同步按钮 + 上次同步时间
```

## API 端点

所有请求发往 Gateway 本地地址，默认 `https://localhost:5000`。

### 认证状态检测

```
GET /v1/api/iserver/auth/status
```

响应示例：
```json
{
  "authenticated": true,
  "competing": false,
  "connected": true
}
```

### 获取账户列表

```
GET /v1/api/portfolio/accounts
```

响应示例：
```json
[
  {
    "id": "U1234567",
    "accountId": "U1234567",
    "accountTitle": "个人账户",
    "type": "INDIVIDUAL"
  }
]
```

### 获取交易记录

```
GET /v1/api/iserver/account/trades
```

响应示例：
```json
[
  {
    "execution_id": "0000e0d5.6789abcd.01.01",
    "symbol": "AAPL",
    "side": "BOT",
    "price": "178.50",
    "size": "100",
    "trade_time": "20260510-14:30:00",
    "net_amount": -17850.0,
    "account": "U1234567",
    "exchange": "NASDAQ",
    "realized_pnl": "0",
    "conid": 265598
  }
]
```

### 保持 Session 活跃

```
POST /v1/api/tickle
```

在 app 运行期间定期调用（每 60 秒），防止 session 过期。

## 数据映射

| IBKR 字段 | TradeEntry 字段 | 转换逻辑 |
|-----------|----------------|---------|
| symbol | ticker | 直接映射 |
| side | direction | "BOT" → "买入", "SLD" → "卖出" |
| price | price | String → Double |
| size | quantity | 取绝对值，String → Int |
| trade_time | date | 解析 "yyyyMMdd-HH:mm:ss" 格式 |
| realized_pnl | pnl | String → Double，0 时设为 nil |
| execution_id | ibkrExecutionId | 直接映射，用于去重 |

## TradeEntry 模型变更

新增两个字段：

```swift
var ibkrExecutionId: String?  // IBKR 交易执行 ID，用于去重
var ibkrImported: Bool = false // 标记是否从 IBKR 导入
```

## 同步流程

### 启动时自动同步

```
App 启动
  → IBKRSyncManager.autoSync()
  → 检测 Gateway 状态 (GET /v1/api/iserver/auth/status)
  → 未运行或未认证 → 静默跳过，不打扰用户
  → 已认证 → 拉取交易 (GET /v1/api/iserver/account/trades)
  → 按 execution_id 去重（查询已有 ibkrExecutionId）
  → 新交易 → 创建 TradeEntry（复盘字段留空）
  → 更新 lastSyncTime
```

### 手动同步

```
用户点击同步按钮
  → 检测 Gateway 状态
  → 未运行 → 提示"请先启动 IBKR Gateway"
  → 未认证 → 提示并提供"打开浏览器登录"按钮
  → 已认证 → 拉取交易 → 去重 → 导入
  → 显示结果："导入了 X 笔新交易"
```

### Session 保活

```
Gateway 已认证时
  → 启动 Timer，每 55 秒调用 POST /v1/api/tickle
  → App 进入后台时停止
  → App 回到前台时重启
```

## 去重策略

- 以 `ibkrExecutionId` 为唯一键
- 同步前先查询数据库中已有的 executionId 集合
- 只导入集合中不存在的交易
- 不会覆盖用户已手动填写的复盘内容

## UI 设计

### 设置页 — IBKR 连接区域

```
Section("IBKR 连接") {
    // 连接状态指示灯（绿色已连接 / 红色未连接 / 灰色未检测）
    HStack {
        Circle (绿/红/灰, 8pt)
        Text("已连接" / "未连接" / "检测中...")
    }

    // Gateway 地址
    TextField("Gateway 地址", text: gatewayURL)
    // 默认 https://localhost:5000

    // 操作按钮
    Button("在浏览器中登录") → NSWorkspace.shared.open(gatewayURL)
    Button("立即同步") → IBKRSyncManager.manualSync()

    // 上次同步时间
    Text("上次同步：2026-05-10 14:30")
}
```

### 交易列表 — 同步按钮

macOS 和 iOS 交易列表工具栏新增同步按钮：

```swift
ToolbarItem {
    Button { syncManager.manualSync() } label: {
        Image(systemName: "arrow.triangle.2.circlepath")
    }
}
```

同步中显示 ProgressView 旋转动画。

### 交易卡片 — IBKR 标记

IBKR 导入的交易卡片右上角显示小标记：

```swift
if trade.ibkrImported {
    Text("IBKR")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 3))
}
```

## HTTPS 自签名证书处理

Gateway 默认使用自签名 HTTPS 证书。需要在 URLSession 中配置信任本地证书：

```swift
class IBKRSessionDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // 仅信任 localhost 的自签名证书
        if challenge.protectionSpace.host == "localhost" {
            let credential = URLCredential(trust: challenge.protectionSpace.serverTrust!)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
```

## 数据持久化

同步相关的用户设置通过 `@AppStorage` 存储：

- `ibkrGatewayURL: String` — Gateway 地址，默认 "https://localhost:5000"
- `ibkrLastSyncTime: Date?` — 上次同步时间
- `ibkrAutoSync: Bool` — 是否启动时自动同步，默认 true

## 错误处理

| 场景 | 处理方式 |
|------|---------|
| Gateway 未运行 | 自动同步时静默跳过；手动同步时提示"请启动 Gateway" |
| 未认证 | 提示 + 提供"打开浏览器登录"按钮 |
| 网络错误 | Toast 提示错误信息，不阻塞 app 使用 |
| 数据解析失败 | 跳过该条交易，日志记录，继续处理其他交易 |
| 无新交易 | 手动同步时提示"没有新交易" |

## 文件清单

| 文件 | 说明 |
|------|------|
| `Shared/Services/IBKRService.swift` | 网络请求层，封装所有 API 调用 |
| `Shared/Services/IBKRSyncManager.swift` | 同步逻辑，去重、映射、触发 |
| `Shared/Views/IBKRSettingsView.swift` | 设置页 IBKR 区域 |
| `Shared/Models/TradeEntry.swift` | 新增 ibkrExecutionId、ibkrImported 字段 |
| `Shared/Views/TradeCardView.swift` | 新增 IBKR 导入标记 |
| `macOS/MacContentView.swift` | 交易列表工具栏新增同步按钮 |
| `iOS/iOSContentView.swift` | 交易列表工具栏新增同步按钮 |

## 不做的事

- 不通过 API 下单或修改交易
- 不存储 IBKR 账号密码
- 不自动启动 Gateway（用户自行管理）
- 不做实时行情推送
