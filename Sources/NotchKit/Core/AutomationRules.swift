import Foundation

/// What to tell the user after asking macOS whether Perch may control another app (to read
/// which file or page a dragged window shows).
public enum AutomationRules {
    /// errAEEventNotPermitted: the user said no, or switched it off in System Settings.
    public static let notPermitted: OSStatus = -1743
    /// errAEEventWouldRequireUserConsent: only returned when not asking.
    public static let needsConsent: OSStatus = -1744
    /// procNotFound: the app quit.
    public static let appNotRunning: OSStatus = -600

    /// Nil means go ahead.
    public static func message(for status: OSStatus, appName: String) -> String? {
        switch status {
        case noErr: nil
        case notPermitted, needsConsent:
            String(localized: "Perch isn't allowed to read \(appName)'s windows. Turn on \(appName) under Perch in System Settings › Privacy & Security › Automation, then try again.")
        case appNotRunning: String(localized: "\(appName) isn't running any more.")
        default: String(localized: "Couldn't ask \(appName) which document this is (error \(status)).")
        }
    }
}
