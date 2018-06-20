// Copyright SIX DAY LLC. All rights reserved.

import Moya
import CryptoSwift

enum KyberNetworkService: String {
  case getRate = "/getRate"
  case getRateUSD = "/getRateUSD"
  case getHistoryOneColumn = "/getHistoryOneColumn"
  case getLatestBlock = "/getLatestBlock"
  case getKyberEnabled = "/getKyberEnabled"
  case getMaxGasPrice = "/getMaxGasPrice"
  case getGasPrice = "/getGasPrice"
}

extension KyberNetworkService: TargetType {

  var baseURL: URL {
    let baseURLString = KNEnvironment.internalBaseEndpoint
    return URL(string: baseURLString)!
  }

  var path: String {
    return self.rawValue
  }

  var method: Moya.Method {
    return .get
  }

  var task: Task {
    return .requestPlain
  }

  var sampleData: Data {
    return Data() // sample data for UITest
  }

  var headers: [String: String]? {
    return [
      "content-type": "application/json",
      "client": Bundle.main.bundleIdentifier ?? "",
      "client-build": Bundle.main.buildNumber ?? "",
    ]
  }
}

enum KNTrackerService {
  case getTrades(fromDate: Date?, toDate: Date?, address: String)
  case getSupportedTokens()
  case getChartHistory(symbol: String, resolution: String, from: Int64, to: Int64, rateType: String)
}

extension KNTrackerService: TargetType {
  var baseURL: URL {
    let baseURLString = KNEnvironment.internalTrackerEndpoint
    switch self {
    case .getTrades(let fromDate, let toDate, let address):
      let path: String = {
        var path = "/api/search?q=\(address)&exportData=true"
        if let date = fromDate {
          path += "&fromDate=\(date.timeIntervalSince1970)"
        }
        if let date = toDate {
          path += "&toDate=\(date.timeIntervalSince1970)"
        }
        return path
      }()
      return URL(string: baseURLString + path)!
    case .getSupportedTokens:
      return URL(string: baseURLString + "/api/tokens/supported")!
    case .getChartHistory(let symbol, let resolution, let from, let to, let rateType):
      let url = "/chart/history?symbol=\(symbol)&resolution=\(resolution)&from=\(from)&to=\(to)&rateType=\(rateType)"
      return URL(string: baseURLString + url)!
    }
  }

  var path: String {
    return ""
  }

  var method: Moya.Method {
    return .get
  }

  var task: Task {
    return .requestPlain
  }

  var sampleData: Data {
    return Data() // sample data for UITest
  }

  var headers: [String: String]? {
    return [
      "content-type": "application/json",
      "client": Bundle.main.bundleIdentifier ?? "",
      "client-build": Bundle.main.buildNumber ?? "",
    ]
  }
}

enum KyberGOService {
  case listIEOs
  case getAccessToken(code: String)
  case getUserInfo(accessToken: String)
  case getSignedTx(userID: Int, ieoID: Int, address: String, time: UInt)
}

extension KyberGOService: TargetType {
  var baseURL: URL {
    switch self {
    case .listIEOs:
      return URL(string: "https://kyber.mangcut.vn/api/ieos")!
    case .getAccessToken:
      return URL(string: "https://kyber.mangcut.vn/oauth/token")!
    case .getUserInfo:
      return URL(string: "https://kyber.mangcut.vn/api/user_info")!
    case .getSignedTx:
      return URL(string: KNSecret.ieoSignedEndpoint)!
    }
  }

  var path: String { return "" }

  var method: Moya.Method {
    switch self {
    case .listIEOs, .getUserInfo: return .get
    default: return .post
    }
  }

  var task: Task {
    switch self {
    case .listIEOs: return .requestPlain
    case .getAccessToken(let code):
      let json: JSONDictionary = [
        "grant_type": "authorization_code",
        "code": code,
        "redirect_uri": KNSecret.redirectURL,
        "client_id": KNSecret.appID,
        "client_secret": KNSecret.secret,
      ]
      let data = try! JSONSerialization.data(withJSONObject: json, options: [])
      return .requestData(data)
    case .getUserInfo(let accessToken):
      let json: JSONDictionary = [ "access_token": accessToken ]
      let data = try! JSONSerialization.data(withJSONObject: json, options: [])
      return .requestData(data)
    case .getSignedTx(let userID, let ieoID, let address, let time):
      let params: JSONDictionary = [
        "contributor": address,
        "ieoid": ieoID,
        "nonce": time,
        "userid": userID,
      ]
      return .requestCompositeData(bodyData: Data(), urlParameters: params)
    }
  }
  var sampleData: Data { return Data() }
  var headers: [String: String]? {
    switch self {
    case .getSignedTx(let userID, let ieoID, let address, let time):
      let string = "contributor=\(address)&ieoid=\(ieoID)&nonce=\(time)&userid=\(userID)"
      let hmac = try! HMAC(key: KNSecret.ieoSignedKey, variant: .sha512)
      let hash = try! hmac.authenticate(string.bytes).toHexString()
      return [
        "Content-Type": "application/x-www-form-urlencoded",
        "signed": hash,
        "client": Bundle.main.bundleIdentifier ?? "",
        "client-build": Bundle.main.buildNumber ?? "",
      ]
    default:
      return [
        "content-type": "application/json",
        "client": Bundle.main.bundleIdentifier ?? "",
        "client-build": Bundle.main.buildNumber ?? "",
      ]
    }
  }
}
