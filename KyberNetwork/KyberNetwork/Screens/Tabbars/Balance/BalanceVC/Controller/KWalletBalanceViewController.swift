// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import BigInt
import Crashlytics

enum KWalletBalanceViewEvent {
  case openQRCode
  case selectToken(token: TokenObject)
  case buy(token: TokenObject)
  case sell(token: TokenObject)
  case send(token: TokenObject)
  case receiveToken
}

protocol KWalletBalanceViewControllerDelegate: class {
  func kWalletBalanceViewController(_ controller: KWalletBalanceViewController, run event: KWalletBalanceViewEvent)
  func kWalletBalanceViewController(_ controller: KWalletBalanceViewController, run menuEvent: KNBalanceTabHamburgerMenuViewEvent)
}

class KWalletBalanceViewController: KNBaseViewController {

  fileprivate var isViewSetup: Bool = false

  @IBOutlet weak var headerContainerView: UIView!
  @IBOutlet weak var walletDataView: UIView!
  @IBOutlet weak var balanceTextLabel: UILabel!
  @IBOutlet weak var balanceValueLabel: UILabel!
  @IBOutlet weak var walletNameLabel: UILabel!
  @IBOutlet weak var emptyStateView: UIView!
  @IBOutlet weak var emptyBalanceTextLabel: UILabel!

  @IBOutlet weak var hasPendingTxView: UIView!

  @IBOutlet weak var kyberListButton: UIButton!
  @IBOutlet weak var otherButton: UIButton!
  @IBOutlet weak var searchTextField: UITextField!
  @IBOutlet weak var currencyButton: UIButton!
  @IBOutlet weak var nameTextButton: UIButton!

  @IBOutlet weak var tokensBalanceTableView: UITableView!
  @IBOutlet weak var bottomPaddingConstraintForTableView: NSLayoutConstraint!

  fileprivate var viewModel: KWalletBalanceViewModel
  weak var delegate: KWalletBalanceViewControllerDelegate?

  lazy var hamburgerMenu: KNBalanceTabHamburgerMenuViewController = {
    let viewModel = KNBalanceTabHamburgerMenuViewModel(
      walletObjects: KNWalletStorage.shared.wallets,
      currentWallet: self.viewModel.wallet
    )
    let hamburgerVC = KNBalanceTabHamburgerMenuViewController(viewModel: viewModel)
    hamburgerVC.view.frame = self.view.bounds
    hamburgerVC.view.isHidden = true
    self.view.addSubview(hamburgerVC.view)
    self.addChildViewController(hamburgerVC)
    hamburgerVC.didMove(toParentViewController: self)
    hamburgerVC.delegate = self
    return hamburgerVC
  }()

  init(viewModel: KWalletBalanceViewModel) {
    self.viewModel = viewModel
    super.init(nibName: KWalletBalanceViewController.className, bundle: nil)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    self.headerContainerView.applyGradient(with: UIColor.Kyber.headerColors)
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
    self.headerContainerView.removeSublayer(at: 0)
    self.headerContainerView.applyGradient(with: UIColor.Kyber.headerColors)
  }

  // MARK: Set up UIs
  fileprivate func setupUI() {
    self.bottomPaddingConstraintForTableView.constant = self.bottomPaddingSafeArea()
    self.setupHamburgerMenu()
    self.setupWalletBalanceHeaderView()
    self.setupDisplayDataType()
    self.setupTokensBalanceTableView()
  }

  fileprivate func setupWalletBalanceHeaderView() {
    self.balanceTextLabel.text = NSLocalizedString("balance", value: "Balance", comment: "")
    self.balanceTextLabel.addLetterSpacing()
    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.openQRCodeViewPressed(_:)))
    self.walletDataView.addGestureRecognizer(tapGesture)
    self.updateWalletBalanceUI()
    self.updateWalletInfoUI()
  }

  fileprivate func setupHamburgerMenu() {
    self.hasPendingTxView.rounded(radius: self.hasPendingTxView.frame.height / 2.0)
    self.hasPendingTxView.isHidden = true
    self.hamburgerMenu.hideMenu(animated: false)
  }

  fileprivate func setupDisplayDataType() {
    self.nameTextButton.setTitle(
      NSLocalizedString("name", value: "Name", comment: ""),
      for: .normal
    )
    self.updateDisplayedDataType()
    self.searchTextField.delegate = self
  }

  fileprivate func setupTokensBalanceTableView() {
    let nib = UINib(nibName: KNBalanceTokenTableViewCell.className, bundle: nil)
    self.tokensBalanceTableView.register(
      nib,
      forCellReuseIdentifier: KNBalanceTokenTableViewCell.kCellID
    )
    self.tokensBalanceTableView.delegate = self
    self.tokensBalanceTableView.dataSource = self
    self.tokensBalanceTableView.rowHeight = KNBalanceTokenTableViewCell.kCellHeight
    self.tokensBalanceTableView.reloadData()

    self.emptyBalanceTextLabel.text = self.viewModel.textNoMatchingTokens
  }

  // MARK: Update UIs
  fileprivate func updateWalletInfoUI() {
    self.walletNameLabel.text = {
      let name = self.viewModel.wallet.name
      let address = "\(self.viewModel.wallet.address.prefix(6))...\(self.viewModel.wallet.address.suffix(4))"
      return "\(name) - \(address)"
    }()
    self.walletNameLabel.addLetterSpacing()
    self.view.layoutIfNeeded()
  }

  fileprivate func updateWalletBalanceUI() {
    self.balanceValueLabel.attributedText = self.viewModel.balanceDisplayAttributedString
    self.tokensBalanceTableView.isHidden = self.viewModel.displayedTokens.isEmpty
    self.emptyStateView.isHidden = !self.viewModel.displayedTokens.isEmpty
    self.view.layoutIfNeeded()
  }

  fileprivate func updateDisplayedDataType() {
    self.currencyButton.semanticContentAttribute = .forceRightToLeft
    self.currencyButton.setTitle(self.viewModel.currencyType.rawValue, for: .normal)
    self.kyberListButton.setTitleColor(self.viewModel.colorKyberListedButton, for: .normal)
    self.kyberListButton.setTitle(
      NSLocalizedString("kyber.listed", value: "Kyber Listed", comment: ""),
      for: .normal
    )
    self.otherButton.setTitleColor(self.viewModel.colorOthersButton, for: .normal)
    self.otherButton.setTitle(
      NSLocalizedString("other", value: "Other", comment: ""),
      for: .normal
    )
    self.updateWalletBalanceUI()
    self.tokensBalanceTableView.reloadData()
    self.view.layoutIfNeeded()
  }

  // MARK: Actions handling

  @objc func openQRCodeViewPressed(_ sender: Any) {
    self.delegate?.kWalletBalanceViewController(self, run: .openQRCode)
  }

  @IBAction func menuButtonPressed(_ sender: Any) {
    KNCrashlyticsUtil.logCustomEvent(withName: "wallet_balance", customAttributes: ["type": "hamburger_menu"])
    self.hamburgerMenu.openMenu(animated: true)
  }

  @IBAction func kyberListButtonPressed(_ sender: Any) {
    KNCrashlyticsUtil.logCustomEvent(withName: "wallet_balance", customAttributes: ["type": "kyber_listed_tokens"])
    if self.viewModel.updateDisplayKyberList(true) {
      self.updateDisplayedDataType()
    }
  }

  @IBAction func otherButtonPressed(_ sender: Any) {
    KNCrashlyticsUtil.logCustomEvent(withName: "wallet_balance", customAttributes: ["type": "other_tokens"])
    if self.viewModel.updateDisplayKyberList(false) {
      self.updateDisplayedDataType()
    }
  }

  @IBAction func searchButtonPressed(_ sender: Any) {
    KNCrashlyticsUtil.logCustomEvent(withName: "wallet_balance", customAttributes: ["type": "search_token"])
    if !self.searchTextField.isFirstResponder { self.searchTextField.becomeFirstResponder() }
  }

  @IBAction func sortNameButtonPressed(_ sender: Any) {
    KNCrashlyticsUtil.logCustomEvent(withName: "wallet_balance", customAttributes: ["type": "sorted_name"])
    self.viewModel.updateTokenDisplayType(positionClicked: 1)
    self.tokensBalanceTableView.reloadData()
  }

  @IBAction func changeButtonPressed(_ sender: Any) {
    KNCrashlyticsUtil.logCustomEvent(withName: "wallet_balance", customAttributes: ["type": "sorted_change_24h"])
    self.viewModel.updateTokenDisplayType(positionClicked: 3)
    self.tokensBalanceTableView.reloadData()
  }

  @IBAction func screenEdgePanGestureAction(_ sender: UIScreenEdgePanGestureRecognizer) {
    self.hamburgerMenu.gestureScreenEdgePanAction(sender)
  }

  @IBAction func currencyButtonPressed(_ sender: Any) {
    let newType: KWalletCurrencyType = self.viewModel.currencyType == .usd ? .eth : .usd
    KNCrashlyticsUtil.logCustomEvent(withName: "wallet_balance", customAttributes: ["type": "currency_changed_\(newType.rawValue)"])
    _ = self.viewModel.updateCurrencyType(newType)
    self.viewModel.updateTokenDisplayType(positionClicked: 2)
    self.updateDisplayedDataType()
  }
}

// MARK: Update from coordinator
extension KWalletBalanceViewController {
  func coordinatorUpdateSessionWithNewViewModel(_ viewModel: KWalletBalanceViewModel) {
    self.viewModel = viewModel
    self.updateWalletBalanceUI()
    self.updateWalletInfoUI()
    self.tokensBalanceTableView.reloadData()
    self.hamburgerMenu.update(
      walletObjects: KNWalletStorage.shared.wallets,
      currentWallet: self.viewModel.wallet
    )
    self.hamburgerMenu.hideMenu(animated: false)
    self.kyberListButton.setTitleColor(self.viewModel.colorKyberListedButton, for: .normal)
    self.otherButton.setTitleColor(self.viewModel.colorOthersButton, for: .normal)
    self.view.layoutIfNeeded()
  }

  func coordinatorUpdateWalletObjects() {
    guard let currentWallet = KNWalletStorage.shared.get(forPrimaryKey: viewModel.wallet.address) else { return }
    self.viewModel.updateWalletObject(currentWallet)
    self.updateWalletInfoUI()
    self.hamburgerMenu.update(
      walletObjects: KNWalletStorage.shared.wallets,
      currentWallet: currentWallet
    )
  }

  func coordinatorUpdateTokenObjects(_ tokenObjects: [TokenObject]) {
    if self.viewModel.updateTokenObjects(tokenObjects) {
      self.updateWalletBalanceUI()
      self.tokensBalanceTableView.reloadData()
    }
  }

  func coordinatorUpdateTokenBalances(_ balances: [String: Balance]) {
    if self.viewModel.updateTokenBalances(balances) {
      self.updateWalletBalanceUI()
      self.tokensBalanceTableView.reloadData()
    }
  }

  func coordinatorUpdateBalanceInETHAndUSD(ethBalance: BigInt, usdBalance: BigInt) {
    self.viewModel.updateBalanceInETHAndUSD(
      ethBalance: ethBalance,
      usdBalance: usdBalance
    )
    self.updateWalletBalanceUI()
    self.viewModel.exchangeRatesDataUpdated()
    self.tokensBalanceTableView.reloadData()
  }

  func coordinatorUpdatePendingTransactions(_ transactions: [KNTransaction]) {
    self.hamburgerMenu.update(transactions: transactions)
    self.hasPendingTxView.isHidden = transactions.isEmpty
  }

  func coordinatorSortedChange24h(with currencyType: KWalletCurrencyType) {
    // reset search text
    self.searchTextField.text = ""
    self.viewModel.updateSearchText("")
    // update: currency type, sorted change24h
    self.viewModel.updateTokenSortedChange24h(with: currencyType)
    // update Kyber listed/Other, Currency button
    self.updateDisplayedDataType()
  }
}

// MARK: Hamburger menu delegation
extension KWalletBalanceViewController: KNBalanceTabHamburgerMenuViewControllerDelegate {
  func balanceTabHamburgerMenuViewController(_ controller: KNBalanceTabHamburgerMenuViewController, run event: KNBalanceTabHamburgerMenuViewEvent) {
    self.delegate?.kWalletBalanceViewController(self, run: event)
  }
}

// MARK: Table view delegate, datasource
extension KWalletBalanceViewController: UITableViewDelegate {
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: false)
    let tokenObject = self.viewModel.tokenObject(for: indexPath.row)
    self.delegate?.kWalletBalanceViewController(self, run: .selectToken(token: tokenObject))
    KNCrashlyticsUtil.logCustomEvent(withName: "wallet_balance", customAttributes: ["type": "selected_\(tokenObject.symbol)"])
  }
}

extension KWalletBalanceViewController: UITableViewDataSource {
  func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return self.viewModel.numberRows
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(
      withIdentifier: KNBalanceTokenTableViewCell.kCellID,
      for: indexPath
    ) as! KNBalanceTokenTableViewCell
    let row: Int = indexPath.row

    // Data for cell
    let tokenObject: TokenObject = self.viewModel.tokenObject(for: row)
    let trackerRate: KNTrackerRate? = self.viewModel.trackerRate(for: row)
    let balance: Balance? = self.viewModel.balance(for: tokenObject)

    let cellModel = KNBalanceTokenTableViewCellModel(
      token: tokenObject,
      trackerRate: trackerRate,
      balance: balance,
      currencyType: self.viewModel.currencyType,
      index: indexPath.row
    )
    cell.updateCellView(with: cellModel)
    return cell
  }

  func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    return true
  }

  func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
    let tokenObject = self.viewModel.tokenObject(for: indexPath.row)
    let sendText = NSLocalizedString("send", value: "Send", comment: "")
    let sendAction = UITableViewRowAction(style: .default, title: sendText) { _, _ in
      self.delegate?.kWalletBalanceViewController(self, run: .send(token: tokenObject))
    }
    sendAction.backgroundColor = UIColor.Kyber.enygold
    let sellText = NSLocalizedString("sell", value: "Sell", comment: "")
    let sellAction = UITableViewRowAction(style: .default, title: sellText) { _, _ in
      self.delegate?.kWalletBalanceViewController(self, run: .sell(token: tokenObject))
    }
    sellAction.backgroundColor = UIColor.Kyber.blueGreen
    let buyText = NSLocalizedString("buy", value: "Buy", comment: "")
    let buyAction = UITableViewRowAction(style: .default, title: buyText) { _, _ in
      self.delegate?.kWalletBalanceViewController(self, run: .buy(token: tokenObject))
    }
    buyAction.backgroundColor = UIColor.Kyber.shamrock
    return tokenObject.isSupported ? [sendAction, sellAction, buyAction] : [sendAction]
  }
}

extension KWalletBalanceViewController: UITextFieldDelegate {
  func textFieldShouldClear(_ textField: UITextField) -> Bool {
    textField.text = ""
    if textField == self.searchTextField {
      self.searchAmountTextFieldChanged()
    }
    return true
  }

  func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
    let text = ((textField.text ?? "") as NSString).replacingCharacters(in: range, with: string)
    textField.text = text.replacingOccurrences(of: " ", with: "")
    if textField == self.searchTextField {
      self.searchAmountTextFieldChanged()
    }
    return false
  }

  fileprivate func searchAmountTextFieldChanged() {
    self.viewModel.updateSearchText((self.searchTextField.text ?? "").replacingOccurrences(of: " ", with: ""))
    self.tokensBalanceTableView.reloadData()
    self.updateWalletBalanceUI()
  }
}
