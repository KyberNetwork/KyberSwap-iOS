// Copyright SIX DAY LLC. All rights reserved.

import NotificationCenter
import UserNotifications

// Transaction Keys
let kTransactionDidUpdateNotificationKey = "kTransactionDidUpdateNotificationKey"
let kTransactionListDidUpdateNotificationKey = "kTransactionListDidUpdateNotificationKey"

// Token Transaction Key
let kTokenTransactionListDidUpdateNotificationKey = "kTokenTransactionListDidUpdateNotificationKey"
let kTokenObjectListDidUpdateNotificationKey = "kTokenObjectListDidUpdateNotificationKey"

// Tokens
let kSupportedTokenListDidUpdateNotificationKey = "kSupportedTokenListDidUpdateNotificationKey"

// Balance Keys
let kETHBalanceDidUpdateNotificationKey = "kETHBalanceDidUpdateNotificationKey"
let kOtherBalanceDidUpdateNotificationKey = "kOtherBalanceDidUpdateNotificationKey"

// Rate
let kExchangeTokenRateNotificationKey = "kExchangeTokenRateNotificationKey"
let kExchangeUSDRateNotificationKey = "kExchangeUSDRateNotificationKey"
let kProdCachedRateFailedToLoadNotiKey = "kProdCachedRateFailedToLoadNotiKey"

let kCoinTickersDidUpdateNotificationKey = "kCoinTickerDataDidUpdateNotificationKey"

// Setup
let kWalletHeaderViewDidChangeTypeNotificationKey = "kWalletHeaderViewDidChangeTypeNotificationKey"

// Gas Price
let kGasPriceDidUpdateNotificationKey = "kGasPriceDidUpdateNotificationKey"

let kUpdateListContactNotificationKey = "kUpdateListContactNotificationKey"

let kUpdateListAlertsNotificationKey = "kUpdateListAlertsNotificationKey"

// IEO
let kIEOUserDidUpdateNotificationKey = "kIEOUserDidUpdateNotificationKey"
let kIEODidReceiveCallbackNotificationKey = "kIEODidReceiveCallbackNotificationKey"
let kIEOTxListUpdateNotificationKey = "kIEOTxListUpdateNotificationKey"

let kUserWalletsListUpdatedNotificationKey = "kUserWalletsListUpdatedNotificationKey"

// Receive txs
let kNewReceivedTransactionKey = "kNewReceivedTransactionKey"

class KNNotificationUtil {

  static func postNotification(for key: String, object: Any? = nil, userInfo: [AnyHashable: Any]? = nil) {
    let notificationName = Notification.Name(rawValue: key)
    NotificationCenter.default.post(name: notificationName, object: object, userInfo: userInfo)
  }

  static func notificationName(from name: String) -> Notification.Name {
    return Notification.Name(name)
  }

  static func localPushNotification(title: String, body: String, userInfo: [AnyHashable: Any] = [:]) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.userInfo = userInfo
    if #available(iOS 12, *) {
      print("Using iOS 12")
    } else {
      content.setValue("YES", forKey: "shouldAlwaysAlertWhileAppIsForeground")
    }
    let request = UNNotificationRequest(identifier: "localPushNotification", content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request) { error in
      NSLog("Error \(error.debugDescription)")
    }
  }
}
