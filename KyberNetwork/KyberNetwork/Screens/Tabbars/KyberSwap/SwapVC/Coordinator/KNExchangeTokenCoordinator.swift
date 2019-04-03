// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import BigInt
import TrustKeystore
import TrustCore
import Result
import Moya

protocol KNExchangeTokenCoordinatorDelegate: class {
  func exchangeTokenCoordinatorDidSelectWallet(_ wallet: KNWalletObject)
  func exchangeTokenCoordinatorRemoveWallet(_ wallet: Wallet)
  func exchangeTokenCoordinatorDidSelectAddWallet()
  func exchangeTokenCoordinatorDidSelectPromoCode()
}

//swiftlint:disable file_length
class KNExchangeTokenCoordinator: Coordinator {

  let navigationController: UINavigationController
  fileprivate(set) var session: KNSession
  var tokens: [TokenObject] = KNSupportedTokenStorage.shared.supportedTokens
  var isSelectingSourceToken: Bool = true

  var coordinators: [Coordinator] = []

  fileprivate var balances: [String: Balance] = [:]
  weak var delegate: KNExchangeTokenCoordinatorDelegate?

  fileprivate var sendTokenCoordinator: KNSendTokenViewCoordinator?
  fileprivate var setGasPriceVC: KNSetGasPriceViewController?
  fileprivate var confirmSwapVC: KConfirmSwapViewController?
  fileprivate var promoConfirmSwapVC: KNPromoSwapConfirmViewController?

  lazy var rootViewController: KSwapViewController = {
    let (from, to): (TokenObject, TokenObject) = {
      let address = self.session.wallet.address.description
      let destToken = KNWalletPromoInfoStorage.shared.getDestinationToken(from: address)
      if let dest = destToken {
        let from = KNSupportedTokenStorage.shared.ptToken
        let to = KNSupportedTokenStorage.shared.supportedTokens.first(where: { $0.symbol == dest.uppercased() }) ?? KNSupportedTokenStorage.shared.ethToken
        return (from, to)
      }
      return (KNSupportedTokenStorage.shared.ethToken, KNSupportedTokenStorage.shared.kncToken)
    }()
    let viewModel = KSwapViewModel(
      wallet: self.session.wallet,
      from: from,
      to: to,
      supportedTokens: tokens
    )
    let controller = KSwapViewController(viewModel: viewModel)
    controller.loadViewIfNeeded()
    controller.delegate = self
    return controller
  }()

  fileprivate var promoCodeCoordinator: KNPromoCodeCoordinator?

  fileprivate var qrcodeCoordinator: KNWalletQRCodeCoordinator? {
    guard let walletObject = KNWalletStorage.shared.get(forPrimaryKey: self.session.wallet.address.description) else { return nil }
    let qrcodeCoordinator = KNWalletQRCodeCoordinator(
      navigationController: self.navigationController,
      walletObject: walletObject
    )
    return qrcodeCoordinator
  }

  fileprivate var historyCoordinator: KNHistoryCoordinator?
  fileprivate var searchTokensViewController: KNSearchTokenViewController?

  init(
    navigationController: UINavigationController = UINavigationController(),
    session: KNSession
    ) {
    self.navigationController = navigationController
    self.navigationController.setNavigationBarHidden(true, animated: false)
    self.session = session
  }

  func start() {
    self.navigationController.viewControllers = [self.rootViewController]
  }

  func stop() {
  }
}

// MARK: Update from app coordinator
extension KNExchangeTokenCoordinator {
  func appCoordinatorDidUpdateNewSession(_ session: KNSession, resetRoot: Bool = false) {
    self.session = session
    self.rootViewController.coordinatorUpdateNewSession(wallet: session.wallet)
    let pendingTrans = self.session.transactionStorage.kyberPendingTransactions
    self.rootViewController.coordinatorDidUpdatePendingTransactions(pendingTrans)
    self.historyCoordinator = nil
    self.historyCoordinator = KNHistoryCoordinator(
      navigationController: self.navigationController,
      session: self.session
    )
    self.historyCoordinator?.delegate = self
    self.historyCoordinator?.appCoordinatorPendingTransactionDidUpdate(pendingTrans)
    if resetRoot {
      self.navigationController.popToRootViewController(animated: false)
    }
  }

  func appCoordinatorDidUpdateWalletObjects() {
    self.rootViewController.coordinatorUpdateWalletObjects()
    self.historyCoordinator?.appCoordinatorDidUpdateWalletObjects()
  }

  func appCoordinatorTokenBalancesDidUpdate(totalBalanceInUSD: BigInt, totalBalanceInETH: BigInt, otherTokensBalance: [String: Balance]) {
    self.rootViewController.coordinatorUpdateTokenBalance(otherTokensBalance)
    otherTokensBalance.forEach { self.balances[$0.key] = $0.value }
    self.sendTokenCoordinator?.coordinatorTokenBalancesDidUpdate(balances: self.balances)
    self.searchTokensViewController?.updateBalances(otherTokensBalance)
  }

  func appCoordinatorETHBalanceDidUpdate(totalBalanceInUSD: BigInt, totalBalanceInETH: BigInt, ethBalance: Balance) {
    if let eth = self.tokens.first(where: { $0.isETH }) {
      self.balances[eth.contract] = ethBalance
      self.searchTokensViewController?.updateBalances([eth.contract: ethBalance])
      self.rootViewController.coordinatorUpdateTokenBalance([eth.contract: ethBalance])
    }
    self.sendTokenCoordinator?.coordinatorETHBalanceDidUpdate(ethBalance: ethBalance)
  }

  func appCoordinatorUSDRateDidUpdate(totalBalanceInUSD: BigInt, totalBalanceInETH: BigInt) {
    self.rootViewController.coordinatorTrackerRateDidUpdate()
    self.sendTokenCoordinator?.coordinatorDidUpdateTrackerRate()
    self.confirmSwapVC?.coordinatorUpdateCurrentMarketRate()
  }

  func appCoordinatorShouldOpenExchangeForToken(_ token: TokenObject, isReceived: Bool = false) {
    self.navigationController.popToRootViewController(animated: true)
    self.rootViewController.coordinatorUpdateSelectedToken(token, isSource: !isReceived)
    self.rootViewController.tabBarController?.selectedIndex = 1
  }

  func appCoordinatorTokenObjectListDidUpdate(_ tokenObjects: [TokenObject]) {
    let supportedTokens = KNSupportedTokenStorage.shared.supportedTokens
    self.tokens = supportedTokens
    self.sendTokenCoordinator?.coordinatorTokenObjectListDidUpdate(tokenObjects)
    self.searchTokensViewController?.updateListSupportedTokens(supportedTokens)
  }

  func appCoordinatorPendingTransactionsDidUpdate(transactions: [KNTransaction]) {
    self.rootViewController.coordinatorDidUpdatePendingTransactions(transactions)
    self.historyCoordinator?.appCoordinatorPendingTransactionDidUpdate(transactions)
  }

  func appCoordinatorGasPriceCachedDidUpdate() {
    self.rootViewController.coordinatorUpdateGasPriceCached()
    self.sendTokenCoordinator?.coordinatorGasPriceCachedDidUpdate()
  }

  func appCoordinatorTokensTransactionsDidUpdate() {
    self.historyCoordinator?.appCoordinatorTokensTransactionsDidUpdate()
  }

  func appCoordinatorPushNotificationOpenSwap(from: String, to: String) {
    guard let from = self.session.tokenStorage.tokens.first(where: { return $0.symbol == from }),
      let to = self.session.tokenStorage.tokens.first(where: { return $0.symbol == to }) else { return }
    self.navigationController.popToRootViewController(animated: false)
    self.rootViewController.coordinatorUpdateSelectedToken(from, isSource: true)
    self.rootViewController.coordinatorUpdateSelectedToken(to, isSource: false)
  }
}

// MARK: Network requests
extension KNExchangeTokenCoordinator {
  fileprivate func didConfirmSendExchangeTransaction(_ exchangeTransaction: KNDraftExchangeTransaction) {
    self.rootViewController.coordinatorExchangeTokenUserDidConfirmTransaction()
    KNNotificationUtil.postNotification(for: kTransactionDidUpdateNotificationKey)
    self.session.externalProvider.getAllowance(token: exchangeTransaction.from) { [weak self] getAllowanceResult in
      guard let `self` = self else { return }
      switch getAllowanceResult {
      case .success(let res):
        if res >= exchangeTransaction.amount {
          self.sendExchangeTransaction(exchangeTransaction)
        } else {
          self.sendApproveForExchangeTransaction(exchangeTransaction, remain: res)
        }
      case .failure(let error):
        self.confirmSwapVC?.resetActionButtons()
        self.promoConfirmSwapVC?.resetActionButtons()
        KNNotificationUtil.postNotification(
          for: kTransactionDidUpdateNotificationKey,
          object: error,
          userInfo: nil
        )
      }
    }
  }

  fileprivate func sendExchangeTransaction(_ exchage: KNDraftExchangeTransaction) {
    self.session.externalProvider.exchange(exchange: exchage) { [weak self] result in
      guard let `self` = self else { return }
      switch result {
      case .success(let txHash):
        let transaction = exchage.toTransaction(
          hash: txHash,
          fromAddr: self.session.wallet.address,
          toAddr: self.session.externalProvider.networkAddress,
          nounce: self.session.externalProvider.minTxCount
        )
        self.session.addNewPendingTransaction(transaction)
        if KNWalletPromoInfoStorage.shared.getDestinationToken(from: self.session.wallet.address.description) == nil {
          if self.confirmSwapVC != nil {
            self.navigationController.popViewController(animated: true, completion: {
              self.confirmSwapVC = nil
            })
          }
        } else {
          // promo code
          if self.promoConfirmSwapVC != nil {
            self.navigationController.popViewController(animated: true, completion: {
              self.promoConfirmSwapVC = nil
            })
          }
        }
      case .failure(let error):
        self.confirmSwapVC?.resetActionButtons()
        KNNotificationUtil.postNotification(
          for: kTransactionDidUpdateNotificationKey,
          object: error,
          userInfo: nil
        )
      }
    }
  }

  fileprivate func sendApproveForExchangeTransaction(_ exchangeTransaction: KNDraftExchangeTransaction, remain: BigInt) {
    self.resetAllowanceForExchangeTransactionIfNeeded(exchangeTransaction, remain: remain) { [weak self] resetResult in
      guard let `self` = self else { return }
      switch resetResult {
      case .success:
        self.session.externalProvider.sendApproveERC20Token(exchangeTransaction: exchangeTransaction) { [weak self] result in
          switch result {
          case .success:
            self?.sendExchangeTransaction(exchangeTransaction)
          case .failure(let error):
            self?.confirmSwapVC?.resetActionButtons()
            KNNotificationUtil.postNotification(
              for: kTransactionDidUpdateNotificationKey,
              object: error,
              userInfo: nil
            )
          }
        }
      case .failure(let error):
        self.confirmSwapVC?.resetActionButtons()
        KNNotificationUtil.postNotification(
          for: kTransactionDidUpdateNotificationKey,
          object: error,
          userInfo: nil
        )
      }
    }
  }

  fileprivate func resetAllowanceForExchangeTransactionIfNeeded(_ exchangeTransaction: KNDraftExchangeTransaction, remain: BigInt, completion: @escaping (Result<Bool, AnyError>) -> Void) {
    if remain.isZero {
      completion(.success(true))
      return
    }
    self.session.externalProvider.sendApproveERCToken(for: exchangeTransaction.from, value: BigInt(0)) { result in
      switch result {
      case .success:
        completion(.success(true))
      case .failure(let error):
        completion(.failure(error))
      }
    }
  }
}

// MARK: Promo Confirm transaction
extension KNExchangeTokenCoordinator: KNPromoSwapConfirmViewControllerDelegate {
  func promoCodeSwapConfirmViewControllerDidBack() {
    self.navigationController.popViewController(animated: true) {
      self.promoConfirmSwapVC = nil
    }
  }

  func promoCodeSwapConfirmViewController(_ controller: KNPromoSwapConfirmViewController, transaction: KNDraftExchangeTransaction, destAddress: String) {
    self.didConfirmSendExchangeTransaction(transaction)
  }
}

// MARK: Confirm transaction
extension KNExchangeTokenCoordinator: KConfirmSwapViewControllerDelegate {
  func kConfirmSwapViewController(_ controller: KConfirmSwapViewController, run event: KConfirmViewEvent) {
    if case .confirm(let type) = event, case .exchange(let exchangeTransaction) = type {
      self.didConfirmSendExchangeTransaction(exchangeTransaction)
    } else {
      self.navigationController.popViewController(animated: true) {
        self.confirmSwapVC = nil
      }
    }
  }
}

// MARK: Swap view delegation
extension KNExchangeTokenCoordinator: KSwapViewControllerDelegate {
  func kSwapViewController(_ controller: KSwapViewController, run event: KSwapViewEvent) {
    switch event {
    case .searchToken(let from, let to, let isSource):
      self.openSearchToken(from: from, to: to, isSource: isSource)
    case .estimateRate(let from, let to, let amount, let showError):
      self.updateEstimatedRate(from: from, to: to, amount: amount, showError: showError)
    case .estimateGas(let from, let to, let amount, let gasPrice):
      self.updateEstimatedGasLimit(from: from, to: to, amount: amount, gasPrice: gasPrice)
    case .getUserCapInWei:
      self.updateUserCapInWei()
    case .showQRCode:
      self.showWalletQRCode()
    case .setGasPrice(let gasPrice, let gasLimit):
      self.openSetGasPrice(gasPrice: gasPrice, estGasLimit: gasLimit)
    case .validateRate(let data):
      self.validateRateBeforeSwapping(data: data)
    case .swap(let data):
      self.exchangeButtonPressed(data: data)
    }
  }

  func kSwapViewController(_ controller: KSwapViewController, run event: KNBalanceTabHamburgerMenuViewEvent) {
    switch event {
    case .selectSendToken:
      self.openSendTokenView()
    case .selectAddWallet:
      self.openAddWalletView()
    case .select(let wallet):
      self.updateCurrentWallet(wallet)
    case .selectAllTransactions:
      self.historyCoordinator = nil
      self.historyCoordinator = KNHistoryCoordinator(
        navigationController: self.navigationController,
        session: self.session
      )
      self.historyCoordinator?.delegate = self
      self.historyCoordinator?.appCoordinatorDidUpdateNewSession(self.session)
      self.historyCoordinator?.start()
    case .selectPromoCode:
      self.openPromoCodeView()
    }
  }

  fileprivate func openSearchToken(from: TokenObject, to: TokenObject, isSource: Bool) {
    self.isSelectingSourceToken = isSource
    self.tokens = KNSupportedTokenStorage.shared.supportedTokens
    self.searchTokensViewController = {
      let viewModel = KNSearchTokenViewModel(
        headerColor: KNAppStyleType.current.swapHeaderBackgroundColor,
        supportedTokens: self.tokens
      )
      let controller = KNSearchTokenViewController(viewModel: viewModel)
      controller.loadViewIfNeeded()
      controller.delegate = self
      return controller
    }()
    self.navigationController.pushViewController(self.searchTokensViewController!, animated: true)
    self.searchTokensViewController?.updateBalances(self.balances)
  }

  fileprivate func validateRateBeforeSwapping(data: KNDraftExchangeTransaction) {
    self.navigationController.displayLoading(text: NSLocalizedString("checking", value: "Checking", comment: ""), animated: true)
    let address = self.session.wallet.address.description
    var errorMessage: String?
    let group = DispatchGroup()
    group.enter()
    self.updateEstimatedRate(from: data.from, to: data.to, amount: data.amount, showError: false) { error in
      if let err = error { errorMessage = err.prettyError }
      group.leave()
    }
    if KNEnvironment.default.isMainnet {
      group.enter()
      DispatchQueue.global(qos: .background).async {
        let provider = MoyaProvider<KNTrackerService>()
        provider.request(.getUserTradable(address: address)) { result in
          if case .success(let resp) = result,
            let json = try? resp.mapJSON() as? JSONDictionary ?? [:] {
            let data = json["data"] as? Bool ?? false
            if data {
              errorMessage = NSLocalizedString("your.cap.has.reached.increase.by.completing.kyc", value: "Your cap has reached. Increase your cap by completing KYC.", comment: "")
            }
          }
          group.leave()
        }
      }
    }
    group.notify(queue: .main) {
      self.navigationController.hideLoading()
      if let message = errorMessage {
        self.navigationController.showErrorTopBannerMessage(
          with: NSLocalizedString("error", value: "Error", comment: ""),
          message: message,
          time: 1.5
        )
      } else {
        self.rootViewController.coordinatorDidValidateRate()
      }
    }
  }

  fileprivate func exchangeButtonPressed(data: KNDraftExchangeTransaction) {
    if KNWalletPromoInfoStorage.shared.getDestinationToken(from: self.session.wallet.address.description) != nil {
      let address = self.session.wallet.address.description
      // promo code wallet
      let destWallet = KNWalletPromoInfoStorage.shared.getDestWallet(from: address) ?? address
      let expiredDate: Date = {
        let time = KNWalletPromoInfoStorage.shared.getExpiredTime(from: address) ?? 0.0
        return Date(timeIntervalSince1970: time)
      }()
      let viewModel = KNPromoSwapConfirmViewModel(
        transaction: data,
        srcWallet: self.session.wallet.address.description,
        destWallet: destWallet,
        expiredDate: expiredDate
      )
      self.promoConfirmSwapVC = KNPromoSwapConfirmViewController(viewModel: viewModel)
      self.promoConfirmSwapVC?.loadViewIfNeeded()
      self.promoConfirmSwapVC?.delegate = self
      self.navigationController.pushViewController(self.promoConfirmSwapVC!, animated: true)
    } else {
      self.confirmSwapVC = {
        let viewModel = KConfirmSwapViewModel(transaction: data)
        let controller = KConfirmSwapViewController(viewModel: viewModel)
        controller.loadViewIfNeeded()
        controller.delegate = self
        return controller
      }()
      self.navigationController.pushViewController(self.confirmSwapVC!, animated: true)
    }
  }

  fileprivate func updateEstimatedRate(from: TokenObject, to: TokenObject, amount: BigInt, showError: Bool, completion: ((Error?) -> Void)? = nil) {
    if from == to {
      let rate = BigInt(10).power(from.decimals)
      self.rootViewController.coordinatorDidUpdateEstimateRate(
        from: from,
        to: to,
        amount: amount,
        rate: rate,
        slippageRate: rate * BigInt(97) / BigInt(100)
      )
      completion?(nil)
      return
    }
    self.session.externalProvider.getExpectedRate(
      from: from,
      to: to,
      amount: amount) { [weak self] (result) in
        var estRate: BigInt = BigInt(0)
        var slippageRate: BigInt = BigInt(0)
        switch result {
        case .success(let data):
          estRate = data.0
          slippageRate = data.1
          estRate /= BigInt(10).power(18 - to.decimals)
          slippageRate /= BigInt(10).power(18 - to.decimals)
          self?.rootViewController.coordinatorDidUpdateEstimateRate(
            from: from,
            to: to,
            amount: amount,
            rate: estRate,
            slippageRate: slippageRate
          )
          completion?(nil)
        case .failure(let error):
          if showError {
            self?.navigationController.showErrorTopBannerMessage(
              with: NSLocalizedString("error", value: "Error", comment: ""),
              message: NSLocalizedString("can.not.update.exchange.rate", comment: "Can not update exchange rate"),
              time: 1.5
            )
            self?.rootViewController.coordinatorDidUpdateEstimateRate(
              from: from,
              to: to,
              amount: amount,
              rate: BigInt(0),
              slippageRate: BigInt(0)
            )
          }
          completion?(error)
        }
    }
  }

  func updateEstimatedGasLimit(from: TokenObject, to: TokenObject, amount: BigInt, gasPrice: BigInt) {
    let exchangeTx = KNDraftExchangeTransaction(
      from: from,
      to: to,
      amount: amount,
      maxDestAmount: BigInt(2).power(255),
      expectedRate: BigInt(0),
      minRate: .none,
      gasPrice: gasPrice,
      gasLimit: .none,
      expectedReceivedString: nil
    )
    self.session.externalProvider.getEstimateGasLimit(for: exchangeTx) { [weak self] result in
      if case .success(let estimate) = result {
        self?.rootViewController.coordinatorDidUpdateEstimateGasUsed(
          from: from,
          to: to,
          amount: amount,
          gasLimit: estimate
        )
      }
    }
  }

  fileprivate func updateUserCapInWei() {
    if !KNEnvironment.default.isMainnet { return }
    let address = self.session.wallet.address.description
    DispatchQueue.global(qos: .background).async {
      let provider = MoyaProvider<KNTrackerService>()
      provider.request(.getUserCap(address: address.lowercased())) { result in
        DispatchQueue.main.async {
          if case .success(let resp) = result,
            let json = try? resp.mapJSON() as? JSONDictionary ?? [:],
            let capData = json["data"] as? JSONDictionary,
            let capTx = capData["TxLimit"] as? Double {
            if let rateUSD = KNTrackerRateStorage.shared.trackerRate(for: KNSupportedTokenStorage.shared.ethToken)?.rateUSDBigInt, rateUSD != 0 {
              let cap = BigInt(capTx) * BigInt(10).power(36) / rateUSD
              self.rootViewController.coordinatorUpdateUserCapInWei(cap: cap)
            }
          }
        }
      }
    }
  }

  fileprivate func showWalletQRCode() {
    self.qrcodeCoordinator?.start()
  }

  fileprivate func openSetGasPrice(gasPrice: BigInt, estGasLimit: BigInt) {
    let setGasPriceVC: KNSetGasPriceViewController = {
      let viewModel = KNSetGasPriceViewModel(gasPrice: gasPrice, estGasLimit: estGasLimit)
      let controller = KNSetGasPriceViewController(viewModel: viewModel)
      controller.loadViewIfNeeded()
      controller.delegate = self
      return controller
    }()
    self.setGasPriceVC = setGasPriceVC
    self.navigationController.pushViewController(setGasPriceVC, animated: true)
  }

  fileprivate func openSendTokenView() {
    self.sendTokenCoordinator = KNSendTokenViewCoordinator(
      navigationController: self.navigationController,
      session: self.session,
      balances: self.balances,
      from: self.session.tokenStorage.ethToken
    )
    self.sendTokenCoordinator?.start()
  }

  fileprivate func openPromoCodeView() {
    self.delegate?.exchangeTokenCoordinatorDidSelectPromoCode()
  }

  fileprivate func openAddWalletView() {
    self.delegate?.exchangeTokenCoordinatorDidSelectAddWallet()
  }

  fileprivate func updateCurrentWallet(_ wallet: KNWalletObject) {
    self.delegate?.exchangeTokenCoordinatorDidSelectWallet(wallet)
  }
}

// MARK: Search token
extension KNExchangeTokenCoordinator: KNSearchTokenViewControllerDelegate {
  func searchTokenViewController(_ controller: KNSearchTokenViewController, run event: KNSearchTokenViewEvent) {
    self.navigationController.popViewController(animated: true) {
      self.searchTokensViewController = nil
      if case .select(let token) = event {
        self.rootViewController.coordinatorUpdateSelectedToken(
          token,
          isSource: self.isSelectingSourceToken
        )
      }
    }
  }
}

// MARK: Set gas price
extension KNExchangeTokenCoordinator: KNSetGasPriceViewControllerDelegate {
  func setGasPriceViewControllerDidReturn(gasPrice: BigInt?) {
    self.navigationController.popViewController(animated: true) {
      self.setGasPriceVC = nil
      self.rootViewController.coordinatorExchangeTokenDidUpdateGasPrice(gasPrice)
    }
  }
}

// MARK: Add new wallet delegate
extension KNExchangeTokenCoordinator: KNAddNewWalletCoordinatorDelegate {
  func addNewWalletCoordinator(add wallet: Wallet) {
    let address = wallet.address.description
    let walletObject = KNWalletStorage.shared.get(forPrimaryKey: address) ?? KNWalletObject(address: address)
    self.delegate?.exchangeTokenCoordinatorDidSelectWallet(walletObject)
  }

  func addNewWalletCoordinator(remove wallet: Wallet) {
    self.delegate?.exchangeTokenCoordinatorRemoveWallet(wallet)
  }
}

extension KNExchangeTokenCoordinator: KNHistoryCoordinatorDelegate {
  func historyCoordinatorDidClose() {
    self.historyCoordinator = nil
  }
}
