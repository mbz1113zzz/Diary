import SwiftUI

struct ContentView: View {
    var body: some View {
        #if os(macOS)
        MacContentView()
        #else
        iOSContentView()
        #endif
    }
}
