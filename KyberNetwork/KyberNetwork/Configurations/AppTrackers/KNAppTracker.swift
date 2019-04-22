// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import TrustKeystore
import TrustCore

enum KNTransactionLoadState: Int {
  case none = 0
  case done = 1
  case failed = 2
}

class KNAppTracker {

  // Env
  static let kInternalTrackerEndpointKey: String = "kInternalTrackerEndpointKey"
  static let kExternalEnvironmentKey: String = "kExternalEnvironmentKey"

  static let kTransactionLoadStateKey: String = "kTransactionLoadStateKey"
  static let kAllTransactionLoadLastBlockKey: String = "kAllTransactionLoadLastBlockKey"
  static let kInternalTransactionLoadLastBlockKey: String = "kInternalTransactionLoadLastBlockKey"
  static let kTransactionNonceKey: String = "kTransactionNonceKey"

  static let kSupportedLoadingTimeKey: String = "kSupportedLoadingTimeKey"

  static let kCurrencyTypeKey: String = "kCurrencyTypeKey"

  static let kAppStyle: String = "kAppStyle"

  static let kPushNotificationTokenKey: String = "kPushNotificationTokenKey"

  static let kForceUpdateAlertKey: String = "kForceUpdateAlertKey"

  static let kHasLoggedUserOutWithNativeSignInKey: String = "kHasLoggedUserOutWithNativeSignInKey"

  static let userDefaults: UserDefaults = UserDefaults.standard

  static let minimumPriceAlertPercent: Double = -99.0
  static let minimumPriceAlertChangePercent: Double = 0.1 // min change 0.1%
  static let maximumPriceAlertPercent: Double = 10000.0

  static func internalCachedEnpoint() -> String {
    return KNSecret.internalCachedEndpoint
  }

  static func internalTrackerEndpoint() -> String {
    return KNEnvironment.default.kyberAPIEnpoint
  }

  static func updateInternalTrackerEndpoint(value: String) {
    userDefaults.set(value, forKey: kInternalTrackerEndpointKey)
    userDefaults.synchronize()
  }

  // MARK: External environment
  static func externalEnvironment() -> KNEnvironment {
    if let value = userDefaults.object(forKey: kExternalEnvironmentKey) as? Int, let env = KNEnvironment(rawValue: value) {
      return env
    }
    return KNEnvironment.ropsten
  }

  static func updateExternalEnvironment(_ env: KNEnvironment) {
    userDefaults.set(env.rawValue, forKey: kExternalEnvironmentKey)
    userDefaults.synchronize()
  }

  // MARK: Transaction load state
  static func transactionLoadState(for address: Address) -> KNTransactionLoadState {
    let sessionID = KNSession.sessionID(from: address)
    let key = kTransactionLoadStateKey + sessionID
    if let value = userDefaults.object(forKey: key) as? Int {
      return KNTransactionLoadState(rawValue: value) ?? .none
    }
    return .none
  }

  static func updateTransactionLoadState(_ state: KNTransactionLoadState, for address: Address) {
    let sessionID = KNSession.sessionID(from: address)
    let key = kTransactionLoadStateKey + sessionID
    userDefaults.set(state.rawValue, forKey: key)
    userDefaults.synchronize()
  }

  static func lastBlockLoadAllTransaction(for address: Address) -> Int {
    let sessionID = KNSession.sessionID(from: address)
    let key = kAllTransactionLoadLastBlockKey + sessionID
    if let value = userDefaults.object(forKey: key) as? Int {
      return value
    }
    return 0
  }

  static func updateAllTransactionLastBlockLoad(_ block: Int, for address: Address) {
    let sessionID = KNSession.sessionID(from: address)
    let key = kAllTransactionLoadLastBlockKey + sessionID
    userDefaults.set(block, forKey: key)
    userDefaults.synchronize()
  }

  static func lastBlockLoadInternalTransaction(for address: Address) -> Int {
    let sessionID = KNSession.sessionID(from: address)
    let key = kInternalTransactionLoadLastBlockKey + sessionID
    if let value = userDefaults.object(forKey: key) as? Int {
      return value
    }
    return 0
  }

  static func updateInternalTransactionLastBlockLoad(_ block: Int, for address: Address) {
    let sessionID = KNSession.sessionID(from: address)
    let key = kInternalTransactionLoadLastBlockKey + sessionID
    userDefaults.set(block, forKey: key)
    userDefaults.synchronize()
  }

  static func transactionNonce(for address: Address) -> Int {
    let sessionID = KNSession.sessionID(from: address)
    let key = kTransactionNonceKey + sessionID
    return userDefaults.object(forKey: key) as? Int ?? 0
  }

  static func updateTransactionNonce(_ nonce: Int, address: Address) {
    let sessionID = KNSession.sessionID(from: address)
    let key = kTransactionNonceKey + sessionID
    userDefaults.set(nonce, forKey: key)
    userDefaults.synchronize()
  }

  // MARK: Supported Tokens
  static func updateSuccessfullyLoadSupportedTokens() {
    let time = Date().timeIntervalSince1970
    userDefaults.set(time, forKey: kSupportedLoadingTimeKey)
    userDefaults.synchronize()
  }

  static func getSuccessfullyLoadSupportedTokensDate() -> Date? {
    guard let time = userDefaults.value(forKey: kSupportedLoadingTimeKey) as? Double else {
      return nil
    }
    return Date(timeIntervalSince1970: time)
  }

  // MARK: Currency used (USD, ETH)
  static func updateCurrencyType(_ type: KWalletCurrencyType) {
    userDefaults.set(type.rawValue, forKey: kCurrencyTypeKey)
    userDefaults.synchronize()
  }

  static func getCurrencyType() -> KWalletCurrencyType {
    if let type = userDefaults.object(forKey: kCurrencyTypeKey) as? String {
      return KWalletCurrencyType(rawValue: type) ?? .usd
    }
    return .usd
  }

  // MARK: Profile base string
  static func getKyberProfileBaseString() -> String {
    return KNEnvironment.default.profileURL
  }

  // MARK: App style
  static func updateAppStyleType(_ type: KNAppStyleType) {
    userDefaults.set(type.rawValue, forKey: kAppStyle)
    userDefaults.synchronize()
  }

  static func getAppStyleType() -> KNAppStyleType {
    let type = userDefaults.object(forKey: kAppStyle) as? String ?? ""
    return KNAppStyleType(rawValue: type) ?? .default
  }

  // MARK: Push notification token
  static func updatePushNotificationToken(_ token: String) {
    userDefaults.set(token, forKey: kPushNotificationTokenKey)
    userDefaults.synchronize()
  }

  static func getPushNotificationToken() -> String? {
    return userDefaults.object(forKey: kPushNotificationTokenKey) as? String
  }

  // MARK: Reset app tracker
  static func resetAppTrackerData(for address: Address) {
    self.updateAllTransactionLastBlockLoad(0, for: address)
    self.updateTransactionLoadState(.none, for: address)
    self.updateTransactionNonce(0, address: address)
  }

  static func resetAllAppTrackerData() {
    userDefaults.removeObject(forKey: kSupportedLoadingTimeKey)
    userDefaults.removeObject(forKey: kCurrencyTypeKey)
  }

  static var isPriceAlertEnabled: Bool { return true }

  static func hasLoggedUserOutWithNativeSignIn() -> Bool {
    return userDefaults.object(forKey: kHasLoggedUserOutWithNativeSignInKey) as? Bool ?? false
  }

  static func updateHasLoggedUserOutWithNativeSignIn(isTrue: Bool = true) {
    userDefaults.set(isTrue, forKey: kHasLoggedUserOutWithNativeSignInKey)
    userDefaults.synchronize()
  }
}
