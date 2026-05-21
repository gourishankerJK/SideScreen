import Foundation
import CoreGraphics

print("Testing CoreGraphics tablet event constants...")

let source = CGEventSource(stateID: .privateState)
if let event = CGEvent(source: source) {
    event.type = .tabletProximity
    
    event.setIntegerValueField(.tabletProximityEventPointerType, value: 1)
    event.setIntegerValueField(.tabletProximityEventEnterProximity, value: 1)
    event.setIntegerValueField(.tabletProximityEventVendorID, value: 0x056a)
    event.setIntegerValueField(.tabletProximityEventTabletID, value: 1)
    event.setIntegerValueField(.tabletProximityEventPointerID, value: 1)
    event.setIntegerValueField(.tabletProximityEventDeviceID, value: 1)
    event.setIntegerValueField(.tabletProximityEventSystemTabletID, value: 1)
    
    print("tabletProximity compilation OK!")
}

if let mouseEvent = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: CGPoint(x: 100, y: 100), mouseButton: .left) {
    mouseEvent.setIntegerValueField(.mouseEventSubtype, value: 1) // kCGEventMouseSubtypeTabletPoint = 1
    mouseEvent.setDoubleValueField(.tabletEventPointPressure, value: 0.5)
    mouseEvent.setDoubleValueField(.tabletEventTiltX, value: 0.2)
    mouseEvent.setDoubleValueField(.tabletEventTiltY, value: -0.3)
    
    print("tabletPoint compilation OK!")
}
