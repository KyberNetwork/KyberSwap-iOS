// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import Result
import Moya

class KNProfileHomeViewModel: NSObject {
  var currentUser: IEOUser? { return IEOUserStorage.shared.user }
  var isUserSignedIn: Bool { return self.currentUser != nil }
}
