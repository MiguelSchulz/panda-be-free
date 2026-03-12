import BambuUI
import SFSafeSymbols
import SwiftUI

struct FullscreenCameraView: View {
    let cameraProvider: any CameraStreamProviding
    @Binding var isPresented: Bool
    var isLightOn = false
    var onToggleLight: ((Bool) -> Void)?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let frame = cameraProvider.currentFrame {
                ZoomableContainer {
                    Image(uiImage: frame)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
                .ignoresSafeArea()
            } else {
                ProgressView("Waiting for first frame...")
                    .tint(.white)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemSymbol: .xmark)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.black.opacity(0.5), in: Circle())
                    }
                    .accessibilityLabel("Close")
                }
                Spacer()
                if let onToggleLight {
                    HStack {
                        Button {
                            onToggleLight(!isLightOn)
                        } label: {
                            Image(systemSymbol: isLightOn ? .lightbulbFill : .lightbulb)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(isLightOn ? .yellow : .white.opacity(0.7))
                                .padding(10)
                                .background(.black.opacity(0.5), in: Circle())
                        }
                        .accessibilityLabel("Toggle Light")
                        Spacer()
                    }
                }
            }
            .padding(16)
        }
        .ignoresSafeArea()
        .persistentSystemOverlays(.hidden)
        .statusBarHidden()
        .onAppear {
            AppDelegate.orientationLock = .landscape
            rotateToLandscape()
        }
        .onDisappear {
            AppDelegate.orientationLock = .portrait
            rotateToPortrait()
        }
    }

    private func rotateToLandscape() {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first else { return }
        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape))
        for window in windowScene.windows {
            window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }

    private func rotateToPortrait() {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first else { return }
        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
        for window in windowScene.windows {
            window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }
}
