import SwiftUI
import SwiftData

struct DiaryCardView: View {
    let entry: DiaryEntry
    var tradeCount: Int = 0
    var todoProgress: (completed: Int, total: Int) = (0, 0)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let mood = entry.mood {
                    Text(mood)
                        .font(.title3)
                }
                if let weather = entry.weather {
                    Text(weather)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(DateFormatters.shortDate.string(from: entry.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !entry.content.isEmpty {
                Text(entry.content)
                    .font(.body)
                    .lineLimit(2)
                    .foregroundStyle(.primary)
            }

            HStack(spacing: 12) {
                if tradeCount > 0 {
                    Label("\(tradeCount)笔交易", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if todoProgress.total > 0 {
                    Label("\(todoProgress.completed)/\(todoProgress.total)待办", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color.systemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}
