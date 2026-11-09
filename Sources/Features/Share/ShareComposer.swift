import SwiftUI

/// A rendered card, ready to hand to the share sheet.
struct ShareItem: Identifiable {
    let id = UUID()
    let image: UIImage
    /// The same card as a PNG on disk. A file gives the sheet a real thumbnail
    /// and a readable name ("StatsWorkout-October 2026"), and every target —
    /// Instagram and WhatsApp included — can read it.
    let fileURL: URL?
}

/// Builds the shareable artwork from what a screen already shows.
///
/// It renders SwiftUI into an image with `ImageRenderer`, on the main actor and
/// only when the user asks for it — a few kilobytes of text and shapes, so no
/// spinner is needed.
@MainActor
enum ShareComposer {
    static func dashboard(
        stats: PeriodStats,
        metric: Metric,
        scope: DataScope,
        title: String,
        subtitle: String,
        formatter: MetricFormatter,
        periodFormatter: PeriodFormatter
    ) -> ShareItem? {
        let card = DashboardShareCard(
            title: title,
            subtitle: "\(subtitle) · \(scope.title)",
            metric: metric,
            stats: stats,
            formatter: formatter,
            periodFormatter: periodFormatter,
            axisTicks: axisTicks(for: stats, periodFormatter: periodFormatter)
        )
        guard let image = render(card) else { return nil }

        return ShareItem(
            image: image,
            fileURL: writeFile(image, name: "StatsWorkout-\(title)")
        )
    }

    static func workout(
        activity: ActivitySample,
        metricRows: [ActivityDetailViewModel.MetricRow],
        route: [RoutePoint],
        title: String,
        dateText: String,
        timeText: String,
        locale: Locale
    ) -> ShareItem? {
        let card = WorkoutShareCard(
            kind: activity.kind,
            title: title,
            dateText: dateText,
            timeText: timeText,
            stats: metricRows.prefix(6).map { (title: $0.title, value: $0.value, systemImage: $0.systemImage) },
            route: route
        )
        guard let image = render(card) else { return nil }

        return ShareItem(image: image, fileURL: writeFile(image, name: title))
    }

    // MARK: - Helpers

    /// Four evenly spaced labels: enough to read the axis, few enough to stay legible.
    static func axisTicks(for stats: PeriodStats, periodFormatter: PeriodFormatter) -> [(index: Int, text: String)] {
        let count = stats.buckets.count
        guard count > 0 else { return [] }
        let wanted = [0, count / 3, count * 2 / 3, count - 1]
        var seen = Set<Int>()
        return wanted.compactMap { index in
            guard index >= 0, index < count, seen.insert(index).inserted else { return nil }
            let bucket = stats.buckets[index].bucket
            return (index, periodFormatter.bucketAxisLabel(for: bucket, in: stats))
        }
    }

    /// Writes the PNG next to the app's temporary files so a share target can
    /// read it as a file, with a readable name. Returns `nil` if writing fails,
    /// in which case the in-memory image is shared instead.
    private static func writeFile(_ image: UIImage, name: String) -> URL? {
        // Encoding a 1080 × 1350 image can fail under memory pressure; a JPEG is
        // an acceptable fallback and still uploads fine to every target.
        guard let (data, pathExtension) = encode(image) else { return nil }
        let safeName = name
            .components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>\n\r\t"))
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("share", isDirectory: true)
        let url = directory
            .appendingPathComponent(safeName.isEmpty ? "StatsWorkout" : String(safeName.prefix(60)))
            .appendingPathExtension(pathExtension)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private static func encode(_ image: UIImage) -> (Data, String)? {
        if let png = image.pngData(), !png.isEmpty { return (png, "png") }
        if let jpeg = image.jpegData(compressionQuality: 0.92), !jpeg.isEmpty { return (jpeg, "jpg") }
        return nil
    }

    private static func render<V: View>(_ view: V) -> UIImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = ShareCard.pixelScale
        // Social networks are shown on a white feed, so an alpha channel adds
        // nothing and a PNG without one uploads more reliably.
        renderer.isOpaque = true
        return renderer.uiImage
    }
}
