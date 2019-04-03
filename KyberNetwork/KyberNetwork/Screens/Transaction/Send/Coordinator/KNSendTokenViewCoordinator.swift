// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import BigInt
import TrustKeystore

class KNSendTokenViewCoordinator: Coordinator {

  let navigationController: UINavigationController
  fileprivate var session: KNSession
  var coordinators: [Coordinator] = []
  var balances: [String: Balance] = [:]
  fileprivate var from: TokenObject

  lazy var rootViewController: KSendTokenViewController = {
    let viewModel = KNSendTokenViewModel(
      from: self.from,
      balances: self.balances
    )
    let controller = KSendTokenViewController(viewModel: viewModel)
    controller.loadViewIfNeeded()
    controller.delegate = self
    return controller
  }()

  fileprivate(set) var searchTokensVC: KNSearchTokenViewController?
  fileprivate(set) var confirmVC: KConfirmSendViewController?

  lazy var addContactVC: KNNewContactViewController = {
    let viewModel: KNNewContactViewModel = KNNewContactViewModel(address: "")
    let controller = KNNewContactViewController(viewModel: viewModel)
    controller.loadViewIfNeeded()
    controller.delegate = self
    return controller
  }()

  init(
    navigationController: UINavigationController,
    session: KNSession,
    balances: [String: Balance],
    from: TokenObject = KNSupportedTokenStorage.shared.ethToken
    ) {
    self.navigationController = navigationController
    self.session = session
    self.balances = balances
    self.from = from
    if self.from.isPromoToken {
      self.from = KNSupportedTokenStorage.shared.ethToken
    }
  }

  func start() {
    self.navigationController.pushViewController(self.rootViewController, animated: true)
    self.rootViewController.coordinatorUpdateBalances(self.balances)

    let isPromo = KNWalletPromoInfoStorage.shared.getDestinationToken(from: self.session.wallet.address.description) != nil
    self.rootViewController.coordinatorUpdateIsPromoWallet(isPromo)
  }

  func stop() {
    self.navigationController.popViewController(animated: true)
  }
}

// MARK: Update from coordinator
extension KNSendTokenViewCoordinator {
  func coordinatorTokenBalancesDidUpdate(balances: [String: Balance]) {
    balances.forEach { self.balances[$0.key] = $0.value }
    self.rootViewController.coordinatorUpdateBalances(self.balances)
    self.searchTokensVC?.updateBalances(self.balances)
  }

  func coordinatorETHBalanceDidUpdate(ethBalance: Balance) {
    let eth = KNSupportedTokenStorage.shared.ethToken
    self.balances[eth.contract] = ethBalance
    self.rootViewController.coordinatorUpdateBalances(self.balances)
    self.searchTokensVC?.updateBalances(self.balances)
  }

  func coordinatorShouldOpenSend(from token: TokenObject) {
    self.rootViewController.coordinatorDidUpdateSendToken(token, balance: self.balances[token.contract])
  }

  func coordinatorTokenObjectListDidUpdate(_ tokenObjects: [TokenObject]) {
    self.searchTokensVC?.updateListSupportedTokens(tokenObjects)
  }

  func coordinatorGasPriceCachedDidUpdate() {
    self.rootViewController.coordinatorUpdateGasPriceCached()
  }

  func coordinatorOpenSendView(to address: String) {
    self.rootViewController.coordinatorSend(to: address)
  }

  func coordinatorDidUpdateTrackerRate() {
    self.rootViewController.coordinatorUpdateTrackerRate()
  }
}

// MARK: Send Token View Controller Delegate
extension KNSendTokenViewCoordinator: KSendTokenViewControllerDelegate {
  func kSendTokenViewController(_ controller: KSendTokenViewController, run event: KSendTokenViewEvent) {
    switch event {
    case .back: self.stop()
    case .setGasPrice:
      break
    case .estimateGas(let transaction):
      self.estimateGasLimit(for: transaction)
    case .searchToken(let selectedToken):
      self.openSearchToken(selectedToken: selectedToken)
    case .send(let transaction):
      self.send(transaction: transaction)
    case .addContact(let address):
      self.openNewContact(address: address)
    case .contactSelectMore:
      self.openListContactsView()
    }
  }

  fileprivate func estimateGasLimit(for transaction: UnconfirmedTransaction) {
    self.session.externalProvider.getEstimateGasLimit(
    for: transaction) { [weak self] result in
      if case .success(let gasLimit) = result {
        self?.rootViewController.coordinatorUpdateEstimatedGasLimit(
          gasLimit,
          from: transaction.transferType.tokenObject(),
          amount: transaction.value
        )
      }
    }
  }

  fileprivate func openSearchToken(selectedToken: TokenObject) {
    let tokens = self.session.tokenStorage.tokens
    self.searchTokensVC = {
      let viewModel = KNSearchTokenViewModel(
        headerColor: KNAppStyleType.current.walletFlowHeaderColor,
        supportedTokens: tokens
      )
      let controller = KNSearchTokenViewController(viewModel: viewModel)
      controller.loadViewIfNeeded()
      controller.delegate = self
      return controller
    }()
    self.navigationController.pushViewController(self.searchTokensVC!, animated: true)
    self.searchTokensVC?.updateBalances(self.balances)
  }

  fileprivate func send(transaction: UnconfirmedTransaction) {
    self.confirmVC = {
      let viewModel = KConfirmSendViewModel(transaction: transaction)
      let controller = KConfirmSendViewController(viewModel: viewModel)
      controller.delegate = self
      controller.loadViewIfNeeded()
      return controller
    }()
    self.navigationController.pushViewController(self.confirmVC!, animated: true)
  }

  fileprivate func openNewContact(address: String) {
    let viewModel: KNNewContactViewModel = KNNewContactViewModel(address: address)
    self.addContactVC.updateView(viewModel: viewModel)
    self.navigationController.pushViewController(self.addContactVC, animated: true)
  }

  fileprivate func openListContactsView() {
    let controller = KNListContactViewController()
    controller.loadViewIfNeeded()
    controller.delegate = self
    self.navigationController.pushViewController(controller, animated: true)
  }
}

// MARK: Search Token Delegate
extension KNSendTokenViewCoordinator: KNSearchTokenViewControllerDelegate {
  func searchTokenViewController(_ controller: KNSearchTokenViewController, run event: KNSearchTokenViewEvent) {
    self.navigationController.popViewController(animated: true) {
      self.searchTokensVC = nil
      if case .select(let token) = event {
        let balance = self.balances[token.contract]
        self.rootViewController.coordinatorDidUpdateSendToken(token, balance: balance)
      }
    }
  }
}

// MARK: Confirm Transaction Delegate
extension KNSendTokenViewCoordinator: KConfirmSendViewControllerDelegate {
  func kConfirmSendViewController(_ controller: KConfirmSendViewController, run event: KConfirmViewEvent) {
    if case .confirm(let type) = event, case .transfer(let transaction) = type {
      self.didConfirmTransfer(transaction)
    } else {
      self.navigationController.popViewController(animated: true) {
        self.confirmVC = nil
      }
    }
  }
}

// MARK: Network requests
extension KNSendTokenViewCoordinator {
  fileprivate func didConfirmTransfer(_ transaction: UnconfirmedTransaction) {
    self.rootViewController.coordinatorSendTokenUserDidConfirmTransaction()
    // send transaction request
    self.session.externalProvider.transfer(transaction: transaction, completion: { [weak self] sendResult in
      guard let `self` = self else { return }
      switch sendResult {
      case .success(let txHash):
        let tx: Transaction = transaction.toTransaction(
          wallet: self.session.wallet,
          hash: txHash,
          nounce: self.session.externalProvider.minTxCount
        )
        self.session.addNewPendingTransaction(tx)
        if self.confirmVC != nil {
          self.navigationController.popViewController(animated: true, completion: {
            self.confirmVC = nil
          })
        }
      case .failure(let error):
        self.confirmVC?.resetActionButtons()
        KNNotificationUtil.postNotification(
          for: kTransactionDidUpdateNotificationKey,
          object: error,
          userInfo: nil
        )
      }
    })
  }
}

extension KNSendTokenViewCoordinator: KNNewContactViewControllerDelegate {
  func newContactViewController(_ controller: KNNewContactViewController, run event: KNNewContactViewEvent) {
    self.navigationController.popViewController(animated: true) {
      if case .send(let address) = event {
        self.rootViewController.coordinatorSend(to: address)
      }
    }
  }
}

extension KNSendTokenViewCoordinator: KNListContactViewControllerDelegate {
  func listContactViewController(_ controller: KNListContactViewController, run event: KNListContactViewEvent) {
    self.navigationController.popViewController(animated: true) {
      if case .select(let contact) = event {
        self.rootViewController.coordinatorDidSelectContact(contact)
      } else if case .send(let address) = event {
        self.rootViewController.coordinatorSend(to: address)
      }
    }
  }
}
