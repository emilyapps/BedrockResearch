import SwiftUI

private struct AppFontScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1.0
}

extension EnvironmentValues {
    /// App-wide text scale factor, set from `AppState.fontScale` (Settings > Accessibility).
    var appFontScale: CGFloat {
        get { self[AppFontScaleKey.self] }
        set { self[AppFontScaleKey.self] = newValue }
    }
}

extension View {
    /// Applies `font`, scaled by the app's accessibility text-size setting.
    func appFont(_ font: Font) -> some View {
        modifier(AppFontModifier(font: font))
    }
}

private struct AppFontModifier: ViewModifier {
    let font: Font
    @Environment(\.appFontScale) private var scale

    func body(content: Content) -> some View {
        content.font(font.scaled(by: scale))
    }
}
