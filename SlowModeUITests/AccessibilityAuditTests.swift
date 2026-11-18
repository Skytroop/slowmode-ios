import XCTest

/// Recorre las pantallas en modo demostración y pasa la auditoría de accesibilidad de Xcode
/// (contraste, texto que se corta con letra grande, botones pequeños, elementos sin etiqueta…).
///
/// De momento los problemas se registran (líneas "A11Y" en el log y adjuntos en el informe) sin
/// hacer fallar el CI, para poder corregirlos por tandas. Cuando estén resueltos, `strict` pasa a `true`.
final class AccessibilityAuditTests: XCTestCase {
    private let strict: Bool = false

    override func setUp() {
        continueAfterFailure = true
    }

    @MainActor
    func testAuditMainScreens() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-demo"]
        app.launch()

        let home = app.descendants(matching: .any)[AccessibilityID.homeView]
        XCTAssertTrue(home.waitForExistence(timeout: 15), "Inicio no aparece")
        // Espera a que se importen las pistas de demostración.
        XCTAssertTrue(app.buttons[AccessibilityID.miniPlayerOpen].waitForExistence(timeout: 20), "No aparece el minirreproductor")
        try audit(app, screen: "Inicio")

        app.tabBars.buttons["Biblioteca"].tap()
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.libraryView].waitForExistence(timeout: 5))
        try audit(app, screen: "Biblioteca")

        app.tabBars.buttons["Comunidad"].tap()
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.communityView].waitForExistence(timeout: 5))
        try audit(app, screen: "Comunidad")

        app.tabBars.buttons["Buscar"].tap()
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.searchView].waitForExistence(timeout: 5))
        try audit(app, screen: "Buscar")

        app.buttons[AccessibilityID.miniPlayerOpen].tap()
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.nowPlayingView].waitForExistence(timeout: 5), "Reproduciendo no se abre")
        try audit(app, screen: "Reproduciendo")

        let expand = app.buttons[AccessibilityID.slowModeExpand]
        if expand.waitForExistence(timeout: 3) {
            expand.tap()
            try audit(app, screen: "Reproduciendo · panel Slow Mode")
        }

        app.buttons[AccessibilityID.nowPlayingClose].tap()
    }

    /// Mide el arranque en frío (se ve en el informe de resultados del CI).
    @MainActor
    func testLaunchPerformance() throws {
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        measure(metrics: [XCTApplicationLaunchMetric()], options: options) {
            let app = XCUIApplication()
            app.launchArguments = ["-uitest-demo"]
            app.launch()
            app.terminate()
        }
    }

    @MainActor
    private func audit(_ app: XCUIApplication, screen: String) throws {
        var findings: [String] = []
        try app.performAccessibilityAudit { issue in
            let element: String = issue.element.map { "\($0.identifier) «\($0.label)»" } ?? "—"
            findings.append("A11Y [\(screen)] \(issue.compactDescription) · \(element)")
            return !self.strict
        }
        for line in findings {
            print(line)
        }
        let attachment = XCTAttachment(string: findings.isEmpty ? "Sin problemas" : findings.joined(separator: "\n"))
        attachment.name = "Accesibilidad · \(screen)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
