import Testing
@testable import SlowMode

struct SmokeTests {
    @Test func appNameIsSet() {
        #expect(AppInfo.name == "Slow Mode")
    }
}
