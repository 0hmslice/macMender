import SwiftUI

/// A width-constrained scrolling page for free-form content. Native `Form`,
/// `List`, and `Table` pages should own their scrolling behavior instead.
struct MacMenderScrollablePage<Content: View>: View {
    var maxContentWidth: CGFloat = 920
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: MacMenderSpacing.section) {
                content
            }
            .frame(maxWidth: maxContentWidth, alignment: .topLeading)
            .padding(.horizontal, MacMenderSpacing.page)
            .padding(.vertical, MacMenderSpacing.section)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .scrollContentBackground(.hidden)
    }
}

struct MacMenderPageHeader: View {
    var title: String
    var subtitle: String
    var systemImage: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: MacMenderSpacing.standard) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.tint)
                    .frame(width: 32, height: 32)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: MacMenderSpacing.compact) {
                Text(title)
                    .font(.title2.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}

struct MacMenderContentSection<Content: View>: View {
    var title: String
    var subtitle: String? = nil
    var systemImage: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: MacMenderSpacing.standard) {
            VStack(alignment: .leading, spacing: MacMenderSpacing.compact) {
                HStack(spacing: MacMenderSpacing.small) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .foregroundStyle(.secondary)
                            .frame(width: 18)
                            .accessibilityHidden(true)
                    }
                    Text(title)
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                }

                if let subtitle {
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()

            content
        }
        .padding(MacMenderSpacing.section)
        .frame(maxWidth: .infinity, alignment: .leading)
        .macMenderContentSurface()
    }
}

struct MacMenderSettingsRow<Accessory: View>: View {
    var title: String
    var detail: String? = nil
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(alignment: detail == nil ? .center : .top, spacing: MacMenderSpacing.section) {
            VStack(alignment: .leading, spacing: MacMenderSpacing.compact) {
                Text(title)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: MacMenderSpacing.standard)

            accessory
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MacMenderStatusLabel: View {
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.accessibilityShowBorders) private var showBorders

    var title: String
    var tone: MacMenderStatusTone
    var systemImage: String? = nil

    var body: some View {
        Label(title, systemImage: resolvedSymbol)
            .font(.caption.weight(.medium))
            .foregroundStyle(tone.color)
            .padding(.horizontal, MacMenderSpacing.small)
            .padding(.vertical, MacMenderSpacing.compact)
            .background(tone.color.opacity(0.12), in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(
                        tone.color.opacity(strongBorder ? 0.65 : 0.28),
                        lineWidth: strongBorder ? 1.5 : 1
                    )
            }
            .accessibilityElement(children: .combine)
    }

    private var resolvedSymbol: String {
        systemImage ?? tone.defaultSymbol
    }

    private var strongBorder: Bool {
        differentiateWithoutColor || showBorders
    }
}

struct MacMenderCallout<Content: View>: View {
    var systemImage: String
    var tone: MacMenderStatusTone = .neutral
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .top, spacing: MacMenderSpacing.standard) {
            Image(systemName: systemImage)
                .font(.callout.weight(.semibold))
                .foregroundStyle(tone.color)
                .frame(width: 18)
                .accessibilityLabel(tone.accessibilityTitle)

            content
                .font(.callout)

            Spacer(minLength: 0)
        }
        .padding(MacMenderSpacing.standard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tone.color.opacity(0.08), in: RoundedRectangle(cornerRadius: MacMenderRadius.content, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MacMenderRadius.content, style: .continuous)
                .strokeBorder(tone.color.opacity(0.18), lineWidth: 1)
        }
    }
}

struct MacMenderEmptyState: View {
    var title: String
    var message: String
    var systemImage: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: MacMenderSpacing.standard) {
            Image(systemName: systemImage)
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(spacing: MacMenderSpacing.compact) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(MacMenderSpacing.spacious)
        .accessibilityElement(children: .contain)
    }
}
