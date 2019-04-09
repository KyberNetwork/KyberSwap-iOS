// Copyright SIX DAY LLC. All rights reserved.

import UIKit

enum KNSignInViewEvent {
  case back
  case signInWithEmail(email: String, password: String)
  case signInWithFacebook
  case signInWithGoogle
  case signInWithTwitter
  case forgotPassword
  case signUp
}

class KNSignInViewModel {
  var isSecureText: Bool = true

  var dontHaveAccountAttributedText: NSAttributedString = {
    let normalAttributes: [NSAttributedStringKey: Any] = [
      NSAttributedStringKey.font: UIFont.Kyber.medium(with: 14),
      NSAttributedStringKey.foregroundColor: UIColor(red: 90, green: 94, blue: 103),
    ]
    let orangeAttributes: [NSAttributedStringKey: Any] = [
      NSAttributedStringKey.font: UIFont.Kyber.medium(with: 14),
      NSAttributedStringKey.foregroundColor: UIColor(red: 254, green: 163, blue: 76),
    ]
    let attributedText = NSMutableAttributedString()
    attributedText.append(NSAttributedString(string: "Don't have an account? ".toBeLocalised(), attributes: normalAttributes))
    attributedText.append(NSAttributedString(string: "Sign Up Now", attributes: orangeAttributes)
    )
    return attributedText
  }()
}

protocol KNSignInViewControllerDelegate: class {
  func signInViewController(_ controller: KNSignInViewController, run event: KNSignInViewEvent)
}

class KNSignInViewController: KNBaseViewController {

  @IBOutlet weak var headerContainerView: UIView!
  @IBOutlet weak var navTitleLabel: UILabel!

  @IBOutlet weak var orTextLabel: UILabel!

  @IBOutlet weak var emailTextField: UITextField!
  @IBOutlet weak var passwordTextField: UITextField!
  @IBOutlet weak var forgotPassButton: UIButton!
  @IBOutlet weak var secureTextButton: UIButton!
  @IBOutlet weak var dontHaveAnAccountButton: UIButton!
  @IBOutlet weak var signInButton: UIButton!

  fileprivate let viewModel: KNSignInViewModel
  weak var delegate: KNSignInViewControllerDelegate?

  init(viewModel: KNSignInViewModel) {
    self.viewModel = viewModel
    super.init(nibName: KNSignInViewController.className, bundle: nil)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  @IBOutlet var dashLineViews: [UIView]!

  override func viewDidLoad() {
    super.viewDidLoad()
    self.headerContainerView.applyGradient(with: UIColor.Kyber.headerColors)
    self.dashLineViews.forEach({
      $0.backgroundColor = .clear
      $0.dashLine(width: 1.0, color: UIColor.Kyber.dashLine)
    })
    self.signInButton.applyGradient()

    self.navTitleLabel.text = NSLocalizedString("sign.in", value: "Sign In", comment: "")
    self.orTextLabel.text = "or".toBeLocalised()
    self.signInButton.setTitle(NSLocalizedString("sign.in", value: "Sign In", comment: ""), for: .normal)
    self.signInButton.rounded(radius: KNAppStyleType.current.buttonRadius(for: self.signInButton.frame.height))
    self.emailTextField.placeholder = "Email Address".toBeLocalised()
    self.passwordTextField.placeholder = "Password".toBeLocalised()
    self.forgotPassButton.setTitle("Forgot Password?".toBeLocalised(), for: .normal)
    self.dontHaveAnAccountButton.setAttributedTitle(self.viewModel.dontHaveAccountAttributedText, for: .normal)
    self.passwordTextField.isSecureTextEntry = self.viewModel.isSecureText
    let image = self.viewModel.isSecureText ? UIImage(named: "hide_secure_text") : UIImage(named: "show_secure_text")
    self.secureTextButton.setImage(image, for: .normal)
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    self.emailTextField.becomeFirstResponder()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    self.view.endEditing(true)
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    self.headerContainerView.removeSublayer(at: 0)
    self.headerContainerView.applyGradient(with: UIColor.Kyber.headerColors)
    self.dashLineViews.forEach({
      $0.dashLine(width: 1.0, color: UIColor.Kyber.dashLine)
    })
    self.signInButton.removeSublayer(at: 0)
    self.signInButton.applyGradient()
  }

  @IBAction func backButtonPressed(_ sender: Any) {
    self.delegate?.signInViewController(self, run: .back)
  }

  @IBAction func forgotButtonPressed(_ sender: Any) {
    self.delegate?.signInViewController(self, run: .forgotPassword)
  }

  @IBAction func facebookButtonPressed(_ sender: Any) {
    self.delegate?.signInViewController(self, run: .signInWithFacebook)
  }

  @IBAction func googleButtonPressed(_ sender: Any) {
    self.delegate?.signInViewController(self, run: .signInWithGoogle)
  }

  @IBAction func twitterButtonPressed(_ sender: Any) {
    self.delegate?.signInViewController(self, run: .signInWithTwitter)
  }

  @IBAction func secureTextButtonPressed(_ sender: Any) {
    self.viewModel.isSecureText = !self.viewModel.isSecureText
    self.passwordTextField.isSecureTextEntry = self.viewModel.isSecureText
    let image = self.viewModel.isSecureText ? UIImage(named: "hide_secure_text") : UIImage(named: "show_secure_text")
    self.secureTextButton.setImage(image, for: .normal)
  }

  @IBAction func signInButtonPressed(_ sender: Any) {
    let email = self.emailTextField.text ?? ""
    let pass = self.passwordTextField.text ?? ""
    guard email.isValidEmail() else {
      self.showErrorTopBannerMessage(
        with: NSLocalizedString("error", value: "Error", comment: ""),
        message: "Please enter a valid email address to continue".toBeLocalised(),
        time: 2.0
      )
      return
    }
    guard !pass.isEmpty else {
      self.showErrorTopBannerMessage(
        with: NSLocalizedString("error", value: "Error", comment: ""),
        message: "Please enter a password to continue".toBeLocalised(),
        time: 2.0
      )
      return
    }
    self.delegate?.signInViewController(self, run: .signInWithEmail(email: email, password: pass))
  }

  @IBAction func dontHaveAccountButtonPressed(_ sender: Any) {
    self.delegate?.signInViewController(self, run: .signUp)
  }
}
