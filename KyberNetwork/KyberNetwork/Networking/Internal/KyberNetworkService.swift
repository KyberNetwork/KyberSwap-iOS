// Copyright SIX DAY LLC. All rights reserved.

import Moya
import CryptoSwift

enum KyberNetworkService: String {
  case getRate = "/rate"
  case getRateUSD = "/rateUSD"
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
      if case .supportedToken = self {
        return KNEnvironment.default.supportedTokenEndpoint
      }
      if case .getRate = self {
        if KNEnvironment.default == .ropsten { return KNSecret.internalRopstenRateEndpoint }
        if KNEnvironment.default == .rinkeby { return KNSecret.internalRinkebyRateEndpoint }
        if KNEnvironment.default == .staging { return KNSecret.internalStagingEndpoint }
      }
      if KNEnvironment.default == .staging { return KNSecret.internalStagingEndpoint }
      return KNSecret.internalCachedEndpoint
    }()
    return URL(string: baseURLString)!
  }

  var path: String {
    if case .getRate = self {
      if KNEnvironment.default == .ropsten || KNEnvironment.default == .rinkeby { return "" }
    }
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
  case getRates
  case getUserCap(address: String)
  case getUserTradable(address: String)
}

extension KNTrackerService: TargetType {
  var baseURL: URL {
    let baseURLString = KNEnvironment.internalTrackerEndpoint
    switch self {
    case .getUserCap(let address):
      return URL(string: "\(KNSecret.userCapURL)\(address)")!
    case .getUserTradable(let address):
      return URL(string: "\(KNSecret.userCanTradeURL)\(address)")!
    case .getTrades(let fromDate, let toDate, let address):
      let path: String = {
        var path = "\(KNSecret.getTradeEndpoint)?q=\(address)&exportData=true"
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
      return URL(string: baseURLString + KNSecret.getSupportedToken)!
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

enum KyberGOService {
  case listIEOs
  case getAccessToken(code: String, isRefresh: Bool)
  case getUserInfo(accessToken: String)
  case checkParticipate(accessToken: String, ieoID: Int)
  case getSignedTx(userID: Int, ieoID: Int, address: String, time: UInt)
  case getTxList(accessToken: String)
  case createTx(ieoID: Int, srcAddress: String, hash: String, accessToken: String)
  case markView(accessToken: String)
}

extension KyberGOService: TargetType {
  var baseURL: URL {
    let baseString = KNAppTracker.getKyberProfileBaseString()
    switch self {
    case .listIEOs:
      return URL(string: "\(baseString)/api/ieos")!
    case .getAccessToken:
      return URL(string: "\(baseString)/oauth/token")!
    case .getUserInfo:
      return URL(string: "\(baseString)/api/user_info")!
    case .checkParticipate:
      return URL(string: "\(baseString)/api/can_participate_ieo")!
    case .getSignedTx:
      return URL(string: KNSecret.ieoSignedEndpoint)!
    case .getTxList:
      return URL(string: "\(baseString)/api/txs")!
    case .createTx:
      return URL(string: "\(baseString)/api/txs")!
    case .markView:
      return URL(string: "\(baseString)/api/txs/set_viewed_txs")!
    }
  }

  var path: String { return "" }

  var method: Moya.Method {
    switch self {
    case .listIEOs, .getUserInfo, .checkParticipate, .getTxList: return .get
    default: return .post
    }
  }

  var task: Task {
    let clientID: String = KNEnvironment.default.clientID
    let clientSecret: String = KNEnvironment.default.clientSecret
    let redirectURL: String = KNEnvironment.default.redirectLink
    switch self {
    case .listIEOs: return .requestPlain
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
    case .checkParticipate(let accessToken, let ieoID):
      let json: JSONDictionary = [
        "client_id": clientID,
        "client_secret": clientSecret,
        "access_token": accessToken,
        "ieo_id": ieoID,
      ]
      let data = try! JSONSerialization.data(withJSONObject: json, options: [])
      return .requestData(data)
    case .getUserInfo(let accessToken):
      let json: JSONDictionary = [
        "access_token": accessToken,
        "lang": Locale.current.kyberSupportedLang,
      ]
      let data = try! JSONSerialization.data(withJSONObject: json, options: [])
      return .requestData(data)
    case .getTxList(let accessToken):
      let json: JSONDictionary = [
        "client_id": clientID,
        "client_secret": clientSecret,
        "access_token": accessToken,
        ]
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
    case .createTx(let ieoID, let srcAddress, let hash, let accessToken):
      let json: JSONDictionary = [
        "client_id": clientSecret,
        "client_secret": clientSecret,
        "access_token": accessToken,
        "ieo_id": ieoID,
        "hash": hash,
        "source_address": srcAddress,
      ]
      let data = try! JSONSerialization.data(withJSONObject: json, options: [])
      return .requestData(data)
    case .markView(let accessToken):
      let json: JSONDictionary = [
        "client_id": clientID,
        "client_secret": clientSecret,
        "access_token": accessToken,
        ]
      let data = try! JSONSerialization.data(withJSONObject: json, options: [])
      return .requestData(data)
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
