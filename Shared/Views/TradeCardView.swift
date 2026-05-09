import SwiftUI

struct TradeCardView: View {
    let trade: TradeEntry

    private var pnlColor: Color {
        guard let pnl = trade.pnl else { return .secondary }
        if pnl > 0 { return .green }
        if pnl < 0 { return .red }
        return .secondary
    }

    private var pnlText: String {
        guard let pnl = trade.pnl else { return "" }
        let sign = pnl >= 0 ? "+" : ""
        var text = "\(sign)\(String(format: "%.2f", pnl))"
        if let pct = trade.pnlPercent {
            text += " (\(sign)\(String(format: "%.1f", pct))%)"
        }
        return text
    }

    private var accentColor: Color {
        guard let pnl = trade.pnl else { return .gray }
        if pnl > 0 { return .green }
        if pnl < 0 { return .red }
        return .gray
    }

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(trade.ticker)
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text(trade.direction)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(trade.direction == "买入" ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                        .foregroundStyle(trade.direction == "买入" ? .red : .green)
                        .clipShape(Capsule())
                    Spacer()
                    Text(DateFormatters.shortDate.string(from: trade.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("$\(String(format: "%.2f", trade.price)) × \(trade.quantity)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if !pnlText.isEmpty {
                    HStack {
                        Text(pnlText)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(pnlColor)
                    }
                }

                HStack(spacing: 12) {
                    if let reason = trade.entryReason, !reason.isEmpty {
                        Label(reason, systemImage: "arrow.right.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if let emotion = trade.emotion, !emotion.isEmpty {
                        Text(emotion)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}
