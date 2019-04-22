// Copyright SIX DAY LLC. All rights reserved.

import UIKit

class KNForgotPasswordViewController: KNBaseViewController {

  @IBOutlet weak var containerView: UIView!

  @IBOutlet weak var resetPasswordTextLabel: UILabel!
  @IBOutlet weak var emailTextField: UITextField!

  @IBOutlet weak var sendButton: UIButton!

  override func viewDidLoad() {
    super.viewDidLoad()
    self.containerView.rounded(radius: 5.0)
    self.resetPasswordTextLabel.text = "Reset Password".toBeLocalised()
    self.emailTextField.placeholder = "Email Address".toBeLocalised()
    self.sendButton.rounded(radius: KNAppStyleType.current.buttonRadius(for: self.sendButton.frame.height))
    self.sendButton.setTitle(NSLocalizedString("continue", value: "Continue", comment: ""), for: .normal)
    self.sendButton.applyGradient()

    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.tapOutSideToDismiss(_:)))
    self.view.addGestureRecognizer(tapGesture)
    self.view.isUserInteractionEnabled = true
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    self.emailTextField.becomeFirstResponder()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    self.sendButton.removeSublayer(at: 0)
    self.sendButton.applyGradient()
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    self.view.endEditing(true)
  }

  @objc func tapOutSideToDismiss(_ sender: UITapGestureRecognizer) {
    let position = sender.location(in: self.view)
    if position.x < self.containerView.frame.minX || position.x > self.containerView.frame.maxX
      || position.y < self.containerView.frame.minY || position.y > self.containerView.frame.maxY {
      self.dismiss(animated: true, completion: nil)
    }
  }

  @IBAction func sendButtonPressed(_ sender: Any) {
    let email = self.emailTextField.text ?? ""
    guard email.isValidEmail() else {
      self.showErrorTopBannerMessage(
        with: NSLocalizedString("error", value: "Error", comment: ""),
        message: "Please enter a valid email address to continue".toBeLocalised(),
        time: 2.0
      )
      return
    }
    self.sendResetPasswordRequest(email)
  }

  fileprivate func sendResetPasswordRequest(_ email: String) {
    self.displayLoading()
    KNSocialAccountsCoordinator.shared.resetPassword(email) { [weak self] result in
      guard let `self` = self else { return }
      self.hideLoading()
      switch result {
      case .success(let data):
        if data.0 {
          // success
          self.showSuccessTopBannerMessage(
            with: NSLocalizedString("success", comment: ""),
            message: data.1,
            time: 1.5
          )
          self.dismiss(animated: true, completion: nil)
        } else {
          self.showErrorTopBannerMessage(
            with: NSLocalizedString("error", comment: ""),
            message: data.1,
            time: 1.5
          )
        }
      case .failure:
        self.showErrorTopBannerMessage(
          with: NSLocalizedString("error", comment: ""),
          message: "Can not send your request, please try again".toBeLocalised(),
          time: 1.5
        )
      }
    }
  }
}
