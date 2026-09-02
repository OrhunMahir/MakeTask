import SwiftUI

struct NoteBackground: View {
    let color: NoteColor
    let isCollapsed: Bool

    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        ZStack {
            if settings.transparencyEnabled {
                VisualEffectView(material: isCollapsed ? .popover : .hudWindow)
            } else {
                Color(nsColor: .windowBackgroundColor)
            }

            color.tint
                .opacity(
                    isCollapsed
                        ? (settings.transparencyEnabled ? 0.12 : 0.08)
                        : (settings.transparencyEnabled ? 0.18 : 0.12)
                )

            if isCollapsed {
                Color(nsColor: .windowBackgroundColor)
                    .opacity(settings.transparencyEnabled ? 0.34 : 0.12)
            }
        }
    }
}
