// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import BigInt

class KSwapViewModel {

  let defaultTokenIconImg = UIImage(named: "default_token")
  let eth = KNSupportedTokenStorage.shared.ethToken
  let knc = KNSupportedTokenStorage.shared.kncToken

  fileprivate(set) var wallet: Wallet
  fileprivate(set) var walletObject: KNWalletObject
  fileprivate var supportedTokens: [TokenObject] = []

  fileprivate(set) var from: TokenObject
  fileprivate(set) var to: TokenObject

  fileprivate var balances: [String: Balance] = [:]
  fileprivate var balance: Balance?

  fileprivate(set) var amountFrom: String = ""
  fileprivate(set) var amountTo: String = ""
  fileprivate(set) var isFocusingFromAmount: Bool = true

  fileprivate(set) var userCapInWei: BigInt = BigInt(2).power(255)
  fileprivate(set) var estRate: BigInt?
  fileprivate(set) var slippageRate: BigInt?
  fileprivate(set) var minRatePercent: Double = 3.0

  var estimatedRateDouble: Double {
    guard let rate = self.estRate else { return 0.0 }
    return Double(rate) / pow(10.0, Double(self.to.decimals))
  }

  fileprivate(set) var selectedGasPriceType: KNSelectedGasPriceType = .medium
  fileprivate(set) var gasPrice: BigInt = KNGasCoordinator.shared.fastKNGas

  fileprivate(set) var estimateGasLimit: BigInt = KNGasConfiguration.exchangeTokensGasLimitDefault

  init(wallet: Wallet,
       from: TokenObject,
       to: TokenObject,
       supportedTokens: [TokenObject]
    ) {
    self.wallet = wallet
    let addr = wallet.address.description
    self.walletObject = KNWalletStorage.shared.get(forPrimaryKey: addr) ?? KNWalletObject(address: addr)
    self.from = from
    self.to = to
    self.supportedTokens = supportedTokens
  }

  var headerBackgroundColor: UIColor { return KNAppStyleType.current.swapFlowHeaderColor }
  // MARK: Wallet name
  var walletNameString: String { return "| \(self.walletObject.name)" }

  // MARK: From Token
  var allFromTokenBalanceString: String {
    if self.from.isETH {
      let balance = self.balances[self.from.contract]?.value ?? BigInt(0)
      if balance <= self.feeBigInt { return "0" }
      let availableToSwap = max(BigInt(0), balance - self.feeBigInt)
      let string = availableToSwap.string(
        decimals: self.from.decimals,
        minFractionDigits: 0,
        maxFractionDigits: min(self.from.decimals, 6)
      )
      return "\(string.prefix(12))"
    }
    return self.balanceText
  }

  var amountFromBigInt: BigInt {
    return self.amountFrom.fullBigInt(decimals: self.from.decimals) ?? BigInt(0)
  }

  var amountToEstimate: BigInt {
    if self.amountFromBigInt.isZero, let smallAmount = EtherNumberFormatter.short.number(from: "0.001", decimals: self.from.decimals) {
      return smallAmount
    }
    return self.amountFromBigInt
  }

  var equivalentUSDAmount: BigInt? {
    if let usdRate = KNRateCoordinator.shared.usdRate(for: self.to) {
      return usdRate.rate * self.amountToBigInt / BigInt(10).power(self.to.decimals)
    }
    return nil
  }

  var displayEquivalentUSDAmount: String? {
    guard let amount = self.equivalentUSDAmount, !amount.isZero else { return nil }
    let value = amount.displayRate(decimals: 18)
    return "~ $\(value) USD"
  }

  var fromTokenIconName: String {
    return self.from.icon
  }

  var isFromTokenBtnEnabled: Bool {
    guard KNWalletPromoInfoStorage.shared.getDestinationToken(from: self.walletObject.address) != nil else {
      // not a promo wallet, always enabled
      return true
    }
    if self.from.isPromoToken { return false }
    return true
  }

  var fromTokenBtnTitle: String {
    return self.from.symbol
  }

  // when user wants to fix received amount
  var expectedExchangeAmountText: String {
    guard let rate = self.estRate, !self.amountToBigInt.isZero else {
      return ""
    }
    let expectedExchange: BigInt = {
      if rate.isZero { return rate }
      let amount = self.amountToBigInt
      return amount * BigInt(10).power(self.from.decimals) / rate
    }()
    return expectedExchange.string(decimals: self.from.decimals, minFractionDigits: 6, maxFractionDigits: 6)
  }

  var percentageRateDiff: Double {
    guard let rate = KNRateCoordinator.shared.getCachedProdRate(from: self.from.symbol, to: self.to.symbol), !rate.rate.isZero else {
      return 0.0
    }
    if self.estimatedRateDouble == 0 { return 0.0 }
    let marketRateDouble = Double(rate.rate) / pow(10.0, Double(self.to.decimals))
    let change = (self.estimatedRateDouble - marketRateDouble) / marketRateDouble * 100.0
    if change > -0.1 { return 0.0 }
    return change
  }

  var differentRatePercentageDisplay: String? {
    if self.amountFromBigInt.isZero { return nil }
    let change = self.percentageRateDiff
    if change >= -0.1 { return nil }
    let display = NumberFormatterUtil.shared.displayPercentage(from: fabs(change))
    return "\(display)%"
  }

  // MARK: To Token
  var amountToBigInt: BigInt {
    return self.amountTo.removeGroupSeparator().fullBigInt(decimals: self.to.decimals) ?? BigInt(0)
  }

  var isToTokenBtnEnabled: Bool {
    guard let destToken = KNWalletPromoInfoStorage.shared.getDestinationToken(from: self.walletObject.address) else {
      // not a promo wallet, always enabled
      return true
    }
    if self.from.isPromoToken && self.to.symbol == destToken { return false }
    return true
  }

  var toTokenBtnTitle: String {
    return self.to.symbol
  }

  var toTokenIconName: String {
    return self.to.icon
  }

  var amountTextFieldColor: UIColor {
    return self.isAmountValid ? UIColor.Kyber.enygold : UIColor.red
  }

  var expectedReceivedAmountText: String {
    guard let rate = self.estRate, !self.amountFromBigInt.isZero else {
      return ""
    }
    let expectedAmount: BigInt = {
      let amount = self.amountFromBigInt
      return rate * amount / BigInt(10).power(self.from.decimals)
    }()
    return expectedAmount.string(decimals: self.to.decimals, minFractionDigits: min(self.to.decimals, 6), maxFractionDigits: min(self.to.decimals, 6))
  }

  func tokenButtonAttributedText(isSource: Bool) -> NSAttributedString {
    let attributedString = NSMutableAttributedString()
    let symbolAttributes: [NSAttributedStringKey: Any] = [
      NSAttributedStringKey.font: UIFont.Kyber.medium(with: 22),
      NSAttributedStringKey.foregroundColor: UIColor(red: 29, green: 48, blue: 58),
      NSAttributedStringKey.kern: 0.0,
    ]
    let nameAttributes: [NSAttributedStringKey: Any] = [
      NSAttributedStringKey.font: UIFont.Kyber.medium(with: 13),
      NSAttributedStringKey.foregroundColor: UIColor.Kyber.gray,
      NSAttributedStringKey.kern: 0.0,
    ]
    let symbol = isSource ? self.from.symbol : self.to.symbol
    let name = isSource ? self.from.name : self.to.name
    attributedString.append(NSAttributedString(string: symbol, attributes: symbolAttributes))
    attributedString.append(NSAttributedString(string: "\n\(name)", attributes: nameAttributes))
    return attributedString
  }

  // MARK: Balance
  var balanceText: String {
    let bal: BigInt = self.balance?.value ?? BigInt(0)
    let string = bal.string(
      decimals: self.from.decimals,
      minFractionDigits: 0,
      maxFractionDigits: min(self.from.decimals, 6)
    )
    return "\(string.prefix(12))"
  }

  var balanceTextString: String {
    let balanceText = NSLocalizedString("balance", value: "balance", comment: "")
    return "\(self.from.symbol) \(balanceText)".uppercased()
  }

  // MARK: Rate
  var exchangeRateText: String {
    return self.estRate?.displayRate(decimals: self.to.decimals) ?? "---"
  }

  var minRate: BigInt? {
    guard let estRate = self.estRate else { return nil }
    return estRate * BigInt(100.0 - self.minRatePercent) / BigInt(100.0)
  }

  var slippageRateText: String? {
    return self.slippageRate?.string(decimals: self.to.decimals, minFractionDigits: 0, maxFractionDigits: min(self.to.decimals, 9))
  }

  // MARK: Gas Price
  var gasPriceText: String {
    return "\(self.gasPrice.shortString(units: .gwei, maxFractionDigits: 1)) gwei"
  }

  // MARK: Verify data
  // Amount should > 0 and <= balance
  var isAmountTooSmall: Bool {
    if self.amountFromBigInt <= BigInt(0) { return true }
    if self.from.isETH {
      return self.amountFromBigInt < BigInt(0.001 * Double(EthereumUnit.ether.rawValue))
    }
    if self.to.isETH {
      return self.amountToBigInt < BigInt(0.001 * Double(EthereumUnit.ether.rawValue))
    }
    let ethRate: BigInt = {
      let cacheRate = KNRateCoordinator.shared.ethRate(for: self.from)
      return cacheRate?.rate ?? BigInt(0)
    }()
    let valueInETH = ethRate * self.amountFromBigInt
    let valueMin = BigInt(0.001 * Double(EthereumUnit.ether.rawValue)) * BigInt(10).power(self.from.decimals)
    return valueInETH < valueMin
  }

  var isBalanceEnough: Bool {
    if self.amountFromBigInt > self.balance?.value ?? BigInt(0) { return false }
    return true
  }

  var isCapEnough: Bool {
    let ethAmount: BigInt = {
      if self.from.isETH { return self.amountFromBigInt }
      if self.to.isETH { return self.amountToBigInt }
      let ethRate: BigInt = {
        let cacheRate = KNRateCoordinator.shared.ethRate(for: self.from)
        return cacheRate?.rate ?? BigInt(0)
      }()
      return ethRate * self.amountFromBigInt / BigInt(10).power(self.from.decimals)
    }()
    return self.userCapInWei >= ethAmount
  }

  var isAmountTooBig: Bool {
    if !self.isBalanceEnough { return true }
    if !self.isCapEnough { return true }
    return false
  }

  var isETHSwapAmountAndFeeTooBig: Bool {
    if !self.from.isETH { return false } // not ETH
    let totalValue = self.feeBigInt + self.amountFromBigInt
    let balance = self.balances[self.from.contract]?.value ?? BigInt(0)
    return balance < totalValue
  }

  var isAmountValid: Bool {
    return !self.isAmountTooSmall && !self.isAmountTooBig
  }

  // rate should not be nil and greater than zero
  var isSlippageRateValid: Bool {
    if self.slippageRate == nil || self.slippageRate?.isZero == true { return false }
    return true
  }

  var isRateValid: Bool {
    if self.estRate == nil || self.estRate?.isZero == true { return false }
    if self.slippageRate == nil || self.slippageRate?.isZero == true { return false }
    return true
  }

  var feeBigInt: BigInt {
    return self.gasPrice * self.estimateGasLimit
  }

  var isHavingEnoughETHForFee: Bool {
    var fee = self.gasPrice * self.estimateGasLimit
    if self.from.isETH { fee += self.amountFromBigInt }
    let ethBal = self.balances[self.eth.contract]?.value ?? BigInt(0)
    return ethBal >= fee
  }

  // MARK: Update data
  func updateWallet(_ wallet: Wallet) {
    self.wallet = wallet
    let address = wallet.address.description
    self.walletObject = KNWalletStorage.shared.get(forPrimaryKey: address) ?? KNWalletObject(address: address)

    if let destToken = KNWalletPromoInfoStorage.shared.getDestinationToken(from: address), let ptToken = KNSupportedTokenStorage.shared.ptToken {
      self.from = ptToken
      self.to = KNSupportedTokenStorage.shared.supportedTokens.first(where: { $0.symbol == destToken }) ?? self.eth
    } else {
      // not a promo wallet
      self.from = self.eth
      self.to = self.knc
    }

    self.amountFrom = ""
    self.amountTo = ""
    self.isFocusingFromAmount = true

    self.balances = [:]
    self.balance = nil

    self.estRate = nil
    self.slippageRate = nil
    self.estimateGasLimit = KNGasConfiguration.calculateDefaultGasLimit(from: self.from, to: self.to)
  }

  func updateWalletObject() {
    self.walletObject = KNWalletStorage.shared.get(forPrimaryKey: self.walletObject.address) ?? self.walletObject
  }

  func swapTokens() {
    swap(&self.from, &self.to)
    self.amountFrom = ""
    self.amountTo = ""
    self.isFocusingFromAmount = true

    self.estRate = nil
    self.slippageRate = nil
    self.estimateGasLimit = KNGasConfiguration.calculateDefaultGasLimit(from: self.from, to: self.to)
    self.balance = self.balances[self.from.contract]
  }

  func updateSelectedToken(_ token: TokenObject, isSource: Bool) {
    if isSource {
      self.from = token
    } else {
      self.to = token
    }
    if self.isFocusingFromAmount && isSource {
      // focusing on from amount, and from token is changed, reset amount
      self.amountFrom = ""
    } else if !self.isFocusingFromAmount && !isSource {
      // focusing on to amount, and to token is changed, reset to amount
      self.amountTo = ""
    }
    self.estRate = nil
    self.slippageRate = nil
    self.estimateGasLimit = KNGasConfiguration.calculateDefaultGasLimit(from: self.from, to: self.to)
    self.balance = self.balances[self.from.contract]
  }

  func updateEstimatedRateFromCachedIfNeeded() {
    guard let rate = KNRateCoordinator.shared.getRate(from: self.from, to: self.to), self.estRate == nil, self.slippageRate == nil else { return }
    self.estRate = rate.rate
    self.slippageRate = rate.minRate
  }

  func updateFocusingField(_ isSource: Bool) {
    self.isFocusingFromAmount = isSource
  }

  func updateAmount(_ amount: String, isSource: Bool) {
    if isSource {
      self.amountFrom = amount
    } else {
      self.amountTo = amount
    }
  }

  func updateBalance(_ balances: [String: Balance]) {
    balances.forEach { (key, value) in
      self.balances[key] = value
    }
    if let bal = balances[self.from.contract] {
      self.balance = bal
    }
  }

  func updateSelectedGasPriceType(_ type: KNSelectedGasPriceType) {
    self.selectedGasPriceType = type
    switch type {
    case .fast: self.gasPrice = KNGasCoordinator.shared.fastKNGas
    case .medium: self.gasPrice = KNGasCoordinator.shared.standardKNGas
    case .slow: self.gasPrice = KNGasCoordinator.shared.lowKNGas
    default: break
    }
  }

  // update when set gas price
  func updateGasPrice(_ gasPrice: BigInt) {
    self.gasPrice = gasPrice
    self.selectedGasPriceType = .custom
  }

  @discardableResult
  func updateExchangeRate(for from: TokenObject, to: TokenObject, amount: BigInt, rate: BigInt, slippageRate: BigInt) -> Bool {
    let isAmountChanged: Bool = {
      if self.amountFromBigInt == amount { return false }
      let doubleValue = Double(amount) / pow(10.0, Double(self.from.decimals))
      return doubleValue != 0.001
    }()
    if from == self.from, to == self.to, !isAmountChanged {
      self.estRate = rate
      self.slippageRate = slippageRate
      return true
    }
    return false
  }

  func updateExchangeMinRatePercent(_ percent: Double) {
    self.minRatePercent = percent
  }

  func updateEstimateGasLimit(for from: TokenObject, to: TokenObject, amount: BigInt, gasLimit: BigInt) {
    let isAmountChanged: Bool = {
      if self.amountFromBigInt == amount { return false }
      let doubleValue = Double(amount) / pow(10.0, Double(self.from.decimals))
      return doubleValue != 0.001
    }()
    if from == self.from, to == self.to, !isAmountChanged {
      self.estimateGasLimit = gasLimit
    }
  }

  func updateUserCapInWei(cap: BigInt) {
    self.userCapInWei = cap
  }
}
