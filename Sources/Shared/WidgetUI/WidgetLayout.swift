import SwiftUI
import WidgetKit

/// Which metrics a widget shows, given its size.
///
/// The configuration screen cannot know the family — one intent serves all three
/// sizes — so the *order* of the chosen metrics decides: the main metric always
/// shows, then as many of "also show" as the size has room for. Small gets one
/// number, medium three, large five.
enum WidgetLayout {
    static func capacity(for family: WidgetFamily) -> Int {
        switch family {
        case .systemSmall: return 1
        case .systemMedium: return 3
        case .systemLarge: return 5
        default: return 1
        }
    }

    static func metrics(for family: WidgetFamily, configuration: WidgetFilters) -> [Metric] {
        WidgetMetricSelection.metrics(for: configuration, capacity: capacity(for: family))
    }

    /// Every size gets the bars: even the small one has room for a short strip,
    /// and a bare number makes for a dull widget.
    static func showsChart(for family: WidgetFamily) -> Bool { true }

    /// Only the large size has room for a tall chart *and* a metric grid.
    static func chartHeight(for family: WidgetFamily) -> CGFloat {
        switch family {
        case .systemSmall: return 42
        case .systemLarge: return 168
        default: return 46
        }
    }
}
