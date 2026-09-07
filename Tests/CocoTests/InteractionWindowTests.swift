import AppKit
import Testing
@testable import Coco

@MainActor
struct InteractionWindowTests {
    @Test func foodReceivesTheFirstClickWhileCocoIsInactive() {
        let view = TargetView(frame: CGRect(x: 0, y: 0, width: 48, height: 48))
        #expect(view.acceptsFirstMouse(for: nil))
    }
}
