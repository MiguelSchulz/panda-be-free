import SFSafeSymbols
import SwiftUI

public struct CameraCard: View {
    let cameraProvider: any CameraStreamProviding
    var isLightOn: Bool
    var onToggleLight: ((Bool) -> Void)?
    var onTapFullscreen: (() -> Void)?

    @GestureState private var zoomState: (scale: CGFloat, offset: CGSize) = (1.0, .zero)
    @State private var imageSize: CGSize = .zero

    public init(
        cameraProvider: any CameraStreamProviding,
        isLightOn: Bool = false,
        onToggleLight: ((Bool) -> Void)? = nil,
        onTapFullscreen: (() -> Void)? = nil
    ) {
        self.cameraProvider = cameraProvider
        self.isLightOn = isLightOn
        self.onToggleLight = onToggleLight
        self.onTapFullscreen = onTapFullscreen
    }

    public var body: some View {
        ZStack {
            if let frame = cameraProvider.currentFrame {
                Image(uiImage: frame)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .onGeometryChange(for: CGSize.self) { $0.size } action: { imageSize = $0 }
                    .clipShape(.rect(cornerRadius: 12))
                    .scaleEffect(zoomState.scale)
                    .offset(zoomState.offset)
                    .gesture(
                        MagnifyGesture()
                            .updating($zoomState) { value, state, _ in
                                let scale = max(1.0, min(value.magnification, 5.0))
                                guard imageSize.width > 0 else {
                                    state = (scale, .zero)
                                    return
                                }
                                let focal = value.startLocation
                                state = (
                                    scale: scale,
                                    offset: CGSize(
                                        width: (scale - 1) * (imageSize.width / 2 - focal.x),
                                        height: (scale - 1) * (imageSize.height / 2 - focal.y)
                                    )
                                )
                            }
                    )
            } else if cameraProvider.isStreaming {
                placeholder(text: "Waiting for first frame...")
            } else {
                placeholder(text: "Camera not available")
            }

            if cameraProvider.currentFrame != nil {
                VStack {
                    Spacer()
                    HStack {
                        if let onToggleLight {
                            Button {
                                onToggleLight(!isLightOn)
                            } label: {
                                Image(systemSymbol: isLightOn ? .lightbulbFill : .lightbulb)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(isLightOn ? .yellow : .white.opacity(0.7))
                                    .padding(10)
                                    .background(.black.opacity(0.5), in: Circle())
                            }
                            .accessibilityLabel("Toggle Light")
                        }
                        Spacer()
                        if let onTapFullscreen {
                            Button(action: onTapFullscreen) {
                                Image(systemSymbol: .arrowUpLeftAndArrowDownRight)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(10)
                                    .background(.black.opacity(0.5), in: Circle())
                            }
                            .accessibilityLabel("Fullscreen")
                        }
                    }
                    .padding(12)
                }
            }
        }
        .zIndex(1)
    }

    private func placeholder(text: LocalizedStringResource) -> some View {
        VStack(spacing: 8) {
            ProgressView()
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .background(Color(.systemGray6), in: .rect(cornerRadius: 12))
    }
}
