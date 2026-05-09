import SwiftUI

struct WeatherPickerView: View {
    @Binding var selected: String?

    private let options: [(icon: String, label: String)] = [
        ("☀️", "晴"), ("⛅", "多云"), ("☁️", "阴"),
        ("🌧️", "雨"), ("❄️", "雪"), ("🌫️", "雾")
    ]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(options, id: \.label) { option in
                VStack(spacing: 2) {
                    Text(option.icon)
                        .font(.title3)
                    Text(option.label)
                        .font(.caption2)
                }
                .padding(6)
                .background(selected == option.label ? Color.accentColor.opacity(0.2) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onTapGesture {
                    selected = selected == option.label ? nil : option.label
                }
            }
        }
    }
}
