// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import BigInt
import Result

/*
 Handling notification from many fetchers, views, ...
 */
extension KNAppCoordinator {
  func addObserveNotificationFromSession() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(self.transactionStateDidUpdate(_:)),
      name: Notification.Name(kTransactionDidUpdateNotificationKey),
      object: nil
    )
    let ethBalanceName = Notification.Name(kETHBalanceDidUpdateNotificationKey)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(self.ethBalanceDidUpdateNotification(_:)),
      name: ethBalanceName,
      object: nil
    )
    let tokenBalanceName = Notification.Name(kOtherBalanceDidUpdateNotificationKey)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(self.tokenBalancesDidUpdateNotification(_:)),
      name: tokenBalanceName,
      object: nil
    )
    let tokenTxListName = Notification.Name(kTokenTransactionListDidUpdateNotificationKey)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(self.tokenTransactionListDidUpdate(_:)),
      name: tokenTxListName,
      object: nil
    )
    let tokenObjectListName = Notification.Name(kTokenObjectListDidUpdateNotificationKey)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(self.tokenObjectListDidUpdate(_:)),
      name: tokenObjectListName,
      object: nil
    )
  }

  func addInternalObserveNotification() {
    let rateTokensName = Notification.Name(kExchangeTokenRateNotificationKey)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(self.exchangeRateTokenDidUpdateNotification(_:)),
      name: rateTokensName,
      object: nil)
    let rateUSDName = Notification.Name(kExchangeUSDRateNotificationKey)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(self.exchangeRateUSDDidUpdateNotification(_:)),
      name: rateUSDName,
      object: nil
    )
    let supportedTokensName = Notification.Name(kSupportedTokenListDidUpdateNotificationKey)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(self.tokenObjectListDidUpdate(_:)),
      name: supportedTokensName,
      object: nil
    )
    let gasPriceName = Notification.Name(kGasPriceDidUpdateNotificationKey)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(self.gasPriceCachedDidUpdate(_:)),
      name: gasPriceName,
      object: nil
    )
  }

  func removeObserveNotificationFromSession() {
    NotificationCenter.default.removeObserver(
      self,
      name: Notification.Name(kTransactionDidUpdateNotificationKey),
      object: nil
    )
    NotificationCenter.default.removeObserver(
      self,
      name: Notification.Name(kETHBalanceDidUpdateNotificationKey),
      object: nil
    )
    NotificationCenter.default.removeObserver(
      self,
      name: Notification.Name(kOtherBalanceDidUpdateNotificationKey),
      object: nil
    )
    NotificationCenter.default.removeObserver(
      self,
      name: Notification.Name(kTokenTransactionListDidUpdateNotificationKey),
      object: nil
    )
    NotificationCenter.default.removeObserver(
      self,
      name: Notification.Name(kTokenObjectListDidUpdateNotificationKey),
      object: nil
    )
  }

  func removeInternalObserveNotification() {
    NotificationCenter.default.removeObserver(
      self,
      name: Notification.Name(kExchangeTokenRateNotificationKey),
      object: nil
    )
    NotificationCenter.default.removeObserver(
      self,
      name: Notification.Name(kExchangeUSDRateNotificationKey),
      object: nil
    )
    let supportedTokensName = Notification.Name(kSupportedTokenListDidUpdateNotificationKey)
    NotificationCenter.default.removeObserver(
      self,
      name: supportedTokensName,
      object: nil
    )
    let gasPriceName = Notification.Name(kGasPriceDidUpdateNotificationKey)
    NotificationCenter.default.removeObserver(
      self,
      name: gasPriceName,
      object: nil
    )
  }

  @objc func exchangeRateTokenDidUpdateNotification(_ sender: Any?) {
    if self.session == nil { return }
    guard let loadBalanceCoordinator = self.loadBalanceCoordinator else { return }

    self.balanceTabCoordinator?.appCoordinatorExchangeRateDidUpdate(
      totalBalanceInUSD: loadBalanceCoordinator.totalBalanceInUSD,
      totalBalanceInETH: loadBalanceCoordinator.totalBalanceInETH
    )
    self.exchangeCoordinator?.appCoordinatorUpdateExchangeTokenRates()
  }

  @objc func exchangeRateUSDDidUpdateNotification(_ sender: Notification) {
    if self.session == nil { return }
    guard let loadBalanceCoordinator = self.loadBalanceCoordinator else { return }
    let totalUSD: BigInt = loadBalanceCoordinator.totalBalanceInUSD
    let totalETH: BigInt = loadBalanceCoordinator.totalBalanceInETH

    self.exchangeCoordinator?.appCoordinatorUSDRateDidUpdate(
      totalBalanceInUSD: totalUSD,
      totalBalanceInETH: totalETH
    )
    self.balanceTabCoordinator?.appCoordinatorExchangeRateDidUpdate(
      totalBalanceInUSD: totalUSD,
      totalBalanceInETH: totalETH
    )
    self.settingsCoordinator?.appCoordinatorUSDRateUpdate()
  }

  @objc func ethBalanceDidUpdateNotification(_ sender: Any?) {
    if self.session == nil { return }
    guard let loadBalanceCoordinator = self.loadBalanceCoordinator else { return }
    let totalUSD: BigInt = loadBalanceCoordinator.totalBalanceInUSD
    let totalETH: BigInt = loadBalanceCoordinator.totalBalanceInETH
    let ethBalance: Balance = loadBalanceCoordinator.ethBalance

    self.exchangeCoordinator?.appCoordinatorETHBalanceDidUpdate(
      totalBalanceInUSD: totalUSD,
      totalBalanceInETH: totalETH,
      ethBalance: ethBalance
    )
    self.balanceTabCoordinator?.appCoordinatorETHBalanceDidUpdate(
      totalBalanceInUSD: totalUSD,
      totalBalanceInETH: totalETH,
      ethBalance: ethBalance
    )
    self.settingsCoordinator?.appCoordinatorETHBalanceDidUpdate(ethBalance: ethBalance)
  }

  @objc func tokenBalancesDidUpdateNotification(_ sender: Any?) {
    if self.session == nil { return }
    guard let loadBalanceCoordinator = self.loadBalanceCoordinator else { return }
    let totalUSD: BigInt = loadBalanceCoordinator.totalBalanceInUSD
    let totalETH: BigInt = loadBalanceCoordinator.totalBalanceInETH
    let otherTokensBalance: [String: Balance] = loadBalanceCoordinator.otherTokensBalance

    self.exchangeCoordinator?.appCoordinatorTokenBalancesDidUpdate(
      totalBalanceInUSD: totalUSD,
      totalBalanceInETH: totalETH,
      otherTokensBalance: otherTokensBalance
    )
    self.balanceTabCoordinator?.appCoordinatorTokenBalancesDidUpdate(
      totalBalanceInUSD: totalUSD,
      totalBalanceInETH: totalETH,
      otherTokensBalance: otherTokensBalance
    )
    self.settingsCoordinator?.appCoordinatorTokenBalancesDidUpdate(balances: otherTokensBalance)
  }

  @objc func transactionStateDidUpdate(_ sender: Notification) {
    if self.session == nil { return }
    let transaction: KNTransaction? = {
      if let txHash = sender.object as? String {
        return self.session.transactionStorage.getKyberTransaction(forPrimaryKey: txHash)
      }
      return nil
    }()
    if let error = sender.object as? AnyError {
      KNNotificationUtil.localPushNotification(
        title: NSLocalizedString("failed", value: "Failed", comment: ""),
        body: error.prettyError,
        userInfo: ["transaction_hash": ""]
      )
      self.navigationController.showErrorTopBannerMessage(
        with: NSLocalizedString("failed", value: "Failed", comment: ""),
        message: error.prettyError,
        time: 3.0
      )
      KNCrashlyticsUtil.logCustomEvent(withName: "transaction_update", customAttributes: ["type": "failed"])
      return
    }
    guard let trans = transaction else { return }
    let details = trans.getDetails()
    if trans.state == .pending {
      // just sent
      self.navigationController.showSuccessTopBannerMessage(
        with: NSLocalizedString("broadcasted", value: "Broadcasted", comment: ""),
        message: details,
        time: 3.0
      )
    } else if trans.state == .completed {
      self.navigationController.showSuccessTopBannerMessage(
        with: NSLocalizedString("success", value: "Success", comment: ""),
        message: details,
        time: 3.0
      )
      if self.session != nil {
        self.session.transacionCoordinator?.forceUpdateNewTransactionsWhenPendingTxCompleted()
        self.loadBalanceCoordinator?.forceUpdateBalanceTransactionsCompleted()
      }
      KNNotificationUtil.localPushNotification(
        title: NSLocalizedString("success", value: "Success", comment: ""),
        body: details,
        userInfo: ["transaction_hash": trans.id]
      )
      KNCrashlyticsUtil.logCustomEvent(withName: "transaction_update", customAttributes: ["type": "success"])
    } else if trans.state == .failed || trans.state == .error {
      self.navigationController.showSuccessTopBannerMessage(
        with: NSLocalizedString("failed", value: "Failed", comment: ""),
        message: details,
        time: 3.0
      )
      KNNotificationUtil.localPushNotification(
        title: NSLocalizedString("failed", value: "Failed", comment: ""),
        body: details,
        userInfo: ["transaction_hash": trans.id]
      )
      KNCrashlyticsUtil.logCustomEvent(withName: "transaction_update", customAttributes: ["type": "failed"])
    }
    let transactions = self.session.transactionStorage.kyberPendingTransactions
    self.exchangeCoordinator?.appCoordinatorPendingTransactionsDidUpdate(transactions: transactions)
    self.balanceTabCoordinator?.appCoordinatorPendingTransactionsDidUpdate(transactions: transactions)
  }

  @objc func tokenTransactionListDidUpdate(_ sender: Any?) {
    if self.session == nil { return }
    self.exchangeCoordinator?.appCoordinatorTokensTransactionsDidUpdate()
    self.balanceTabCoordinator?.appCoordinatorTokensTransactionsDidUpdate()
    self.loadBalanceCoordinator?.forceUpdateBalanceTransactionsCompleted()
  }

  @objc func tokenObjectListDidUpdate(_ sender: Any?) {
    if self.session == nil { return }
    self.session.tokenStorage.addKyberSupportedTokens()
    let tokenObjects: [TokenObject] = self.session.tokenStorage.tokens
    self.balanceTabCoordinator?.appCoordinatorTokenObjectListDidUpdate(tokenObjects)
    self.exchangeCoordinator?.appCoordinatorTokenObjectListDidUpdate(tokenObjects)
    self.settingsCoordinator?.appCoordinatorTokenObjectListDidUpdate(tokenObjects)
  }

  @objc func gasPriceCachedDidUpdate(_ sender: Any?) {
    if self.session == nil { return }
    self.exchangeCoordinator?.appCoordinatorGasPriceCachedDidUpdate()
    self.balanceTabCoordinator?.appCoordinatorGasPriceCachedDidUpdate()
  }
}
