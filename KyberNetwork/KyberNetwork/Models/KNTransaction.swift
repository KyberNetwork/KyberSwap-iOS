// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import BigInt
import RealmSwift

enum KNTransactionType {
  case transfer(UnconfirmedTransaction)
  case exchange(KNDraftExchangeTransaction)

  var isTransfer: Bool {
    if case .transfer = self { return true }
    return false
  }
}

class KNTransaction: Object {
  @objc dynamic var id: String = ""
  @objc dynamic var blockNumber: Int = 0
  @objc dynamic var from = ""
  @objc dynamic var to = ""
  @objc dynamic var value = ""
  @objc dynamic var gas = ""
  @objc dynamic var gasPrice = ""
  @objc dynamic var gasUsed = ""
  @objc dynamic var nonce: String = ""
  @objc dynamic var date = Date()
  @objc dynamic var internalState: Int = TransactionState.completed.rawValue
  var localizedOperations = List<LocalizedOperationObject>()

  convenience init(
    id: String,
    blockNumber: Int,
    from: String,
    to: String,
    value: String,
    gas: String,
    gasPrice: String,
    gasUsed: String,
    nonce: String,
    date: Date,
    localizedOperations: [LocalizedOperationObject],
    state: TransactionState
    ) {

    self.init()
    self.id = id
    self.blockNumber = blockNumber
    self.from = from
    self.to = to
    self.value = value
    self.gas = gas
    self.gasPrice = gasPrice
    self.gasUsed = gasUsed
    self.nonce = nonce
    self.date = date
    self.internalState = state.rawValue

    let list = List<LocalizedOperationObject>()
    localizedOperations.forEach { element in
      list.append(element)
    }

    self.localizedOperations = list
  }

  override static func primaryKey() -> String? {
    return "id"
  }

  var state: TransactionState {
    return TransactionState(int: self.internalState)
  }
}

extension KNTransaction {
  var operation: LocalizedOperationObject? {
    return localizedOperations.first
  }

  var shortDesc: String {
    guard let object = self.localizedOperations.first else { return "" }
    if object.type == "transfer" {
      return "\(object.symbol ?? "") -> \(self.to.prefix(10))..."
    }
    return "\(object.symbol ?? "") -> \(object.name ?? "")"
  }

  var isTransfer: Bool {
    guard let object = self.localizedOperations.first else { return false }
    return object.type == "transfer"
  }
}

extension KNTransaction {
  func getTokenObject() -> TokenObject? {
    guard let localObject = self.localizedOperations.first, localObject.type == "transfer" else {
      return nil
    }
    return TokenObject(
      contract: localObject.contract ?? "",
      name: localObject.name ?? "",
      symbol: localObject.symbol ?? "",
      decimals: localObject.decimals,
      value: "0",
      isCustom: false,
      isDisabled: false
    )
  }

  static func from(transaction: Transaction) -> KNTransaction {
    var operations: [LocalizedOperationObject] = []
    for object in transaction.localizedOperations {
      operations.append(object)
    }
    return KNTransaction(
      id: transaction.id,
      blockNumber: transaction.blockNumber,
      from: transaction.from,
      to: transaction.to,
      value: transaction.value,
      gas: transaction.gas,
      gasPrice: transaction.gasPrice,
      gasUsed: transaction.gasUsed,
      nonce: transaction.nonce,
      date: transaction.date,
      localizedOperations: operations,
      state: transaction.state
    )
  }

  func toTransaction() -> Transaction {
    var operations: [LocalizedOperationObject] = []
    for object in self.localizedOperations {
      operations.append(object)
    }
    return Transaction(
      id: self.id,
      blockNumber: self.blockNumber,
      from: self.from,
      to: self.to,
      value: self.value,
      gas: self.gas,
      gasPrice: self.gasPrice,
      gasUsed: self.gasUsed,
      nonce: self.nonce,
      date: self.date,
      localizedOperations: operations,
      state: self.state
    )
  }

  func getDetails() -> String {
    let status: KNTransactionStatus = {
      if self.state == .pending { return .pending }
      if self.state == .failed || self.state == .error { return .failed }
      if self.state == .completed { return .success }
      return .unknown
    }()
    let details: String = {
      if status == .pending {
        return NSLocalizedString("your.transaction.has.been.broadcasted", comment: "")
      }
      guard let object = self.localizedOperations.first, status == .failed || status == .success else { return status.statusDetails }
      let storage: KNTokenStorage? = {
        do {
          let keystore = try EtherKeystore()
          guard let wallet = keystore.recentlyUsedWallet else { return nil }
          let config = RealmConfiguration.configuration(for: wallet, chainID: KNEnvironment.default.chainID)
          do {
            let realm = try Realm(configuration: config)
            return KNTokenStorage(realm: realm)
          } catch { }
        } catch { }
        return nil
      }()
      guard let from = storage?.get(forPrimaryKey: object.from) else { return status.statusDetails }
      guard let amount = self.value.fullBigInt(decimals: from.decimals) else { return status.statusDetails }
      let amountFrom: String = "\(amount.string(decimals: from.decimals, minFractionDigits: 0, maxFractionDigits: 9).prefix(10))"
      if object.type.lowercased() == "transfer" {
        let localisedString: String = {
          if status == .success {
            return NSLocalizedString("successfully.sent.to", value: "%@ successfully sent to %@", comment: "")
          }
          return NSLocalizedString("can.not.send.to", value: "Can not send %@ to %@", comment: "")
        }()
        return String(format: localisedString, arguments: ["\(amountFrom) \(from.symbol)", "\n\(self.to)"])
      }
      guard let to = storage?.get(forPrimaryKey: object.to) else { return status.statusDetails }
      guard let expectedAmount = object.value.fullBigInt(decimals: object.decimals) else { return status.statusDetails }
      let amountTo: String = "\(expectedAmount.string(decimals: object.decimals, minFractionDigits: 0, maxFractionDigits: 9).prefix(10))"
      let localisedString: String = {
        if status == .success {
          return NSLocalizedString("successfully.converted.to", value: "%@ successfully converted to %@", comment: "")
        }
        return NSLocalizedString("can.not.convert.from.to", value: "Can not convert from %@ to %@", comment: "")
      }()
      return String(format: localisedString, arguments: ["\(amountFrom) \(from.symbol)", "\(amountTo) \(to.symbol)"])
    }()
    return details
  }
}

extension TransactionsStorage {
  var kyberTransactions: [KNTransaction] {
    return realm.objects(KNTransaction.self)
      .sorted(byKeyPath: "date", ascending: false)
      .filter { !$0.id.isEmpty }
  }

  var kyberPendingTransactions: [KNTransaction] {
    return self.kyberTransactions.filter { return $0.state == .pending }
  }

  var kyberMinedTransactions: [KNTransaction] {
    return self.kyberTransactions.filter { return $0.state != .pending || $0.state != .unknown }
  }

  func getKyberTransaction(forPrimaryKey: String) -> KNTransaction? {
    return realm.object(ofType: KNTransaction.self, forPrimaryKey: forPrimaryKey)
  }

  @discardableResult
  func addKyberTransactions(_ items: [KNTransaction]) -> [KNTransaction] {
    realm.beginWrite()
    realm.add(items, update: true)
    try! realm.commitWrite()
    return items
  }

  func delete(_ items: [KNTransaction]) {
    try! realm.write {
      realm.delete(items)
    }
  }

  @discardableResult
  func update(state: TransactionState, for transaction: KNTransaction) -> KNTransaction {
    realm.beginWrite()
    transaction.internalState = state.rawValue
    try! realm.commitWrite()
    return transaction
  }

  func deleteAllKyberTransactions() {
    self.delete(self.kyberTransactions)
  }
}
