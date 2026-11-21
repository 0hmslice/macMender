import AppKit
import SwiftUI

struct PermissionDragToAddGuide: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animateArrow = false

    var body: some View {
        ViewThatFits(in: .horizontal) {
            wideLayout
            compactLayout
        }
        .onAppear {
            guard !reduceMotion else { return }
            animateArrow = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                animateArrow = true
            }
        }
    }

    private var wideLayout: some View {
        HStack(alignment: .center, spacing: MacMenderSpacing.section) {
            guideVisuals
                .frame(minWidth: 380)

            instructions
                .frame(minWidth: 230, maxWidth: .infinity, alignment: .leading)
        }
    }

    private var compactLayout: some View {
        VStack(alignment: .leading, spacing: MacMenderSpacing.section) {
            guideVisuals
            instructions
        }
    }

    private var guideVisuals: some View {
        HStack(alignment: .center, spacing: MacMenderSpacing.standard) {
            DraggableAppTile()
            arrow
            PrivacyListMockup()
        }
        .frame(maxWidth: .infinity, minHeight: 146, alignment: .center)
    }

    private var arrow: some View {
        Image(systemName: "arrow.right")
            .font(.title3.weight(.semibold))
            .foregroundStyle(Color.accentColor)
            .frame(width: 24)
            .offset(x: reduceMotion ? 0 : (animateArrow ? 0 : -8))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.55), value: animateArrow)
            .accessibilityHidden(true)
    }

    private var instructions: some View {
        VStack(alignment: .leading, spacing: MacMenderSpacing.small) {
            NumberedInstruction(number: 1, title: "Open the right Privacy & Security pane from macMender.")
            NumberedInstruction(number: 2, title: "Look for macMender in the permission list.")
            NumberedInstruction(number: 3, title: "If macMender is not listed, use the + button or drag the app in if macOS allows it.")
            NumberedInstruction(number: 4, title: "Turn the toggle on, then return here and recheck.")
            Text("If macOS asks you to reopen macMender, reopen it and continue setup from this step.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct DraggableAppTile: View {
    private var appURL: URL {
        Bundle.main.bundleURL
    }

    private var appIcon: NSImage {
        NSWorkspace.shared.icon(forFile: appURL.path)
    }

    var body: some View {
        VStack(spacing: MacMenderSpacing.small) {
            Image(nsImage: appIcon)
                .resizable()
                .frame(width: 58, height: 58)
                .shadow(color: .black.opacity(0.12), radius: 6, y: 3)

            Text("macMender")
                .font(.headline)
            Text("Drag if macOS allows it")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 166, height: 142)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: MacMenderRadius.content, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MacMenderRadius.content, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
        }
        .contentShape(.rect)
        .onDrag {
            NSItemProvider(object: appURL as NSURL)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("macMender app, draggable into the macOS permission list")
        .accessibilityHint("Drag this app into Privacy & Security if macOS allows it")
    }
}

private struct PrivacyListMockup: View {
    var body: some View {
        VStack(alignment: .leading, spacing: MacMenderSpacing.small) {
            Text("Privacy & Security")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            PrivacyMockRow(title: "Finder", enabled: true)
            PrivacyMockRow(title: "macMender", enabled: false, highlighted: true)
            PrivacyMockRow(title: "Other App", enabled: true)
            Text("Add macMender here")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .padding(.top, 2)
        }
        .padding(MacMenderSpacing.standard)
        .frame(width: 166)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: MacMenderRadius.content, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MacMenderRadius.content, style: .continuous)
                .stroke(Color.accentColor.opacity(0.24), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Example Privacy and Security list with macMender highlighted")
    }
}

private struct PrivacyMockRow: View {
    var title: String
    var enabled: Bool
    var highlighted: Bool = false

    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(highlighted ? Color.accentColor.opacity(0.40) : .secondary.opacity(0.25))
                .frame(width: 18, height: 18)
            Text(title)
                .font(.caption)
            Spacer()
            Capsule()
                .fill(enabled ? Color.green.opacity(0.75) : .secondary.opacity(0.25))
                .frame(width: 28, height: 16)
        }
    }
}

private struct NumberedInstruction: View {
    var number: Int
    var title: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: MacMenderSpacing.small) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Color.accentColor, in: Circle())
                .accessibilityHidden(true)
            Text(title)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(number): \(title)")
    }
}
