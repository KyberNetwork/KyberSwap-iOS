// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import BigInt

struct KConfirmSwapViewModel {

  let transaction: KNDraftExchangeTransaction

  init(transaction: KNDraftExchangeTransaction) {
    self.transaction = transaction
  }

  var titleString: String {
    return "\(self.transaction.from.symbol) -> \(self.transaction.to.symbol)"
  }

  var leftAmountString: String {
    let amountString = self.transaction.amount.displayRate(decimals: transaction.from.decimals)
    return "\(amountString.prefix(12)) \(self.transaction.from.symbol)"
  }

  var equivalentUSDAmount: BigInt? {
    if let usdRate = KNRateCoordinator.shared.usdRate(for: self.transaction.to) {
      let expectedReceive = self.transaction.amount * self.transaction.expectedRate / BigInt(10).power(self.transaction.to.decimals)
      return usdRate.rate * expectedReceive / BigInt(10).power(self.transaction.to.decimals)
    }
    return nil
  }

  var displayEquivalentUSDAmount: String? {
    guard let amount = self.equivalentUSDAmount, !amount.isZero else { return nil }
    let value = amount.displayRate(decimals: 18)
    return "~ $\(value) USD"
  }

  var rightAmountString: String {
    let receivedAmount = self.transaction.displayExpectedReceive(short: false)
    return "\(receivedAmount.prefix(12)) \(self.transaction.to.symbol)"
  }

  var displayEstimatedRate: String {
    let rateString = self.transaction.expectedRate.displayRate(decimals: transaction.to.decimals)
    return "1 \(self.transaction.from.symbol) = \(rateString) \(self.transaction.to.symbol)"
  }

  var percentageRateDiff: Double {
    guard let rate = KNRateCoordinator.shared.getCachedProdRate(from: self.transaction.from.symbol, to: self.transaction.to.symbol), !rate.rate.isZero else {
      return 0.0
    }
    if self.transaction.expectedRate.isZero { return 0.0 }
    let marketRateDouble = Double(rate.rate) / pow(10.0, Double(self.transaction.to.decimals))
    let estimatedRateDouble = Double(self.transaction.expectedRate) / pow(10.0, Double(self.transaction.to.decimals))
    let change = (estimatedRateDouble - marketRateDouble) / marketRateDouble * 100.0
    if change >= -0.1 { return 0.0 }
    return change
  }

  var warningRateMessage: String? {
    let change = self.percentageRateDiff
    if change > -1.0 { return nil }
    let display = NumberFormatterUtil.shared.displayPercentage(from: fabs(change))
    let percent = "\(display)%"
    let message = String(format: NSLocalizedString("This rate is %@ lower than current Market", value: "This rate is %@ lower than current Market", comment: ""), percent)
    return message
  }

  var minRateString: String {
    let minRate = self.transaction.minRate ?? BigInt(0)
    return minRate.displayRate(decimals: self.transaction.to.decimals)
  }

  var transactionFee: BigInt {
    let gasPrice: BigInt = self.transaction.gasPrice ?? KNGasCoordinator.shared.fastKNGas
    let gasLimit: BigInt = self.transaction.gasLimit ?? KNGasConfiguration.exchangeTokensGasLimitDefault
    return gasPrice * gasLimit
  }

  var feeETHString: String {
    let string: String = self.transactionFee.displayRate(decimals: 18)
    return "\(string) ETH"
  }

  var feeUSDString: String {
    guard let trackerRate = KNTrackerRateStorage.shared.trackerRate(for: KNSupportedTokenStorage.shared.ethToken) else { return "~ --- USD" }
    let usdRate: BigInt = KNRate.rateUSD(from: trackerRate).rate
    let value: BigInt = usdRate * self.transactionFee / BigInt(EthereumUnit.ether.rawValue)
    let valueString: String = value.displayRate(decimals: 18)
    return "~ \(valueString) USD"
  }
}
