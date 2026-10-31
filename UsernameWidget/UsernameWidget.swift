//
//  UsernameWidget.swift
//  UsernameWidget
//

import WidgetKit
import SwiftUI
import AppIntents

struct UsernameEntry: TimelineEntry {
    let date: Date
    let username: String
}

struct Provider: TimelineProvider {
    private let generator = UsernameGenerator()

    func placeholder(in context: Context) -> UsernameEntry {
        UsernameEntry(date: .now, username: "QuietOtter4821")
    }

    func getSnapshot(in context: Context, completion: @escaping (UsernameEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : makeEntry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsernameEntry>) -> Void) {
        // A fresh username every hour, using the options chosen in the app.
        let entries = (0..<6).map { hour in
            makeEntry(at: Calendar.current.date(byAdding: .hour, value: hour, to: .now)!)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func makeEntry(at date: Date) -> UsernameEntry {
        UsernameEntry(date: date, username: generator.generate(options: SharedSettings.loadOptions()))
    }
}

struct UsernameWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: UsernameEntry

    var body: some View {
        switch family {
        #if !os(macOS)
        case .accessoryRectangular:
            VStack(alignment: .leading) {
                Label("Username", systemImage: "person.crop.circle.badge.plus")
                    .font(.caption)
                name(.headline)
            }
        #if os(iOS)
        case .accessoryInline:
            Text(entry.username)
        #endif
        case .accessoryCircular:
            name(.caption2)
        #endif
        default:
            VStack(alignment: .leading, spacing: 8) {
                Label("New username", systemImage: "person.crop.circle.badge.plus")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                name(.title3)
                    .textSelection(.enabled)
                Button(intent: RefreshUsernameIntent()) {
                    Label("Another", systemImage: "arrow.clockwise")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func name(_ style: Font.TextStyle) -> some View {
        Text(entry.username)
            .font(.system(style, design: .monospaced, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.4)
    }
}

struct UsernameWidget: Widget {
    // Lock Screen families don't exist on macOS, and visionOS has no inline family.
    private static var families: [WidgetFamily] {
        #if os(macOS)
        [.systemSmall, .systemMedium]
        #elseif os(iOS)
        [.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline, .accessoryCircular]
        #else
        [.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular]
        #endif
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: SharedSettings.widgetKind, provider: Provider()) { entry in
            UsernameWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Username")
        .description("A fresh username every hour, using your options from the app.")
        .supportedFamilies(Self.families)
    }
}

#Preview(as: .systemSmall) {
    UsernameWidget()
} timeline: {
    UsernameEntry(date: .now, username: "QuietOtter4821")
    UsernameEntry(date: .now, username: "BraveFalcon07")
}
