// Copyright SIX DAY LLC. All rights reserved.

import UIKit

class KNNotificationMethodsViewController: KNBaseViewController {

  @IBOutlet weak var headerContainerView: UIView!
  @IBOutlet weak var navTitleLabel: UILabel!
  @IBOutlet weak var getAlertByTextLabel: UILabel!
  
  @IBOutlet weak var emailTextLabel: UILabel!
  @IBOutlet weak var emailTextField: UITextField!

  @IBOutlet weak var telegramTextLabel: UILabel!
  @IBOutlet weak var telegramTextField: UITextField!

  fileprivate var emails: [JSONDictionary] = []
  fileprivate var activeEmail: String?
  fileprivate var telegrams: [JSONDictionary] = []
  fileprivate var activeTelegram: String?

  override func viewDidLoad() {
    super.viewDidLoad()
    self.headerContainerView.applyGradient(with: UIColor.Kyber.headerColors)
    self.navTitleLabel.text = NSLocalizedString("Alert Method", comment: "")

    self.emailTextLabel.isHidden = true
    self.emailTextField.isHidden = true

    self.telegramTextLabel.isHidden = true
    self.telegramTextField.isHidden = true

    self.updateUIs()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if IEOUserStorage.shared.user == nil { self.navigationController?.popViewController(animated: true) }
    self.reloadAlertMethods()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    self.headerContainerView.removeSublayer(at: 0)
    self.headerContainerView.applyGradient(with: UIColor.Kyber.headerColors)
  }

  fileprivate func reloadAlertMethods() {
    guard let accessToken = IEOUserStorage.shared.user?.accessToken else { return }
    self.displayLoading()
    KNPriceAlertCoordinator.shared.getAlertMethods(accessToken: accessToken) { [weak self] (resp, error) in
      guard let `self` = self else { return }
      self.hideLoading()
      if error == nil {
        self.emails = resp["email"] as? [JSONDictionary] ?? []
        self.telegrams = resp["telegram"] as? [JSONDictionary] ?? []
        if let email = self.emails.first(where: { return ($0["active"] as? Bool ?? false) }) {
          self.activeEmail = email["id"] as? String
        } else {
          self.activeEmail = "Not enabled".toBeLocalised()
        }
        if resp["email"] == nil || self.emails.isEmpty {
          self.emailTextLabel.isHidden = true
          self.emailTextField.isHidden = true
        } else {
          self.emailTextLabel.isHidden = false
          self.emailTextField.isHidden = false
        }
        if resp["telegram"] == nil || self.telegrams.isEmpty {
          self.telegramTextLabel.isHidden = true
          self.telegramTextField.isHidden = true
        } else {
          self.telegramTextLabel.isHidden = false
          self.telegramTextField.isHidden = false
        }
        self.updateUIs()
      } else {
        self.showAlertCanNotLoadAlertMethods()
      }
    }
  }

  fileprivate func showAlertCanNotLoadAlertMethods() {
    let alert = UIAlertController(
      title: NSLocalizedString("error", value: "Error", comment: ""),
      message: NSLocalizedString("Can not load alert methods. Please try again", comment: ""),
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: NSLocalizedString("reload", value: "Reload", comment: ""), style: .default, handler: { _ in
      self.reloadAlertMethods()
    }))
    alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", value: "Cancel", comment: ""), style: .cancel, handler: { _ in
      self.navigationController?.popViewController(animated: true)
    }))
    self.present(alert, animated: true, completion: nil)
  }

  fileprivate func updateUIs() {
    
  }


  @IBAction func saveButtonPressed(_ sender: Any) {
    guard let accessToken = IEOUserStorage.shared.user?.accessToken else { return }
    self.displayLoading(text: NSLocalizedString("Updating", comment: ""), animated: true)
    KNPriceAlertCoordinator.shared.updateAlertMethods(accessToken: accessToken, email: self.emails, telegram: self.telegrams) { [weak self] (message, error) in
      guard let `self` = self else { return }
      self.hideLoading()
      if error == nil {
        self.showSuccessTopBannerMessage(
          with: NSLocalizedString("success", value: "Success", comment: ""),
          message: NSLocalizedString("Updated alert methods successfully!", comment: ""),
          time: 1.5
        )
      } else {
        self.showSuccessTopBannerMessage(
          with: NSLocalizedString("error", value: "Error", comment: ""),
          message: message,
          time: 1.5
        )
      }
    }
  }

  @IBAction func backButtonPressed(_ sender: Any) {
    self.navigationController?.popViewController(animated: true)
  }

  @IBAction func screenEdgePanAction(_ sender: UIScreenEdgePanGestureRecognizer) {
    self.navigationController?.popViewController(animated: true)
  }
}
