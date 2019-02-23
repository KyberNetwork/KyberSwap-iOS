// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import Crashlytics

protocol KNSettingsCoordinatorDelegate: class {
  func settingsCoordinatorUserDidSelectNewWallet(_ wallet: Wallet)
  func settingsCoordinatorUserDidSelectExit()
  func settingsCoordinatorUserDidRemoveWallet(_ wallet: Wallet)
  func settingsCoordinatorUserDidUpdateWalletObjects()
  func settingsCoordinatorUserDidSelectAddWallet()
}

class KNSettingsCoordinator: Coordinator {

  var coordinators: [Coordinator] = []
  let navigationController: UINavigationController
  private(set) var session: KNSession
  fileprivate(set) var balances: [String: Balance] = [:]

  weak var delegate: KNSettingsCoordinatorDelegate?

  lazy var rootViewController: KNSettingsTabViewController = {
    let controller = KNSettingsTabViewController()
    controller.loadViewIfNeeded()
    controller.delegate = self
    return controller
  }()

  lazy var listWalletsCoordinator: KNListWalletsCoordinator = {
    return KNListWalletsCoordinator(
      navigationController: self.navigationController,
      session: self.session,
      delegate: self
    )
  }()

  lazy var contactVC: KNListContactViewController = {
    let controller = KNListContactViewController()
    controller.loadViewIfNeeded()
    controller.delegate = self
    return controller
  }()

  lazy var passcodeCoordinator: KNPasscodeCoordinator = {
    let coordinator = KNPasscodeCoordinator(
      navigationController: self.navigationController,
      type: .setPasscode(cancellable: true)
    )
    coordinator.delegate = self
    return coordinator
  }()

  fileprivate var sendTokenCoordinator: KNSendTokenViewCoordinator?

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

  func appCoordinatorDidUpdateNewSession(_ session: KNSession, resetRoot: Bool = false) {
    self.session = session
    if resetRoot {
      self.navigationController.popToRootViewController(animated: true)
    }
    self.listWalletsCoordinator.updateNewSession(self.session)
  }

  func appCoordinatorTokenBalancesDidUpdate(balances: [String: Balance]) {
    balances.forEach { self.balances[$0.key] = $0.value }
    self.sendTokenCoordinator?.coordinatorTokenBalancesDidUpdate(balances: balances)
  }

  func appCoordinatorETHBalanceDidUpdate(ethBalance: Balance) {
    let eth = KNSupportedTokenStorage.shared.ethToken
    self.balances[eth.contract] = ethBalance
    self.sendTokenCoordinator?.coordinatorETHBalanceDidUpdate(ethBalance: ethBalance)
  }

  func appCoordinatorUSDRateUpdate() {
    self.sendTokenCoordinator?.coordinatorDidUpdateTrackerRate()
  }

  func appCoordinatorTokenObjectListDidUpdate(_ tokenObjects: [TokenObject]) {
    self.sendTokenCoordinator?.coordinatorTokenObjectListDidUpdate(tokenObjects)
  }
}

extension KNSettingsCoordinator: KNSettingsTabViewControllerDelegate {
  func settingsTabViewController(_ controller: KNSettingsTabViewController, run event: KNSettingsTabViewEvent) {
    switch event {
    case .manageWallet:
      KNCrashlyticsUtil.logCustomEvent(withName: "settings", customAttributes: ["value": "manage_wallet"])
      self.settingsViewControllerWalletsButtonPressed()
    case .contact:
      KNCrashlyticsUtil.logCustomEvent(withName: "settings", customAttributes: ["value": "contact"])
      self.navigationController.pushViewController(self.contactVC, animated: true)
    case .support:
      KNCrashlyticsUtil.logCustomEvent(withName: "settings", customAttributes: ["value": "support"])
      self.navigationController.openSafari(with: "https://docs.google.com/forms/d/1Ik-H0nN8qKpi90NVTCwwDzopId7C8mX_HOPeT5iBLhc/viewform?edit_requested=true")
    case .about:
      KNCrashlyticsUtil.logCustomEvent(withName: "settings", customAttributes: ["value": "about"])
      self.openCommunityURL("https://kyber.network/about/company")
    case .changePIN:
      KNCrashlyticsUtil.logCustomEvent(withName: "settings", customAttributes: ["value": "change_pin"])
      self.passcodeCoordinator = KNPasscodeCoordinator(
        navigationController: self.navigationController,
        type: .authenticate(isUpdating: true)
      )
      self.passcodeCoordinator.delegate = self
      self.passcodeCoordinator.start()
    case .community:
      KNCrashlyticsUtil.logCustomEvent(withName: "settings", customAttributes: ["value": "community"])
      let url = KNAppTracker.getKyberProfileBaseString() + "/community"
      self.openCommunityURL(url)
    case .shareWithFriends:
      KNCrashlyticsUtil.logCustomEvent(withName: "settings", customAttributes: ["value": "share_with_friends"])
      self.openShareWithFriends()
    case .telegram:
      KNCrashlyticsUtil.logCustomEvent(withName: "settings", customAttributes: ["value": "open_telegram"])
      self.openCommunityURL("https://t.me/kybernetwork")
    case .telegramDev:
      KNCrashlyticsUtil.logCustomEvent(withName: "settings", customAttributes: ["value": "open_telegram_dev"])
      self.openCommunityURL("https://t.me/KyberDeveloper")
    case .github:
      KNCrashlyticsUtil.logCustomEvent(withName: "settings", customAttributes: ["value": "open_github"])
      self.openCommunityURL("https://github.com/KyberNetwork/KyberSwap")
    case .twitter:
      KNCrashlyticsUtil.logCustomEvent(withName: "settings", customAttributes: ["value": "open_twitter"])
      self.openCommunityURL("https://twitter.com/KyberSwap")
    case .facebook:
      KNCrashlyticsUtil.logCustomEvent(withName: "settings", customAttributes: ["value": "open_facebook"])
      self.openCommunityURL("https://www.facebook.com/kybernetwork")
    case .medium:
      KNCrashlyticsUtil.logCustomEvent(withName: "settings", customAttributes: ["value": "open_medium"])
      self.openCommunityURL("https://medium.com/@kyberswap")
    case .reddit:
      KNCrashlyticsUtil.logCustomEvent(withName: "settings", customAttributes: ["value": "open_reddit"])
      self.openCommunityURL("https://www.reddit.com/r/kybernetwork")
    case .linkedIn:
      KNCrashlyticsUtil.logCustomEvent(withName: "settings", customAttributes: ["value": "open_linked_in"])
      self.openCommunityURL("https://www.linkedin.com/company/kybernetwork")
    case .reportBugs:
      KNCrashlyticsUtil.logCustomEvent(withName: "settings", customAttributes: ["value": "report_bugs"])
      self.navigationController.openSafari(with: "https://goo.gl/forms/ZarhiV7MPE0mqr712")
    case .rateOurApp:
      KNCrashlyticsUtil.logCustomEvent(withName: "settings", customAttributes: ["value": "rate_our_app"])
      self.navigationController.openSafari(with: "https://goo.gl/forms/RkvyT7MpTYV93gV02")
    }
  }

  fileprivate func openCommunityURL(_ url: String) {
    self.navigationController.openSafari(with: url)
  }

  fileprivate func openShareWithFriends() {
    let text = NSLocalizedString(
      "share.with.friends.text",
      value: "I just found an awesome wallet app. Check out here https://kyberswap.com",
      comment: ""
    )
    let activitiy = UIActivityViewController(activityItems: [text], applicationActivities: nil)
    activitiy.title = NSLocalizedString("share.with.friends", value: "Share with friends", comment: "")
    activitiy.popoverPresentationController?.sourceView = self.rootViewController.shareWithFriendsButton
    self.navigationController.present(activitiy, animated: true, completion: nil)
  }

  func settingsViewControllerDidClickExit() {
    self.delegate?.settingsCoordinatorUserDidSelectExit()
  }

  func settingsViewControllerWalletsButtonPressed() {
    self.listWalletsCoordinator.start()
  }

  func settingsViewControllerPasscodeDidChange(_ isOn: Bool) {
    if isOn {
      self.passcodeCoordinator.start()
    } else {
      KNPasscodeUtil.shared.deletePasscode()
    }
  }

  func settingsViewControllerOpenDebug() {
    let debugVC = KNDebugMenuViewController()
    self.navigationController.present(debugVC, animated: true, completion: nil)
  }

  func settingsViewControllerBackUpButtonPressed(wallet: KNWalletObject) {
    guard let wallet = self.session.keystore.wallets.first(where: { $0.address.description.lowercased() == wallet.address.lowercased() }) else { return }
    let alertController = UIAlertController(
      title: NSLocalizedString("export.at.your.own.risk", value: "Export at your own risk!", comment: ""),
      message: nil,
      preferredStyle: .actionSheet
    )
    alertController.addAction(UIAlertAction(
      title: NSLocalizedString("backup.keystore", value: "Backup Keystore", comment: ""),
      style: .default,
      handler: { _ in
      self.backupKeystore(wallet: wallet)
      }
    ))
    alertController.addAction(UIAlertAction(
      title: NSLocalizedString("backup.private.key", value: "Backup Private Key", comment: ""),
      style: .default,
      handler: { _ in
      self.backupPrivateKey(wallet: wallet)
      }
    ))
    if case .real(let account) = wallet.type, case .success = self.session.keystore.exportMnemonics(account: account) {
      alertController.addAction(UIAlertAction(
        title: NSLocalizedString("backup.mnemonic", value: "Backup Mnemonic", comment: ""),
        style: .default,
        handler: { _ in
          self.backupMnemonic(wallet: wallet)
        }
      ))
    }
    alertController.addAction(UIAlertAction(
      title: NSLocalizedString("copy.address", value: "Copy Address", comment: ""),
      style: .default,
      handler: { _ in
      self.copyAddress(wallet: wallet)
      }
    ))
    alertController.addAction(UIAlertAction(
      title: NSLocalizedString("cancel", value: "Cancel", comment: ""),
      style: .cancel,
      handler: nil)
    )
    self.navigationController.topViewController?.present(alertController, animated: true, completion: nil)
  }

  fileprivate func backupKeystore(wallet: Wallet) {
    KNCrashlyticsUtil.logCustomEvent(withName: "edit_wallet", customAttributes: ["type": "show_back_up_keystore"])
    let createPassword = KNCreatePasswordViewController(delegate: self)
    createPassword.modalPresentationStyle = .overCurrentContext
    createPassword.modalTransitionStyle = .crossDissolve
    self.navigationController.topViewController?.present(createPassword, animated: true, completion: nil)
  }

  fileprivate func backupPrivateKey(wallet: Wallet) {
    KNCrashlyticsUtil.logCustomEvent(withName: "edit_wallet", customAttributes: ["type": "show_back_up_private_key"])
    if case .real(let account) = wallet.type {
      let result = self.session.keystore.exportPrivateKey(account: account)
      switch result {
      case .success(let data):
        self.openShowBackUpView(data: data.hexString)
      case .failure(let error):
        self.navigationController.topViewController?.displayError(error: error)
      }
    }
  }

  fileprivate func backupMnemonic(wallet: Wallet) {
    KNCrashlyticsUtil.logCustomEvent(withName: "edit_wallet", customAttributes: ["type": "show_back_up_mnemonic"])
    if case .real(let account) = wallet.type {
      let result = self.session.keystore.exportMnemonics(account: account)
      switch result {
      case .success(let data):
        self.openShowBackUpView(data: data)
      case .failure(let error):
        self.navigationController.topViewController?.displayError(error: error)
      }
    }
  }

  fileprivate func openShowBackUpView(data: String) {
    let showBackUpVC = KNShowBackUpDataViewController(
      wallet: self.session.wallet.address.description,
      backupData: data
    )
    showBackUpVC.loadViewIfNeeded()
    self.navigationController.pushViewController(showBackUpVC, animated: true)
  }

  fileprivate func copyAddress(wallet: Wallet) {
    KNCrashlyticsUtil.logCustomEvent(withName: "edit_wallet", customAttributes: ["type": "show_back_up_copy_address"])
    UIPasteboard.general.string = wallet.address.description
  }

  fileprivate func exportDataString(_ value: String) {
    let dateFormatter: DateFormatter = {
      let formatter = DateFormatter()
      formatter.dateFormat = "yyyy-MM-dd_HH:mm"
      return formatter
    }()
    let fileName = "kyberswap_backup_\(self.session.wallet.address.description)_\(dateFormatter.string(from: Date())).json"
    let url = URL(fileURLWithPath: NSTemporaryDirectory().appending(fileName))
    do {
      try value.data(using: .utf8)!.write(to: url)
    } catch { return }

    let activityViewController = UIActivityViewController(
      activityItems: [url],
      applicationActivities: nil
    )
    activityViewController.completionWithItemsHandler = { _, result, _, error in
      do { try FileManager.default.removeItem(at: url)
      } catch { }
    }
    activityViewController.popoverPresentationController?.sourceView = navigationController.view
    activityViewController.popoverPresentationController?.sourceRect = navigationController.view.centerRect
    self.navigationController.topViewController?.present(activityViewController, animated: true, completion: nil)
  }
}

extension KNSettingsCoordinator: KNCreatePasswordViewControllerDelegate {
  func createPasswordUserDidFinish(_ password: String) {
    if case .real(let account) = self.session.wallet.type {
      if let currentPassword = self.session.keystore.getPassword(for: account) {
        self.navigationController.topViewController?.displayLoading(text: "\(NSLocalizedString("preparing.data", value: "Preparing data", comment: ""))...", animated: true)
        self.session.keystore.export(account: account, password: currentPassword, newPassword: password, completion: { [weak self] result in
          self?.navigationController.topViewController?.hideLoading()
          switch result {
          case .success(let value):
            self?.exportDataString(value)
          case .failure(let error):
            self?.navigationController.topViewController?.displayError(error: error)
          }
        })
      }
    }
  }

  func createPasswordDidCancel(sender: KNCreatePasswordViewController) {
    sender.dismiss(animated: true, completion: nil)
  }
}

extension KNSettingsCoordinator: KNListContactViewControllerDelegate {
  func listContactViewController(_ controller: KNListContactViewController, run event: KNListContactViewEvent) {
    switch event {
    case .back:
      self.navigationController.popViewController(animated: true)
    case .send(let address):
      self.openSendToken(address: address)
    case .select(let contact):
      self.openNewContact(address: contact.address)
    }
  }

  fileprivate func openNewContact(address: String) {
    let viewModel = KNNewContactViewModel(address: address)
    let controller = KNNewContactViewController(viewModel: viewModel)
    controller.loadViewIfNeeded()
    controller.delegate = self
    self.navigationController.pushViewController(controller, animated: true)
  }

  fileprivate func openSendToken(address: String) {
    self.sendTokenCoordinator = KNSendTokenViewCoordinator(
      navigationController: self.navigationController,
      session: self.session,
      balances: self.balances,
      from: self.session.tokenStorage.ethToken
    )
    self.sendTokenCoordinator?.start()
    self.sendTokenCoordinator?.coordinatorOpenSendView(to: address)
  }
}

extension KNSettingsCoordinator: KNNewContactViewControllerDelegate {
  func newContactViewController(_ controller: KNNewContactViewController, run event: KNNewContactViewEvent) {
    switch event {
    case .dismiss: self.navigationController.popViewController(animated: true)
    case .send(let address):
      self.openSendToken(address: address)
    }
  }
}

extension KNSettingsCoordinator: KNPasscodeCoordinatorDelegate {
  func passcodeCoordinatorDidCreatePasscode() {
    self.passcodeCoordinator.stop {
      self.navigationController.showSuccessTopBannerMessage(
        with: NSLocalizedString("success", value: "Success", comment: ""),
        message: NSLocalizedString("your.pin.has.been.update.successfully", value: "Your PIN has been updated successfully!", comment: ""),
        time: 1.5
      )
    }
  }

  func passcodeCoordinatorDidEvaluatePIN() {
    self.passcodeCoordinator.stop {
      self.passcodeCoordinator = KNPasscodeCoordinator(
        navigationController: self.navigationController,
        type: .setPasscode(cancellable: true)
      )
      self.passcodeCoordinator.delegate = self
      self.passcodeCoordinator.start()
    }
  }

  func passcodeCoordinatorDidCancel() {
    self.passcodeCoordinator.stop {}
  }
}

extension KNSettingsCoordinator: KNListWalletsCoordinatorDelegate {
  func listWalletsCoordinatorDidClickBack() {
    self.listWalletsCoordinator.stop()
  }

  func listWalletsCoordinatorDidSelectWallet(_ wallet: Wallet) {
    self.listWalletsCoordinator.stop()
    if wallet == self.session.wallet { return }
    self.delegate?.settingsCoordinatorUserDidSelectNewWallet(wallet)
  }

  func listWalletsCoordinatorDidSelectRemoveWallet(_ wallet: Wallet) {
    self.delegate?.settingsCoordinatorUserDidRemoveWallet(wallet)
  }

  func listWalletsCoordinatorDidUpdateWalletObjects() {
    self.delegate?.settingsCoordinatorUserDidUpdateWalletObjects()
  }

  func listWalletsCoordinatorDidSelectAddWallet() {
    self.delegate?.settingsCoordinatorUserDidSelectAddWallet()
  }

  func listWalletsCoordinatorShouldBackUpWallet(_ wallet: KNWalletObject) {
    self.settingsViewControllerBackUpButtonPressed(wallet: wallet)
  }
}
