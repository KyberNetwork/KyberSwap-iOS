// Copyright SIX DAY LLC. All rights reserved.

import UIKit

enum KNSignUpViewEvent {
  case back
  case pressedGoogle
  case pressedFacebook
  case pressedTwitter
  case signUp(accountType: KNSocialAccountsType, isSubscribe: Bool)
  case openTAC
  case alreadyMemberSignIn
}

class KNSignUpViewModel {
  var isSecureText: Bool = true
  var isSubscribe: Bool = false
  var isAgreeTAC: Bool = false

  var alreadyMemberAttributedText: NSAttributedString = {
    let normalAttributes: [NSAttributedStringKey: Any] = [
      NSAttributedStringKey.font: UIFont.Kyber.medium(with: 14),
      NSAttributedStringKey.foregroundColor: UIColor(red: 90, green: 94, blue: 103),
      ]
    let orangeAttributes: [NSAttributedStringKey: Any] = [
      NSAttributedStringKey.font: UIFont.Kyber.medium(with: 14),
      NSAttributedStringKey.foregroundColor: UIColor(red: 254, green: 163, blue: 76),
      ]
    let attributedText = NSMutableAttributedString()
    attributedText.append(NSAttributedString(string: "Already a member? ".toBeLocalised(), attributes: normalAttributes))
    attributedText.append(NSAttributedString(string: "Sign In", attributes: orangeAttributes)
    )
    return attributedText
  }()
}

protocol KNSignUpViewControllerDelegate: class {
  func signUpViewController(_ controller: KNSignUpViewController, run event: KNSignUpViewEvent)
}

class KNSignUpViewController: KNBaseViewController {

  @IBOutlet weak var headerContainerView: UIView!
  @IBOutlet weak var navTitleLabel: UILabel!
  @IBOutlet weak var orTextLabel: UILabel!

  @IBOutlet var separatorViews: [UIView]!

  @IBOutlet weak var emailAddressTextField: UITextField!
  @IBOutlet weak var displayNameTextField: UITextField!
  @IBOutlet weak var passwordTextField: UITextField!
  @IBOutlet weak var secureTextButton: UIButton!

  @IBOutlet weak var signUpButton: UIButton!
  @IBOutlet weak var signInButton: UIButton!
  @IBOutlet weak var subscribeNewsLetters: UIButton!
  @IBOutlet weak var subscribeButton: UIButton!

  @IBOutlet weak var selectTermConditionButton: UIButton!
  @IBOutlet weak var agreeToTextLabel: UILabel!
  @IBOutlet weak var termsAndConditionsButton: UIButton!

  fileprivate var viewModel: KNSignUpViewModel
  weak var delegate: KNSignUpViewControllerDelegate?

  init(viewModel: KNSignUpViewModel) {
    self.viewModel = viewModel
    super.init(nibName: KNSignUpViewController.className, bundle: nil)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    self.headerContainerView.applyGradient(with: UIColor.Kyber.headerColors)
    self.separatorViews.forEach({
      $0.backgroundColor = .clear
      $0.dashLine(width: 1.0, color: UIColor.Kyber.dashLine)
    })

    self.emailAddressTextField.placeholder = "Email Address".toBeLocalised()
    self.displayNameTextField.placeholder = "Display Name".toBeLocalised()
    self.passwordTextField.placeholder = "Password".toBeLocalised()
    self.passwordTextField.isSecureTextEntry = self.viewModel.isSecureText
    let image = self.viewModel.isSecureText ? UIImage(named: "hide_secure_text") : UIImage(named: "show_secure_text")
    self.secureTextButton.setImage(image, for: .normal)

    self.subscribeButton.setImage(self.viewModel.isSubscribe ? UIImage(named: "check_box_icon") : nil, for: .normal)
    self.subscribeButton.rounded(color: self.viewModel.isSubscribe ? UIColor.clear : UIColor.Kyber.border, width: 1.0, radius: 2.5)

    self.selectTermConditionButton.setImage(self.viewModel.isAgreeTAC ? UIImage(named: "check_box_icon") : nil, for: .normal)
    self.selectTermConditionButton.rounded(color: self.viewModel.isAgreeTAC ? UIColor.clear : UIColor.Kyber.border, width: 1.0, radius: 2.5)

    self.signUpButton.setTitle(NSLocalizedString("sign.up", value: "Sign Up", comment: ""), for: .normal)
    self.signUpButton.rounded(radius: KNAppStyleType.current.buttonRadius(for: self.signUpButton.frame.height))
    self.signUpButton.applyGradient()

    self.signInButton.setAttributedTitle(
      self.viewModel.alreadyMemberAttributedText,
      for: .normal
    )
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    self.emailAddressTextField.becomeFirstResponder()
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    self.view.endEditing(true)
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    self.headerContainerView.removeSublayer(at: 0)
    self.headerContainerView.applyGradient(with: UIColor.Kyber.headerColors)

    self.separatorViews.forEach({
      $0.dashLine(width: 1.0, color: UIColor.Kyber.dashLine)
    })

    self.signUpButton.removeSublayer(at: 0)
    self.signUpButton.applyGradient()
  }

  @IBAction func backButtonPressed(_ sender: Any) {
    self.delegate?.signUpViewController(self, run: .back)
  }

  @IBAction func googleButtonPressed(_ sender: Any) {
    self.view.endEditing(true)
    self.delegate?.signUpViewController(self, run: .pressedGoogle)
  }

  @IBAction func facebookButtonPressed(_ sender: Any) {
    self.view.endEditing(true)
    self.delegate?.signUpViewController(self, run: .pressedFacebook)
  }

  @IBAction func twitterButtonPressed(_ sender: Any) {
    self.view.endEditing(true)
    self.delegate?.signUpViewController(self, run: .pressedTwitter)
  }

  @IBAction func secureTextButtonPressed(_ sender: Any) {
    self.viewModel.isSecureText = !self.viewModel.isSecureText
    self.passwordTextField.isSecureTextEntry = self.viewModel.isSecureText
    let image = self.viewModel.isSecureText ? UIImage(named: "hide_secure_text") : UIImage(named: "show_secure_text")
    self.secureTextButton.setImage(image, for: .normal)
  }

  @IBAction func signUpButtonPressed(_ sender: Any) {
    guard let email = self.emailAddressTextField.text, email.isValidEmail() else {
      self.showErrorTopBannerMessage(
        with: NSLocalizedString("error", value: "Error", comment: ""),
        message: "Please enter a valid email address to continue".toBeLocalised(),
        time: 2.0
      )
      return
    }
    guard let name = self.displayNameTextField.text, !name.isEmpty else {
      self.showErrorTopBannerMessage(
        with: NSLocalizedString("error", value: "Error", comment: ""),
        message: "Please enter a display name to continue".toBeLocalised(),
        time: 2.0
      )
      return
    }
    guard let password = self.passwordTextField.text, password.isValidPassword() else {
      self.showErrorTopBannerMessage(
        with: NSLocalizedString("error", value: "Error", comment: ""),
        message: "Please enter a valid password to continue".toBeLocalised(),
        time: 2.0
      )
      return
    }
    guard self.viewModel.isAgreeTAC else {
      self.showErrorTopBannerMessage(
        with: NSLocalizedString("error", value: "Error", comment: ""),
        message: "Please accept our Terms and Conditions to continue".toBeLocalised(),
        time: 2.0
      )
      return
    }
    self.view.endEditing(true)
    let account = KNSocialAccountsType.normal(name: name, email: email, password: password)
    self.delegate?.signUpViewController(self, run: .signUp(accountType: account, isSubscribe: self.viewModel.isSubscribe))
  }

  @IBAction func signInButtonPressed(_ sender: Any) {
    self.view.endEditing(true)
    self.delegate?.signUpViewController(self, run: .alreadyMemberSignIn)
  }

  @IBAction func subscribeButtonPressed(_ sender: Any) {
    self.viewModel.isSubscribe = !self.viewModel.isSubscribe
    self.subscribeButton.setImage(self.viewModel.isSubscribe ? UIImage(named: "check_box_icon") : nil, for: .normal)
    self.subscribeButton.rounded(color: self.viewModel.isSubscribe ? UIColor.clear : UIColor.Kyber.border, width: 1.0, radius: 2.5)
    self.view.layoutIfNeeded()
  }

  @IBAction func selectTermsAndConditionsPressed(_ sender: Any) {
    self.viewModel.isAgreeTAC = !self.viewModel.isAgreeTAC
    self.selectTermConditionButton.setImage(self.viewModel.isAgreeTAC ? UIImage(named: "check_box_icon") : nil, for: .normal)
    self.selectTermConditionButton.rounded(color: self.viewModel.isAgreeTAC ? UIColor.clear : UIColor.Kyber.border, width: 1.0, radius: 2.5)
    self.view.layoutIfNeeded()
  }

  @IBAction func termsAndConditionsButtonPressed(_ sender: Any) {
    self.view.endEditing(true)
    self.delegate?.signUpViewController(self, run: .openTAC)
  }
}
