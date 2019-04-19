// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import BigInt
import Result
import Crashlytics

//swiftlint:disable file_length

enum KSwapViewEvent {
  case searchToken(from: TokenObject, to: TokenObject, isSource: Bool)
  case estimateRate(from: TokenObject, to: TokenObject, amount: BigInt, showError: Bool)
  case estimateComparedRate(from: TokenObject, to: TokenObject) // compare to show warning
  case estimateGas(from: TokenObject, to: TokenObject, amount: BigInt, gasPrice: BigInt)
  case getUserCapInWei
  case setGasPrice(gasPrice: BigInt, gasLimit: BigInt)
  case validateRate(data: KNDraftExchangeTransaction)
  case swap(data: KNDraftExchangeTransaction)
  case showQRCode
}

protocol KSwapViewControllerDelegate: class {
  func kSwapViewController(_ controller: KSwapViewController, run event: KSwapViewEvent)
  func kSwapViewController(_ controller: KSwapViewController, run event: KNBalanceTabHamburgerMenuViewEvent)
}

class KSwapViewController: KNBaseViewController {

  fileprivate var isViewSetup: Bool = false
  fileprivate var isErrorMessageEnabled: Bool = false

  fileprivate var viewModel: KSwapViewModel
  weak var delegate: KSwapViewControllerDelegate?

  @IBOutlet weak var scrollContainerView: UIScrollView!

  @IBOutlet weak var headerContainerView: UIView!
  @IBOutlet weak var walletNameLabel: UILabel!
  @IBOutlet weak var dataContainerView: UIView!
  @IBOutlet weak var fromTokenButton: UIButton!

  @IBOutlet weak var hasPendingTxView: UIView!
  @IBOutlet weak var balanceTextLabel: UILabel! // "\(symbol) balance"
  @IBOutlet weak var balanceLabel: UILabel!
  @IBOutlet weak var toTokenButton: UIButton!

  @IBOutlet weak var fromAmountTextField: UITextField!
  @IBOutlet weak var equivalentUSDValueLabel: UILabel!
  @IBOutlet weak var toAmountTextField: UITextField!

  @IBOutlet weak var rateTextLabel: UILabel!
  @IBOutlet weak var exchangeRateLabel: UILabel!
  @IBOutlet weak var loadingRateIndicator: UIActivityIndicatorView!

  @IBOutlet weak var warningRateContainerView: UIView!
  @IBOutlet weak var warningRatePercent: UIButton!

  @IBOutlet weak var advancedSettingsView: KAdvancedSettingsView!
  @IBOutlet weak var heightConstraintForAdvacedSettingsView: NSLayoutConstraint!

  @IBOutlet weak var bottomPaddingConstraintForScrollView: NSLayoutConstraint!

  @IBOutlet weak var continueButton: UIButton!

  fileprivate var estRateTimer: Timer?
  fileprivate var estGasLimitTimer: Timer?
  fileprivate var getUserCapTimer: Timer?

  lazy var hamburgerMenu: KNBalanceTabHamburgerMenuViewController = {
    let viewModel = KNBalanceTabHamburgerMenuViewModel(
      walletObjects: KNWalletStorage.shared.wallets,
      currentWallet: self.viewModel.walletObject
    )
    let hamburgerVC = KNBalanceTabHamburgerMenuViewController(viewModel: viewModel)
    hamburgerVC.view.frame = self.view.bounds
    self.view.addSubview(hamburgerVC.view)
    self.addChildViewController(hamburgerVC)
    hamburgerVC.didMove(toParentViewController: self)
    hamburgerVC.delegate = self
    return hamburgerVC
  }()

  lazy var toolBar: KNCustomToolbar = {
    return KNCustomToolbar(
      leftBtnTitle: NSLocalizedString("swap.all", value: "Swap All", comment: ""),
      rightBtnTitle: NSLocalizedString("done", value: "Done", comment: ""),
      barTintColor: UIColor.Kyber.enygold,
      delegate: self)
  }()

  deinit {
    self.removeObserveNotification()
  }

  init(viewModel: KSwapViewModel) {
    self.viewModel = viewModel
    super.init(nibName: KSwapViewController.className, bundle: nil)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    self.headerContainerView.applyGradient(with: UIColor.Kyber.headerColors)
    self.continueButton.applyGradient()

    self.addObserveNotifications()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    if !self.isViewSetup {
      self.isViewSetup = true
      self.setupUI()
    }
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    self.dataContainerView.addShadow(
      color: UIColor.black.withAlphaComponent(0.6),
      offset: CGSize(width: 0, height: 7),
      opacity: 0.32,
      radius: 32
    )
    self.advancedSettingsView.layoutSubviews()
    self.headerContainerView.removeSublayer(at: 0)
    self.headerContainerView.applyGradient(with: UIColor.Kyber.headerColors)
    self.continueButton.removeSublayer(at: 0)
    self.continueButton.applyGradient()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    self.isErrorMessageEnabled = true
    // start update est rate
    self.estRateTimer?.invalidate()
    self.updateEstimatedRate(showError: true, showLoading: true)
    self.estRateTimer = Timer.scheduledTimer(
      withTimeInterval: KNLoadingInterval.defaultLoadingInterval,
      repeats: true,
      block: { [weak self] _ in
        self?.updateEstimatedRate()
      }
    )

    // start update est gas limit
    self.estGasLimitTimer?.invalidate()
    self.updateEstimatedGasLimit()
    self.estGasLimitTimer = Timer.scheduledTimer(
      withTimeInterval: KNLoadingInterval.defaultLoadingInterval,
      repeats: true,
      block: { [weak self] _ in
        self?.updateEstimatedGasLimit()
      }
    )

    self.getUserCapTimer?.invalidate()
    self.updateUserCapInWei()
    self.getUserCapTimer = Timer.scheduledTimer(
      withTimeInterval: 30.0,
      repeats: true,
      block: { [weak self] _ in
      self?.updateUserCapInWei()
      }
    )

    self.updateExchangeRateField()
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    self.isErrorMessageEnabled = false
    self.view.endEditing(true)
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    self.estRateTimer?.invalidate()
    self.estRateTimer = nil
    self.estGasLimitTimer?.invalidate()
    self.estGasLimitTimer = nil
  }

  fileprivate func setupUI() {
    self.bottomPaddingConstraintForScrollView.constant = self.bottomPaddingSafeArea()
    self.walletNameLabel.text = self.viewModel.walletNameString
    self.setupTokensView()
    self.setupHamburgerMenu()
    self.setupAdvancedSettingsView()
    self.setupContinueButton()
  }

  fileprivate func setupTokensView() {
    self.dataContainerView.rounded(radius: 4)

    self.fromTokenButton.titleLabel?.numberOfLines = 2
    self.fromTokenButton.titleLabel?.lineBreakMode = .byTruncatingTail
    self.toTokenButton.titleLabel?.numberOfLines = 2
    self.toTokenButton.titleLabel?.lineBreakMode = .byTruncatingTail

    self.fromAmountTextField.text = ""
    self.fromAmountTextField.adjustsFontSizeToFitWidth = true
    self.fromAmountTextField.inputAccessoryView = self.toolBar
    self.fromAmountTextField.delegate = self

    self.viewModel.updateAmount("", isSource: true)
    self.balanceTextLabel.text = self.viewModel.balanceTextString
    self.rateTextLabel.text = NSLocalizedString("rate", value: "Rate", comment: "").uppercased()

    self.toAmountTextField.text = ""
    self.toAmountTextField.adjustsFontSizeToFitWidth = true
    self.toAmountTextField.inputAccessoryView = self.toolBar
    self.toAmountTextField.delegate = self

    self.viewModel.updateAmount("", isSource: false)

    let tapBalanceGesture = UITapGestureRecognizer(target: self, action: #selector(self.balanceLabelTapped(_:)))
    self.balanceLabel.addGestureRecognizer(tapBalanceGesture)

    self.updateTokensView()
  }

  fileprivate func setupHamburgerMenu() {
    self.hasPendingTxView.rounded(radius: self.hasPendingTxView.frame.height / 2.0)
    self.hamburgerMenu.hideMenu(animated: false)
  }

  fileprivate func setupAdvancedSettingsView() {
    let isPromo = KNWalletPromoInfoStorage.shared.getDestWallet(from: self.viewModel.walletObject.address) != nil
    let viewModel = KAdvancedSettingsViewModel(hasMinRate: true, isPromo: isPromo)
    viewModel.updateGasPrices(
      fast: KNGasCoordinator.shared.fastKNGas,
      medium: KNGasCoordinator.shared.standardKNGas,
      slow: KNGasCoordinator.shared.lowKNGas
    )
    viewModel.updateMinRateValue(self.viewModel.estimatedRateDouble, percent: self.viewModel.minRatePercent)
    viewModel.updateViewHidden(isHidden: true)
    viewModel.updatePairToken("\(self.viewModel.from.symbol)-\(self.viewModel.to.symbol)")
    self.advancedSettingsView.updateViewModel(viewModel)
    self.heightConstraintForAdvacedSettingsView.constant = self.advancedSettingsView.height
    self.advancedSettingsView.delegate = self
    self.view.setNeedsUpdateConstraints()
    self.view.updateConstraints()
  }

  fileprivate func setupContinueButton() {
    let style = KNAppStyleType.current
    let radius = style.buttonRadius(for: self.continueButton.frame.height)
    self.continueButton.rounded(radius: radius)
    self.continueButton.setTitle(
      NSLocalizedString("continue", value: "Continue", comment: ""),
      for: .normal
    )
  }

  @IBAction func hamburgerMenuPressed(_ sender: Any) {
    KNCrashlyticsUtil.logCustomEvent(withName: "kyberswap", customAttributes: ["type": "hamburger_menu"])
    self.view.endEditing(true)
    self.hamburgerMenu.openMenu(animated: true)
  }

  @IBAction func fromTokenButtonPressed(_ sender: UIButton) {
    KNCrashlyticsUtil.logCustomEvent(withName: "kyberswap", customAttributes: ["type": "from_token_pressed"])
    let event = KSwapViewEvent.searchToken(
      from: self.viewModel.from,
      to: self.viewModel.to,
      isSource: true
    )
    self.delegate?.kSwapViewController(self, run: event)
  }

  @IBAction func toTokenButtonPressed(_ sender: UIButton) {
    KNCrashlyticsUtil.logCustomEvent(withName: "kyberswap", customAttributes: ["type": "to_token_pressed"])
    let event = KSwapViewEvent.searchToken(
      from: self.viewModel.from,
      to: self.viewModel.to,
      isSource: false
    )
    self.delegate?.kSwapViewController(self, run: event)
  }

  @IBAction func swapButtonPressed(_ sender: UIButton) {
    KNCrashlyticsUtil.logCustomEvent(withName: "kyberswap", customAttributes: ["type": "swap_2_tokens"])
    if !self.viewModel.isFromTokenBtnEnabled { return }
    self.viewModel.swapTokens()
    self.fromAmountTextField.text = ""
    self.toAmountTextField.text = ""
    self.viewModel.updateAmount("", isSource: true)
    self.viewModel.updateAmount("", isSource: false)
    self.updateTokensView()
  }

  @IBAction func warningRateButtonPressed(_ sender: Any) {
    guard let string = self.viewModel.differentRatePercentageDisplay else { return }
    let message = String(format: NSLocalizedString("This rate is %@ lower than current Market", value: "This rate is %@ lower than current Market", comment: ""), string)
    self.showWarningTopBannerMessage(
      with: "",
      message: message,
      time: 2.0
    )
  }

  @objc func prodCachedRateFailedToLoad(_ sender: Any?) {
    let event = KSwapViewEvent.estimateComparedRate(
      from: self.viewModel.from,
      to: self.viewModel.to
    )
    self.delegate?.kSwapViewController(self, run: event)
  }

  /*
   Continue token pressed
   - check amount valid (> 0 and <= balance)
   - check rate is valie (not zero)
   - (Temp) either from or to must be ETH
   - send exchange tx to coordinator for preparing trade
   */
  @IBAction func continueButtonPressed(_ sender: UIButton) {
    KNCrashlyticsUtil.logCustomEvent(withName: "kyberswap", customAttributes: ["type": "continue_\(self.viewModel.from.symbol)_\(self.viewModel.to.symbol)"])
    self.validateDataBeforeContinuing(hasCallValidateRate: false)
  }

  fileprivate func validateDataBeforeContinuing(hasCallValidateRate: Bool) {
    if self.showWarningDataInvalidIfNeeded(isConfirming: true) { return }
    let rate = self.viewModel.estRate ?? BigInt(0)
    let amount: BigInt = {
      if self.viewModel.isFocusingFromAmount { return self.viewModel.amountFromBigInt }
      let expectedExchange: BigInt = {
        if rate.isZero { return rate }
        let amount = self.viewModel.amountToBigInt
        return amount * BigInt(10).power(self.viewModel.from.decimals) / rate
      }()
      return expectedExchange
    }()
    let exchange = KNDraftExchangeTransaction(
      from: self.viewModel.from,
      to: self.viewModel.to,
      amount: amount,
      maxDestAmount: BigInt(2).power(255),
      expectedRate: rate,
      minRate: self.viewModel.minRate,
      gasPrice: self.viewModel.gasPrice,
      gasLimit: self.viewModel.estimateGasLimit,
      expectedReceivedString: self.viewModel.amountTo
    )
    if !hasCallValidateRate {
      self.delegate?.kSwapViewController(self, run: .validateRate(data: exchange))
    } else {
      self.delegate?.kSwapViewController(self, run: .swap(data: exchange))
    }
  }

  @IBAction func screenEdgePanGestureAction(_ sender: UIScreenEdgePanGestureRecognizer) {
    self.hamburgerMenu.gestureScreenEdgePanAction(sender)
  }

  @objc func keyboardSwapAllButtonPressed(_ sender: Any) {
    KNCrashlyticsUtil.logCustomEvent(withName: "kyberswap", customAttributes: ["type": "swap_all"])
    self.view.endEditing(true)
    self.viewModel.updateFocusingField(true)
    self.fromAmountTextField.text = self.viewModel.allFromTokenBalanceString.removeGroupSeparator()
    self.viewModel.updateAmount(self.fromAmountTextField.text ?? "", isSource: true)
    self.updateTokensView()
    self.updateViewAmountDidChange()
    if self.viewModel.from.isETH {
      self.showSuccessTopBannerMessage(
        with: "",
        message: NSLocalizedString("a.small.amount.of.eth.is.used.for.transaction.fee", value: "A small amount of ETH will be used for transaction fee", comment: ""),
        time: 1.5
      )
    }
    self.view.layoutIfNeeded()
  }

  @objc func keyboardDoneButtonPressed(_ sender: Any) {
    self.view.endEditing(true)
    self.view.layoutIfNeeded()
  }

  func coordinatorUpdateGasPriceCached() {
    self.viewModel.updateSelectedGasPriceType(self.viewModel.selectedGasPriceType)
    self.updateAdvancedSettingsView()
  }

  fileprivate func updateEstimatedRate(showError: Bool = false, showLoading: Bool = false) {
    self.loadingRateIndicator.startAnimating()
    if showLoading { self.loadingRateIndicator.isHidden = false }
    let event = KSwapViewEvent.estimateRate(
      from: self.viewModel.from,
      to: self.viewModel.to,
      amount: self.viewModel.amountToEstimate,
      showError: showError
    )
    self.delegate?.kSwapViewController(self, run: event)
  }

  fileprivate func updateEstimatedGasLimit() {
    let event = KSwapViewEvent.estimateGas(
      from: self.viewModel.from,
      to: self.viewModel.to,
      amount: self.viewModel.amountToEstimate,
      gasPrice: self.viewModel.gasPrice
    )
    self.delegate?.kSwapViewController(self, run: event)
  }

  fileprivate func updateUserCapInWei() {
    self.delegate?.kSwapViewController(self, run: .getUserCapInWei)
  }

  /*
   Return true if data is invalid and a warning message is shown,
   false otherwise
  */
  fileprivate func showWarningDataInvalidIfNeeded(isConfirming: Bool = false) -> Bool {
    if !isConfirming && !self.isErrorMessageEnabled || !self.hamburgerMenu.view.isHidden { return false }
    if !isConfirming && (self.fromAmountTextField.isEditing || self.toAmountTextField.isEditing) { return false }
    guard self.viewModel.from != self.viewModel.to else {
      self.showWarningTopBannerMessage(
        with: NSLocalizedString("unsupported", value: "Unsupported", comment: ""),
        message: NSLocalizedString("can.not.swap.same.token", value: "Can not swap the same token", comment: ""),
        time: 1.5
      )
      return true
    }
    guard !self.viewModel.amountFrom.isEmpty else {
      self.showWarningTopBannerMessage(
        with: NSLocalizedString("invalid.input", value: "Invalid input", comment: ""),
        message: NSLocalizedString("please.enter.an.amount.to.continue", value: "Please enter an amount to continue", comment: "")
      )
      return true
    }
    if self.viewModel.estRate?.isZero == true {
      self.showWarningTopBannerMessage(
        with: NSLocalizedString("invalid.amount", value: "Invalid amount", comment: ""),
        message: NSLocalizedString("can.not.handle.your.amount", value: "Can not handle your amount", comment: "")
      )
      return true
    }
    guard self.viewModel.isBalanceEnough else {
      self.showWarningTopBannerMessage(
        with: NSLocalizedString("amount.too.big", value: "Amount too big", comment: ""),
        message: NSLocalizedString("balance.not.enough.to.make.transaction", value: "Balance is not enough to make the transaction.", comment: "")
      )
      return true
    }
    guard !self.viewModel.isAmountTooSmall else {
      self.showWarningTopBannerMessage(
        with: NSLocalizedString("invalid.amount", value: "Invalid amount", comment: ""),
        message: NSLocalizedString("amount.too.small.to.perform.swap", value: "Amount too small to perform swap, minimum equivalent to 0.001 ETH", comment: "")
      )
      return true
    }
    guard self.viewModel.isCapEnough else {
      self.showWarningTopBannerMessage(
        with: NSLocalizedString("amount.too.big", value: "Amount too big", comment: ""),
        message: NSLocalizedString("your.cap.has.reached.increase.by.completing.kyc", value: "Your cap has reached. Increase your cap by completing KYC.", comment: ""),
        time: 2.0
      )
      return true
    }
    if isConfirming {
      guard self.viewModel.isHavingEnoughETHForFee else {
        self.showWarningTopBannerMessage(
          with: NSLocalizedString("insufficient.eth", value: "Insufficient ETH", comment: ""),
          message: NSLocalizedString("not.have.enought.eth.to.pay.transaction.fee", value: "Not have enough ETH to pay for transaction fee", comment: "")
        )
        return true
      }
      guard self.viewModel.isSlippageRateValid else {
        self.showWarningTopBannerMessage(
          with: NSLocalizedString("invalid.amount", value: "Invalid amount", comment: ""),
          message: NSLocalizedString("can.not.handle.your.amount", value: "Can not handle your amount", comment: "")
        )
        return true
      }
      guard self.viewModel.estRate != nil, self.viewModel.estRate?.isZero == false else {
        self.showWarningTopBannerMessage(
          with: NSLocalizedString("rate.might.change", value: "Rate might change", comment: ""),
          message: NSLocalizedString("please.wait.for.expected.rate.updated", value: "Please wait for expected rate to be updated", comment: "")
        )
        return true
      }
    }
    return false
  }
}

// MARK: Update UIs
extension KSwapViewController {
  /*
   Update tokens view when either from or to tokens changed
   - updatedFrom: true if from token is changed
   - updatedTo: true if to token is changed
   */
  func updateTokensView(updatedFrom: Bool = true, updatedTo: Bool = true) {
    if updatedFrom {
      self.fromTokenButton.setAttributedTitle(
        self.viewModel.tokenButtonAttributedText(isSource: true),
        for: .normal
      )
      self.fromTokenButton.setTokenImage(
        token: self.viewModel.from,
        size: self.viewModel.defaultTokenIconImg?.size
      )
      self.balanceTextLabel.text = self.viewModel.balanceTextString
    }
    if updatedTo {
      self.toTokenButton.setAttributedTitle(
        self.viewModel.tokenButtonAttributedText(isSource: false),
        for: .normal
      )
      self.toTokenButton.setTokenImage(
        token: self.viewModel.to,
        size: self.viewModel.defaultTokenIconImg?.size
      )
    }
    self.viewModel.updateEstimatedRateFromCachedIfNeeded()
    // call update est rate from node
    self.updateEstimatedRate(showError: updatedFrom || updatedTo, showLoading: updatedFrom || updatedTo)

    self.balanceLabel.text = self.viewModel.balanceText

    self.updateExchangeRateField()

    if !self.fromAmountTextField.isEditing && self.viewModel.isFocusingFromAmount {
      self.fromAmountTextField.textColor = self.viewModel.amountTextFieldColor
      self.toAmountTextField.textColor = UIColor.Kyber.mirage
    }
    if !self.toAmountTextField.isEditing && !self.viewModel.isFocusingFromAmount {
      self.toAmountTextField.textColor = self.viewModel.amountTextFieldColor
      self.fromAmountTextField.textColor = UIColor.Kyber.mirage
    }
    self.updateAdvancedSettingsView()

    // update tokens button in case promo wallet
    self.toTokenButton.isEnabled = self.viewModel.isToTokenBtnEnabled
    self.fromTokenButton.isEnabled = self.viewModel.isFromTokenBtnEnabled

    self.equivalentUSDValueLabel.text = self.viewModel.displayEquivalentUSDAmount
    self.view.layoutIfNeeded()
  }

  fileprivate func updateExchangeRateField() {
    self.exchangeRateLabel.text = self.viewModel.exchangeRateText
    let warningRate: String? = self.viewModel.differentRatePercentageDisplay
    self.warningRateContainerView.isHidden = warningRate == nil
    self.warningRatePercent.setTitle(warningRate, for: .normal)
  }

  fileprivate func updateAdvancedSettingsView() {
    let rate = self.viewModel.estimatedRateDouble
    let percent = self.viewModel.minRatePercent
    self.advancedSettingsView.updatePairToken("\(self.viewModel.from.symbol)-\(self.viewModel.to.symbol)")
    self.advancedSettingsView.updateMinRate(rate, percent: percent)

    self.advancedSettingsView.updateGasPrices(
      fast: KNGasCoordinator.shared.fastKNGas,
      medium: KNGasCoordinator.shared.standardKNGas,
      slow: KNGasCoordinator.shared.lowKNGas
    )
    self.view.layoutIfNeeded()
  }

  @objc func balanceLabelTapped(_ sender: Any) {
    self.keyboardSwapAllButtonPressed(sender)
  }
}

extension KSwapViewController {
  fileprivate func addObserveNotifications() {
    let name = Notification.Name(kProdCachedRateFailedToLoadNotiKey)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(self.prodCachedRateFailedToLoad(_:)),
      name: name,
      object: nil
    )
  }

  fileprivate func removeObserveNotification() {
    let name = Notification.Name(kProdCachedRateFailedToLoadNotiKey)
    NotificationCenter.default.removeObserver(self, name: name, object: nil)
  }
}

// MARK: Update from coordinator
extension KSwapViewController {
  /*
   Update new session when current wallet is changed, update all UIs
   */
  func coordinatorUpdateNewSession(wallet: Wallet) {
    self.viewModel.updateWallet(wallet)
    self.walletNameLabel.text = self.viewModel.walletNameString
    self.fromAmountTextField.text = ""
    self.toAmountTextField.text = ""
    self.viewModel.updateAmount("", isSource: true)
    self.viewModel.updateAmount("", isSource: false)
    self.updateTokensView()
    self.updateViewAmountDidChange()
    self.updateAdvancedSettingsView()
    let isPromo = KNWalletPromoInfoStorage.shared.getDestinationToken(from: wallet.address.description) != nil
    self.advancedSettingsView.updateIsPromoWallet(isPromo)
    self.hamburgerMenu.update(
      walletObjects: KNWalletStorage.shared.wallets,
      currentWallet: self.viewModel.walletObject
    )
    self.hamburgerMenu.hideMenu(animated: false)
    self.view.layoutIfNeeded()
  }

  func coordinatorUpdateWalletObjects() {
    self.viewModel.updateWalletObject()
    self.walletNameLabel.text = self.viewModel.walletNameString
    self.hamburgerMenu.update(
      walletObjects: KNWalletStorage.shared.wallets,
      currentWallet: self.viewModel.walletObject
    )
    self.view.layoutIfNeeded()
  }

  func coordinatorUpdateTokenBalance(_ balances: [String: Balance]) {
    self.viewModel.updateBalance(balances)
    self.balanceLabel.text = self.viewModel.balanceText
    if !self.fromAmountTextField.isEditing && self.viewModel.isFocusingFromAmount {
      self.fromAmountTextField.textColor = self.viewModel.amountTextFieldColor
      self.toAmountTextField.textColor = UIColor.Kyber.mirage
    } else if !self.toAmountTextField.isEditing && !self.viewModel.isFocusingFromAmount {
      self.toAmountTextField.textColor = self.viewModel.amountTextFieldColor
      self.fromAmountTextField.textColor = UIColor.Kyber.mirage
    }
    self.view.layoutIfNeeded()
  }

  /*
   Update estimate rate, check if the from, to, amount are all the same as current value in the model
   Update UIs according to new values
   */
  func coordinatorDidUpdateEstimateRate(from: TokenObject, to: TokenObject, amount: BigInt, rate: BigInt, slippageRate: BigInt) {
    let updated = self.viewModel.updateExchangeRate(
      for: from,
      to: to,
      amount: amount,
      rate: rate,
      slippageRate: slippageRate
    )
    self.updateExchangeRateField()
    if self.viewModel.isFocusingFromAmount {
      self.toAmountTextField.text = self.viewModel.expectedReceivedAmountText
      self.viewModel.updateAmount(self.toAmountTextField.text ?? "", isSource: false)
    } else {
      self.fromAmountTextField.text = self.viewModel.expectedExchangeAmountText
      self.viewModel.updateAmount(self.fromAmountTextField.text ?? "", isSource: true)
    }
    if !self.fromAmountTextField.isEditing && self.viewModel.isFocusingFromAmount {
      self.fromAmountTextField.textColor = self.viewModel.amountTextFieldColor
      self.toAmountTextField.textColor = UIColor.Kyber.mirage
    } else if !self.toAmountTextField.isEditing && !self.viewModel.isFocusingFromAmount {
      self.toAmountTextField.textColor = self.viewModel.amountTextFieldColor
      self.fromAmountTextField.textColor = UIColor.Kyber.mirage
    }

    self.updateAdvancedSettingsView()
    self.equivalentUSDValueLabel.text = self.viewModel.displayEquivalentUSDAmount
    if updated { self.loadingRateIndicator.isHidden = true }
    self.view.layoutIfNeeded()
  }

  /*
   Update estimate gas limit, check if the from, to, amount are all the same as current value in the model    Update UIs according to new values
   */
  func coordinatorDidUpdateEstimateGasUsed(from: TokenObject, to: TokenObject, amount: BigInt, gasLimit: BigInt) {
    self.viewModel.updateEstimateGasLimit(
      for: from,
      to: to,
      amount: amount,
      gasLimit: gasLimit
    )
  }

  /*
   Update user cap in wei
   */

  func coordinatorUpdateUserCapInWei(cap: BigInt) {
    self.viewModel.updateUserCapInWei(cap: cap)
    if !self.fromAmountTextField.isEditing && self.viewModel.isFocusingFromAmount {
      self.fromAmountTextField.textColor = self.viewModel.amountTextFieldColor
      self.toAmountTextField.textColor = UIColor.Kyber.mirage
    }
    if !self.toAmountTextField.isEditing && !self.viewModel.isFocusingFromAmount {
      self.toAmountTextField.textColor = self.viewModel.amountTextFieldColor
      self.fromAmountTextField.textColor = UIColor.Kyber.mirage
    }
    self.view.layoutIfNeeded()
  }
  /*
   Update selected token
   - token: New selected token
   - isSource: true if selected token is from, otherwise it is to
   Update UIs according to new values
   */
  func coordinatorUpdateSelectedToken(_ token: TokenObject, isSource: Bool, isWarningShown: Bool = true) {
    if isSource, !self.fromTokenButton.isEnabled { return }
    if !isSource, !self.toTokenButton.isEnabled { return }
    if isSource, self.viewModel.from == token { return }
    if !isSource, self.viewModel.to == token { return }
    self.viewModel.updateSelectedToken(token, isSource: isSource)
    // support for promo wallet
    let isUpdatedTo: Bool = {
      if token.isPromoToken, isSource,
        let dest = KNWalletPromoInfoStorage.shared.getDestinationToken(from: self.viewModel.walletObject.address),
        let destToken = KNSupportedTokenStorage.shared.supportedTokens.first(where: { $0.symbol == dest.uppercased() }) {
        self.viewModel.updateSelectedToken(destToken, isSource: false)
        return true
      }
      return !isSource
    }()

    if self.viewModel.isFocusingFromAmount {
      self.fromAmountTextField.text = self.viewModel.amountFrom
      self.toAmountTextField.text = self.viewModel.expectedReceivedAmountText
    } else {
      self.toAmountTextField.text = self.viewModel.amountTo
      self.fromAmountTextField.text = self.viewModel.expectedExchangeAmountText
    }
    self.viewModel.updateAmount(self.fromAmountTextField.text ?? "", isSource: true)
    self.viewModel.updateAmount(self.toAmountTextField.text ?? "", isSource: false)
    self.updateTokensView(updatedFrom: isSource, updatedTo: isUpdatedTo)
    if self.viewModel.from == self.viewModel.to && isWarningShown {
      self.showWarningTopBannerMessage(
        with: NSLocalizedString("unsupported", value: "Unsupported", comment: ""),
        message: NSLocalizedString("can.not.swap.same.token", value: "Can not swap the same token", comment: ""),
        time: 1.5
      )
    }
    self.view.layoutIfNeeded()
  }

  /*
   Result from sending exchange token
   */
  func coordinatorExchangeTokenDidReturn(result: Result<String, AnyError>) {
    if case .failure(let error) = result {
      self.displayError(error: error)
    }
  }

  /*
  Rate validate for swapping
   */
  func coordinatorDidValidateRate() {
    self.validateDataBeforeContinuing(hasCallValidateRate: true)
  }

  /*
   Show transaction status after user confirmed transaction
   */
  func coordinatorExchangeTokenUserDidConfirmTransaction() {
    // Reset exchange amount
    self.viewModel.updateAmount("", isSource: true)
    self.viewModel.updateAmount("", isSource: false)
    self.viewModel.updateFocusingField(true)
    self.toAmountTextField.text = ""
    self.fromAmountTextField.text = ""
    self.equivalentUSDValueLabel.text = self.viewModel.displayEquivalentUSDAmount
    self.updateExchangeRateField()
    self.view.layoutIfNeeded()
  }

  func coordinatorTrackerRateDidUpdate() {
    self.equivalentUSDValueLabel.text = self.viewModel.displayEquivalentUSDAmount
    self.updateExchangeRateField()
  }

  func coordinatorUpdateProdCachedRates() {
    self.viewModel.updateProdCachedRate()
    self.updateExchangeRateField()
  }

  func coordinatorUpdateComparedRateFromNode(from: TokenObject, to: TokenObject, rate: BigInt) {
    if self.viewModel.from == from, self.viewModel.to == to {
      self.viewModel.updateProdCachedRate(rate)
      self.updateExchangeRateField()
    }
  }

  /*
   - gasPrice: new gas price after user finished selected gas price from set gas price view
   */
  func coordinatorExchangeTokenDidUpdateGasPrice(_ gasPrice: BigInt?) {
    if let gasPrice = gasPrice {
      self.viewModel.updateGasPrice(gasPrice)
    }
    self.view.layoutIfNeeded()
  }

  func coordinatorDidUpdatePendingTransactions(_ transactions: [KNTransaction]) {
    self.hamburgerMenu.update(transactions: transactions)
    self.hasPendingTxView.isHidden = transactions.isEmpty
    self.view.layoutIfNeeded()
  }
}

// MARK: UITextFieldDelegate
extension KSwapViewController: UITextFieldDelegate {
  func textFieldShouldClear(_ textField: UITextField) -> Bool {
    textField.text = ""
    self.viewModel.updateFocusingField(textField == self.fromAmountTextField)
    self.viewModel.updateAmount("", isSource: textField == self.fromAmountTextField)
    self.updateViewAmountDidChange()
    self.updateEstimatedRate(showError: true, showLoading: true)
    return false
  }

  func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
    let prevDest = self.toAmountTextField.text ?? ""
    let text = ((textField.text ?? "") as NSString).replacingCharacters(in: range, with: string).cleanStringToNumber()
    if textField == self.fromAmountTextField && text.fullBigInt(decimals: self.viewModel.from.decimals) == nil { return false }
    if textField == self.toAmountTextField && text.fullBigInt(decimals: self.viewModel.to.decimals) == nil { return false }
    textField.text = text
    self.viewModel.updateFocusingField(textField == self.fromAmountTextField)
    self.viewModel.updateAmount(text, isSource: textField == self.fromAmountTextField)
    self.updateViewAmountDidChange()
    if textField == self.toAmountTextField {
      let prevDestAmountBigInt = prevDest.removeGroupSeparator().fullBigInt(decimals: self.viewModel.to.decimals) ?? BigInt(0)
      self.updateRateDestAmountDidChangeIfNeeded(prevDest: prevDestAmountBigInt)
    }
    return false
  }

  func textFieldDidBeginEditing(_ textField: UITextField) {
    self.viewModel.updateFocusingField(textField == self.fromAmountTextField)
    if self.viewModel.isFocusingFromAmount {
      self.fromAmountTextField.textColor = UIColor.Kyber.merigold
      self.toAmountTextField.textColor = UIColor.Kyber.mirage
    } else {
      self.fromAmountTextField.textColor = UIColor.Kyber.mirage
      self.toAmountTextField.textColor = UIColor.Kyber.enygold
    }
  }

  func textFieldDidEndEditing(_ textField: UITextField) {
    if self.viewModel.isFocusingFromAmount {
      self.fromAmountTextField.textColor = self.viewModel.amountTextFieldColor
      self.toAmountTextField.textColor = UIColor.Kyber.mirage
    } else {
      self.toAmountTextField.textColor = self.viewModel.amountTextFieldColor
      self.fromAmountTextField.textColor = UIColor.Kyber.mirage
    }
    self.updateEstimatedRate(showError: true)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      _ = self.showWarningDataInvalidIfNeeded()
    }
  }

  fileprivate func updateViewAmountDidChange() {
    if self.viewModel.isFocusingFromAmount {
      self.toAmountTextField.text = self.viewModel.expectedReceivedAmountText
      self.viewModel.updateAmount(self.toAmountTextField.text ?? "", isSource: false)
    } else {
      self.fromAmountTextField.text = self.viewModel.expectedExchangeAmountText
      self.viewModel.updateAmount(self.fromAmountTextField.text ?? "", isSource: true)
    }
    self.updateEstimatedRate(showLoading: true)
    self.updateEstimatedGasLimit()
    if !self.fromAmountTextField.isEditing && self.viewModel.isFocusingFromAmount {
      self.fromAmountTextField.textColor = self.viewModel.amountTextFieldColor
      self.toAmountTextField.textColor = UIColor.Kyber.mirage
    }
    if !self.toAmountTextField.isEditing && !self.viewModel.isFocusingFromAmount {
      self.toAmountTextField.textColor = self.viewModel.amountTextFieldColor
      self.fromAmountTextField.textColor = UIColor.Kyber.mirage
    }
    self.equivalentUSDValueLabel.text = self.viewModel.displayEquivalentUSDAmount
    self.updateExchangeRateField()
    self.view.layoutIfNeeded()
  }

  fileprivate func updateRateDestAmountDidChangeIfNeeded(prevDest: BigInt) {
    let destAmount = self.viewModel.amountToBigInt
    let isChanged: Bool = {
      if prevDest.isZero { return !destAmount.isZero }
      let percent = (Double(destAmount) - Double(prevDest)) / Double(prevDest) * 100.0
      return fabs(percent) >= 1.0
    }()
    if !isChanged { return } // no need to call if change is small
    let isAmountBig: Bool = {
      let minAmount = BigInt(100) * BigInt(EthereumUnit.ether.rawValue) // should call api when amount is greater than 100
      let destAmountInETH: BigInt = {
        if self.viewModel.to.isETH { return destAmount }
        if let cachedRate = KNRateCoordinator.shared.getCachedProdRate(from: self.viewModel.to, to: self.viewModel.eth) {
          return cachedRate * destAmount / BigInt(10).power(self.viewModel.to.decimals)
        }
        return BigInt(0)
      }()
      return destAmountInETH > minAmount
    }()
    if !isAmountBig { return } // no need to call API
    KNRateCoordinator.shared.getCachedSourceAmount(
      from: self.viewModel.from,
      to: self.viewModel.to,
      destAmount: Double(destAmount) / pow(10.0, Double(self.viewModel.to.decimals))
    ) { [weak self] result in
      guard let `self` = self else { return }
      if case .success(let data) = result, let srcAmount = data, !srcAmount.isZero {
        let rate = destAmount * BigInt(10).power(self.viewModel.from.decimals) / srcAmount
        self.viewModel.updateAmount(
          srcAmount.fullString(decimals: self.viewModel.from.decimals).removeGroupSeparator(),
          isSource: true
        )
        self.viewModel.updateExchangeRate(
          for: self.viewModel.from,
          to: self.viewModel.to,
          amount: srcAmount,
          rate: rate,
          slippageRate: rate * BigInt(97) / BigInt(100)
        )
        self.updateTokensView(updatedFrom: false, updatedTo: false)
      }
      self.updateEstimatedRate(showError: true, showLoading: true)
    }
  }
}

// MARK: Advanced Settings View
extension KSwapViewController: KAdvancedSettingsViewDelegate {
  func kAdvancedSettingsView(_ view: KAdvancedSettingsView, run event: KAdvancedSettingsViewEvent) {
    switch event {
    case .displayButtonPressed:
      UIView.animate(
        withDuration: 0.32,
        animations: {
          self.heightConstraintForAdvacedSettingsView.constant = self.advancedSettingsView.height
          self.updateAdvancedSettingsView()
          self.view.layoutIfNeeded()
        }, completion: { _ in
          if self.advancedSettingsView.isExpanded {
            let bottomOffset = CGPoint(
              x: 0,
              y: self.scrollContainerView.contentSize.height - self.scrollContainerView.bounds.size.height
            )
            self.scrollContainerView.setContentOffset(bottomOffset, animated: true)
          }
        }
      )
    case .gasPriceChanged(let type, let value):
      self.viewModel.updateSelectedGasPriceType(type)
      self.viewModel.updateGasPrice(value)
    case .minRatePercentageChanged(let percent):
      self.viewModel.updateExchangeMinRatePercent(Double(percent))
      self.updateAdvancedSettingsView()
    case .infoPressed:
      let minRateDescVC: KMinAcceptableRatePopupViewController = {
        let viewModel = KMinAcceptableRatePopupViewModel(
          minRate: self.viewModel.slippageRateText ?? "0.0",
          symbol: self.viewModel.to.symbol
        )
        return KMinAcceptableRatePopupViewController(viewModel: viewModel)
      }()
      minRateDescVC.modalPresentationStyle = .overFullScreen
      minRateDescVC.modalTransitionStyle = .crossDissolve
      self.present(minRateDescVC, animated: true, completion: nil)
    }
  }
}

// MARK: Hamburger Menu Delegate
extension KSwapViewController: KNBalanceTabHamburgerMenuViewControllerDelegate {
  func balanceTabHamburgerMenuViewController(_ controller: KNBalanceTabHamburgerMenuViewController, run event: KNBalanceTabHamburgerMenuViewEvent) {
    self.delegate?.kSwapViewController(self, run: event)
  }
}

// MARK: Toolbar delegate
extension KSwapViewController: KNCustomToolbarDelegate {
  func customToolbarLeftButtonPressed(_ toolbar: KNCustomToolbar) {
    self.keyboardSwapAllButtonPressed(toolbar)
  }

  func customToolbarRightButtonPressed(_ toolbar: KNCustomToolbar) {
    self.keyboardDoneButtonPressed(toolbar)
  }
}
