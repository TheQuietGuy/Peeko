import Carbon.HIToolbox
import Foundation

/// System-wide shortcuts (⌃⌥ + a letter) through the Carbon hot key API, which needs no
/// Accessibility permission. A key another app already owns is simply skipped.
@MainActor
public final class HotKeys {
    public var onPress: ((LauncherItem) -> Void)?
    /// Escape, held only while the pointer is over the open notch.
    public var onEscape: (() -> Void)?

    private var refs: [EventHotKeyRef] = []
    private var escapeRef: EventHotKeyRef?
    private static let escapeID: UInt32 = 999
    private var handler: EventHandlerRef?
    fileprivate static weak var current: HotKeys?

    public init() {}

    public func register() {
        guard refs.isEmpty else { return }
        installHandler()
        for (index, item) in LauncherItem.allCases.enumerated() {
            guard let code = Self.keyCode(item.key) else { continue }
            var ref: EventHotKeyRef?
            let id = EventHotKeyID(signature: Self.signature, id: UInt32(index))
            let status = RegisterEventHotKey(code, UInt32(controlKey | optionKey), id, GetApplicationEventTarget(), 0, &ref)
            if status == noErr, let ref { refs.append(ref) }
        }
    }

    public func unregister() {
        refs.forEach { UnregisterEventHotKey($0) }
        refs.removeAll()
    }

    /// Takes Escape while the pointer is over the open notch and gives it straight back after,
    /// so other apps only lose it while you're plainly using the notch.
    public func setEscape(_ active: Bool) {
        if active, escapeRef == nil {
            installHandler()
            var ref: EventHotKeyRef?
            let id = EventHotKeyID(signature: Self.signature, id: Self.escapeID)
            if RegisterEventHotKey(UInt32(kVK_Escape), 0, id, GetApplicationEventTarget(), 0, &ref) == noErr { escapeRef = ref }
        } else if !active, let escapeRef {
            UnregisterEventHotKey(escapeRef)
            self.escapeRef = nil
        }
    }

    public var holdsEscape: Bool { escapeRef != nil }

    private func installHandler() {
        HotKeys.current = self
        guard handler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), hotKeyHandler, 1, &spec, nil, &handler)
    }

    fileprivate func pressed(_ index: Int) {
        if index == Int(Self.escapeID) {
            onEscape?()
            return
        }
        guard LauncherItem.allCases.indices.contains(index) else { return }
        onPress?(LauncherItem.allCases[index])
    }

    /// "DNch"
    private static let signature: OSType = 0x444E_6368

    nonisolated static func keyCode(_ key: Character) -> UInt32? {
        let codes: [Character: Int] = [
            "A": kVK_ANSI_A, "B": kVK_ANSI_B, "H": kVK_ANSI_H, "L": kVK_ANSI_L, "M": kVK_ANSI_M, "N": kVK_ANSI_N,
            "O": kVK_ANSI_O, "P": kVK_ANSI_P, "R": kVK_ANSI_R, "S": kVK_ANSI_S, "U": kVK_ANSI_U, "W": kVK_ANSI_W, "X": kVK_ANSI_X, "Y": kVK_ANSI_Y, "Z": kVK_ANSI_Z,
        ]
        return codes[key].map { UInt32($0) }
    }
}

/// Carbon calls this on the main thread.
private func hotKeyHandler(_ next: EventHandlerCallRef?, _ event: EventRef?, _ data: UnsafeMutableRawPointer?) -> OSStatus {
    guard let event else { return OSStatus(eventNotHandledErr) }
    var id = EventHotKeyID()
    let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
    guard status == noErr else { return status }
    let index = Int(id.id)
    MainActor.assumeIsolated { HotKeys.current?.pressed(index) }
    return noErr
}
