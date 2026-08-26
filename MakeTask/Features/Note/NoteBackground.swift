import SwiftUI

struct NoteBackground: View {
    let color: NoteColor

    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        ZStack {
            if settings.transparencyEnabled {
                VisualEffectView(material: .hudWindow)
            } else {
                Color(nsColor: .windowBackgroundColor)
            }

            color.tint
                .opacity(settings.transparencyEnabled ? 0.18 : 0.12)
        }
    }
}
