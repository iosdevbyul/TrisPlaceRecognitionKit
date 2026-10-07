import Foundation

enum PlaceL10n {
    static func string(
        _ key: String
    ) -> String {
        NSLocalizedString(
            key,
            bundle: .module,
            comment: ""
        )
    }

    static func format(
        _ key: String,
        _ arguments: CVarArg...
    ) -> String {
        String(
            format: string(key),
            locale: locale,
            arguments: arguments
        )
    }

    static var locale: Locale {
        let identifier =
            Bundle.module
                .preferredLocalizations
                .first
            ?? "en"

        return Locale(
            identifier: identifier
        )
    }
}
