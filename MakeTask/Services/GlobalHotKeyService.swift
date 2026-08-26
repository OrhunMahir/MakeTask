import Carbon.HIToolbox
import Foundation

final class GlobalHotKeyService {
    enum HotKeyError: LocalizedError {
        case handlerInstallationFailed(OSStatus)
        case registrationFailed(OSStatus)

        var errorDescription: String? {
            switch self {
            case .handlerInstallationFailed(let status):
                "Could not install the keyboard shortcut handler (OSStatus \(status))."
            case .registrationFailed(let status):
                "The keyboard shortcut could not be registered. It may already be in use (OSStatus \(status))."
            }
        }
    }

    private static let signature: OSType = 0x4D4B5453 // "MKTS"

    private let identifier: UInt32
    private var hotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    var onPressed: (() -> Void)?

    init(identifier: UInt32 = 1) throws {
        self.identifier = identifier

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                let service = Unmanaged<GlobalHotKeyService>
                    .fromOpaque(userData)
                    .takeUnretainedValue()

                var pressedHotKeyID = EventHotKeyID()
                let parameterStatus = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &pressedHotKeyID
                )
                guard parameterStatus == noErr,
                      pressedHotKeyID.signature == GlobalHotKeyService.signature,
                      pressedHotKeyID.id == service.identifier else {
                    return OSStatus(eventNotHandledErr)
                }

                DispatchQueue.main.async {
                    service.onPressed?()
                }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        guard status == noErr else {
            throw HotKeyError.handlerInstallationFailed(status)
        }
    }

    func register(keyCode: UInt32, modifiers: UInt32) throws {
        unregister()
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: identifier)
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKey
        )

        guard status == noErr else {
            hotKey = nil
            throw HotKeyError.registrationFailed(status)
        }
    }

    func unregister() {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
            self.hotKey = nil
        }
    }

    deinit {
        unregister()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }
}
