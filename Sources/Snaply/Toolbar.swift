import AppKit
import SwiftUI

@MainActor
final class EditorState: ObservableObject {
    @Published var tool: Tool = .select
    @Published var colorIndex: Int { didSet { Preferences.shared.colorIndex = colorIndex } }
    @Published var sizeIndex: Int { didSet { Preferences.shared.strokeSize = sizeIndex } }
    @Published var canUndo = false
    @Published var canRedo = false

    init() {
        let prefs = Preferences.shared
        colorIndex = min(max(prefs.colorIndex, 0), Palette.colors.count - 1)
        sizeIndex = min(max(prefs.strokeSize, 0), Palette.widths.count - 1)
    }

    var color: NSColor { Palette.colors[colorIndex] }
    var width: CGFloat { Palette.widths[sizeIndex] }
    var fontSize: CGFloat { Palette.fontSizes[sizeIndex] }
    var counterRadius: CGFloat { Palette.counterRadii[sizeIndex] }
}

enum EditorAction {
    case undo, redo, pin, saveAs, save, copy, close
}

// MARK: - Toolbar UI

struct EditorToolbar: View {
    @ObservedObject var state: EditorState
    let perform: (EditorAction) -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            HStack(spacing: 2) {
                ForEach(Tool.allCases) { tool in
                    ToolbarButton(icon: tool.icon, help: "\(tool.title)  \(tool.keyLabel)",
                                  selected: state.tool == tool) {
                        state.tool = tool
                    }
                }
                ToolbarDivider()
                ToolbarButton(icon: "arrow.uturn.backward", help: "Отменить  ⌘Z", enabled: state.canUndo) {
                    perform(.undo)
                }
                ToolbarButton(icon: "arrow.uturn.forward", help: "Повторить  ⇧⌘Z", enabled: state.canRedo) {
                    perform(.redo)
                }
                ToolbarDivider()
                ToolbarButton(icon: "pin", help: "Закрепить поверх окон  ⌘P") { perform(.pin) }
                ToolbarButton(icon: "square.and.arrow.down.on.square", help: "Сохранить как…  ⇧⌘S") { perform(.saveAs) }
                ToolbarButton(icon: "square.and.arrow.down", help: "Сохранить в папку  ⌘S") { perform(.save) }
                ToolbarButton(icon: "doc.on.doc", help: "Копировать  ⌘C / ↩", prominent: true) { perform(.copy) }
                ToolbarButton(icon: "xmark", help: "Закрыть  Esc") { perform(.close) }
            }
            .padding(5)
            .hudBackground()

            if state.tool.hasStyle {
                HStack(spacing: 4) {
                    ForEach(Palette.colors.indices, id: \.self) { i in
                        ColorSwatch(color: Color(nsColor: Palette.colors[i]), selected: state.colorIndex == i) {
                            state.colorIndex = i
                        }
                    }
                    ToolbarDivider()
                    ForEach(Palette.widths.indices, id: \.self) { i in
                        SizeDot(diameter: [5, 8, 12][i], selected: state.sizeIndex == i,
                                color: Color(nsColor: state.color)) {
                            state.sizeIndex = i
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .hudBackground()
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(10) // room for shadows
        .animation(.easeOut(duration: 0.15), value: state.tool.hasStyle)
        .environment(\.colorScheme, .dark)
    }
}

private struct HUDBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(white: 0.12).opacity(0.94))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
    }
}

extension View {
    func hudBackground() -> some View { modifier(HUDBackground()) }
}

private struct ToolbarDivider: View {
    var body: some View {
        Rectangle().fill(Color.white.opacity(0.14)).frame(width: 1, height: 18).padding(.horizontal, 4)
    }
}

private struct ToolbarButton: View {
    let icon: String
    let help: String
    var selected = false
    var enabled = true
    var prominent = false
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13.5, weight: .medium))
                .frame(width: 30, height: 30)
                .foregroundStyle(foreground)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous).fill(background)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .disabled(!enabled)
        .onHover { hovering = $0 }
        .help(help)
    }

    private var foreground: Color {
        if !enabled { return .white.opacity(0.3) }
        return selected || prominent ? .white : .white.opacity(0.85)
    }

    private var background: Color {
        if selected || prominent { return Color.accentColor.opacity(hovering ? 1 : 0.88) }
        return hovering && enabled ? .white.opacity(0.12) : .clear
    }
}

private struct ColorSwatch: View {
    let color: Color
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(color).frame(width: 16, height: 16)
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
                if selected {
                    Circle().strokeBorder(Color.white, lineWidth: 2).frame(width: 23, height: 23)
                }
            }
            .frame(width: 26, height: 26)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
    }
}

private struct SizeDot: View {
    let diameter: CGFloat
    let selected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle().fill(selected ? color : Color.white.opacity(0.7))
                .frame(width: diameter, height: diameter)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(selected ? Color.white.opacity(0.14) : .clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
    }
}
