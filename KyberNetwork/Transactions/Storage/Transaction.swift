// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import RealmSwift

class Transaction: Object {
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
    @objc dynamic var compoundKey: String = ""

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
        self.compoundKey = "\(id)\(from)\(to)"
    }

    convenience init(
        id: String,
        date: Date,
        state: TransactionState
    ) {
        self.init()
        self.id = id
        self.date = date
        self.internalState = state.rawValue
        self.compoundKey = id
    }

    override static func primaryKey() -> String? {
        return "compoundKey"
    }

    var state: TransactionState {
        return TransactionState(int: self.internalState)
    }
}

extension Transaction {
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

    var isETHTransfer: Bool {
      guard let token = self.getTokenObject() else { return false }
      return token.isETH
    }

    func isReceivingETH(ownerAddress: String) -> Bool {
      if ownerAddress.lowercased() != self.to.lowercased() { return false }
      guard let token = self.getTokenObject() else { return false }
      return token.isETH
    }

}

extension Transaction {
  func getTokenObject() -> TokenObject? {
    guard let localObject = self.localizedOperations.first, localObject.type == "transfer" else {
      return nil
    }
    guard let contract = localObject.contract,
    let name = localObject.name, !name.isEmpty,
    let symbol = localObject.symbol, !symbol.isEmpty else { return nil }
    let contractAddr: String = {
      if !contract.isEmpty { return contract }
      if symbol == "ETH" { return "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee" }
      return ""
    }()
    if contractAddr.isEmpty { return nil }
    return TokenObject(
      contract: contractAddr,
      name: name,
      symbol: symbol,
      decimals: localObject.decimals,
      value: "0",
      isCustom: false,
      isDisabled: false
    )
  }

  func getTokenSymbol() -> String? {
    guard let localObject = self.localizedOperations.first, localObject.type == "transfer" else {
      return nil
    }
    return localObject.symbol
  }
}

extension Transaction {
  static func swapTransation(sendTx: Transaction, receiveTx: Transaction, curWallet: String) -> Transaction? {
    if sendTx.id != receiveTx.id { return nil }
    if sendTx.from.lowercased() != curWallet.lowercased() && receiveTx.from.lowercased() != curWallet.lowercased() { return nil }
    if sendTx.from.lowercased() != curWallet.lowercased() {
      return Transaction.swapTransation(sendTx: receiveTx, receiveTx: sendTx, curWallet: curWallet)
    }
    if sendTx.from.lowercased() != curWallet.lowercased() || receiveTx.to.lowercased() != curWallet.lowercased() { return nil }
    // must be one send, one receive
    guard let srcToken = sendTx.getTokenObject(), let destToken = receiveTx.getTokenObject() else { return nil }
    if srcToken.symbol == destToken.symbol { return nil }
    let destAddress = sendTx.to.lowercased()
    let fromAmount = sendTx.value
    let destAmount = receiveTx.value

    let localObject = LocalizedOperationObject(
      from: srcToken.contract,
      to: destToken.contract,
      contract: nil,
      type: "exchange",
      value: destAmount,
      symbol: srcToken.symbol,
      name: destToken.symbol,
      decimals: destToken.decimals
    )
    return Transaction(
      id: sendTx.id,
      blockNumber: sendTx.blockNumber,
      from: curWallet,
      to: destAddress,
      value: fromAmount,
      gas: sendTx.gas,
      gasPrice: sendTx.gasPrice,
      gasUsed: sendTx.gasUsed,
      nonce: sendTx.nonce,
      date: sendTx.date,
      localizedOperations: [localObject],
      state: .completed
    )
  }
}
