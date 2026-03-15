import SwiftUI
import WidgetKit

@main
struct PandaBeFreeWidgets: WidgetBundle {
    var body: some Widget {
        CameraWidget()
        PrintStateWidget()
        AMSWidget()
        PrinterOverviewWidget()
        PrinterLiveActivity()
    }
}
