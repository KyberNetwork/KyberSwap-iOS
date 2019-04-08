// Copyright SIX DAY LLC. All rights reserved.

import Foundation

extension Bundle {
    var versionNumber: String? {
        return infoDictionary?["CFBundleShortVersionString"] as? String
    }
    var buildNumber: String? {
        return infoDictionary?["CFBundleVersion"] as? String
    }

    var buildNumberInt: Int {
        return Int(Bundle.main.buildNumber ?? "-1") ?? -1
    }

    var fullVersion: String {
        let versionNumber = Bundle.main.versionNumber ?? ""
        let buildNumber = Bundle.main.buildNumber ?? ""
        return "\(versionNumber) (\(buildNumber))"
    }

    static func isUpdateAvailable() throws -> Bool {
      guard let info = Bundle.main.infoDictionary,
        let currentVersion = info["CFBundleShortVersionString"] as? String,
        let identifier = info["CFBundleIdentifier"] as? String,
        let url = URL(string: "http://itunes.apple.com/lookup?bundleId=\(identifier)") else {
          throw VersionError.invalidBundleInfo
      }
      let data = try Data(contentsOf: url)
      guard let json = try JSONSerialization.jsonObject(with: data, options: [.allowFragments]) as? [String: Any] else {
        throw VersionError.invalidResponse
      }
      if let result = (json["results"] as? [Any])?.first as? [String: Any], let version = result["version"] as? String {
        return version != currentVersion
      }
      throw VersionError.invalidResponse
    }
}

enum VersionError: Error {
  case invalidResponse, invalidBundleInfo
}

var isDebug: Bool {
    #if DEBUG
        return true
    #else
        return false
    #endif
}
