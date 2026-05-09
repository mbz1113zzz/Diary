import SwiftUI
import SwiftData

enum PetAnimationLevel: String, CaseIterable, Identifiable {
    case calm = "安静"
    case normal = "标准"
    case lively = "活泼"

    var id: Self { self }

    var bounceDistance: CGFloat {
        switch self {
        case .calm: return 2
        case .normal: return 5
        case .lively: return 9
        }
    }

    var bounceDuration: TimeInterval {
        switch self {
        case .calm: return 2.2
        case .normal: return 1.35
        case .lively: return 0.82
        }
    }

    var sparkleDistance: CGFloat {
        switch self {
        case .calm: return 4
        case .normal: return 10
        case .lively: return 16
        }
    }
}

enum PetAvatarStyle: String, CaseIterable, Identifiable {
    case berry = "莓果团"
    case moon = "月亮猫"
    case mint = "薄荷怪"
    case coral = "珊瑚水母"
    case star = "星星龙"

    var id: Self { self }

    var palette: PixelPetPalette {
        switch self {
        case .berry:
            return PixelPetPalette(
                body: Color(red: 0.95, green: 0.36, blue: 0.55),
                shade: Color(red: 0.72, green: 0.18, blue: 0.36),
                accent: Color(red: 1.0, green: 0.82, blue: 0.28),
                cheek: Color(red: 1.0, green: 0.62, blue: 0.74),
                eye: Color(red: 0.16, green: 0.09, blue: 0.12)
            )
        case .moon:
            return PixelPetPalette(
                body: Color(red: 0.45, green: 0.49, blue: 0.95),
                shade: Color(red: 0.25, green: 0.29, blue: 0.68),
                accent: Color(red: 1.0, green: 0.86, blue: 0.32),
                cheek: Color(red: 0.70, green: 0.76, blue: 1.0),
                eye: Color(red: 0.06, green: 0.07, blue: 0.18)
            )
        case .mint:
            return PixelPetPalette(
                body: Color(red: 0.36, green: 0.82, blue: 0.63),
                shade: Color(red: 0.16, green: 0.55, blue: 0.40),
                accent: Color(red: 0.97, green: 0.96, blue: 0.50),
                cheek: Color(red: 0.62, green: 0.93, blue: 0.78),
                eye: Color(red: 0.04, green: 0.18, blue: 0.13)
            )
        case .coral:
            return PixelPetPalette(
                body: Color(red: 0.98, green: 0.48, blue: 0.42),
                shade: Color(red: 0.78, green: 0.23, blue: 0.29),
                accent: Color(red: 0.42, green: 0.86, blue: 0.98),
                cheek: Color(red: 1.0, green: 0.68, blue: 0.58),
                eye: Color(red: 0.14, green: 0.08, blue: 0.10)
            )
        case .star:
            return PixelPetPalette(
                body: Color(red: 0.94, green: 0.68, blue: 0.22),
                shade: Color(red: 0.67, green: 0.42, blue: 0.12),
                accent: Color(red: 0.42, green: 0.72, blue: 1.0),
                cheek: Color(red: 1.0, green: 0.82, blue: 0.45),
                eye: Color(red: 0.16, green: 0.10, blue: 0.03)
            )
        }
    }

    var pixels: [String] {
        switch self {
        case .berry:
            return [
                "..AAA...",
                ".ABBBBA.",
                "ABBBBBBA",
                "BBEBBEBB",
                "BBBCBCBB",
                ".BBBBBB.",
                "..BSSB..",
                "...SS..."
            ]
        case .moon:
            return [
                "A.....A.",
                "ABAAAABA",
                "ABBBBBBA",
                "BBEBBEBB",
                "BBBBACBB",
                ".BBBBB..",
                "..BSSB..",
                "..S..S.."
            ]
        case .mint:
            return [
                "..A..A..",
                ".ABBBBA.",
                "ABBBBBBA",
                "BBEBBEBB",
                "BBCBBCBB",
                ".BBBBBB.",
                ".SBBBBS.",
                "S......S"
            ]
        case .coral:
            return [
                "..AAAA..",
                ".ABBBBA.",
                "ABBBBBBA",
                "BBEBBEBB",
                "BBBCBCBB",
                ".BBBBBB.",
                ".S.S.S..",
                "S.S.S.S."
            ]
        case .star:
            return [
                "...A....",
                "..ABA...",
                ".ABBBBA.",
                "ABEBBEBA",
                ".BBCCBB.",
                "..BBBB..",
                ".S.BB.S.",
                "S......S"
            ]
        }
    }
}

enum PetMood {
    case sleepy
    case curious
    case sparkly
    case cozy

    var title: String {
        switch self {
        case .sleepy: return "小像素在打盹"
        case .curious: return "小像素探头"
        case .sparkly: return "小像素发光"
        case .cozy: return "小像素窝好了"
        }
    }

    var line: String {
        switch self {
        case .sleepy:
            return "今天还空空的，它先把毯子铺好。"
        case .curious:
            return "它发现了一点新东西，正在偷偷晃尾巴。"
        case .sparkly:
            return "今天有动静，它啪嗒啪嗒很忙。"
        case .cozy:
            return "它把今天收进小窝里，轻轻拍了拍。"
        }
    }

    var accentColor: Color {
        switch self {
        case .sleepy: return .secondary
        case .curious: return .blue
        case .sparkly: return .orange
        case .cozy: return .purple
        }
    }
}

struct PetCompanionView: View {
    @AppStorage("pet.isEnabled") private var isEnabled = true
    @AppStorage("pet.animationLevel") private var animationLevelRaw = PetAnimationLevel.normal.rawValue
    @AppStorage("pet.avatarStyle") private var avatarStyleRaw = PetAvatarStyle.berry.rawValue
    @Query(sort: [SortDescriptor(\DiaryEntry.date, order: .reverse)])
    private var diaries: [DiaryEntry]
    @Query(sort: [SortDescriptor(\TradeEntry.date, order: .reverse)])
    private var trades: [TradeEntry]
    @Query(sort: [SortDescriptor(\TodoItem.date, order: .reverse)])
    private var todos: [TodoItem]

    @State private var isBouncing = false
    @State private var isBlinking = false
    @State private var sparkleOffset: CGFloat = 0
    @State private var hopTrigger = false
    @State private var bubbleIndex = 0

    private var animationLevel: PetAnimationLevel {
        PetAnimationLevel(rawValue: animationLevelRaw) ?? .normal
    }

    private var avatarStyle: PetAvatarStyle {
        PetAvatarStyle(rawValue: avatarStyleRaw) ?? .berry
    }

    private var mood: PetMood {
        let today = DateFormatters.startOfDay(Date())
        let hasDiary = diaries.contains { Calendar.current.isDate($0.date, inSameDayAs: today) && !$0.isEmpty }
        let todaysTrades = trades.filter { Calendar.current.isDate($0.date, inSameDayAs: today) }
        let todaysTodos = todos.filter { Calendar.current.isDate($0.date, inSameDayAs: today) }

        if todaysTrades.contains(where: { ($0.pnl ?? 0) < 0 }) {
            return .cozy
        }
        if hasDiary || todaysTodos.contains(where: \.isCompleted) {
            return .sparkly
        }
        if !todaysTrades.isEmpty || !todaysTodos.isEmpty {
            return .curious
        }
        return .sleepy
    }

    private var bubbleLines: [String] {
        switch mood {
        case .sleepy:
            return ["呼噜", "小窝准备好了", "今天有一点安静"]
        case .curious:
            return ["啪嗒", "发现新脚印", "我在看"]
        case .sparkly:
            return ["亮晶晶", "今天有小星星", "啪嗒啪嗒"]
        case .cozy:
            return ["窝在这里", "尾巴卷起来", "慢慢来"]
        }
    }

    private var bubbleText: String {
        bubbleLines[bubbleIndex % bubbleLines.count]
    }

    var body: some View {
        if isEnabled {
            HStack(spacing: 14) {
                ZStack {
                    PetShadow()
                        .offset(y: 38)
                        .scaleEffect(isBouncing ? 0.92 : 1.05)

                    PixelPet(style: avatarStyle, isBlinking: isBlinking)
                        .offset(y: isBouncing ? -animationLevel.bounceDistance : 2)
                        .offset(y: hopTrigger ? -14 : 0)
                        .rotationEffect(.degrees(isBouncing ? -2 : 2))

                    PetSparkles(color: avatarStyle.palette.accent, offset: sparkleOffset)
                        .opacity(mood == .sleepy && animationLevel == .calm ? 0.2 : 1)
                }
                .frame(width: 104, height: 104)
                .onTapGesture {
                    interact()
                }

                VStack(alignment: .leading, spacing: 8) {
                    PetBubble(text: bubbleText, tint: avatarStyle.palette.accent)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(mood.title)
                            .font(.headline)
                        Text(mood.line)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        HStack(spacing: 6) {
                            Capsule()
                                .fill(avatarStyle.palette.body)
                                .frame(width: 26, height: 6)
                            Capsule()
                                .fill(avatarStyle.palette.accent.opacity(0.65))
                                .frame(width: 14, height: 6)
                            Capsule()
                                .fill(avatarStyle.palette.shade.opacity(0.45))
                                .frame(width: 8, height: 6)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding()
            .background(Color.systemBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .onTapGesture {
                interact()
            }
            .onAppear {
                startAmbientAnimation()
                blink()
            }
            .onChange(of: animationLevelRaw) { _, _ in
                startAmbientAnimation()
            }
        }
    }

    private func startAmbientAnimation() {
        isBouncing = false
        sparkleOffset = 0
        withAnimation(.easeInOut(duration: animationLevel.bounceDuration).repeatForever(autoreverses: true)) {
            isBouncing = true
        }
        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
            sparkleOffset = animationLevel.sparkleDistance
        }
    }

    private func interact() {
        bubbleIndex += 1
        withAnimation(.spring(response: 0.22, dampingFraction: 0.45)) {
            hopTrigger = true
        }
        Task {
            try? await Task.sleep(for: .milliseconds(180))
            await MainActor.run {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.7)) {
                    hopTrigger = false
                }
            }
        }
    }

    private func blink() {
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2.8))
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.12)) {
                        isBlinking = true
                    }
                }
                try? await Task.sleep(for: .seconds(0.16))
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.12)) {
                        isBlinking = false
                    }
                }
            }
        }
    }
}

struct PetSettingsView: View {
    @AppStorage("pet.isEnabled") private var isEnabled = true
    @AppStorage("pet.animationLevel") private var animationLevelRaw = PetAnimationLevel.normal.rawValue
    @AppStorage("pet.avatarStyle") private var avatarStyleRaw = PetAvatarStyle.berry.rawValue

    private var animationLevel: Binding<PetAnimationLevel> {
        Binding(
            get: { PetAnimationLevel(rawValue: animationLevelRaw) ?? .normal },
            set: { animationLevelRaw = $0.rawValue }
        )
    }

    private var avatarStyle: Binding<PetAvatarStyle> {
        Binding(
            get: { PetAvatarStyle(rawValue: avatarStyleRaw) ?? .berry },
            set: { avatarStyleRaw = $0.rawValue }
        )
    }

    var body: some View {
        Section("小宠物") {
            Toggle("显示小像素", isOn: $isEnabled)
            Picker("形象", selection: avatarStyle) {
                ForEach(PetAvatarStyle.allCases) { style in
                    Text(style.rawValue).tag(style)
                }
            }
            .disabled(!isEnabled)
            Picker("动画强度", selection: animationLevel) {
                ForEach(PetAnimationLevel.allCases) { level in
                    Text(level.rawValue).tag(level)
                }
            }
            .disabled(!isEnabled)
        }
    }
}

struct PetSettingsMenu: View {
    @AppStorage("pet.isEnabled") private var isEnabled = true
    @AppStorage("pet.animationLevel") private var animationLevelRaw = PetAnimationLevel.normal.rawValue
    @AppStorage("pet.avatarStyle") private var avatarStyleRaw = PetAvatarStyle.berry.rawValue

    var body: some View {
        Menu {
            Toggle("显示小像素", isOn: $isEnabled)
            Picker("形象", selection: $avatarStyleRaw) {
                ForEach(PetAvatarStyle.allCases) { style in
                    Text(style.rawValue).tag(style.rawValue)
                }
            }
            .disabled(!isEnabled)
            Picker("动画强度", selection: $animationLevelRaw) {
                ForEach(PetAnimationLevel.allCases) { level in
                    Text(level.rawValue).tag(level.rawValue)
                }
            }
            .disabled(!isEnabled)
        } label: {
            Label("小宠物", systemImage: "square.grid.3x3")
        }
    }
}

struct MascotDock: View {
    var alignment: Alignment = .topTrailing

    var body: some View {
        VStack {
            if alignment == .bottomTrailing || alignment == .bottomLeading {
                Spacer(minLength: 0)
            }
            HStack {
                if alignment == .topTrailing || alignment == .bottomTrailing {
                    Spacer(minLength: 0)
                }
                PetCompanionView()
                    .frame(maxWidth: 360)
                    .padding()
                if alignment == .topLeading || alignment == .bottomLeading {
                    Spacer(minLength: 0)
                }
            }
            if alignment == .topTrailing || alignment == .topLeading {
                Spacer(minLength: 0)
            }
        }
        .allowsHitTesting(true)
    }
}

struct MascotPageContainer<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack(alignment: .topTrailing) {
            content
            MascotDock(alignment: .topTrailing)
        }
    }
}

struct PetMiniView: View {
    @AppStorage("pet.isEnabled") private var isEnabled = true
    @AppStorage("pet.animationLevel") private var animationLevelRaw = PetAnimationLevel.normal.rawValue
    @AppStorage("pet.avatarStyle") private var avatarStyleRaw = PetAvatarStyle.berry.rawValue

    @State private var isBouncing = false
    @State private var isBlinking = false
    @State private var hopTrigger = false

    private var animationLevel: PetAnimationLevel {
        PetAnimationLevel(rawValue: animationLevelRaw) ?? .normal
    }

    private var avatarStyle: PetAvatarStyle {
        PetAvatarStyle(rawValue: avatarStyleRaw) ?? .berry
    }

    var body: some View {
        if isEnabled {
            Button {
                interact()
            } label: {
                ZStack {
                    Circle()
                        .fill(avatarStyle.palette.accent.opacity(0.12))
                        .frame(width: 58, height: 58)
                        .blur(radius: 8)

                    PixelPet(style: avatarStyle, isBlinking: isBlinking, pixelSize: 5.8, inset: 0, showsPanel: false)
                        .offset(y: isBouncing ? -animationLevel.bounceDistance / 2 : 1)
                        .offset(y: hopTrigger ? -8 : 0)
                }
                .frame(width: 76, height: 76)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("小宠物")
            .onAppear {
                startAmbientAnimation()
                blink()
            }
            .onChange(of: animationLevelRaw) { _, _ in
                startAmbientAnimation()
            }
        }
    }

    private func startAmbientAnimation() {
        isBouncing = false
        withAnimation(.easeInOut(duration: animationLevel.bounceDuration).repeatForever(autoreverses: true)) {
            isBouncing = true
        }
    }

    private func interact() {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.48)) {
            hopTrigger = true
        }
        Task {
            try? await Task.sleep(for: .milliseconds(160))
            await MainActor.run {
                withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) {
                    hopTrigger = false
                }
            }
        }
    }

    private func blink() {
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3.2))
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.12)) {
                        isBlinking = true
                    }
                }
                try? await Task.sleep(for: .seconds(0.16))
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.12)) {
                        isBlinking = false
                    }
                }
            }
        }
    }
}

struct MascotCornerContainer<Content: View>: View {
    private let bottomPadding: CGFloat?
    @ViewBuilder private let content: Content

    init(bottomPadding: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.bottomPadding = bottomPadding
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            content
            PetMiniView()
                .padding(.trailing, 30)
                .padding(.bottom, resolvedBottomPadding)
                .zIndex(1)
        }
    }

    private var resolvedBottomPadding: CGFloat {
        if let bottomPadding {
            return bottomPadding
        }
        #if os(iOS)
        return 104
        #else
        return 40
        #endif
    }
}

private struct PetBubble: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.14))
            .foregroundStyle(tint)
            .clipShape(Capsule())
            .contentTransition(.opacity)
    }
}

private struct PixelPet: View {
    let style: PetAvatarStyle
    let isBlinking: Bool
    var pixelSize: CGFloat = 9
    var inset: CGFloat = 10
    var showsPanel = true

    private var grid: [GridItem] {
        Array(repeating: GridItem(.fixed(pixelSize), spacing: 0), count: 8)
    }

    var body: some View {
        LazyVGrid(columns: grid, spacing: 0) {
            ForEach(0..<64, id: \.self) { index in
                Rectangle()
                    .fill(color(for: index))
                    .frame(width: pixelSize, height: pixelSize)
            }
        }
        .padding(inset)
        .background(showsPanel ? style.palette.accent.opacity(0.12) : Color.clear)
        .overlay {
            if showsPanel {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(style.palette.shade.opacity(0.22), lineWidth: 2)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func color(for index: Int) -> Color {
        let row = style.pixels[index / 8]
        let charIndex = row.index(row.startIndex, offsetBy: index % 8)
        let symbol = row[charIndex]
        if isBlinking && symbol == "E" { return style.palette.shade }
        switch symbol {
        case "A": return style.palette.accent
        case "B": return style.palette.body
        case "S": return style.palette.shade
        case "C": return style.palette.cheek
        case "E": return style.palette.eye
        default: return .clear
        }
    }
}

struct PixelPetPalette {
    let body: Color
    let shade: Color
    let accent: Color
    let cheek: Color
    let eye: Color
}

private struct PetShadow: View {
    var body: some View {
        Ellipse()
            .fill(Color.black.opacity(0.12))
            .frame(width: 70, height: 16)
    }
}

private struct PetSparkles: View {
    let color: Color
    let offset: CGFloat

    var body: some View {
        ZStack {
            Image(systemName: "sparkle")
                .font(.caption)
                .foregroundStyle(color)
                .offset(x: 40, y: -32 - offset)
            Image(systemName: "sparkle")
                .font(.caption2)
                .foregroundStyle(color.opacity(0.8))
                .offset(x: -42, y: -16 + offset / 2)
            Circle()
                .fill(color.opacity(0.22))
                .frame(width: 8, height: 8)
                .offset(x: 44, y: 28 + offset / 3)
        }
    }
}
