import Foundation

enum AppEnvironment {
    static let isRunningTests: Bool = {
        if NSClassFromString("XCTestCase") != nil { return true }
        let env = ProcessInfo.processInfo.environment
        if env["XCTestConfigurationFilePath"] != nil { return true }
        if env["CI"] == "true" { return true }
        if env["NON_INTERACTIVE_TESTS"] == "1" { return true }
        return false
    }()
}

