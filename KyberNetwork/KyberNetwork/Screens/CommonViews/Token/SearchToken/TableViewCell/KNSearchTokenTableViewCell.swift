// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import BigInt

class KNSearchTokenTableViewCell: UITableViewCell {

  @IBOutlet weak var iconImageView: UIImageView!
  @IBOutlet weak var tokenNameLabel: UILabel!
  @IBOutlet weak var tokenSymbolLabel: UILabel!
  @IBOutlet weak var balanceLabel: UILabel!

  override func awakeFromNib() {
    super.awakeFromNib()
    self.tokenNameLabel.text = ""
    self.tokenSymbolLabel.text = ""
    self.textLabel?.textColor = UIColor.Kyber.gray
    self.textLabel?.font = UIFont.systemFont(ofSize: 17, weight: .medium)
  }

  func updateCell(with token: TokenObject, balance: Balance?) {
    if let image = UIImage(named: token.icon.lowercased()) {
      self.iconImageView.image = image
    } else {
      self.iconImageView.setImage(
        with: token.iconURL,
        placeholder: UIImage(named: "default_token"))
    }
    self.tokenSymbolLabel.text = "\(token.symbol.prefix(8))"
    self.tokenSymbolLabel.addLetterSpacing()
    self.tokenNameLabel.text = token.name
    self.tokenNameLabel.addLetterSpacing()
    let balText: String = balance?.value.string(
      decimals: token.decimals,
      minFractionDigits: 0,
      maxFractionDigits: min(token.decimals, 6)
      ) ?? ""
    self.balanceLabel.text = "\(balText.prefix(12))"
    self.balanceLabel.addLetterSpacing()
    self.layoutIfNeeded()
  }
}
