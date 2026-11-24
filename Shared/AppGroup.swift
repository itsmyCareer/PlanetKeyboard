import Foundation

struct AppGroup {
    static var userDefaults: UserDefaults {
        UserDefaults(suiteName: AppConstants.appGroupID) ?? .standard
    }

    static var containerURL: URL {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppConstants.appGroupID
        ) ?? FileManager.default.temporaryDirectory
    }
}
