import SwiftUI

struct EditorView: View {
    @Bindable var document: AnnotationDocument
    let copy: () -> Bool
    let save: () -> Void
    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            EditorToolbar(document: document, copied: copied, copy: { copied = copy() }, save: save)
                .padding(12)
            Divider()
            AnnotationCanvas(document: document)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onChange(of: document.hasUnsavedChanges) {
            if document.hasUnsavedChanges { copied = false }
        }
        .task(id: copied) {
            if copied {
                try? await Task.sleep(for: .seconds(2))
                if !Task.isCancelled { copied = false }
            }
        }
    }
}
