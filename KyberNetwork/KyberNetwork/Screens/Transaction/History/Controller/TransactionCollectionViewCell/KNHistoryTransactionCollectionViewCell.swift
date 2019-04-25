// Copyright SIX DAY LLC. All rights reserved.

import UIKit

protocol KNHistoryTransactionCollectionViewCellDelegate: class {
  func historyTransactionCollectionViewCell(_ cell: KNHistoryTransactionCollectionViewCell, openDetails transaction: Transaction)
}

struct KNHistoryTransactionCollectionViewModel {
  let index: Int
  let transaction: Transaction
  let ownerAddress: String
  let ownerWalletName: String

  init(
    transaction: Transaction,
    ownerAddress: String,
    ownerWalletName: String,
    index: Int
    ) {
    self.transaction = transaction
    self.ownerAddress = ownerAddress
    self.ownerWalletName = ownerWalletName
    self.index = index
  }

  var backgroundColor: UIColor { return self.index % 2 == 0 ? UIColor.white : UIColor(red: 246, green: 247, blue: 250) }

  var isSwap: Bool { return self.transaction.localizedOperations.first?.type == "exchange" }
  var isSent: Bool {
    if self.isSwap { return false }
    return self.transaction.from.lowercased() == self.ownerAddress.lowercased()
  }

  var iconName: String {
    if self.transaction.state == .error || self.transaction.state == .failed { return "error_icon" }
    if self.isSwap { return "token_swap_icon" }
    return self.isSent ? "out_icon" : "in_icon"
  }

  var isAmountTransactionHidden: Bool {
    return self.transaction.state == .error || self.transaction.state == .failed
  }

  var transactionTitleString: String {
    if self.transaction.state == .error || self.transaction.state == .failed {
      return "[\(NSLocalizedString("error", value: "Error", comment: ""))]"
    }
    let typeString: String = {
      if self.isSwap { return NSLocalizedString("swap", value: "Swap", comment: "") }
      return self.isSent ? NSLocalizedString("send", value: "Send", comment: "") : NSLocalizedString("receive", value: "Receive", comment: "")
    }()
    return typeString
  }

  let normalTextAttributes: [NSAttributedStringKey: Any] = [
    NSAttributedStringKey.foregroundColor: UIColor(red: 182, green: 186, blue: 185),
    NSAttributedStringKey.font: UIFont.Kyber.medium(with: 14),
    NSAttributedStringKey.kern: 0.0,
  ]

  let highlightedTextAttributes: [NSAttributedStringKey: Any] = [
    NSAttributedStringKey.foregroundColor: UIColor(red: 90, green: 94, blue: 103),
    NSAttributedStringKey.font: UIFont.Kyber.medium(with: 14),
    NSAttributedStringKey.kern: 0.0,
  ]

  var descriptionLabelAttributedString: NSAttributedString {
    let attributedString = NSMutableAttributedString()
    if self.isSwap {
      attributedString.append(NSAttributedString(string: self.ownerWalletName, attributes: highlightedTextAttributes))
      attributedString.append(NSAttributedString(string: "\n\(self.ownerAddress.prefix(8))....\(self.ownerAddress.suffix(6))", attributes: normalTextAttributes))
      return attributedString
    }

    let fromText: String = {
      if self.isSent { return self.ownerWalletName }
      return "\(self.transaction.from.prefix(8))....\(self.transaction.from.suffix(6))"
    }()
    let toText: String = {
      if self.isSent {
        return "\(self.transaction.to.prefix(8))....\(self.transaction.to.suffix(6))"
      }
      return self.ownerWalletName
    }()
    attributedString.append(NSAttributedString(string: "\(NSLocalizedString("from", value: "From", comment: "")) ", attributes: normalTextAttributes))
    attributedString.append(NSAttributedString(string: fromText, attributes: highlightedTextAttributes))
    attributedString.append(NSAttributedString(string: "\n\(NSLocalizedString("to", value: "To", comment: "")) ", attributes: normalTextAttributes))
    attributedString.append(NSAttributedString(string: toText, attributes: highlightedTextAttributes))
    return attributedString
  }

  var displayedAmountString: String {
    guard let localObject = self.transaction.localizedOperations.first else { return "" }
    if self.isSwap {
      let amountFrom: String = {
        if let double = Double(self.transaction.value),
          let string = NumberFormatterUtil.shared.swapAmountFormatter.string(from: NSNumber(value: double)) {
          return string
        }
        return String(self.transaction.value.prefix(12))
      }()
      let fromText: String = "\(amountFrom) \(localObject.symbol ?? "")"

      let amountTo: String = {
        if let double = Double(localObject.value),
          let string = NumberFormatterUtil.shared.swapAmountFormatter.string(from: NSNumber(value: double)) {
          return string
        }
        return String(localObject.value.prefix(12))
      }()
      let toText = "\(amountTo) \(localObject.name ?? "")"

      return "\(fromText) -> \(toText)"
    }
    let sign: String = self.isSent ? "-" : "+"
    return "\(sign)\(self.transaction.value.prefix(12)) \(localObject.symbol ?? "")"
  }

  var displayedAmountColorHex: String {
    if self.isSwap { return "F89F50" }
    return self.isSent ? "f87171" : "31cb9e"
  }
}

class KNHistoryTransactionCollectionViewCell: UICollectionViewCell {

  static let cellID: String = "kHistoryTransactionCellID"
  static let height: CGFloat = 84.0

  weak var delegate: KNHistoryTransactionCollectionViewCellDelegate?
  fileprivate var viewModel: KNHistoryTransactionCollectionViewModel!

  @IBOutlet weak var stateImageView: UIImageView!
  @IBOutlet weak var transactionStateTitleLabel: UILabel!
  @IBOutlet weak var transactionDescLabel: UILabel!
  @IBOutlet weak var transactionAmountLabel: UILabel!

  override func awakeFromNib() {
    super.awakeFromNib()
    // reset data
    self.transactionStateTitleLabel.text = ""
    self.transactionDescLabel.text = ""
    self.transactionAmountLabel.text = ""
  }

  func updateCell(with model: KNHistoryTransactionCollectionViewModel) {
    self.viewModel = model
    self.backgroundColor = model.backgroundColor
    self.stateImageView.image = UIImage(named: model.iconName)
    self.transactionStateTitleLabel.text = model.transactionTitleString
    self.transactionDescLabel.attributedText = model.descriptionLabelAttributedString
    self.transactionAmountLabel.text = model.displayedAmountString
    self.transactionAmountLabel.textColor = UIColor(hex: model.displayedAmountColorHex)
    self.transactionAmountLabel.isHidden = model.isAmountTransactionHidden
    self.layoutIfNeeded()
  }
}
