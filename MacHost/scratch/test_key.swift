import Foundation
import ApplicationServices

func verifyFields() {
    let source = CGEventSource(stateID: .privateState)
    let loc = CGPoint(x: 100, y: 100)
    if let event = CGEvent(mouseEventSource: source, mouseType: .leftMouseDragged, mouseCursorPosition: loc, mouseButton: .left) {
        event.setDoubleValueField(.tabletEventPointPressure, value: 0.8)
        event.setDoubleValueField(.tabletEventTiltX, value: 0.2)
        event.setDoubleValueField(.tabletEventTiltY, value: -0.3)
        event.setDoubleValueField(.mouseEventPressure, value: 0.8)
        print("Success: CGEvent fields exist!")
    }
}

verifyFields()
