import WidgetKit
import SwiftUI

// Phase 2 adds home/lock screen widgets (today's calories, last workout
// summary) per the PRD; this bundle carries only the Live Activity for MVP.
@main
struct PulseBoardWidgetBundle: WidgetBundle {
    var body: some Widget {
        PulseBoardLiveActivity()
    }
}
