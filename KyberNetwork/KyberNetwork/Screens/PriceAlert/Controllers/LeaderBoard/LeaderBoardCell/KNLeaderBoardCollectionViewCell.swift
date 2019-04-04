// Copyright SIX DAY LLC. All rights reserved.

import UIKit

class KNLeaderBoardCollectionViewCell: UICollectionViewCell {

  static let height: CGFloat = 120.0

  @IBOutlet weak var userInfoContainerView: UIView!
  @IBOutlet weak var rankLabel: UILabel!
  @IBOutlet weak var userContactLabel: UILabel!
  @IBOutlet weak var pairTextLabel: UILabel!
  @IBOutlet weak var pairLabel: UILabel!
  @IBOutlet weak var entryTextLabel: UILabel!
  @IBOutlet weak var entryLabel: UILabel!
  @IBOutlet weak var targetTextLabel: UILabel!
  @IBOutlet weak var targetLabel: UILabel!
  @IBOutlet weak var swingsTextLabel: UILabel!
  @IBOutlet weak var swingsLabel: UILabel!
  @IBOutlet weak var rewardAmount: UIButton!

  override func awakeFromNib() {
    super.awakeFromNib()
    // Initialization code
    self.userInfoContainerView.rounded(radius: 4.0)
    self.rankLabel.rounded(radius: self.rankLabel.frame.width / 2.0)
    self.pairTextLabel.text = "Pair".toBeLocalised().uppercased()
    self.entryTextLabel.text = "Entry".toBeLocalised().uppercased()
    self.targetTextLabel.text = "Target".toBeLocalised().uppercased()
    self.swingsTextLabel.text = "Swing".toBeLocalised().uppercased()
    self.rewardAmount.rounded(radius: 2.5)
    self.rounded(radius: 4.0)
  }

  func updateCell(with data: JSONDictionary, at index: Int) {
    self.pairLabel.text = {
      let symbol = data["symbol"] as? String ?? ""
      let base = data["base"] as? String ?? ""
      return "\(symbol)/\(base)"
    }()
    self.entryLabel.text = {
      let price = data["created_at_price"] as? Double ?? 0.0
      return NumberFormatterUtil.shared.displayAlertPrice(from: price)
    }()
    self.targetLabel.text = {
      let target = data["alert_price"] as? Double ?? 0.0
      return NumberFormatterUtil.shared.displayAlertPrice(from: target)
    }()
    self.swingsLabel.text = {
      let change = data["percent_change"] as? Double ?? 0.0
      return NumberFormatterUtil.shared.displayPercentage(from: change) + "%"
    }()
    let currentUserName = data["current_user_name"] as? String
    let reward = data["reward"] as? String
    let rank = data["rank"] as? Int ?? 0
    if let userName = currentUserName {
      self.rankLabel.text = "\(rank)"
      self.rankLabel.backgroundColor = .white
      self.rankLabel.textColor = (reward != nil) ? UIColor.Kyber.shamrock : UIColor(red: 158, green: 161, blue: 170)
      self.userContactLabel.text = userName
      self.userContactLabel.font = UIFont.Kyber.medium(with: 18)
      self.userContactLabel.textColor = .white
      self.userInfoContainerView.backgroundColor = (reward != nil) ? UIColor.Kyber.shamrock : UIColor(red: 158, green: 161, blue: 170)
    } else {
      self.rankLabel.text = "\(rank)"
      self.rankLabel.backgroundColor = (reward != nil) ? UIColor.Kyber.shamrock : UIColor(red: 158, green: 161, blue: 170)
      self.userContactLabel.text = {
        if let tele = data["telegram_account"] as? String { return tele }
        if let email = data["user_email"] as? String { return email }
        return "unknown"
      }()
      self.userContactLabel.font = UIFont.Kyber.medium(with: 12)
      self.userContactLabel.textColor = UIColor.Kyber.blueGreen
      self.userInfoContainerView.backgroundColor = UIColor(red: 246, green: 247, blue: 250)
    }
    //self.rewardAmount.setTitle(reward, for: .normal)
    self.rewardAmount.isHidden = true
    self.layoutIfNeeded()
  }
}
