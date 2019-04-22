// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import Result
import Moya
import BigInt

/*

 This coordinator controls the fetching exchange token + usd rates,
 running timer interval to frequently fetch data from /getRate and /getRateUSD APIs

*/

class KNRateCoordinator {

  static let shared = KNRateCoordinator()

  fileprivate let provider = MoyaProvider<KNTrackerService>()

  fileprivate var cacheTokenETHRates: [String: KNRate] = [:] // Rate token to ETH
  fileprivate var cachedProdTokenRates: [String: KNRate] = [:] // Prod cached rate to compare when swapping
  fileprivate var cacheRateTimer: Timer?

  fileprivate var cachedUSDRates: [String: KNRate] = [:] // Rate token to USD

  fileprivate var exchangeTokenRatesTimer: Timer?
  fileprivate var isLoadingExchangeTokenRates: Bool = false

  func getRate(from: TokenObject, to: TokenObject) -> KNRate? {
    if from.isETH {
      if let trackerRate = KNTrackerRateStorage.shared.trackerRate(for: to) {
        return KNRate(
          source: from.symbol,
          dest: to.symbol,
          rate: trackerRate.rateETHNow == 0.0 ? 0.0 : 1.0 / trackerRate.rateETHNow,
          decimals: to.decimals
        )
      }
    } else if to.isETH {
      if let rate = self.cacheTokenETHRates[from.symbol] { return rate }
      if let rate = KNTrackerRateStorage.shared.trackerRate(for: from) {
        return KNRate.rateETH(from: rate)
      }
    }
    guard let rateFrom = KNTrackerRateStorage.shared.trackerRate(for: from),
      let rateTo = KNTrackerRateStorage.shared.trackerRate(for: to) else { return nil }
    if rateTo.rateUSDNow == 0.0 { return nil }
    return KNRate(
      source: from.symbol,
      dest: to.symbol,
      rate: rateFrom.rateUSDNow / rateTo.rateUSDNow,
      decimals: to.decimals
    )
  }

  func getCachedProdRate(from: TokenObject, to: TokenObject) -> BigInt? {
    if let rate = self.cachedProdTokenRates["\(from.symbol)_\(to.symbol)"] { return rate.rate }
    if let rateToETH = self.cachedProdTokenRates["\(from.symbol)_ETH"],
      let rateETHTo = self.cachedProdTokenRates["ETH_\(to.symbol)"] {
      let swapRate = rateToETH.rate * rateETHTo.rate / BigInt(10).power(18)
      return swapRate
    }
    return self.getRate(from: from, to: to)?.rate
  }

  func getCacheRate(from: String, to: String) -> KNRate? {
    if to == "ETH" { return self.cacheTokenETHRates[from] }
    if to == "USD" { return self.cachedUSDRates[from] }
    return self.cachedProdTokenRates["\(from)_\(to)"]
  }

  func usdRate(for token: TokenObject) -> KNRate? {
    if let cachedRate = self.cachedUSDRates[token.symbol] { return cachedRate }
    if let trackerRate = KNTrackerRateStorage.shared.trackerRate(for: token) {
      return KNRate.rateUSD(from: trackerRate)
    }
    return nil
  }

  func ethRate(for token: TokenObject) -> KNRate? {
    if let rate = self.getCacheRate(from: token.symbol, to: "ETH") { return rate }
    if let rate = KNTrackerRateStorage.shared.trackerRate(for: token) {
      return KNRate(source: "", dest: "", rate: rate.rateETHNow, decimals: 18)
    }
    return nil
  }

  init() {}

  func resume() {
    self.fetchCacheRate(nil)
    self.cacheRateTimer?.invalidate()
    self.cacheRateTimer = Timer.scheduledTimer(
      withTimeInterval: KNLoadingInterval.defaultLoadingInterval,
      repeats: true,
      block: { [weak self] timer in
        self?.fetchCacheRate(timer)
      }
    )
    // Immediate fetch data from server, then run timers with interview 60 seconds
    self.fetchExchangeTokenRate(nil)
    self.exchangeTokenRatesTimer?.invalidate()

    self.exchangeTokenRatesTimer = Timer.scheduledTimer(
      withTimeInterval: KNLoadingInterval.cacheRateLoadingInterval,
      repeats: true,
      block: { [weak self] timer in
      self?.fetchExchangeTokenRate(timer)
      }
    )
  }

  func pause() {
    self.cacheRateTimer?.invalidate()
    self.cacheRateTimer = nil
    self.exchangeTokenRatesTimer?.invalidate()
    self.exchangeTokenRatesTimer = nil
    self.isLoadingExchangeTokenRates = false
  }

  @objc func fetchExchangeTokenRate(_ sender: Any?) {
    if isLoadingExchangeTokenRates { return }
    isLoadingExchangeTokenRates = true
    DispatchQueue.global(qos: .background).async {
      let provider = MoyaProvider<KNTrackerService>()
      provider.request(.getRates, completion: { [weak self] result in
        guard let `self` = self else { return }
        DispatchQueue.main.async {
          self.isLoadingExchangeTokenRates = false
          if case .success(let resp) = result {
            do {
              _ = try resp.filterSuccessfulStatusCodes()
              guard let json = try resp.mapJSON(failsOnEmptyData: false) as? JSONDictionary else { return }
              var rates: [KNTrackerRate] = []
              for value in json.values {
                if let rateJSON = value as? JSONDictionary {
                  rates.append(KNTrackerRate(dict: rateJSON))
                }
              }
              KNTrackerRateStorage.shared.update(rates: rates)
              // cached rate is more updated than exchange token rate API
              self.updateTrackerRateWithCachedRates(isUSD: true, isNotify: false)
              self.updateTrackerRateWithCachedRates(isUSD: false, isNotify: true)

            } catch {}
          }
        }
      })
    }
  }

  @objc func fetchCacheRate(_ sender: Any?) {
    KNInternalProvider.shared.getKNExchangeTokenRate { [weak self] result in
      guard let `self` = self else { return }
      if case .success(let rates) = result {
        rates.forEach({
          if $0.dest == "ETH" { self.cacheTokenETHRates[$0.source] = $0 }
        })
        self.updateTrackerRateWithCachedRates(isUSD: false)
      }
    }
    KNInternalProvider.shared.getKNExchangeRateUSD { [weak self] result in
      guard let `self` = self else { return }
      if case .success(let rates) = result {
        rates.forEach({
          if $0.dest == "USD" { self.cachedUSDRates[$0.source] = $0 }
        })
        self.updateTrackerRateWithCachedRates(isUSD: true)
      }
    }
    KNInternalProvider.shared.getProductionCachedRate { [weak self] result in
      guard let `self` = self else { return }
      if case .success(let rates) = result {
        rates.forEach({
          self.cachedProdTokenRates["\($0.source)_\($0.dest)"] = $0
        })
        KNNotificationUtil.postNotification(for: kProdCachedRateSuccessToLoadNotiKey)
      } else {
        KNNotificationUtil.postNotification(for: kProdCachedRateFailedToLoadNotiKey)
      }
    }
  }

  fileprivate func updateTrackerRateWithCachedRates(isUSD: Bool, isNotify: Bool = true) {
    KNTrackerRateStorage.shared.updateCachedRates(
      cachedRates: isUSD ? self.cachedUSDRates.map({ $0.1 }) : self.cacheTokenETHRates.map({ $0.1 })
    )
    KNNotificationUtil.postNotification(for: kExchangeTokenRateNotificationKey)
  }

  func getCachedSourceAmount(from: TokenObject, to: TokenObject, destAmount: Double, completion: @escaping (Result<BigInt?, AnyError>) -> Void) {
    let baseURL: String = KNEnvironment.default.cachedSourceAmountRateURL
    let urlString = String(format: baseURL, arguments: [from.symbol, to.symbol, "\(destAmount)"])
    let task = URLSession.shared.dataTask(with: URL(string: urlString)!) { (data, _, error) in
      DispatchQueue.main.async {
        if let data = data, error == nil {
          do {
            let json = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.allowFragments) as? JSONDictionary ?? [:]
            let success = json["success"] as? Bool ?? false
            let value = json["value"] as? String ?? ""
            if let srcAmount = value.fullBigInt(decimals: from.decimals), success {
              completion(.success(srcAmount))
            } else {
              completion(.success(nil))
            }
          } catch let err {
            completion(.failure(AnyError(err)))
          }
        } else if let err = error {
          completion(.failure(AnyError(err)))
        } else {
          completion(.success(nil))
        }
      }
    }
    task.resume()
  }
}

class KNRateHelper {
  static func displayRate(from rate: BigInt, decimals: Int) -> String {
    /*
     Displaying rate with at most 4 digits after leading zeros
     */
    if rate.isZero {
      return rate.string(decimals: decimals, minFractionDigits: min(decimals, 4), maxFractionDigits: min(decimals, 4))
    }
    var string = rate.string(decimals: decimals, minFractionDigits: decimals, maxFractionDigits: decimals)
    let separator = EtherNumberFormatter.full.decimalSeparator
    if let _ = string.firstIndex(of: separator[separator.startIndex]) { string = string + "0000" }
    var start = false
    var cnt = 0
    var index = string.startIndex
    for id in 0..<string.count {
      if string[index] == separator[separator.startIndex] {
        start = true
      } else if start {
        if cnt > 0 || string[index] != "0" { cnt += 1 }
        if cnt == 4 { return string.substring(to: id + 1) }
      }
      index = string.index(after: index)
    }
    if cnt == 0, let id = string.firstIndex(of: separator[separator.startIndex]) {
      index = string.index(id, offsetBy: 5)
      return String(string[..<index])
    }
    return string
  }

  static func displayRate(from rate: String) -> String {
    var string = rate
    let separator = EtherNumberFormatter.full.decimalSeparator
    if let _ = string.firstIndex(of: separator[separator.startIndex]) { string = string + "0000" }
    var start = false
    var cnt = 0
    var index = string.startIndex
    for id in 0..<string.count {
      if string[index] == separator[separator.startIndex] {
        start = true
      } else if start {
        if cnt > 0 || string[index] != "0" { cnt += 1 }
        if cnt == 4 { return string.substring(to: id + 1) }
      }
      index = string.index(after: index)
    }
    if cnt == 0, let id = string.firstIndex(of: separator[separator.startIndex]) {
      index = string.index(id, offsetBy: 5)
      return String(string[..<index])
    }
    return string
  }
}
