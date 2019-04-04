// Copyright SIX DAY LLC. All rights reserved.

import UIKit

class KNManageAlertCoordinator: Coordinator {

  let navigationController: UINavigationController
  var coordinators: [Coordinator] = []

  lazy var rootViewController: KNManageAlertsViewController = {
    let controller = KNManageAlertsViewController()
    controller.loadViewIfNeeded()
    controller.delegate = self
    return controller
  }()

  fileprivate var newAlertController: KNNewAlertViewController?

  init(navigationController: UINavigationController) {
    self.navigationController = navigationController
  }

  func start() {
    self.navigationController.pushViewController(self.rootViewController, animated: true)
  }

  func stop() {
    self.navigationController.popViewController(animated: true)
  }
}

extension KNManageAlertCoordinator: KNManageAlertsViewControllerDelegate {
  func manageAlertsViewController(_ viewController: KNManageAlertsViewController, run event: KNManageAlertsViewEvent) {
    switch event {
    case .back: self.stop()
    case .addNewAlert:
      self.openAddNewAlert()
    case .alertMethod:
      self.openAlertMethod()
    case .leaderBoard:
      self.openLeaderBoard()
    }
  }

  func openAddNewAlert() {
    if KNAlertStorage.shared.isMaximumAlertsReached {
      let alertController = UIAlertController(
        title: "Alert limit exceeded".toBeLocalised(),
        message: "You already have 10 (maximum) alerts in your inbox. Please delete an existing alert to add a new one".toBeLocalised(),
        preferredStyle: .alert
      )
      alertController.addAction(UIAlertAction(title: NSLocalizedString("ok", value: "OK", comment: ""), style: .cancel, handler: nil))
      self.navigationController.present(alertController, animated: true, completion: nil)
    } else {
      self.newAlertController = KNNewAlertViewController()
      self.newAlertController?.loadViewIfNeeded()
      self.navigationController.pushViewController(self.newAlertController!, animated: true)
    }
  }

  func openAlertMethod() {
    let alertMethodsVC = KNNotificationMethodsViewController()
    alertMethodsVC.loadViewIfNeeded()
    self.navigationController.pushViewController(alertMethodsVC, animated: true)
  }

  func openLeaderBoard() {
    guard IEOUserStorage.shared.user != nil else { return }
    let leaderBoardVC = KNAlertLeaderBoardViewController()
    leaderBoardVC.loadViewIfNeeded()
    leaderBoardVC.delegate = self
    self.navigationController.pushViewController(leaderBoardVC, animated: true)
  }

  func manageAlertsViewController(_ viewController: KNManageAlertsViewController, run event: KNAlertTableViewEvent) {
    switch event {
    case .delete(let alert):
      let message = alert.hasReward ? "This alert is rewarded in a current running campaign, you will lose your reward if removing it, do you want to continue?".toBeLocalised() : "Do you want to delete this alert?".toBeLocalised()
      let alertController = UIAlertController(title: NSLocalizedString("delete", value: "Delete", comment: ""), message: message, preferredStyle: .alert)
      alertController.addAction(UIAlertAction(title: NSLocalizedString("cancel", value: "Cancel", comment: ""), style: .cancel, handler: nil))
      alertController.addAction(UIAlertAction(title: NSLocalizedString("delete", value: "Delete", comment: ""), style: .destructive, handler: { _ in
        self.deleteAnAlert(alert)
      }))
      self.navigationController.present(alertController, animated: true, completion: nil)
    case .edit(let alert):
      self.openEditAlert(alert)
    case .select(let alert):
      self.openEditAlert(alert)
    default: break
    }
  }

  fileprivate func deleteAnAlert(_ alert: KNAlertObject) {
    KNCrashlyticsUtil.logCustomEvent(withName: "manage_alert", customAttributes: ["type": "delete_alert"])
    guard let accessToken = IEOUserStorage.shared.user?.accessToken else { return }
    self.navigationController.displayLoading()
    KNPriceAlertCoordinator.shared.removeAnAlert(accessToken: accessToken, alertID: alert.id) { [weak self] (_, error) in
      guard let `self` = self else { return }
      self.navigationController.hideLoading()
      if let error = error {
        KNCrashlyticsUtil.logCustomEvent(
          withName: "manage_alert",
          customAttributes: ["type": "delete_alert_failed", "error": error]
        )
        self.navigationController.showErrorTopBannerMessage(
          with: NSLocalizedString("error", value: "Error", comment: ""),
          message: error,
          time: 1.5
        )
      } else {
        self.navigationController.showSuccessTopBannerMessage(
          with: "",
          message: "Alert deleted!".toBeLocalised(),
          time: 1.0
        )
      }
    }
  }

  fileprivate func openEditAlert(_ alert: KNAlertObject) {
    KNCrashlyticsUtil.logCustomEvent(withName: "manage_alert", customAttributes: ["type": "open_edit_alert"])
    self.newAlertController = KNNewAlertViewController()
    self.newAlertController?.loadViewIfNeeded()
    self.navigationController.pushViewController(self.newAlertController!, animated: true) {
      self.newAlertController?.updateEditAlert(alert)
    }
  }
}

extension KNManageAlertCoordinator: KNAlertLeaderBoardViewControllerDelegate {
  func alertLeaderBoardViewControllerShouldBack() {
    self.navigationController.popViewController(animated: true)
  }
}
