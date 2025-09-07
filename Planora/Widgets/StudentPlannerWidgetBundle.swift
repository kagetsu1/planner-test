import SwiftUI
import WidgetKit

struct PlanoraWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextClassWidget()
        TasksWidget()
        EventsWidget()
    }
}
