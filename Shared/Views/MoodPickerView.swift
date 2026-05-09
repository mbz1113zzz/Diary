import SwiftUI

struct MoodPickerView: View {
    @Binding var selected: String?

    private let moods = ["😊", "😐", "😔", "😤", "🤩", "😴", "🤔", "😰"]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(moods, id: \.self) { mood in
                Text(mood)
                    .font(.title2)
                    .padding(6)
                    .background(selected == mood ? Color.accentColor.opacity(0.2) : Color.clear)
                    .clipShape(Circle())
                    .onTapGesture {
                        selected = selected == mood ? nil : mood
                    }
            }
        }
    }
}
