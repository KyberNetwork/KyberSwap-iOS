// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import BigInt

struct KNBalanceTokenTableViewCellModel {
  let token: TokenObject
  let trackerRate: KNTrackerRate?
  let balance: Balance?
  let currencyType: KWalletCurrencyType
  let index: Int

  init(
    token: TokenObject,
    trackerRate: KNTrackerRate?,
    balance: Balance?,
    currencyType: KWalletCurrencyType,
    index: Int
    ) {
    self.token = token
    self.trackerRate = trackerRate
    self.balance = balance
    self.currencyType = currencyType
    self.index = index
  }

  var isNewTokenHidden: Bool {
    if let isNew = token.extraData?.shouldShowAsNew, isNew { return false }
    return true
  }

  var backgroundColor: UIColor {
    return self.index % 2 == 0 ? .white : UIColor(red: 248, green: 249, blue: 255)
  }

  var displaySymbolAndNameAttributedString: NSAttributedString {
    let attributedString = NSMutableAttributedString()
    let symbolAttributes: [NSAttributedStringKey: Any] = [
      NSAttributedStringKey.font: UIFont.Kyber.medium(with: 16),
      NSAttributedStringKey.foregroundColor: UIColor(red: 29, green: 48, blue: 58),
      NSAttributedStringKey.kern: 0.0,
    ]
    attributedString.append(NSAttributedString(string: String(self.token.symbol.prefix(8)), attributes: symbolAttributes))
    return attributedString
  }

  var displayRateString: String {
    let rate: BigInt? = {
      if self.currencyType == .usd {
        if let trackerRate = self.trackerRate {
          return KNRate.rateUSD(from: trackerRate).rate
        }
        return nil
      }
      if let trackerRate = self.trackerRate {
        return KNRate.rateETH(from: trackerRate).rate
      }
      return nil
    }()
    return rate?.displayRate(decimals: 18) ?? "---"
  }

  var displayAmountHoldingsText: String {
    return self.balance?.value.string(decimals: self.token.decimals, minFractionDigits: 0, maxFractionDigits: min(self.token.decimals, 6)) ?? "---"
  }

  fileprivate var displayBalanceValue: String {
    return self.currencyType == .usd ? self.displayBalanceInUSD : self.displayBalanceInETH
  }

  fileprivate var displayBalanceInUSD: String {
    if let amount = self.balance?.value, let trackerRate = self.trackerRate {
      let rate = KNRate.rateUSD(from: trackerRate)
      let value = (amount * rate.rate / BigInt(10).power(self.token.decimals)).string(units: .ether, minFractionDigits: 0, maxFractionDigits: 6)
      return "~\(value.prefix(11)) \(self.currencyType.rawValue)"
    }
    return "---"
  }

  fileprivate var displayBalanceInETH: String {
    if let amount = self.balance?.value, let trackerRate = self.trackerRate {
      let rate = KNRate.rateETH(from: trackerRate)
      let value = (amount * rate.rate / BigInt(10).power(self.token.decimals)).string(units: .ether, minFractionDigits: 0, maxFractionDigits: 9)
      return "~\(value.prefix(11)) \(self.currencyType.rawValue)"
    }
    return "---"
  }

  var colorChange24h: UIColor {
    guard let tracker = self.trackerRate else { return UIColor.Kyber.grayChateau }
    let change: Double = {
      if self.currencyType == .eth { return tracker.changeETH24h }
      return tracker.changeUSD24h
    }()
    if change == 0 { return UIColor.Kyber.grayChateau }
    if change > 0 { return UIColor.Kyber.shamrock }
    return UIColor.Kyber.strawberry
  }

  var change24hString: String {
    guard let tracker = self.trackerRate else { return "---" }
    let change: Double = {
      if self.currencyType == .eth { return tracker.changeETH24h }
      return tracker.changeUSD24h
    }()
    let string = NumberFormatterUtil.shared.displayPercentage(from: change)
    return "\(string)%"
  }

  var change24hImage: UIImage? {
    guard let tracker = self.trackerRate else { return nil }
    let change: Double = {
      if self.currencyType == .eth { return tracker.changeETH24h }
      return tracker.changeUSD24h
    }()
    if change == 0 { return nil }
    if change > 0 { return UIImage(named: "change_up") }
    return UIImage(named: "change_down")
  }
}

class KNBalanceTokenTableViewCell: UITableViewCell {

  static let kCellID: String = "KNBalanceTokenTableViewCell"
  static let kCellHeight: CGFloat = 64

  @IBOutlet weak var newTextLabel: UILabel!
  @IBOutlet weak var iconImageView: UIImageView!
  @IBOutlet weak var symbolLabel: UILabel!
  @IBOutlet weak var amountHoldingsLabel: UILabel!
  @IBOutlet weak var rateLabel: UILabel!
  @IBOutlet weak var change24h: UIButton!

  override func awakeFromNib() {
    super.awakeFromNib()
    // Initialization code
    self.iconImageView.image = nil
    self.symbolLabel.text = ""
    self.rateLabel.text = ""
    self.amountHoldingsLabel.text = ""
    self.newTextLabel.text = NSLocalizedString("new", value: "New", comment: "").uppercased()
    self.iconImageView.rounded(radius: self.iconImageView.frame.width / 2.0)
  }

  func updateCellView(with viewModel: KNBalanceTokenTableViewCellModel) {
    self.newTextLabel.isHidden = viewModel.isNewTokenHidden
    self.iconImageView.setTokenImage(
      token: viewModel.token,
      size: self.iconImageView.frame.size
    )
    self.symbolLabel.attributedText = viewModel.displaySymbolAndNameAttributedString
    self.rateLabel.text = viewModel.displayRateString
    self.rateLabel.addLetterSpacing()
    self.amountHoldingsLabel.text = viewModel.displayAmountHoldingsText
    self.amountHoldingsLabel.addLetterSpacing()
    self.backgroundColor = viewModel.backgroundColor

    self.change24h.setTitleColor(
      viewModel.colorChange24h,
      for: .normal
    )
    self.change24h.setTitle(
      viewModel.change24hString,
      for: .normal
    )
    self.change24h.setImage(viewModel.change24hImage, for: .normal)
  }
}
