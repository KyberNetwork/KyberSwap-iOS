// Copyright SIX DAY LLC. All rights reserved.

import Moya
import CryptoSwift

enum KyberNetworkService: String {
  case getRate = "/token_price?currency=ETH"
  case getCachedRate = "/getRate"
  case getRateUSD = "/token_price?currency=USD"
  case getHistoryOneColumn = "/getHistoryOneColumn"
  case getLatestBlock = "/latestBlock"
  case getKyberEnabled = "/kyberEnabled"
  case getMaxGasPrice = "/maxGasPrice"
  case getGasPrice = "/gasPrice"
  case supportedToken = ""
}

extension KyberNetworkService: TargetType {

  var baseURL: URL {
    let baseURLString: String = {
      if case .getCachedRate = self { return KNSecret.prodCachedRateURL }
      if case .supportedToken = self {
        return KNEnvironment.default.supportedTokenEndpoint
      }
      if case .getRate = self { return "\(KNEnvironment.default.kyberAPIEnpoint)\(self.rawValue)" }
      if case .getRateUSD = self { return "\(KNEnvironment.default.kyberAPIEnpoint)\(self.rawValue)" }
      if KNEnvironment.default == .staging { return KNSecret.internalStagingEndpoint }
      return KNSecret.internalCachedEndpoint
    }()
    return URL(string: baseURLString)!
  }

  var path: String {
    if case .getRate = self { return "" }
    if case .getRateUSD = self { return "" }
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
  case getChartHistory(symbol: String, resolution: String, from: Int64, to: Int64, rateType: String)
  case getRates
  case getUserCap(address: String)
}

extension KNTrackerService: TargetType {
  var baseURL: URL {
    let baseURLString = KNEnvironment.internalTrackerEndpoint
    switch self {
    case .getUserCap(let address):
      return URL(string: "\(KNSecret.userCapURL)\(address)")!
    case .getChartHistory(let symbol, let resolution, let from, let to, let rateType):
      let url = "\(KNSecret.getChartHistory)?symbol=\(symbol)&resolution=\(resolution)&from=\(from)&to=\(to)&rateType=\(rateType)"
      return URL(string: baseURLString + url)!
    case .getRates:
      return URL(string: baseURLString + KNSecret.getChange)!
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

enum UserInfoService {
  case getAccessToken(code: String, isRefresh: Bool)
  case getUserInfo(accessToken: String)
  case addPushToken(accessToken: String, pushToken: String)
  case addNewAlert(accessToken: String, jsonData: JSONDictionary)
  case removeAnAlert(accessToken: String, alertID: Int)
  case getListAlerts(accessToken: String)
  case updateAlert(accessToken: String, jsonData: JSONDictionary)
  case getListAlertMethods(accessToken: String)
  case setAlertMethods(accessToken: String, email: Bool, telegram: Bool, pushNoti: Bool)
  case getLeaderBoardData(accessToken: String)
  case getLatestCampaignResult(accessToken: String)
}

extension UserInfoService: TargetType {
  var baseURL: URL {
    let baseString = KNAppTracker.getKyberProfileBaseString()
    switch self {
    case .getAccessToken:
      return URL(string: "\(baseString)/oauth/token")!
    case .getUserInfo:
      return URL(string: "\(baseString)/api/user_info")!
    case .addPushToken:
      return URL(string: "\(baseString)/api/update_push_token")!
    case .addNewAlert, .getListAlerts:
      return URL(string: "\(baseString)/api/alerts")!
    case .updateAlert(_, let jsonData):
      let id = jsonData["id"] as? Int ?? 0
      return URL(string: "\(baseString)/api/alerts/\(id)")!
    case .removeAnAlert(_, let alertID):
      return URL(string: "\(baseString)/api/alerts/\(alertID)")!
    case .getListAlertMethods:
      return URL(string: "\(baseString)/api/alert_methods")!
    case .setAlertMethods:
      return URL(string: "\(baseString)/api/set_alert_methods")!
    case .getLeaderBoardData:
      return URL(string: "\(baseString)/api/alerts/ranks")!
    case .getLatestCampaignResult:
      return URL(string: "\(baseString)/api/alerts/campaign_prizes")!
    }
  }

  var path: String { return "" }

  var method: Moya.Method {
    switch self {
    case .getUserInfo, .getListAlerts, .getListAlertMethods, .getLeaderBoardData, .getLatestCampaignResult: return .get
    case .removeAnAlert: return .delete
    case .setAlertMethods, .addPushToken, .updateAlert: return .patch
    default: return .post
    }
  }

  var task: Task {
    let clientID: String = KNEnvironment.default.clientID
    let clientSecret: String = KNEnvironment.default.clientSecret
    let redirectURL: String = KNEnvironment.default.redirectLink
    switch self {
    case .getAccessToken(let code, let isRefresh):
      var json: JSONDictionary = [
        "grant_type": isRefresh ? "refresh_token" : "authorization_code",
        "redirect_uri": redirectURL,
        "client_id": clientID,
        "client_secret": clientSecret,
      ]
      if isRefresh {
        json["refresh_token"] = code
      } else {
        json["code"] = code
      }
      let data = try! JSONSerialization.data(withJSONObject: json, options: [])
      return .requestData(data)
    case .getUserInfo(let accessToken):
      let json: JSONDictionary = [
        "access_token": accessToken,
        "lang": Locale.current.kyberSupportedLang,
      ]
      let data = try! JSONSerialization.data(withJSONObject: json, options: [])
      return .requestData(data)
    case .addPushToken(let accessToken, let pushToken):
      let json: JSONDictionary = [
        "access_token": accessToken,
        "push_token_mobile": pushToken,
      ]
      let data = try! JSONSerialization.data(withJSONObject: json, options: [])
      return .requestData(data)
    case .getListAlerts(let accessToken):
      let json: JSONDictionary = [
        "access_token": accessToken,
      ]
      let data = try! JSONSerialization.data(withJSONObject: json, options: [])
      return .requestData(data)
    case .addNewAlert(let accessToken, let jsonData):
      var json: JSONDictionary = jsonData
      json["id"] = nil
      json["access_token"] = accessToken
      let data = try! JSONSerialization.data(withJSONObject: json, options: [])
      return .requestData(data)
    case .updateAlert(let accessToken, let jsonData):
      var json: JSONDictionary = jsonData
      json["id"] = nil
      json["access_token"] = accessToken
      let data = try! JSONSerialization.data(withJSONObject: json, options: [])
      return .requestData(data)
    case .removeAnAlert(let accessToken, _):
      let json: JSONDictionary = [
        "access_token": accessToken,
      ]
      let data = try! JSONSerialization.data(withJSONObject: json, options: [])
      return .requestData(data)
    case .getListAlertMethods(let accessToken):
      let json: JSONDictionary = [
        "access_token": accessToken,
      ]
      let data = try! JSONSerialization.data(withJSONObject: json, options: [])
      return .requestData(data)
    case .setAlertMethods(let accessToken, let email, let telegram, let pushNoti):
      let json: JSONDictionary = [
        "access_token": accessToken,
        "email": email,
        "telegram": telegram,
        "push_notification": pushNoti,
      ]
      let data = try! JSONSerialization.data(withJSONObject: json, options: [])
      return .requestData(data)
    case .getLeaderBoardData(let accessToken):
      let json: JSONDictionary = [
        "access_token": accessToken,
      ]
      let data = try! JSONSerialization.data(withJSONObject: json, options: [])
      return .requestData(data)
    case .getLatestCampaignResult(let accessToken):
      let json: JSONDictionary = [
        "access_token": accessToken,
      ]
      let data = try! JSONSerialization.data(withJSONObject: json, options: [])
      return .requestData(data)
    }
  }
  var sampleData: Data { return Data() }
  var headers: [String: String]? {
    return [
      "content-type": "application/json",
      "client": Bundle.main.bundleIdentifier ?? "",
      "client-build": Bundle.main.buildNumber ?? "",
    ]
  }
}

enum ProfileKYCService {
  case personalInfo(
    accessToken: String,
    firstName: String, middleName: String, lastName: String,
    nativeFullName: String,
    gender: Bool, dob: String, nationality: String,
    wallets: [(String, String)],
    residentialAddress: String, country: String, city: String, zipCode: String,
    proofAddress: String, proofAddressImageData: Data,
    sourceFund: String,
    occupationCode: String?, industryCode: String?, taxCountry: String?, taxIDNo: String?
  )
  case identityInfo(
    accessToken: String,
    documentType: String, documentID: String,
    issueDate: String?, expiryDate: String?,
    docFrontImage: Data, docBackImage: Data?, docHoldingImage: Data
  )
  case submitKYC(accessToken: String)
  case userWallets(accessToken: String)
  case checkWalletExist(accessToken: String, wallet: String)
  case addWallet(accessToken: String, label: String, address: String)
  case resubmitKYC(accessToken: String)
  case promoCode(promoCode: String, nonce: UInt)

  var apiPath: String {
    switch self {
    case .personalInfo: return KNSecret.personalInfoEndpoint
    case .identityInfo: return KNSecret.identityInfoEndpoint
    case .submitKYC: return KNSecret.submitKYCEndpoint
    case .userWallets: return KNSecret.userWalletsEndpoint
    case .checkWalletExist: return KNSecret.checkWalletsExistEndpoint
    case .addWallet: return KNSecret.addWallet
    case .resubmitKYC: return KNSecret.resubmitKYC
    case .promoCode: return KNSecret.promoCode
    }
  }
}

extension ProfileKYCService: TargetType {
  var baseURL: URL {
    let baseString = KNAppTracker.getKyberProfileBaseString()
    return URL(string: "\(baseString)/api")!
  }

  var path: String { return self.apiPath }
  var method: Moya.Method {
    if case .promoCode = self { return .get }
    return .post
  }
  var task: Task {
    switch self {
    case .personalInfo(
      let accessToken,
      let firstName,
      let middleName,
      let lastName,
      let nativeFullName,
      let gender,
      let dob,
      let nationality,
      let wallets,
      let residentialAddress,
      let country,
      let city,
      let zipCode,
      let proofAddress,
      let proofAddressImageData,
      let sourceFund,
      let occupationCode,
      let industryCode,
      let taxCountry,
      let taxIDNo):
      let arrJSON: String = {
        if wallets.isEmpty { return "[]" }
        var string = "["
        for id in 0..<wallets.count {
          string += "{\"label\": \"\(wallets[id].0)\", \"address\":\"\(wallets[id].1)\"}"
          if id < wallets.count - 1 {
            string += ","
          }
        }
        string += "]"
        return string
      }()
      var json: JSONDictionary = [
        "access_token": accessToken,
        "first_name": firstName,
        "middle_name": middleName,
        "last_name": lastName,
        "native_full_name": nativeFullName,
        "gender": gender,
        "dob": dob,
        "nationality": nationality,
        "wallets": arrJSON,
        "residential_address": residentialAddress,
        "country": country,
        "city": city,
        "zip_code": zipCode,
        "document_proof_address": proofAddress,
        "photo_proof_address": "data:image/jpeg;base64,\(proofAddressImageData.base64EncodedString())",
        "source_fund": sourceFund,
      ]
      if let code = occupationCode {
        json["occupation_code"] = code
      }
      if let code = industryCode {
        json["industry_code"] = code
      }
      if let taxCountry = taxCountry {
        json["tax_residency_country"] = taxCountry
      }
      json["have_tax_identification"] = taxIDNo != nil
      json["tax_identification_number"] = taxIDNo ?? ""
      let data = try! JSONSerialization.data(withJSONObject: json, options: [])
      return .requestData(data)
    case .identityInfo(let accessToken, let documentType, let documentID, let issueDate, let expiryDate, let docFrontImage, let docBackImage, let docHoldingImage):
      var json: JSONDictionary = [
        "access_token": accessToken,
        "document_type": documentType,
        "document_id": documentID,
        "document_issue_date": issueDate ?? "",
        "document_expiry_date": expiryDate ?? "",
        "photo_identity_front_side": "data:image/jpeg;base64,\(docFrontImage.base64EncodedString())",
        "photo_selfie": "data:image/jpeg;base64,\(docHoldingImage.base64EncodedString())",
      ]
      if let docBackImage = docBackImage {
        json["photo_identity_back_side"] = "data:image/jpeg;base64,\(docBackImage.base64EncodedString())"
      }
      let data = try! JSONSerialization.data(withJSONObject: json, options: [])
      return .requestData(data)
    case .submitKYC(let accessToken):
      let json: JSONDictionary = ["access_token": accessToken]
      let data = try! JSONSerialization.data(withJSONObject: json, options: [])
      return .requestData(data)
    case .userWallets(let accessToken):
      let json: JSONDictionary = ["access_token": accessToken]
      let data = try! JSONSerialization.data(withJSONObject: json, options: [])
      return .requestData(data)
    case .checkWalletExist(let accessToken, let wallet):
      let json: JSONDictionary = [
        "access_token": accessToken,
        "address": wallet,
      ]
      let data = try! JSONSerialization.data(withJSONObject: json, options: [])
      return .requestData(data)
    case .addWallet(let accessToken, let label, let address):
      let json: JSONDictionary = [
        "access_token": accessToken,
        "label": label,
        "address": address,
      ]
      let data = try! JSONSerialization.data(withJSONObject: json, options: [])
      return .requestData(data)
    case .resubmitKYC(let accessToken):
      let json: JSONDictionary = ["access_token": accessToken]
      let data = try! JSONSerialization.data(withJSONObject: json, options: [])
      return .requestData(data)
    case .promoCode(let promoCode, let nonce):
      let params: JSONDictionary = [
        "code": promoCode,
        "isInternalApp": "True",
        "nonce": nonce,
      ]
      return .requestCompositeData(bodyData: Data(), urlParameters: params)
    }
  }

  var sampleData: Data { return Data() }
  var headers: [String: String]? {
    switch self {
    case .promoCode(let promoCode, let nonce):
      let key: String = {
        if KNEnvironment.default == .production || KNEnvironment.default == .mainnetTest {
          return KNSecret.promoCodeProdSecretKey
        }
        return KNSecret.promoCodeDevSecretKey
      }()
      let string = "code=\(promoCode)&isInternalApp=True&nonce=\(nonce)"
      let hmac = try! HMAC(key: key, variant: .sha512)
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
