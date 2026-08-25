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

    private var hotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    var onPressed: (() -> Void)?

    init() throws {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData -> OSStatus in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                let service = Unmanaged<GlobalHotKeyService>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
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
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: 1)
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
