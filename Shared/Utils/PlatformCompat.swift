import SwiftUI

#if os(macOS)
import AppKit

extension Color {
    static let systemBackground = Color(NSColor.windowBackgroundColor)
    static let secondarySystemBackground = Color(NSColor.controlBackgroundColor)
}
#endif
