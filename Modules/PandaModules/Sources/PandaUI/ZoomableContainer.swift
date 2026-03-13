import SwiftUI
import UIKit

private let maxAllowedScale = 4.0

public struct ZoomableContainer<Content: View>: View {
    let content: Content

    @State private var currentScale: CGFloat = 1.0
    @State private var tapLocation: CGPoint = .zero

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func doubleTapAction(location: CGPoint) {
        tapLocation = location
        currentScale = currentScale == 1.0 ? maxAllowedScale / 2 : 1.0
    }

    public var body: some View {
        ZoomableScrollView(scale: $currentScale, tapLocation: $tapLocation) {
            content
        }
        .onTapGesture(count: 2, perform: doubleTapAction)
        .onDisappear {
            currentScale = 1
        }
    }

    private struct ZoomableScrollView: UIViewRepresentable {
        private var content: Content
        @Binding private var currentScale: CGFloat
        @Binding private var tapLocation: CGPoint

        init(scale: Binding<CGFloat>, tapLocation: Binding<CGPoint>, @ViewBuilder content: () -> Content) {
            _currentScale = scale
            _tapLocation = tapLocation
            self.content = content()
        }

        func makeUIView(context: Context) -> UIScrollView {
            // Setup the UIScrollView
            let scrollView = UIScrollView()
            scrollView.delegate = context.coordinator // for viewForZooming(in:)
            scrollView.maximumZoomScale = maxAllowedScale
            scrollView.minimumZoomScale = 1
            scrollView.bouncesZoom = true
            scrollView.showsHorizontalScrollIndicator = false
            scrollView.showsVerticalScrollIndicator = false
            scrollView.clipsToBounds = false
            scrollView.contentInsetAdjustmentBehavior = .never

            // Create a UIHostingController to hold our SwiftUI content
            context.coordinator.hostingController.safeAreaRegions = []
            let hostedView = context.coordinator.hostingController.view!
            hostedView.translatesAutoresizingMaskIntoConstraints = true
            hostedView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            hostedView.frame = scrollView.bounds
            scrollView.addSubview(hostedView)

            return scrollView
        }

        func makeCoordinator() -> Coordinator {
            Coordinator(hostingController: UIHostingController(rootView: content), scale: $currentScale)
        }

        func updateUIView(_ uiView: UIScrollView, context: Context) {
            // Update the hosting controller's SwiftUI content
            context.coordinator.hostingController.rootView = content

            // Don't interfere with active pinch gestures
            guard !context.coordinator.isZooming else { return }

            if tapLocation != .zero {
                // Scale in to a specific point (double-tap)
                uiView.zoom(to: zoomRect(for: uiView, scale: uiView.maximumZoomScale / 2, center: tapLocation), animated: true)
                Task { @MainActor in tapLocation = .zero }
            } else if uiView.zoomScale != currentScale {
                // Programmatic scale change (e.g. double-tap to reset)
                uiView.setZoomScale(currentScale, animated: true)
            }

            assert(context.coordinator.hostingController.view.superview == uiView)
        }

        // MARK: - Utils

        func zoomRect(for scrollView: UIScrollView, scale: CGFloat, center: CGPoint) -> CGRect {
            let scrollViewSize = scrollView.bounds.size

            let width = scrollViewSize.width / scale
            let height = scrollViewSize.height / scale
            let x = center.x - (width / 2.0)
            let y = center.y - (height / 2.0)

            return CGRect(x: x, y: y, width: width, height: height)
        }

        // MARK: - Coordinator

        class Coordinator: NSObject, UIScrollViewDelegate {
            var hostingController: UIHostingController<Content>
            @Binding var currentScale: CGFloat
            var isZooming = false

            init(hostingController: UIHostingController<Content>, scale: Binding<CGFloat>) {
                self.hostingController = hostingController
                _currentScale = scale
            }

            func viewForZooming(in _: UIScrollView) -> UIView? {
                hostingController.view
            }

            func scrollViewWillBeginZooming(_: UIScrollView, with _: UIView?) {
                isZooming = true
            }

            func scrollViewDidEndZooming(_: UIScrollView, with _: UIView?, atScale scale: CGFloat) {
                isZooming = false
                currentScale = scale
            }
        }
    }
}
