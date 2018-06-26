// Copyright SIX DAY LLC. All rights reserved.

import UIKit

enum KNHistoryViewEvent {
  case selectPendingTransaction(transaction: Transaction)
  case selectTokenTransaction(transaction: KNTokenTransaction)
  case dismiss
}

protocol KNHistoryViewControllerDelegate: class {
  func historyViewController(_ controller: KNHistoryViewController, run event: KNHistoryViewEvent)
}

class KNHistoryViewModel {
  fileprivate(set) var tokens: [TokenObject] = KNSupportedTokenStorage.shared.supportedTokens

  fileprivate(set) var tokensTxData: [String: [KNTokenTransaction]] = [:]
  fileprivate(set) var tokensTxHeaders: [String] = []

  fileprivate(set) var pendingTxData: [String: [Transaction]] = [:]
  fileprivate(set) var pendingTxHeaders: [String] = []

  fileprivate(set) var ownerAddress: String

  fileprivate(set) var isShowingPending: Bool = true

  init(
    tokens: [TokenObject] = KNSupportedTokenStorage.shared.supportedTokens,
    tokensTxData: [String: [KNTokenTransaction]],
    tokensTxHeaders: [String],
    pendingTxData: [String: [Transaction]],
    pendingTxHeaders: [String],
    ownerAddress: String
    ) {
    self.tokens = tokens
    self.tokensTxData = tokensTxData
    self.tokensTxHeaders = tokensTxHeaders
    self.pendingTxData = pendingTxData
    self.pendingTxHeaders = pendingTxHeaders
    self.ownerAddress = ownerAddress
    self.isShowingPending = true
  }

  func updateIsShowingPending(_ isShowingPending: Bool) {
    self.isShowingPending = isShowingPending
  }

  func update(tokens: [TokenObject]) {
    self.tokens = tokens
  }

  func update(pendingTxData: [String: [Transaction]], pendingTxHeaders: [String]) {
    self.pendingTxData = pendingTxData
    self.pendingTxHeaders = pendingTxHeaders
  }

  func update(tokenTxData: [String: [KNTokenTransaction]], tokenTxHeaders: [String]) {
    self.tokensTxData = tokenTxData
    self.tokensTxHeaders = tokenTxHeaders
  }

  func updateOwnerAddress(_ ownerAddress: String) {
    self.ownerAddress = ownerAddress
  }

  var isNoPendingTxHidden: Bool {
    if self.isShowingPending { return !self.pendingTxHeaders.isEmpty }
    return true
  }

  var isRateMightChangeHidden: Bool {
    return (!self.isShowingPending || !self.isNoPendingTxHidden)
  }

  var transactionCollectionViewBottomPaddingConstraint: CGFloat {
    return self.isRateMightChangeHidden ? 0.0 : 192.0
  }

  var isTransactionCollectionViewHidden: Bool {
    return !self.isNoPendingTxHidden
  }

  var numberSections: Int {
    if self.isShowingPending { return self.pendingTxHeaders.count }
    return self.tokensTxHeaders.count
  }

  func header(for section: Int) -> String {
    let header: String = {
      if self.isShowingPending { return self.pendingTxHeaders[section] }
      return self.tokensTxHeaders[section]
    }()
    return header
  }

  func numberRows(for section: Int) -> Int {
    let header = self.header(for: section)
    return (self.isShowingPending ? self.pendingTxData[header]?.count : self.tokensTxData[header]?.count) ?? 0
  }

  func tokenTransaction(for row: Int, at section: Int) -> KNTokenTransaction? {
    let header = self.header(for: section)
    if let trans = self.tokensTxData[header], trans.count >= row {
      return trans[row]
    }
    return nil
  }

  func pendingTransaction(for row: Int, at section: Int) -> Transaction? {
    let header = self.header(for: section)
    if let trans = self.pendingTxData[header], trans.count >= row {
      return trans[row]
    }
    return nil
  }

  var normalAttributes: [NSAttributedStringKey: Any] = [
    NSAttributedStringKey.font: UIFont(name: "SFProText-Medium", size: 17)!,
    NSAttributedStringKey.foregroundColor: UIColor(hex: "d8d8d8"),
  ]

  var selectedAttributes: [NSAttributedStringKey: Any] = [
    NSAttributedStringKey.font: UIFont(name: "SFProText-Medium", size: 17)!,
    NSAttributedStringKey.foregroundColor: UIColor.white,
  ]
}

class KNHistoryViewController: KNBaseViewController {

  weak var delegate: KNHistoryViewControllerDelegate?
  fileprivate var viewModel: KNHistoryViewModel

  @IBOutlet weak var noPendingTxContainerView: UIView!
  @IBOutlet weak var youAreAllSet: UILabel!
  @IBOutlet weak var rateMightChangeContainerView: UIView!

  @IBOutlet weak var segmentedControl: UISegmentedControl!

  @IBOutlet weak var transactionCollectionView: UICollectionView!
  @IBOutlet weak var transactionCollectionViewBottomConstraint: NSLayoutConstraint!

  init(viewModel: KNHistoryViewModel) {
    self.viewModel = viewModel
    super.init(nibName: KNHistoryViewController.className, bundle: nil)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var preferredStatusBarStyle: UIStatusBarStyle { return .lightContent }

  override func viewDidLoad() {
    super.viewDidLoad()
    self.setupUI()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    self.viewModel.updateIsShowingPending(true)
    self.updateUIWhenDataDidChange()
  }

  fileprivate func setupUI() {
    self.setupNavigationBar()
    self.setupCollectionView()
  }

  fileprivate func setupNavigationBar() {
    self.navigationItem.title = "History".toBeLocalised()
  }

  fileprivate func setupCollectionView() {
    self.segmentedControl.rounded(color: .clear, width: 0, radius: 5.0)
    self.segmentedControl.setTitleTextAttributes(self.viewModel.normalAttributes, for: .normal)
    self.segmentedControl.setTitleTextAttributes(self.viewModel.selectedAttributes, for: .selected)

    let nib = UINib(nibName: KNTransactionCollectionViewCell.className, bundle: nil)
    self.transactionCollectionView.register(nib, forCellWithReuseIdentifier: KNTransactionCollectionViewCell.cellID)
    let headerNib = UINib(nibName: KNTransactionCollectionReusableView.className, bundle: nil)
    self.transactionCollectionView.register(headerNib, forSupplementaryViewOfKind: UICollectionElementKindSectionHeader, withReuseIdentifier: KNTransactionCollectionReusableView.viewID)
    self.transactionCollectionView.delegate = self
    self.transactionCollectionView.dataSource = self

    self.updateUIWhenDataDidChange()
  }

  fileprivate func updateUIWhenDataDidChange() {
    self.noPendingTxContainerView.isHidden = self.viewModel.isNoPendingTxHidden
    self.rateMightChangeContainerView.isHidden = self.viewModel.isRateMightChangeHidden
    self.transactionCollectionView.isHidden = self.viewModel.isTransactionCollectionViewHidden
    self.transactionCollectionViewBottomConstraint.constant = self.viewModel.transactionCollectionViewBottomPaddingConstraint
    self.transactionCollectionView.reloadData()
    self.view.updateConstraintsIfNeeded()
    self.view.layoutIfNeeded()
  }

  @IBAction func backButtonPressed(_ sender: Any) {
    self.delegate?.historyViewController(self, run: .dismiss)
  }

  @IBAction func segmentedControlValueDidChange(_ sender: UISegmentedControl) {
    self.viewModel.updateIsShowingPending(sender.selectedSegmentIndex == 0)
    self.updateUIWhenDataDidChange()
  }

  @IBAction func screenEdgePanGestureAction(_ sender: UIScreenEdgePanGestureRecognizer) {
    if sender.state == .ended {
      self.delegate?.historyViewController(self, run: .dismiss)
    }
  }
}

extension KNHistoryViewController {
  func coordinatorUpdateHistoryTransactions(
    data: [String: [KNHistoryTransaction]],
    dates: [String],
    ownerAddress: String
    ) {
    self.updateUIWhenDataDidChange()
  }

  func coordinatorUpdateTokenTransactions(
    data: [String: [KNTokenTransaction]],
    dates: [String],
    ownerAddress: String
    ) {
    self.viewModel.update(tokenTxData: data, tokenTxHeaders: dates)
    self.viewModel.updateOwnerAddress(ownerAddress)
    self.updateUIWhenDataDidChange()
  }

  func coordinatorUpdatePendingTransaction(
    data: [String: [Transaction]],
    dates: [String],
    ownerAddress: String) {
    self.viewModel.update(pendingTxData: data, pendingTxHeaders: dates)
    self.viewModel.updateOwnerAddress(ownerAddress)
    self.updateUIWhenDataDidChange()
  }
}

extension KNHistoryViewController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    if self.segmentedControl.selectedSegmentIndex == 0 {
      guard let transaction = self.viewModel.pendingTransaction(for: indexPath.row, at: indexPath.section) else { return }
      self.delegate?.historyViewController(self, run: .selectPendingTransaction(transaction: transaction))
    } else {
      guard let transaction = self.viewModel.tokenTransaction(for: indexPath.row, at: indexPath.section) else { return }
      self.delegate?.historyViewController(self, run: .selectTokenTransaction(transaction: transaction))
    }
  }
}

extension KNHistoryViewController: UICollectionViewDelegateFlowLayout {
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
    return 5
  }

  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
    return UIEdgeInsets(top: 0, left: 0, bottom: 10, right: 0)
  }

  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
    return CGSize(
      width: collectionView.frame.width,
      height: KNTransactionCollectionViewCell.cellHeight
    )
  }

  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
    return CGSize(
      width: collectionView.frame.width,
      height: 32
    )
  }
}

extension KNHistoryViewController: UICollectionViewDataSource {
  func numberOfSections(in collectionView: UICollectionView) -> Int {
    return self.viewModel.numberSections
  }

  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return self.viewModel.numberRows(for: section)
  }

  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: KNTransactionCollectionViewCell.cellID, for: indexPath) as! KNTransactionCollectionViewCell
    if self.viewModel.isShowingPending {
      guard let tx = self.viewModel.pendingTransaction(for: indexPath.row, at: indexPath.section) else { return cell }
      cell.updateCell(with: tx, tokens: self.viewModel.tokens, ownerAddress: self.viewModel.ownerAddress)
    } else {
      guard let tx = self.viewModel.tokenTransaction(for: indexPath.row, at: indexPath.section) else { return cell }
      cell.updateCell(with: tx, ownerAddress: self.viewModel.ownerAddress)
    }
    return cell
  }

  func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
    switch kind {
    case UICollectionElementKindSectionHeader:
      let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: KNTransactionCollectionReusableView.viewID, for: indexPath) as! KNTransactionCollectionReusableView
      headerView.updateView(with: self.viewModel.header(for: indexPath.section))
      return headerView
    default:
      assertionFailure("Unhandling")
      return UICollectionReusableView()
    }
  }
}
