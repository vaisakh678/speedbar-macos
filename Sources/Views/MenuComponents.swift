import AppKit
import SwiftUI

/// Building blocks that give the `MenuBarExtra` panel the proportions and
/// behaviour of a real `NSMenu` — the panel is a plain SwiftUI window, so the
/// row metrics, hover highlight and shortcut hints have to be rebuilt here.
enum MenuMetrics {
    static let width: CGFloat = 288
    static let rowHeight: CGFloat = 24
    static let horizontalInset: CGFloat = 10
    static let font = Font.system(size: 13)
}

/// A non-interactive `Label:  Value` row, like Hot's "Thermal Pressure" line.
struct MenuReadoutRow: View {
    let systemImage: String
    let title: String
    let value: String
    var tint: Color = .secondary

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 12))
                .foregroundStyle(tint)
                .frame(width: 16)
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .foregroundStyle(.primary)
                .monospacedDigit()
                // The connection and session rows carry the longest values;
                // shrink to fit rather than eliding them to "3.7…".
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .font(MenuMetrics.font)
        .frame(height: MenuMetrics.rowHeight)
        .padding(.horizontal, MenuMetrics.horizontalInset)
    }
}

/// A clickable menu row: hover fills it with the selection colour, exactly as
/// an `NSMenu` item does.
struct MenuActionRow: View {
    let title: String
    /// Supply this when the row sits among readout rows, so its text lines up
    /// with theirs instead of starting at the icon column.
    var systemImage: String?
    var shortcut: String?
    var showsChevron = false
    var isEnabled = true
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 12))
                        .foregroundStyle(isHovering ? Color.white : .secondary)
                        .frame(width: 16)
                }
                Text(title)
                Spacer(minLength: 12)
                if let shortcut {
                    Text(shortcut)
                        .foregroundStyle(isHovering ? .primary : .tertiary)
                }
                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isHovering ? .primary : .tertiary)
                }
            }
            .font(MenuMetrics.font)
            .foregroundStyle(isEnabled ? (isHovering ? Color.white : .primary) : Color.secondary)
            .frame(height: MenuMetrics.rowHeight)
            .padding(.horizontal, MenuMetrics.horizontalInset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isHovering && isEnabled ? Color.accentColor : .clear)
                    .padding(.horizontal, 5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onHover { isHovering = $0 }
    }
}

/// A readout row that copies its value to the pasteboard when clicked, and
/// says so briefly afterwards — there is no other affordance in a menu to
/// confirm that a click did anything.
struct MenuCopyRow: View {
    let systemImage: String
    let title: String
    let value: String
    var tint: Color = .secondary

    @State private var isHovering = false
    @State private var didCopy = false

    var body: some View {
        Button(action: copy) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 12))
                    .foregroundStyle(isHovering ? Color.white : tint)
                    .frame(width: 16)
                Text(title)
                    .foregroundStyle(isHovering ? Color.white.opacity(0.85) : Color.secondary)
                Spacer(minLength: 12)
                // Hovering swaps the address out for the copy affordance, so
                // the row reads as a button the moment you point at it — and
                // the address is not left sitting on screen under the cursor.
                if didCopy {
                    Text("Copied")
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                } else if isHovering {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11, weight: .medium))
                } else {
                    Text(value)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
            .font(MenuMetrics.font)
            .foregroundStyle(isHovering ? Color.white : .primary)
            .frame(height: MenuMetrics.rowHeight)
            .padding(.horizontal, MenuMetrics.horizontalInset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isHovering ? Color.accentColor : .clear)
                    .padding(.horizontal, 5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help("Click to copy \(value)")
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)

        didCopy = true
        Task {
            try? await Task.sleep(for: .milliseconds(1200))
            didCopy = false
        }
    }
}

struct MenuSeparator: View {
    var body: some View {
        Divider()
            .padding(.horizontal, MenuMetrics.horizontalInset)
            .padding(.vertical, 4)
    }
}
