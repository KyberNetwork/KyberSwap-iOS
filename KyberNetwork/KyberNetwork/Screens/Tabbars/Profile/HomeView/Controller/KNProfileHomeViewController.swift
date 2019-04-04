// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import Moya
import QRCodeReaderViewController
import TrustCore
import Crashlytics

enum KNProfileHomeViewEvent {
  case signIn
  case signUp
  case logOut
  case openVerification
  case addPriceAlert
  case managePriceAlerts
  case editAlert(alert: KNAlertObject)
  case leaderBoard
}

protocol KNProfileHomeViewControllerDelegate: class {
  func profileHomeViewController(_ controller: KNProfileHomeViewController, run event: KNProfileHomeViewEvent)
}

class KNProfileHomeViewController: KNBaseViewController {

  let kWalletTableViewCellID: String = "kWalletTableViewCellID"
  let kWalletCellRowHeight: CGFloat = 84.0

  @IBOutlet weak var navTitleLabel: UILabel!
  @IBOutlet weak var notSignInView: UIView!
  @IBOutlet weak var notSignInTitleLabel: UILabel!
  @IBOutlet weak var notSignInDescLabel: UILabel!
  @IBOutlet weak var signInButton: UIButton!

  @IBOutlet weak var signInHeaderView: UIView!
  @IBOutlet weak var myProfileTextLabel: UILabel!
  @IBOutlet weak var myWalletsTextLabel: UILabel!
  @IBOutlet weak var signedInView: UIView!
  @IBOutlet weak var logOutButton: UIButton!
  @IBOutlet weak var userImageView: UIImageView!
  @IBOutlet weak var userNameLabel: UILabel!
  @IBOutlet weak var userEmailLabel: UILabel!
  @IBOutlet weak var userKYCStatusLabel: UILabel!

  @IBOutlet weak var userKYCStatusContainerView: UIView!
  @IBOutlet weak var userKYCStatusDescLabel: UILabel!
  @IBOutlet weak var userKYCActionButton: UIButton!
  @IBOutlet var userKYCStatusPaddingConstraints: [NSLayoutConstraint]!
  @IBOutlet weak var userKYCActionHeightConstraint: NSLayoutConstraint!

  @IBOutlet weak var priceAlertContainerView: UIView!
  @IBOutlet weak var priceAlertsTextLabel: UILabel!
  @IBOutlet weak var noPriceAlertContainerView: UIView!
  @IBOutlet weak var noPriceAlertMessageLabel: UILabel!
  @IBOutlet weak var listPriceAlertsContainerView: UIView!
  @IBOutlet weak var priceAlertTableView: KNAlertTableView!
  @IBOutlet weak var moreAlertsButton: UIButton!
  @IBOutlet weak var priceAlertContainerViewHeightConstraint: NSLayoutConstraint!
  @IBOutlet weak var listPriceAlertsContainerViewHeightConstraint: NSLayoutConstraint!
  @IBOutlet weak var priceAlertTableViewHeightConstraint: NSLayoutConstraint!

  @IBOutlet weak var topPaddingConstraintForMyWalletsSection: NSLayoutConstraint!
  @IBOutlet weak var noWalletTextLabel: UILabel!
  @IBOutlet weak var walletsTableView: UITableView!
  @IBOutlet weak var walletWarningMessageLabel: UILabel!
  @IBOutlet weak var maximumWalletsTextLabel: UILabel!
  @IBOutlet weak var heightConstraintWalletsTableView: NSLayoutConstraint!
  @IBOutlet weak var addWalletContainer: UIView!
  @IBOutlet weak var heightConstraintForAddWalletContainer: NSLayoutConstraint!
  @IBOutlet weak var addWalletLabelTextField: UITextField!
  @IBOutlet weak var addWalletAddressTextField: UITextField!
  @IBOutlet weak var addWalletAddButton: UIButton!
  @IBOutlet weak var bottomPaddingConstraintForSignedInView: NSLayoutConstraint!

  weak var delegate: KNProfileHomeViewControllerDelegate?
  fileprivate var viewModel: KNProfileHomeViewModel

  fileprivate var walletTimer: Timer?

  fileprivate let appStyle = KNAppStyleType.current

  init(viewModel: KNProfileHomeViewModel) {
    self.viewModel = viewModel
    super.init(nibName: KNProfileHomeViewController.className, bundle: nil)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    self.setupUI()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    self.updateUIUserDidSignedIn()
    self.fetchWalletList()
    self.walletTimer?.invalidate()
    self.walletTimer = Timer.scheduledTimer(
      withTimeInterval: KNEnvironment.default.isMainnet ? 60.0 : 10.0,
      repeats: true,
      block: { [weak self] _ in
      self?.fetchWalletList()
      }
    )
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    self.walletTimer?.invalidate()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    self.notSignInView.removeSublayer(at: 0)
    self.notSignInView.applyGradient(with: UIColor.Kyber.backgroundColors)
    self.signInHeaderView.removeSublayer(at: 0)
    self.signInHeaderView.applyGradient(with: UIColor.Kyber.headerColors)
  }

  fileprivate func setupUI() {
    self.navTitleLabel.text = NSLocalizedString("profile", value: "Profile", comment: "")
    self.navTitleLabel.addLetterSpacing()
    self.setupNotSignInView()
    self.setupUserSignedInView()
  }

  fileprivate func setupNotSignInView() {
    self.notSignInView.applyGradient(with: UIColor.Kyber.backgroundColors)
    self.signInButton.rounded(
      radius: self.appStyle.buttonRadius(for: self.signInButton.frame.height)
    )
    self.notSignInTitleLabel.text = NSLocalizedString(
      "profile", value: "Profile",
      comment: ""
    )
    self.notSignInTitleLabel.addLetterSpacing()
    self.notSignInDescLabel.text = NSLocalizedString(
      "welcome.third.screen.description", value: "Profile process just got simpler. Straight from the app.",
      comment: ""
    )
    self.notSignInDescLabel.addLetterSpacing()
    self.signInButton.setTitle(
      NSLocalizedString("sign.in", value: "Sign In", comment: ""),
      for: .normal
    )
    self.signInButton.backgroundColor = UIColor.white
    self.signInButton.setTitleColor(UIColor(red: 251, green: 121, blue: 93), for: .normal)
    self.signInButton.addTextSpacing()
    self.notSignInView.isHidden = self.viewModel.isUserSignedIn
  }

  fileprivate func setupUserSignedInView() {
    self.signInHeaderView.applyGradient(with: UIColor.Kyber.headerColors)
    self.bottomPaddingConstraintForSignedInView.constant = self.bottomPaddingSafeArea()
    self.signedInView.isHidden = !self.viewModel.isUserSignedIn
    self.myProfileTextLabel.text = NSLocalizedString("my.profile", value: "My Profile", comment: "")
    self.myProfileTextLabel.addLetterSpacing()
    self.myWalletsTextLabel.text = NSLocalizedString("my.wallets", value: "My Wallet(s)", comment: "")
    self.myWalletsTextLabel.addLetterSpacing()
    self.logOutButton.setTitle(NSLocalizedString("log.out", value: "Log Out", comment: ""), for: .normal)
    self.logOutButton.addTextSpacing()
    let descText: String = NSLocalizedString(
      "complete.your.profile.verfication.increase.trade.limits",
      value: "Complete Your Profile Verification\nIncrease KyberSwap's trade limits",
      comment: ""
    )
    self.updateKYCStatusDescLabel(with: descText)

    self.userImageView.rounded(
      color: UIColor.Kyber.border,
      width: 0.5,
      radius: self.userImageView.frame.height / 2.0
    )

    self.userKYCActionButton.rounded(
      color: UIColor.Kyber.border,
      width: 1.0,
      radius: KNAppStyleType.current.buttonRadius(for: self.userKYCActionButton.frame.height)
    )
    self.userKYCStatusLabel.rounded(radius: 2.0)

    self.noWalletTextLabel.text = NSLocalizedString("you.have.not.added.any.wallets.yet", value: "You haven't added any wallets yet.", comment: "")
    self.noWalletTextLabel.addLetterSpacing()
    self.maximumWalletsTextLabel.text = NSLocalizedString("maximum.three.wallets", value: "Maximum 3 wallets", comment: "")
    self.maximumWalletsTextLabel.addLetterSpacing()
    self.walletWarningMessageLabel.text = nil
    self.walletsTableView.register(UITableViewCell.self, forCellReuseIdentifier: kWalletTableViewCellID)
    self.walletsTableView.rowHeight = kWalletCellRowHeight
    self.walletsTableView.delegate = self
    self.walletsTableView.dataSource = self

    self.addWalletLabelTextField.placeholder = NSLocalizedString("label", value: "Label", comment: "")
    self.addWalletLabelTextField.addPlaceholderSpacing()
    self.addWalletAddressTextField.placeholder = NSLocalizedString("address", value: "Address", comment: "")
    self.addWalletAddressTextField.addPlaceholderSpacing()
    self.addWalletAddButton.rounded(
      color: UIColor.Kyber.border,
      width: 1.0,
      radius: KNAppStyleType.current.buttonRadius(for: self.addWalletAddButton.frame.height)
    )
    self.addWalletAddButton.setTitle(
      NSLocalizedString("add", value: "Add", comment: ""),
      for: .normal
    )
    self.addWalletAddButton.addTextSpacing()
    self.setupPriceAlertsView()
    self.updateUIUserDidSignedIn()
  }

  fileprivate func setupPriceAlertsView() {
    self.priceAlertsTextLabel.text = "Price Alerts".uppercased().toBeLocalised()
    self.noPriceAlertMessageLabel.text = "We will send you notifications when prices go above or below your targets".toBeLocalised()
    self.moreAlertsButton.setTitle("More Alerts".uppercased().toBeLocalised(), for: .normal)
    self.priceAlertTableView.delegate = self
    self.priceAlertTableView.updateView(with: KNAlertStorage.shared.alerts, isFull: false)
    self.priceAlertTableView.updateScrolling(isEnabled: false)
  }

  fileprivate func updatePriceAlertsView(tableViewHeight: CGFloat) {
    if !KNAppTracker.isPriceAlertEnabled {
      self.topPaddingConstraintForMyWalletsSection.constant = 1
      self.priceAlertContainerView.isHidden = true
    } else {
      if tableViewHeight == 0.0 {
        // no alerts
        self.listPriceAlertsContainerView.isHidden = true
        self.noPriceAlertContainerView.isHidden = false
        self.priceAlertContainerViewHeightConstraint.constant = 160.0
        self.topPaddingConstraintForMyWalletsSection.constant = 160.0
      } else {
        self.listPriceAlertsContainerView.isHidden = false
        self.noPriceAlertContainerView.isHidden = true
        // section height + table height + moreAlerts button height
        self.priceAlertContainerViewHeightConstraint.constant = 60.0 + tableViewHeight + 56.0
        self.topPaddingConstraintForMyWalletsSection.constant = 60.0 + tableViewHeight + 56.0
        self.priceAlertTableViewHeightConstraint.constant = tableViewHeight
        self.listPriceAlertsContainerViewHeightConstraint.constant = tableViewHeight + 56.0
      }
      self.moreAlertsButton.backgroundColor = KNAlertStorage.shared.alerts.count == 1 ? UIColor(red: 246, green: 247, blue: 250) : UIColor(red: 242, green: 243, blue: 246)
      self.updateViewConstraints()
      self.view.layoutIfNeeded()
    }
  }

  fileprivate func updateKYCStatusDescLabel(with string: String) {
    self.userKYCStatusDescLabel.attributedText = {
      let attributedString = NSMutableAttributedString()
      attributedString.append(NSAttributedString(string: string))
      if let index = string.firstIndex(of: "\n") {
        let attributes: [NSAttributedStringKey: Any] = [
          NSAttributedStringKey.foregroundColor: UIColor.Kyber.mirage,
          NSAttributedStringKey.kern: 0.0,
          ]
        let range = NSRange(location: 0, length: index.encodedOffset)
        attributedString.addAttributes(attributes, range: range)
      }
      return attributedString
    }()
    self.view.layoutIfNeeded()
  }

  fileprivate func fetchWalletList() {
    self.viewModel.getUserWallets { _ in
      self.updateWalletsData()
    }
  }

  fileprivate func updateUIUserDidSignedIn() {
    guard let user = self.viewModel.currentUser else { return }
    let url: String = {
      if user.avatarURL.starts(with: "http") { return user.avatarURL }
      return "\(KNAppTracker.getKyberProfileBaseString())\(user.avatarURL)"
    }()
    self.signInHeaderView.removeSublayer(at: 0)
    self.signInHeaderView.applyGradient(with: UIColor.Kyber.headerColors)
    self.userImageView.setImage(
      with: url,
      placeholder: UIImage(named: "account"),
      size: nil
    )
    self.userNameLabel.text = user.name
    self.userNameLabel.addLetterSpacing()
    self.userEmailLabel.text = user.contactID
    self.userEmailLabel.addLetterSpacing()
    let status: String = {
      switch user.kycStatus.lowercased() {
      case "draft", "none": return "Unverified"
      case "pending": return "Pending"
      case "approved": return "Approved"
      case "rejected": return "Rejected"
      case "blocked": return "Blocked"
      default: return "Unknown"
      }
    }()
    if status == "Approved" || status == "Pending" || status == "Blocked" {
      //swiftlint:disable line_length
      self.walletWarningMessageLabel.text = NSLocalizedString("kyc.submit.wallet.warning.message", value: "We understand that you have submitted the wallet address as part of the verification process. As such, we regret to inform you that the submitted wallet address cannot be deleted or changed from your profile.", comment: "")
      self.walletWarningMessageLabel.addLetterSpacing()
    } else {
      self.walletWarningMessageLabel.text = nil
    }
    self.userKYCStatusLabel.text = "\(NSLocalizedString(status.lowercased(), value: status, comment: ""))  "
    self.userKYCStatusLabel.addLetterSpacing()

    let actionTitle: String = status == "Rejected" ? NSLocalizedString("edit", value: "Edit", comment: "") : NSLocalizedString("verify", value: "Verify", comment: "")
    self.userKYCActionButton.setTitle(actionTitle, for: .normal)
    // hide button if it is blocked
    self.userKYCActionButton.isHidden = status == "Blocked"

    if status == "Approved" {
      self.userKYCStatusLabel.backgroundColor = UIColor.Kyber.shamrock
    } else if status == "Pending" {
      self.userKYCStatusLabel.backgroundColor = UIColor.Kyber.merigold
    } else if status == "Rejected" {
      self.userKYCStatusLabel.backgroundColor = UIColor.Kyber.strawberry
    } else if status == "Blocked" {
      self.userKYCStatusLabel.backgroundColor = UIColor.Kyber.mirage
    } else {
      self.userKYCStatusLabel.backgroundColor = UIColor(red: 154, green: 171, blue: 180)
    }
    self.userKYCStatusLabel.addLetterSpacing()
    let descText: String = {
      if status == "Approved" || status == "Pending" { return "" }
      if status == "Rejected" || status == "Blocked" {
        let reason = user.kycDetails?.rejectedReason ?? ""
        let title: String = {
          if status == "Rejected" {
            return NSLocalizedString("profile.is.rejected", value: "Your Profile is rejected", comment: "")
          }
          return NSLocalizedString("profile.is.blocked", value: "Your Profile is blocked", comment: "")
        }()
        return "\(title)\n\(reason)"
      }
      return NSLocalizedString(
        "complete.your.profile.verfication.increase.trade.limits",
        value: "Complete Your Profile Verification\nIncrease KyberSwap's trade limits",
        comment: ""
      )
    }()
    self.updateKYCStatusDescLabel(with: descText)

    if status == "Approved" || status == "Pending" {
      self.userKYCStatusPaddingConstraints.forEach({ $0.constant = 0.0 })
      self.userKYCActionHeightConstraint.constant = 0.0
      self.userKYCStatusContainerView.isHidden = true
    } else {
      self.userKYCStatusPaddingConstraints.forEach({ $0.constant = 24.0 })
      self.userKYCActionHeightConstraint.constant = self.userKYCActionButton.isHidden ? 0.0 : 44.0
      self.userKYCStatusContainerView.isHidden = false
    }
    self.updateWalletsData()
    self.priceAlertTableView.updateView(
      with: KNAlertStorage.shared.alerts,
      isFull: false
    )
  }

  fileprivate func updateWalletsData() {
    if self.viewModel.wallets.isEmpty {
      self.noWalletTextLabel.isHidden = false
      self.walletsTableView.isHidden = true
      self.heightConstraintWalletsTableView.constant = 260.0
      self.addWalletContainer.isHidden = false
      self.heightConstraintForAddWalletContainer.constant = 200.0
    } else {
      let hasAddWalletView: Bool = self.viewModel.wallets.count < 3
      let addWalletViewHeight: CGFloat = hasAddWalletView ? 200.0 : 0.0
      self.heightConstraintWalletsTableView.constant = CGFloat(self.viewModel.wallets.count) * kWalletCellRowHeight + addWalletViewHeight
      self.noWalletTextLabel.isHidden = true
      self.walletsTableView.isHidden = false
      self.addWalletContainer.isHidden = !hasAddWalletView
      self.heightConstraintForAddWalletContainer.constant = addWalletViewHeight
      self.walletsTableView.reloadData()
    }
    self.view.layoutIfNeeded()
  }

  @IBAction func signInButtonPressed(_ sender: Any) {
    KNCrashlyticsUtil.logCustomEvent(withName: "profile_kyc", customAttributes: ["value": "sign_in_button_pressed"])
    self.delegate?.profileHomeViewController(self, run: .signIn)
  }

  @IBAction func logOutButtonPressed(_ sender: Any) {
    KNCrashlyticsUtil.logCustomEvent(withName: "profile_kyc", customAttributes: ["value": "sign_out_button_pressed"])
    self.delegate?.profileHomeViewController(self, run: .logOut)
  }

  @IBAction func userKYCActionButtonPressed(_ sender: Any) {
    KNCrashlyticsUtil.logCustomEvent(withName: "profile_kyc", customAttributes: ["value": "verify_pressed_\(self.userKYCActionButton.titleLabel?.text ?? "")"])
    self.delegate?.profileHomeViewController(self, run: .openVerification)
  }

  @IBAction func addWalletScanQRCodePressed(_ sender: Any) {
    KNCrashlyticsUtil.logCustomEvent(withName: "profile_kyc", customAttributes: ["value": "add_wallet_scan_qr_code"])
    let qrcodeReader = QRCodeReaderViewController()
    qrcodeReader.delegate = self
    self.present(qrcodeReader, animated: true, completion: nil)
  }

  @IBAction func addWalletAddButtonPressed(_ sender: Any) {
    KNCrashlyticsUtil.logCustomEvent(withName: "profile_kyc", customAttributes: ["value": "add_wallet_profile_view"])
    guard let label = self.addWalletLabelTextField.text, !label.isEmpty else {
      self.showWarningTopBannerMessage(
        with: NSLocalizedString("invalid.input", value: "Invalid Input", comment: ""),
        message: NSLocalizedString("please.enter.a.valid.wallet.label", value: "Please enter a valid wallet label", comment: ""),
        time: 1.5
      )
      return
    }
    guard let address = self.addWalletAddressTextField.text, Address(string: address) != nil else {
      self.showWarningTopBannerMessage(
        with: NSLocalizedString("invalid.input", value: "Invalid Input", comment: ""),
        message: NSLocalizedString("please.enter.a.valid.address", value: "Please enter a valid address", comment: ""),
        time: 1.5
      )
      return
    }
    self.displayLoading(text: "\(NSLocalizedString("adding", value: "Invalid Adding", comment: ""))...", animated: true)
    self.viewModel.addWallet(label: label, address: address) { [weak self] result in
      guard let `self` = self else { return }
      self.hideLoading()
      switch result {
      case .success(let resp):
        let isAdded: Bool = resp.0
        let message: String = resp.1
        if isAdded {
          self.showSuccessTopBannerMessage(
            with: NSLocalizedString("success", value: "Success", comment: ""),
            message: NSLocalizedString("your.wallet.has.been.added.successfully", value: "Your wallet has been added successfully!", comment: ""),
            time: 1.5
          )
          self.fetchWalletList()
        } else {
          self.showErrorTopBannerMessage(
            with: NSLocalizedString("failed", value: "Failed", comment: ""),
            message: message,
            time: 1.5
          )
        }
      case .failure(let error):
        self.displayError(error: error)
      }
    }
  }

  @IBAction func addPriceAlertButtonPressed(_ sender: Any) {
    KNCrashlyticsUtil.logCustomEvent(withName: "profile_kyc", customAttributes: ["value": "add_alert"])
    self.delegate?.profileHomeViewController(self, run: .addPriceAlert)
  }

  @IBAction func moreAlertsButtonPressed(_ sender: Any) {
    KNCrashlyticsUtil.logCustomEvent(withName: "profile_kyc", customAttributes: ["value": "more_alerts"])
    self.delegate?.profileHomeViewController(self, run: .managePriceAlerts)
  }

  @IBAction func leaderBoardButtonPressed(_ sender: Any) {
    KNCrashlyticsUtil.logCustomEvent(withName: "profile_kyc", customAttributes: ["value": "leader_board"])
    self.delegate?.profileHomeViewController(self, run: .leaderBoard)
  }
}

extension KNProfileHomeViewController {
  func coordinatorUserDidSignInSuccessfully() {
    self.notSignInView.isHidden = self.viewModel.isUserSignedIn
    self.signedInView.isHidden = !self.viewModel.isUserSignedIn
    self.updateUIUserDidSignedIn()
  }

  func coordinatorDidSignOut() {
    self.notSignInView.isHidden = self.viewModel.isUserSignedIn
    self.signedInView.isHidden = !self.viewModel.isUserSignedIn
  }
}

extension KNProfileHomeViewController: UITableViewDelegate {
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    KNCrashlyticsUtil.logCustomEvent(withName: "profile_kyc", customAttributes: ["value": "open_address_on_etherscan"])
    if indexPath.row < self.viewModel.wallets.count {
      let address = self.viewModel.wallets[indexPath.row].1
      self.openSafari(with: KNEnvironment.default.etherScanIOURLString + "address/\(address)")
    }
  }
}

extension KNProfileHomeViewController: UITableViewDataSource {
  func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return self.viewModel.wallets.count
  }

  func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
    return UIView()
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: kWalletTableViewCellID, for: indexPath)
    cell.textLabel?.isUserInteractionEnabled = false
    cell.tintColor = UIColor.Kyber.shamrock
    let wallet = self.viewModel.wallets[indexPath.row]
    cell.textLabel?.attributedText = {
      let attributedString = NSMutableAttributedString()
      let nameAttributes: [NSAttributedStringKey: Any] = [
        NSAttributedStringKey.font: UIFont.Kyber.medium(with: 14),
        NSAttributedStringKey.foregroundColor: UIColor.Kyber.mirage,
        NSAttributedStringKey.kern: 0.0,
      ]
      let addressAttributes: [NSAttributedStringKey: Any] = [
        NSAttributedStringKey.font: UIFont.Kyber.medium(with: 14),
        NSAttributedStringKey.foregroundColor: UIColor.Kyber.grayChateau,
        NSAttributedStringKey.kern: 0.0,
      ]
      attributedString.append(NSAttributedString(string: "    \(wallet.0)", attributes: nameAttributes))
      let addressString: String = "      \(wallet.1.prefix(16))...\(wallet.1.suffix(10))"
      attributedString.append(NSAttributedString(string: "\n\(addressString)", attributes: addressAttributes))
      return attributedString
    }()
    cell.textLabel?.numberOfLines = 2
    cell.backgroundColor = {
      return indexPath.row % 2 == 0 ? UIColor(red: 242, green: 243, blue: 246) : UIColor.Kyber.whisper
    }()
    return cell
  }
}

extension KNProfileHomeViewController: QRCodeReaderDelegate {
  func readerDidCancel(_ reader: QRCodeReaderViewController!) {
    reader.dismiss(animated: true, completion: nil)
  }

  func reader(_ reader: QRCodeReaderViewController!, didScanResult result: String!) {
    reader.dismiss(animated: true) {
      self.addWalletAddressTextField.text = result
    }
  }
}

extension KNProfileHomeViewController: KNAlertTableViewDelegate {
  func alertTableView(_ tableView: UITableView, run event: KNAlertTableViewEvent) {
    switch event {
    case .update(let height):
      self.updatePriceAlertsView(tableViewHeight: height)
    case .delete(let alert):
      let message = alert.hasReward ? "This alert is eligible for a reward from the current competition. Do you still want to delete?".toBeLocalised() : "Do you want to delete this alert?".toBeLocalised()
      let alertController = UIAlertController(title: NSLocalizedString("delete", value: "Delete", comment: ""), message: message, preferredStyle: .alert)
      alertController.addAction(UIAlertAction(title: NSLocalizedString("cancel", value: "Cancel", comment: ""), style: .cancel, handler: nil))
      alertController.addAction(UIAlertAction(title: NSLocalizedString("delete", value: "Delete", comment: ""), style: .destructive, handler: { _ in
        self.deleteAnAlert(alert)
      }))
      self.present(alertController, animated: true, completion: nil)
    case .edit(let alert):
      self.delegate?.profileHomeViewController(self, run: .editAlert(alert: alert))
    case .select(let alert):
      self.delegate?.profileHomeViewController(self, run: .editAlert(alert: alert))
    }
  }

  fileprivate func deleteAnAlert(_ alert: KNAlertObject) {
    KNCrashlyticsUtil.logCustomEvent(withName: "profile_kyc", customAttributes: ["value": "delete_alert"])
    guard let accessToken = IEOUserStorage.shared.user?.accessToken else { return }
    self.displayLoading()
    KNPriceAlertCoordinator.shared.removeAnAlert(accessToken: accessToken, alertID: alert.id) { [weak self] (_, error) in
      guard let `self` = self else { return }
      self.hideLoading()
      if let error = error {
        KNCrashlyticsUtil.logCustomEvent(withName: "profile_kyc", customAttributes: ["value": "delete_alert_failed", "error": error])
        self.showErrorTopBannerMessage(
          with: NSLocalizedString("error", value: "Error", comment: ""),
          message: error,
          time: 1.5
        )
      } else {
        self.showSuccessTopBannerMessage(
          with: "",
          message: "Alert deleted!".toBeLocalised(),
          time: 1.0
        )
      }
    }
  }
}
