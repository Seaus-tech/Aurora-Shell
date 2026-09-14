import Foundation

// Fallback definitions for build info in case the SwiftTerm build tool plugin didn't run.
// If the plugin generates SwiftTermBuildInfo.swift within the SwiftTerm package target,
// that generated file will be used there. This stub only satisfies app targets.

public let SWIFTTERM_BUILD_BRANCH: String = ProcessInfo.processInfo.environment["SWIFTTERM_BUILD_BRANCH"] ?? "unknown"
public let SWIFTTERM_BUILD_TAG: String = ProcessInfo.processInfo.environment["SWIFTTERM_BUILD_TAG"] ?? "0.0.0"
public let SWIFTTERM_BUILD_COMMIT: String = ProcessInfo.processInfo.environment["SWIFTTERM_BUILD_COMMIT"] ?? "0000000"
public let SWIFTTERM_BUILD_DIRTY: Bool = {
    if let v = ProcessInfo.processInfo.environment["SWIFTTERM_BUILD_DIRTY"] {
        return (v as NSString).boolValue
    }
    return false
}()
