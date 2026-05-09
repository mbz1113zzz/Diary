import SwiftUI
import SwiftData

struct DiaryEditorView: View {
    @Bindable var entry: DiaryEntry
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(DateFormatters.dayDisplay.string(from: entry.date))
                    .font(.title2)
                    .fontWeight(.semibold)

                VStack(alignment: .leading, spacing: 8) {
                    Text("心情")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    MoodPickerView(selected: $entry.mood)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("天气")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    WeatherPickerView(selected: $entry.weather)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("今日记录")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $entry.content)
                        .frame(minHeight: 200)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Color.secondarySystemBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding()
        }
        .onChange(of: entry.content) { _, _ in
            entry.updatedAt = Date()
        }
        .onChange(of: entry.mood) { _, _ in
            entry.updatedAt = Date()
        }
        .onChange(of: entry.weather) { _, _ in
            entry.updatedAt = Date()
        }
    }
}
