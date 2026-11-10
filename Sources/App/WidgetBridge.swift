import Foundation
import WidgetKit

/// Asks WidgetKit to redraw the widgets.
///
/// A widget cannot be pushed to: it is redrawn on its own schedule, or when the
/// app asks for it. Every place the app learns something new — a foreground
/// sync, a HealthKit background wake-up, a change of units or language — calls
/// this so the widget is current without waiting for its next budgeted refresh.
enum WidgetBridge {
    static func reload() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
