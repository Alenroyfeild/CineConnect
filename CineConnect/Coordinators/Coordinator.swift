import SwiftUI

@MainActor
protocol Coordinator: AnyObject {
    associatedtype Content: View

    @ViewBuilder func makeView() -> Content
}
