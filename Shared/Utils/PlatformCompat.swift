import SwiftUI

#if os(macOS)
import AppKit

extension Color {
    static let systemBackground = Color(NSColor.windowBackgroundColor)
    static let secondarySystemBackground = Color(NSColor.controlBackgroundColor)
}
#elseif os(iOS)
import UIKit

extension Color {
    static let systemBackground = Color(UIColor.systemBackground)
    static let secondarySystemBackground = Color(UIColor.secondarySystemBackground)
}
#endif

extension Color {
    static func pnl(_ value: Double) -> Color {
        if value > 0 { return .green }
        if value < 0 { return .red }
        return .secondary
    }
}
