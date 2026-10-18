import SwiftUI

struct EditorView: View {
    @Bindable var document: AnnotationDocument
    let feedback: FeedbackModel
    let copy: () -> Bool
    let save: () -> Void
    let send: () -> Void
    let copyText: () -> Void
    @State private var copied = false

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                EditorToolbar(document: document, copied: copied, copy: { copied = copy() }, save: save)
                    .padding(12)
                Divider()
                AnnotationCanvas(document: document)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Divider()
            ComposerView(feedback: feedback, send: send, copyText: copyText)
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
