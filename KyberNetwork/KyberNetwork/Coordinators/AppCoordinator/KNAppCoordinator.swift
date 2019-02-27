// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import IQKeyboardManager
import BigInt
import Moya
import Crashlytics
import OneSignal

class KNAppCoordinator: NSObject, Coordinator {

  let navigationController: UINavigationController
  let window: UIWindow
  internal var keystore: Keystore
  var coordinators: [Coordinator] = []
  internal var session: KNSession!
  internal var currentWallet: Wallet!
  internal var loadBalanceCoordinator: KNLoadBalanceCoordinator?

  internal var exchangeCoordinator: KNExchangeTokenCoordinator?
  internal var balanceTabCoordinator: KNBalanceTabCoordinator?
  internal var settingsCoordinator: KNSettingsCoordinator?

  internal var profileCoordinator: KNProfileHomeCoordinator?

  internal var tabbarController: KNTabBarController!
  internal var transactionStatusCoordinator: KNTransactionStatusCoordinator!

  lazy var splashScreenCoordinator: KNSplashScreenCoordinator = {
    return KNSplashScreenCoordinator()
  }()

  lazy var authenticationCoordinator: KNPasscodeCoordinator = {
    let passcode = KNPasscodeCoordinator(type: .authenticate(isUpdating: false))
    passcode.delegate = self
    return passcode
  }()

  lazy var landingPageCoordinator: KNLandingPageCoordinator = {
    let coordinator = KNLandingPageCoordinator(
      navigationController: self.navigationController,
      keystore: self.keystore
    )
    coordinator.delegate = self
    return coordinator
  }()

  internal var promoCodeCoordinator: KNPromoCodeCoordinator?

  init(
    navigationController: UINavigationController = UINavigationController(),
    window: UIWindow,
    keystore: Keystore) {
    self.navigationController = navigationController
    self.window = window
    self.keystore = keystore
    super.init()
    self.window.rootViewController = self.navigationController
    self.window.makeKeyAndVisible()
  }

  deinit {
    self.removeInternalObserveNotification()
    self.removeObserveNotificationFromSession()
  }

  func start() {
    self.addMissingWalletObjects()
    KNSupportedTokenStorage.shared.addLocalSupportedTokens()
    self.startLandingPageCoordinator()
    self.startFirstSessionIfNeeded()
    self.addInternalObserveNotification()
  }

  fileprivate func addMissingWalletObjects() {
    let walletObjects = self.keystore.wallets.filter {
      return KNWalletStorage.shared.get(forPrimaryKey: $0.address.description) == nil
    }.map { return KNWalletObject(address: $0.address.description) }
    KNWalletStorage.shared.add(wallets: walletObjects)
  }

  fileprivate func startLandingPageCoordinator() {
    self.addCoordinator(self.landingPageCoordinator)
    self.landingPageCoordinator.start()
  }

  fileprivate func startFirstSessionIfNeeded() {
    // For security, should always have passcode protection when user has imported wallets
    if let wallet = self.keystore.recentlyUsedWallet ?? self.keystore.wallets.first,
      KNPasscodeUtil.shared.currentPasscode() != nil {
      self.startNewSession(with: wallet)
    }
  }
}

// Application state
extension KNAppCoordinator {
  func appDidFinishLaunch() {
    self.splashScreenCoordinator.start()
    self.authenticationCoordinator.start(isLaunch: true)
    IQKeyboardManager.shared().isEnabled = true
    IQKeyboardManager.shared().shouldResignOnTouchOutside = true
    KNSession.resumeInternalSession()
  }

  func appDidBecomeActive() {
    KNSession.pauseInternalSession()
    KNSession.resumeInternalSession()
    self.loadBalanceCoordinator?.resume()
  }

  func appWillEnterForeground() {
    self.authenticationCoordinator.start()
  }

  func appDidEnterBackground() {
    self.splashScreenCoordinator.stop()
    KNSession.pauseInternalSession()
    self.loadBalanceCoordinator?.pause()
  }

  func appDidReceiveLocalNotification(transactionHash: String) {
    let urlString = KNEnvironment.default.etherScanIOURLString + "tx/\(transactionHash)"
    if self.transactionStatusCoordinator != nil {
      self.transactionStatusCoordinator.rootViewController?.openSafari(with: urlString)
    } else {
      guard let url = URL(string: urlString) else { return }
      UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
  }

  func appDidReceiverOneSignalPushNotification(notification: OSNotification?) {
    guard let noti = notification else { return }
    let title = noti.payload.title
    let body = noti.payload.body
    let alertController = UIAlertController(title: title, message: body, preferredStyle: .alert)
    alertController.addAction(UIAlertAction(title: NSLocalizedString("ok", value: "OK", comment: ""), style: .cancel, handler: nil))
    self.navigationController.present(alertController, animated: true, completion: nil)
  }

  func appDidReceiverOneSignalPushNotification(result: OSNotificationOpenedResult?) {
    if let noti = result?.notification, let type = noti.payload.additionalData["type"] as? String, type == "price_alert", self.tabbarController != nil {
      self.handlePriceAlertPushNotification(noti)
      return
    }
    if let noti = result?.notification, let type = noti.payload.additionalData["type"] as? String, type == "swap", self.tabbarController != nil {
      self.handleOpenKyberSwapPushNotification(noti)
      return
    }
    if let urlString = result?.notification.payload.additionalData["open_url"] as? String, let url = URL(string: urlString) {
      UIApplication.shared.open(url, options: [:], completionHandler: nil)
      return
    }
    if let noti = result?.notification,
      let type = noti.payload.additionalData["type"] as? String, type == "balance", self.tabbarController != nil {
      self.handleOpenBalanceTabPushNotification(noti)
      return
    }
    guard let payload = result?.notification.payload else { return }
    let title = payload.title
    let body = payload.body
    let alertController = UIAlertController(title: title, message: body, preferredStyle: .alert)
    alertController.addAction(UIAlertAction(title: NSLocalizedString("ok", value: "OK", comment: ""), style: .cancel, handler: nil))
    self.navigationController.present(alertController, animated: true, completion: nil)
  }

  fileprivate func handleOpenKyberSwapPushNotification(_ notification: OSNotification) {
    self.tabbarController.selectedIndex = 1
    let from = notification.payload.additionalData["from"] as? String ?? ""
    let to = notification.payload.additionalData["to"] as? String ?? ""
    self.exchangeCoordinator?.appCoordinatorPushNotificationOpenSwap(from: from, to: to)
  }

  fileprivate func handleOpenBalanceTabPushNotification(_ notification: OSNotification) {
    self.tabbarController.selectedIndex = 0
    let currency = notification.payload.additionalData["currency"] as? String ?? KNAppTracker.getCurrencyType().rawValue
    let currencyType = KWalletCurrencyType(rawValue: currency) ?? KNAppTracker.getCurrencyType()
    self.balanceTabCoordinator?.appCoordinatorBalanceSorted(with: currencyType)
  }

  fileprivate func handlePriceAlertPushNotification(_ notification: OSNotification) {
    let token = notification.payload.additionalData["token"] as? String ?? ""
    let view = notification.payload.additionalData["view"] as? String ?? ""
    if view == "token_chart" {
      self.tabbarController.selectedIndex = 0
      self.balanceTabCoordinator?.appCoordinatorOpenTokenChart(for: token)
    } else if view == "balance" {
      self.tabbarController.selectedIndex = 0
      self.balanceTabCoordinator?.appCoordinatorDidUpdateNewSession(self.session, resetRoot: true)
    } else if view == "kyberswap" {
      self.handleOpenKyberSwapPushNotification(notification)
    }
  }
}
