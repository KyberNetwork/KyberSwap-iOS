// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import BigInt

public struct KNGasConfiguration {
  static let digixGasLimitDefault = BigInt(770_000)
  static let exchangeTokensGasLimitDefault = BigInt(660_000)
  static let exchangeETHTokenGasLimitDefault = BigInt(330_000)
  static let approveTokenGasLimitDefault = BigInt(100_000)
  static let transferTokenGasLimitDefault = BigInt(60_000)
  static let transferETHGasLimitDefault = BigInt(21_000)
  static let buytokenSaleByETHGasLimitDefault = BigInt(550_000)
  static let buyTokenSaleByTokenGasLimitDefault = BigInt(700_000)
  static let daiGasLimitDefault = BigInt(450_000)
  static let makerGasLimitDefault = BigInt(400_000)
  static let propyGasLimitDefault = BigInt(500_000)
  static let promotionTokenGasLimitDefault = BigInt(380_000)
  static let trueUSDTokenGasLimitDefault = BigInt(500_000)

  static let gasPriceDefault: BigInt = EtherNumberFormatter.full.number(from: "10", units: UnitConfiguration.gasPriceUnit)!
  static let gasPriceMin: BigInt = EtherNumberFormatter.full.number(from: "5", units: UnitConfiguration.gasPriceUnit)!
  static let gasPriceMax: BigInt = EtherNumberFormatter.full.number(from: "100", units: UnitConfiguration.gasPriceUnit)!

  static func calculateDefaultGasLimit(from: TokenObject, to: TokenObject) -> BigInt {
    if from == to {
      // normal transfer
      if from.isETH { return transferETHGasLimitDefault }
      return calculateDefaultGasLimitTransfer(token: from)
    }
    let gasSrcToETH: BigInt = {
      if from.isETH { return BigInt(0) }
      if from.isDGX { return digixGasLimitDefault }
      if from.isDAI { return daiGasLimitDefault }
      if from.isMKR { return makerGasLimitDefault }
      if from.isPRO { return propyGasLimitDefault }
      if from.isPT { return promotionTokenGasLimitDefault }
      if from.isTUSD { return trueUSDTokenGasLimitDefault }
      return exchangeETHTokenGasLimitDefault
    }()
    let gasETHToDest: BigInt = {
      if to.isETH { return BigInt(0) }
      if to.isDGX { return digixGasLimitDefault }
      if to.isDAI { return daiGasLimitDefault }
      if to.isMKR { return makerGasLimitDefault }
      if to.isPRO { return propyGasLimitDefault }
      if to.isPT { return promotionTokenGasLimitDefault }
      if to.isTUSD { return trueUSDTokenGasLimitDefault }
      return exchangeETHTokenGasLimitDefault
    }()
    return gasSrcToETH + gasETHToDest
  }

  static func calculateDefaultGasLimitTransfer(token: TokenObject) -> BigInt {
    if token.isETH { return transferETHGasLimitDefault }
    if token.isDGX { return digixGasLimitDefault }
    if token.isDAI { return daiGasLimitDefault }
    if token.isMKR { return makerGasLimitDefault }
    if token.isPRO { return propyGasLimitDefault }
    if token.isPT { return promotionTokenGasLimitDefault }
    if token.isTUSD { return trueUSDTokenGasLimitDefault }
    return transferTokenGasLimitDefault
  }
}
