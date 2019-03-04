// Copyright SIX DAY LLC. All rights reserved.

import RealmSwift
import TrustKeystore
import TrustCore
import BigInt

class KNWalletStorage {

  static var shared = KNWalletStorage()
  private(set) var realm: Realm!

  init() {
    let config = RealmConfiguration.globalConfiguration()
    self.realm = try! Realm(configuration: config)
  }

  var wallets: [KNWalletObject] {
    if self.realm == nil { return [] }
    return self.realm.objects(KNWalletObject.self)
      .sorted(byKeyPath: "date", ascending: true)
      .filter { return !$0.address.isEmpty }
  }

  func get(forPrimaryKey key: String) -> KNWalletObject? {
    if self.realm == nil { return nil }
    return self.realm.object(ofType: KNWalletObject.self, forPrimaryKey: key)
  }

  func add(wallets: [KNWalletObject]) {
    if self.realm == nil { return }
    self.realm.beginWrite()
    self.realm.add(wallets, update: true)
    try! self.realm.commitWrite()
  }

  func update(wallets: [KNWalletObject]) {
    self.add(wallets: wallets)
  }

  func delete(wallets: [KNWalletObject]) {
    if self.realm == nil { return }
    self.realm.beginWrite()
    // remove promo info for wallet if have
    wallets.forEach({
      KNWalletPromoInfoStorage.shared.removeWalletPromoInfo(address: $0.address)
    })
    self.realm.delete(wallets)
    try! self.realm.commitWrite()
  }

  func deleteAll() {
    if self.realm == nil { return }
    try! realm.write {
      realm.delete(realm.objects(KNWalletObject.self))
    }
  }
}
