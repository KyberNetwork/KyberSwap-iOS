// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import BigInt

class KNNewAlertViewModel {
  lazy var numberFormatter: NumberFormatter = {
    return NumberFormatterUtil.shared.percentageFormatter
  }()

  lazy var priceNumberFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.minimumIntegerDigits = 1
    formatter.maximumFractionDigits = 9
    return formatter
  }()

  fileprivate(set) var alertID: Int?
  fileprivate(set) var alertCreatedDate: Double?
  fileprivate(set) var currencyType: KWalletCurrencyType = .usd
  fileprivate(set) var token: String = "ETH"
  fileprivate(set) var currentPrice: Double = 0.0
  fileprivate(set) var targetPrice: Double = 0.0

  var displayTokenTitle: String { return "\(token)/\(currencyType.rawValue)" }
  var displayCurrencyTitle: String { return currencyType.rawValue }

  var currentPriceDisplay: String {
    let price = BigInt(currentPrice * pow(10.0, 18.0))
    let display = price.displayRate(decimals: 18)
    return "Current Price: \(display)"

  }

  var isPercentageHidden: Bool { return self.percentageChange < 0.01 || currentPrice == 0.0 }
  var isAbove: Bool { return targetPrice >= currentPrice }
  var percentageImage: UIImage? { return self.isAbove ? UIImage(named: "change_up") : UIImage(named: "change_down") }
  var percentageChange: Double { return fabs(targetPrice - currentPrice) * 100.0 / currentPrice }
  var percentageChangeDisplay: String {
    return (self.numberFormatter.string(from: NSNumber(value: percentageChange)) ?? "") + "%"
  }
  var percentageChangeColor: UIColor {
    return self.isAbove ? UIColor(red: 49, green: 203, blue: 158) : UIColor(red: 250, green: 101, blue: 102)
  }

  func update(token: String, currencyType: KWalletCurrencyType) {
    self.token = token
    self.currencyType = currencyType
    self.updateCurrentPrice()
  }

  func updateEditAlert(_ alert: KNAlertObject) {
    self.alertID = alert.id
    self.alertCreatedDate = alert.createdDate
    self.currencyType = KWalletCurrencyType(rawValue: alert.currency) ?? .usd
    self.token = alert.token
    self.targetPrice = alert.price
    self.updateCurrentPrice()
  }

  func updateTargetPrice(_ price: Double) {
    self.targetPrice = price
  }

  func updateCurrentPrice() {
    self.currentPrice = {
      if let rate = KNTrackerRateStorage.shared.rates.first(where: { $0.tokenSymbol == self.token }) {
        return self.currencyType == .eth ? rate.rateETHNow : rate.rateUSDNow
      }
      return 0.0
    }()
  }

  func switchCurrencyType() {
    self.currencyType = self.currencyType == .usd ? .eth : .usd
    self.updateCurrentPrice()
  }
}

class KNNewAlertViewController: KNBaseViewController {

  @IBOutlet weak var headerContainerView: UIView!
  @IBOutlet weak var navTitleLabel: UILabel!
  @IBOutlet weak var tokenTextLabel: UILabel!
  @IBOutlet weak var tokenButton: UIButton!
  @IBOutlet weak var currencyButton: UIButton!
  @IBOutlet weak var alertPriceTextLabel: UILabel!
  @IBOutlet weak var alertPriceTextField: UITextField!
  @IBOutlet weak var currentPriceTextLabel: UILabel!
  @IBOutlet weak var percentageChange: UIButton!

  let viewModel: KNNewAlertViewModel = KNNewAlertViewModel()

  deinit {
    NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: kExchangeTokenRateNotificationKey), object: nil)
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    self.headerContainerView.applyGradient(with: UIColor.Kyber.headerColors)
    self.currencyButton.setTitle(self.viewModel.currencyType.rawValue, for: .normal)
    self.updateUIs()
    KNCrashlyticsUtil.logCustomEvent(withName: "new_alert", customAttributes: ["type": "currency_\(self.viewModel.currencyType.rawValue)"])
    self.alertPriceTextField.delegate = self
    self.viewModel.updateCurrentPrice()
    self.updateUIs()
    NotificationCenter.default.addObserver(self, selector: #selector(self.trackerRateDidUpdate(_:)), name: NSNotification.Name(rawValue: kExchangeTokenRateNotificationKey), object: nil)
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if IEOUserStorage.shared.user == nil {
      self.navigationController?.popViewController(animated: true)
    }
    // force reload current exchange rate
    KNRateCoordinator.shared.fetchCacheRate(nil)
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    self.headerContainerView.removeSublayer(at: 0)
    self.headerContainerView.applyGradient(with: UIColor.Kyber.headerColors)
  }

  @objc func trackerRateDidUpdate(_ sender: Any) {
    self.viewModel.updateCurrentPrice()
    self.updateUIs()
  }

  func updatePair(token: TokenObject, currencyType: KWalletCurrencyType) {
    self.viewModel.update(token: token.symbol, currencyType: currencyType)
    self.updateUIs()
    KNCrashlyticsUtil.logCustomEvent(withName: "new_alert", customAttributes: ["type": "currency_\(self.viewModel.currencyType.rawValue)"])
    // for refetch token rates
    KNRateCoordinator.shared.fetchCacheRate(nil)
  }

  func updateEditAlert(_ alert: KNAlertObject) {
    KNCrashlyticsUtil.logCustomEvent(withName: "new_alert", customAttributes: ["type": "alert_edited"])
    self.viewModel.updateEditAlert(alert)
    self.alertPriceTextField.text = self.viewModel.priceNumberFormatter.string(from: NSNumber(value: alert.price))
    self.updateUIs()
  }

  fileprivate func updateUIs() {
    UIView.animate(withDuration: 0.16) {
      let placeHolder = UIImage(named: "default_token")
      let url = "https://raw.githubusercontent.com/KyberNetwork/KyberNetwork.github.io/master/DesignAssets/tokens/iOS/\(self.viewModel.token.lowercased()).png"
      if let image = UIImage(named: self.viewModel.token.lowercased()) {
        self.tokenButton.setImage(
          image.resizeImage(to: CGSize(width: 36.0, height: 36.0)),
          for: .normal
        )
      } else {
        self.tokenButton.setImage(
          with: url,
          placeHolder: placeHolder,
          size: CGSize(width: 36.0, height: 36.0),
          state: .normal
        )
      }
      self.percentageChange.isHidden = self.viewModel.isPercentageHidden || (self.alertPriceTextField.text ?? "").isEmpty
      self.percentageChange.setImage(self.viewModel.percentageImage, for: .normal)
      self.percentageChange.setTitle(self.viewModel.percentageChangeDisplay, for: .normal)
      self.percentageChange.setTitleColor(self.viewModel.percentageChangeColor, for: .normal)
      self.tokenButton.setTitle(self.viewModel.displayTokenTitle, for: .normal)
      self.currencyButton.setTitle(self.viewModel.displayCurrencyTitle, for: .normal)
      self.currentPriceTextLabel.text = self.viewModel.currentPriceDisplay
      self.view.layoutIfNeeded()
    }
  }

  @IBAction func switchCurrencyTypePressed(_ sender: Any) {
    self.viewModel.switchCurrencyType()
    self.updateUIs()
    KNCrashlyticsUtil.logCustomEvent(withName: "new_alert", customAttributes: ["type": "currency_\(self.viewModel.currencyType.rawValue)"])
  }

  @IBAction func selectTokenButtonPressed(_ sender: Any) {
    KNCrashlyticsUtil.logCustomEvent(withName: "new_alert", customAttributes: ["type": "select_token"])
    let viewModel = KNSearchTokenViewModel(
      headerColor: UIColor.Kyber.shamrock,
      supportedTokens: KNSupportedTokenStorage.shared.supportedTokens
    )
    let searchTokenVC = KNSearchTokenViewController(viewModel: viewModel)
    searchTokenVC.loadViewIfNeeded()
    searchTokenVC.delegate = self
    self.navigationController?.pushViewController(searchTokenVC, animated: true)
  }

  @IBAction func backButtonPressed(_ sender: Any) {
    KNCrashlyticsUtil.logCustomEvent(withName: "new_alert", customAttributes: ["type": "back_button"])
    self.navigationController?.popViewController(animated: true)
  }

  @IBAction func screenEdgePanAction(_ sender: UIScreenEdgePanGestureRecognizer
    ) {
    if sender.state == .ended {
      KNCrashlyticsUtil.logCustomEvent(withName: "new_alert", customAttributes: ["type": "screen_edge_pan"])
      self.navigationController?.popViewController(animated: true)
    }
  }

  @IBAction func saveButtonPressed(_ sender: Any) {
    KNCrashlyticsUtil.logCustomEvent(withName: "new_alert", customAttributes: ["type": "save_button", "is_added_new_alert": self.viewModel.alertID == nil])
    if self.viewModel.currentPrice == 0.0 {
      self.showWarningTopBannerMessage(
        with: NSLocalizedString("error", value: "Error", comment: ""),
        message: "We can not update current price of this token pair".toBeLocalised(),
        time: 1.5
      )
      return
    }
    let change = self.getPercentageChange(
      targetPrice: self.viewModel.targetPrice,
      currentPrice: self.viewModel.currentPrice
    )
    if change < KNAppTracker.minimumPriceAlertPercent || change > KNAppTracker.maximumPriceAlertPercent {
      self.showWarningTopBannerMessage(
        with: NSLocalizedString("error", value: "Error", comment: ""),
        message: "Your target price should be from 1% to 10000% of current price".toBeLocalised(),
        time: 1.5
      )
      return
    }
    if fabs(change) < KNAppTracker.minimumPriceAlertChangePercent {
      self.showWarningTopBannerMessage(
        with: NSLocalizedString("error", value: "Error", comment: ""),
        message: "Your target price should be different at least 0.1% from current price".toBeLocalised(),
        time: 1.5
      )
      return
    }
    if self.viewModel.token == "ETH" && self.viewModel.currencyType == .eth {
      self.showWarningTopBannerMessage(
        with: NSLocalizedString("error", value: "Error", comment: ""),
        message: "Can not select pair ETH/ETH".toBeLocalised(),
        time: 1.5
      )
      return
    }
    let targetPrice = self.alertPriceTextField.text ?? ""
    guard let price = targetPrice.fullBigInt(decimals: 18), !targetPrice.isEmpty else {
      self.showWarningTopBannerMessage(
        with: NSLocalizedString("error", value: "Error", comment: ""),
        message: "Please enter your target price to be alerted".toBeLocalised(),
        time: 1.5
      )
      return
    }
    self.viewModel.updateTargetPrice(Double(price) / pow(10.0, 18.0))
    if let _ = self.viewModel.alertID {
      self.updateAlertWithWarningIfNeeded()
    } else {
      self.createNewAlertSavePressed()
    }
  }

  fileprivate func createNewAlertSavePressed() {
    guard let accessToken = IEOUserStorage.shared.user?.accessToken else { return }
    let alert = KNAlertObject(
      token: self.viewModel.token,
      currency: self.viewModel.currencyType.rawValue,
      price: self.viewModel.targetPrice,
      currentPrice: self.viewModel.currentPrice,
      isAbove: self.viewModel.targetPrice > self.viewModel.currentPrice
    )
    self.displayLoading()
    KNPriceAlertCoordinator.shared.addNewAlert(accessToken: accessToken, jsonData: alert.json) { [weak self] (_, error) in
      guard let `self` = self else { return }
      self.hideLoading()
      if let error = error {
        KNCrashlyticsUtil.logCustomEvent(withName: "new_alert", customAttributes: ["type": "create_new_alert_failed", "error": error])
        self.showErrorTopBannerMessage(
          with: NSLocalizedString("error", value: "Error", comment: ""),
          message: error,
          time: 1.5
        )
      } else {
        self.showSuccessTopBannerMessage(
          with: NSLocalizedString("success", value: "Success", comment: ""),
          message: "New alert has been added successfully!".toBeLocalised(),
          time: 1.0
        )
        self.navigationController?.popViewController(animated: true)
      }
    }
  }

  fileprivate func updateAlertWithWarningIfNeeded() {
    guard let alertID = self.viewModel.alertID else { return }
    if let alert = KNAlertStorage.shared.getObject(primaryKey: alertID), alert.hasReward {
      let message = "This alert is rewarded in a running campaign, you will lose the prize if updating it, do you want to continue?".toBeLocalised()
      let alertController = UIAlertController(title: "", message: message, preferredStyle: .alert)
      alertController.addAction(UIAlertAction(title: NSLocalizedString("cancel", value: "Cancel", comment: ""), style: .cancel, handler: nil))
      alertController.addAction(UIAlertAction(title: NSLocalizedString("continue", value: "Continue", comment: ""), style: .destructive, handler: { _ in
        self.updateAlertSavePressed()
      }))
      self.present(alertController, animated: true, completion: nil)
    } else {
      self.updateAlertSavePressed()
    }
  }

  fileprivate func updateAlertSavePressed() {
    guard let accessToken = IEOUserStorage.shared.user?.accessToken, let alertID = self.viewModel.alertID else { return }
    let createdDate: Date = {
      if let date = self.viewModel.alertCreatedDate {
        return Date(timeIntervalSince1970: date)
      }
      return Date()
    }()
    let json: JSONDictionary = [
      "id": alertID,
      "symbol": self.viewModel.token,
      "base": self.viewModel.currencyType.rawValue.lowercased(),
      "alert_type": 0,
      "alert_price": self.viewModel.targetPrice,
      "created_at_price": self.viewModel.currentPrice,
      "is_above": self.viewModel.targetPrice > self.viewModel.currentPrice,
      "status": 0, // active
      "created_at": DateFormatterUtil.shared.priceAlertAPIFormatter.string(from: createdDate),
      "updated_at": DateFormatterUtil.shared.priceAlertAPIFormatter.string(from: Date()),
    ]
    let newAlert = KNAlertObject(json: json)
    self.displayLoading()
    KNPriceAlertCoordinator.shared.updateAlert(accessToken: accessToken, jsonData: newAlert.json) { [weak self] (_, error) in
      guard let `self` = self else { return }
      self.hideLoading()
      if let error = error {
        KNCrashlyticsUtil.logCustomEvent(withName: "new_alert", customAttributes: ["type": "update_alert_failed", "error": error])
        self.showErrorTopBannerMessage(
          with: NSLocalizedString("error", value: "Error", comment: ""),
          message: error,
          time: 1.5
        )
      } else {
        self.showSuccessTopBannerMessage(
          with: NSLocalizedString("success", value: "Success", comment: ""),
          message: "Updated alert successfully!".toBeLocalised(),
          time: 1.0
        )
        self.navigationController?.popViewController(animated: true)
      }
    }
  }
}

extension KNNewAlertViewController: KNSearchTokenViewControllerDelegate {
  func searchTokenViewController(_ controller: KNSearchTokenViewController, run event: KNSearchTokenViewEvent) {
    self.navigationController?.popViewController(animated: true, completion: {
      if case .select(let token) = event {
        self.viewModel.update(token: token.symbol, currencyType: self.viewModel.currencyType)
        // for refetch token rates
        KNRateCoordinator.shared.fetchCacheRate(nil)
        self.updateUIs()
      }
    })
  }
}

extension KNNewAlertViewController: UITextFieldDelegate {
  func textFieldShouldClear(_ textField: UITextField) -> Bool {
    self.alertPriceTextField.text = ""
    self.viewModel.updateTargetPrice(0)
    self.updateUIs()
    return false
  }

  func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
    let text = ((textField.text ?? "") as NSString).replacingCharacters(in: range, with: string)
    guard let priceBigInt = text.fullBigInt(decimals: 18) else {
      return false
    }
    let targetPrice = Double(priceBigInt) / pow(10.0, 18.0)
    let change = self.getPercentageChange(targetPrice: targetPrice, currentPrice: self.viewModel.currentPrice)
    if change > KNAppTracker.maximumPriceAlertPercent { return false }
    self.viewModel.updateTargetPrice(targetPrice)
    self.alertPriceTextField.text = text
    self.updateUIs()
    return false
  }

  fileprivate func getPercentageChange(targetPrice: Double, currentPrice: Double) -> Double {
    if currentPrice == 0 { return KNAppTracker.maximumPriceAlertPercent + 1.0 }
    return (targetPrice - currentPrice) * 100.0 / currentPrice
  }
}
