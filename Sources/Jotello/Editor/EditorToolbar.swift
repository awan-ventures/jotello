import SwiftUI

struct EditorToolbar: View {
    @Bindable var document: AnnotationDocument
    let copied: Bool
    let copy: () -> Void
    let save: () -> Void

    private var editsText: Bool { document.tool == .text || document.selectedAnnotation?.tool == .text }

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 3) {
                ForEach(AnnotationTool.allCases, id: \.self) { tool in
                    Button { document.setTool(tool) } label: {
                        Image(systemName: tool.systemImage)
                            .font(.system(size: 15, weight: .medium)).frame(width: 28, height: 28)
                            .background(document.tool == tool ? Color.accentColor.opacity(0.14) : .clear,
                                        in: RoundedRectangle(cornerRadius: 6))
                            .foregroundStyle(document.tool == tool ? Color.accentColor : .primary)
                    }
                    .buttonStyle(.plain).help(tool.title).accessibilityLabel(tool.title)
                    .accessibilityAddTraits(document.tool == tool ? [.isSelected] : [])
                }
            }
            Divider().frame(height: 22)
            ColorPicker("Color", selection: Binding(get: { Color(nsColor: document.color) }, set: {
                document.setColor(NSColor($0))
            }), supportsOpacity: false)
            .labelsHidden().help("Annotation color")
            HStack(spacing: 5) {
                Text("\(Int(editsText ? document.fontSize : document.strokeWidth))")
                    .font(.caption).monospacedDigit().frame(width: 22)
                Slider(value: Binding(get: { editsText ? document.fontSize : document.strokeWidth }, set: {
                    if editsText { document.setFontSize($0) } else { document.setStrokeWidth($0) }
                }), in: editsText ? 8...200 : 1...30, step: 1, onEditingChanged: styleEditingChanged)
                    .frame(width: 80)
                    .accessibilityLabel(editsText ? "Text size" : "Stroke width")
                    .help(editsText ? "Text size" : "Stroke width")
            }
            Spacer(minLength: 0)
            HStack(spacing: 10) {
                Button { document.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                    .disabled(!document.canUndo).help("Undo (⌘Z)").accessibilityLabel("Undo")
                Button { document.redo() } label: { Image(systemName: "arrow.uturn.forward") }
                    .disabled(!document.canRedo).help("Redo (⇧⌘Z)").accessibilityLabel("Redo")
            }.buttonStyle(.borderless)
            Button(action: copy) {
                Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
            }
            .keyboardShortcut("c", modifiers: [.command, .shift]).help("Copy image (⇧⌘C)")
            Button(action: save) { Image(systemName: "square.and.arrow.down") }
                .keyboardShortcut("s", modifiers: .command)
                .help("Save PNG… (⌘S)").accessibilityLabel("Save PNG")
        }
    }

    private func styleEditingChanged(_ editing: Bool) {
        if editing { document.beginStyleChange() }
        else { document.finishStyleChange() }
    }
}
