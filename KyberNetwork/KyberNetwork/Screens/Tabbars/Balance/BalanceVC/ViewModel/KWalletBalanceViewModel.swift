// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import BigInt

enum KWalletSortType {
  case nameAsc
  case nameDesc
  case priceAsc
  case priceDesc
  case changeAsc
  case changeDesc
  case balanceDesc
}

enum KWalletCurrencyType: String {
  case usd = "USD"
  case eth = "ETH"
}

class KWalletBalanceViewModel: NSObject {

  private(set) var isKyberList: Bool = true
  private(set) var wallet: KNWalletObject
  private(set) var tokenObjects: [TokenObject] = []
  private(set) var tokensDisplayType: KWalletSortType = .balanceDesc

  private(set) var trackerRateData: [String: KNTrackerRate] = [:]
  private(set) var displayedTokens: [TokenObject] = []
  private(set) var displayTrackerRates: [KNTrackerRate?] = []

  private(set) var currencyType: KWalletCurrencyType = KNAppTracker.getCurrencyType()

  private(set) var balances: [String: Balance] = [:]
  private(set) var totalETHBalance: BigInt = BigInt(0)
  private(set) var totalUSDBalance: BigInt = BigInt(0)

  private(set) var searchText: String = ""

  init(wallet: KNWalletObject) {
    self.wallet = wallet
    super.init()
  }

  // MARK: Check if balance has tokens
  var hasTokens: Bool {
    // As combining market and balance, there is no need to check
    return !self.tokenObjects.isEmpty
  }

  var textNoMatchingTokens: String {
    return NSLocalizedString("no.matching.tokens", value: "No matching tokens", comment: "")
  }

  fileprivate func setupTrackerRateData() {
    KNTrackerRateStorage.shared.rates.forEach { rate in
      self.trackerRateData[rate.identifier] = rate
    }
  }

  // MARK: Wallet data
  var walletNameDisplayedText: String {
    return self.wallet.name
  }

  var headerBackgroundColor: UIColor {
    return KNAppStyleType.current.walletFlowHeaderColor
  }

  // MARK: Balance data
  func updateCurrencyType(_ type: KWalletCurrencyType) -> Bool {
    if self.currencyType == type { return false }
    self.currencyType = type
    KNAppTracker.updateCurrencyType(type)
    self.createDisplayedData()
    return true
  }

  var balanceDisplayAttributedString: NSAttributedString {
    let value: String = {
      switch self.currencyType {
      case .usd:
        let usdValue = self.totalUSDBalance.shortString(units: .ether, maxFractionDigits: 2).prefix(11)
        return "\(usdValue)"
      case .eth:
        let ethValue = self.totalETHBalance.shortString(units: .ether, maxFractionDigits: 6).prefix(11)
        return "\(ethValue)"
      }
    }()
    let currency: String = "  \(self.currencyType.rawValue)"

    let valueAttributes: [NSAttributedStringKey: Any] = [
      NSAttributedStringKey.font: UIFont.Kyber.medium(with: 28),
      NSAttributedStringKey.foregroundColor: UIColor.white,
      NSAttributedStringKey.kern: 0.0,
    ]
    let currencyAttributes: [NSAttributedStringKey: Any] = [
      NSAttributedStringKey.font: UIFont.Kyber.medium(with: 14),
      NSAttributedStringKey.foregroundColor: UIColor.white,
      NSAttributedStringKey.kern: 0.0,
    ]
    let attributedString = NSMutableAttributedString()
    attributedString.append(NSAttributedString(string: value, attributes: valueAttributes))
    attributedString.append(NSAttributedString(string: currency, attributes: currencyAttributes))
    return attributedString
  }

  var colorKyberListedButton: UIColor {
    if self.isKyberList { return UIColor.Kyber.enygold }
    return UIColor(red: 29, green: 48, blue: 58)
  }

  var colorOthersButton: UIColor {
    if !self.isKyberList { return UIColor.Kyber.enygold }
    return UIColor(red: 29, green: 48, blue: 58)
  }

  // MARK: Update display data
  // 1: Click name
  // 2: Click price
  // 3: Click change 24h
  func updateTokenDisplayType(positionClicked: Int) {
    if positionClicked == 1 {
      if self.tokensDisplayType == .nameAsc || self.tokensDisplayType == .nameDesc {
        self.tokensDisplayType = self.tokensDisplayType == .nameAsc ? .nameDesc : .nameAsc
      } else {
        self.tokensDisplayType = .nameAsc
      }
    } else if positionClicked == 2 {
      self.tokensDisplayType = .balanceDesc
    } else {
      if self.tokensDisplayType == .changeAsc || self.tokensDisplayType == .changeDesc {
        self.tokensDisplayType = self.tokensDisplayType == .changeAsc ? .changeDesc : .changeAsc
      } else {
        self.tokensDisplayType = .changeAsc
      }
    }
    self.createDisplayedData()
  }

  fileprivate func updateTokensDisplayType(_ type: KWalletSortType) -> Bool {
    if self.tokensDisplayType == type { return false }
    self.tokensDisplayType = type
    self.createDisplayedData()
    return true
  }

  func updateTokenSortedChange24h(with currencyType: KWalletCurrencyType) {
    self.currencyType = currencyType
    KNAppTracker.updateCurrencyType(currencyType)
    self.tokensDisplayType = KWalletSortType.changeDesc
    self.isKyberList = true
    self.createDisplayedData()
  }

  func updateSearchText(_ text: String) {
    self.searchText = text
    self.createDisplayedData()
  }

  // MARK: Tokens balance table view
  var numberRows: Int {
    return self.displayedTokens.count
  }

  func tokenObject(for row: Int) -> TokenObject {
    return self.displayedTokens[row]
  }

  func trackerRate(for row: Int) -> KNTrackerRate? {
    return self.displayTrackerRates[row]
  }

  func balance(for token: TokenObject) -> Balance? {
    if let balance = self.balances[token.contract] { return balance }
    if let amount = token.value.shortBigInt(decimals: 0) {
      return Balance(value: amount)
    }
    return nil
  }

  func iconName(for token: TokenObject) -> String? {
    return token.icon
  }

  // MARK: Update data
  // return true if data is updated and we need to update UIs
  // to reduce number of reloading collection view
  func updateWalletObject(_ walletObject: KNWalletObject) {
    self.wallet = walletObject
  }

  func updateTokenObjects(_ tokenObjects: [TokenObject]) -> Bool {
    if self.tokenObjects == tokenObjects { return false }
    self.tokenObjects = tokenObjects
    self.createDisplayedData()
    return true
  }

  func updateDisplayKyberList(_ isDisplayKyberList: Bool) -> Bool {
    if self.isKyberList == isDisplayKyberList { return false }
    self.isKyberList = isDisplayKyberList
    self.createDisplayedData()
    return true
  }

  func updateTokenBalances(_ balances: [String: Balance]) -> Bool {
    var isDataChanged: Bool = false
    balances.forEach {
      if self.balances[$0.key] == nil || self.balances[$0.key]!.value != $0.value.value {
        isDataChanged = true
      }
      self.balances[$0.key] = $0.value
    }
    if isDataChanged { self.createDisplayedData() }
    return isDataChanged
  }

  func updateBalanceInETHAndUSD(ethBalance: BigInt, usdBalance: BigInt) {
    self.totalETHBalance = ethBalance
    self.totalUSDBalance = usdBalance
  }

  func exchangeRatesDataUpdated() {
    self.setupTrackerRateData()
    self.createDisplayedData()
  }

  fileprivate func createDisplayedData() {
    // Compute displayed token objects sorted by displayed type
    let tokenObjects = self.tokenObjects.filter({ $0.contains(self.searchText) }).filter({ $0.isSupported == self.isKyberList })
    self.displayedTokens = {
      return tokenObjects.sorted(by: {
        return self.displayedTokenComparator(left: $0, right: $1)
      })
    }()
    self.displayTrackerRates = self.displayedTokens.map({
      return self.trackerRateData[$0.identifier()]
    })
  }

  fileprivate func displayedTokenComparator(left: TokenObject, right: TokenObject) -> Bool {
    if self.isKyberList {
      if self.trackerRateData[left.identifier()] == nil { return false }
      if self.trackerRateData[right.identifier()] == nil { return true }
    }
    // sort by name
    if self.tokensDisplayType == .nameAsc { return left.symbol < right.symbol }
    if self.tokensDisplayType == .nameDesc { return left.symbol > right.symbol }

    if self.tokensDisplayType == .balanceDesc {
      // sort by balance
      guard let balance0 = self.balance(for: left) else { return false }
      guard let balance1 = self.balance(for: right) else { return true }
      let value0 = balance0.value * BigInt(10).power(18 - left.decimals)
      let value1 = balance1.value * BigInt(10).power(18 - right.decimals)
      return value0 > value1
    }
    guard let tracker0 = self.trackerRateData[left.identifier()] else { return false }
    guard let tracker1 = self.trackerRateData[right.identifier()] else { return true }
    // sort by price or change
    let change0: Double = {
      return self.currencyType == .eth ? tracker0.changeETH24h : tracker0.changeUSD24h
    }()
    let change1: Double = {
      return self.currencyType == .eth ? tracker1.changeETH24h : tracker1.changeUSD24h
    }()
    // sort by change 24h
    if self.tokensDisplayType == .changeAsc { return change0 < change1 }
    if self.tokensDisplayType == .changeDesc { return change0 > change1 }
    // sort by price, rate ETH or rate USD are the same to compare
    if self.tokensDisplayType == .priceAsc { return tracker0.rateETHNow < tracker1.rateETHNow }
    return tracker0.rateETHNow > tracker1.rateETHNow
  }
}
