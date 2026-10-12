// https://github.com/ziqq/Glimpshot
// Copyright (C) 2026 Anton Ustinoff
// https://github.com/ziqq/Glimpshot/blob/main/LICENSE

import AppKit
import SwiftUI

@MainActor
final class EditorState: ObservableObject {
    @Published var tool: Tool = .select
    @Published var colorIndex: Int { didSet { Preferences.shared.colorIndex = colorIndex } }
    @Published var sizeIndex: Int { didSet { Preferences.shared.strokeSize = sizeIndex } }
    @Published var canUndo = false
    @Published var canRedo = false
    /// Tooltip for the hovered toolbar control, in the toolbar's coordinate space.
    @Published var hint: ToolbarHint?

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

struct ToolbarHint: Equatable {
    let title: String
    let shortcut: String
    let anchor: CGRect
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
                    ToolbarButton(icon: tool.icon, selected: state.tool == tool) {
                        state.tool = tool
                    }
                    .toolbarHint(tool.title, tool.keyLabel, state)
                }
                ToolbarDivider()
                ToolbarButton(icon: "arrow.uturn.backward", enabled: state.canUndo) { perform(.undo) }
                    .toolbarHint(L("action.undo"), "⌘Z", state)
                ToolbarButton(icon: "arrow.uturn.forward", enabled: state.canRedo) { perform(.redo) }
                    .toolbarHint(L("action.redo"), "⇧⌘Z", state)
                ToolbarDivider()
                ToolbarButton(icon: "pin") { perform(.pin) }
                    .toolbarHint(L("action.pin"), "⌘P", state)
                ToolbarButton(icon: "square.and.arrow.down.on.square") { perform(.saveAs) }
                    .toolbarHint(L("action.saveAs"), "⇧⌘S", state)
                ToolbarButton(icon: "square.and.arrow.down") { perform(.save) }
                    .toolbarHint(L("action.save"), "⌘S", state)
                ToolbarButton(icon: "doc.on.doc", prominent: true) { perform(.copy) }
                    .toolbarHint(L("action.copy"), "⌘C  ↩", state)
                ToolbarButton(icon: "xmark") { perform(.close) }
                    .toolbarHint(L("action.close"), "Esc", state)
            }
            .padding(5)
            .hudBackground()

            if state.tool.hasStyle {
                HStack(spacing: 4) {
                    ForEach(Palette.colors.indices, id: \.self) { i in
                        ColorSwatch(color: Color(nsColor: Palette.colors[i]), selected: state.colorIndex == i) {
                            state.colorIndex = i
                        }
                        .toolbarHint(L("style.color"), "\(i + 1)", state)
                    }
                    ToolbarDivider()
                    ForEach(Palette.widths.indices, id: \.self) { i in
                        SizeDot(diameter: [5, 8, 12][i], selected: state.sizeIndex == i,
                                color: Color(nsColor: state.color)) {
                            state.sizeIndex = i
                        }
                        .toolbarHint(L(["style.thin", "style.medium", "style.thick"][i]), "", state)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .hudBackground()
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(10) // room for shadows
        .coordinateSpace(name: "toolbar")
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
    }

    private var foreground: Color {
        if !enabled { return .white.opacity(0.3) }
        return selected || prominent ? .white : .white.opacity(0.85)
    }

    private var background: Color {
        if selected || prominent { return Theme.accentColor.opacity(hovering ? 1 : 0.88) }
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

// MARK: - Hints

private struct HintModifier: ViewModifier {
    let title: String
    let shortcut: String
    @ObservedObject var state: EditorState
    @State private var frame: CGRect = .zero

    func body(content: Content) -> some View {
        content
            .background(GeometryReader { geo in
                Color.clear
                    .onAppear { frame = geo.frame(in: .named("toolbar")) }
                    .onChange(of: geo.frame(in: .named("toolbar"))) { _, new in frame = new }
            })
            .onHover { inside in
                if inside {
                    state.hint = ToolbarHint(title: title, shortcut: shortcut, anchor: frame)
                } else if state.hint?.anchor == frame {
                    state.hint = nil
                }
            }
    }
}

extension View {
    func toolbarHint(_ title: String, _ shortcut: String, _ state: EditorState) -> some View {
        modifier(HintModifier(title: title, shortcut: shortcut, state: state))
    }
}
