import SwiftUI

@MainActor
public protocol CameraStreamProviding: AnyObject, Observable {
    var currentFrame: UIImage? { get }
    var isStreaming: Bool { get }
}
