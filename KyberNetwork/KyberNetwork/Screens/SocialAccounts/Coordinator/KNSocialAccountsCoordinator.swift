// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import FacebookCore
import FacebookLogin
import GoogleSignIn
import Result
import TwitterKit
import Moya

enum KNSocialAccountsType {
  case facebook(name: String, email: String, icon: String, accessToken: String)
  case google(name: String, email: String, icon: String, accessToken: String)
  case twitter(name: String, email: String, icon: String, userID: String)
  case normal(name: String, email: String, password: String)

  var isEmail: Bool {
    if case .normal = self { return true }
    return false
  }
}

extension KNProfileHomeCoordinator: KNSignUpViewControllerDelegate {
  func signUpViewController(_ controller: KNSignUpViewController, run event: KNSignUpViewEvent) {
    self.isSignIn = false
    switch event {
    case .back:
      self.navigationController.popViewController(animated: true)
      self.signUpViewController = nil
    case .pressedGoogle:
      self.authenticateGoogle()
    case .pressedFacebook:
      self.authenticateFacebook()
    case .pressedTwitter:
      self.authenticateTwitter()
    case .alreadyMemberSignIn:
      self.navigationController.popViewController(animated: true)
      self.signUpViewController = nil
    case .openTAC:
      UIApplication.shared.open(URL(string: "https://files.kyberswap.com/tac.pdf")!, options: [:], completionHandler: nil)
    case .signUp(let accountType, let isSubs):
      self.isSubscribe = isSubs
      self.proceedSignUp(accountType: accountType)
    }
  }
}

extension KNProfileHomeCoordinator {
  func profileHomeViewController(_ controller: KNProfileHomeViewController, run event: KNSignInViewEvent) {
    self.isSignIn = true
    switch event {
    case .forgotPassword:
      let forgotPassVC = KNForgotPasswordViewController()
      forgotPassVC.loadViewIfNeeded()
      forgotPassVC.modalPresentationStyle = .overFullScreen
      forgotPassVC.modalTransitionStyle = .crossDissolve
      self.navigationController.present(forgotPassVC, animated: true, completion: nil)
    case .signInWithEmail(let email, let password):
      let accountType = KNSocialAccountsType.normal(name: "", email: email, password: password)
      self.proceedSignIn(accountType: accountType)
    case .signInWithFacebook:
      self.authenticateFacebook()
    case .signInWithGoogle:
      self.authenticateGoogle()
    case .signInWithTwitter:
      self.authenticateTwitter()
    case .dontHaveAccountSignUp:
      self.openSignUpView()
    }
  }

  fileprivate func openSignUpView() {
    self.signUpViewController = nil
    self.signUpViewController = {
      let viewModel = KNSignUpViewModel()
      let controller = KNSignUpViewController(viewModel: viewModel)
      controller.loadViewIfNeeded()
      controller.delegate = self
      return controller
    }()
    self.navigationController.pushViewController(self.signUpViewController!, animated: true)
  }
}

// MARK: Handle Facebook authentication
extension KNProfileHomeCoordinator {
  fileprivate func authenticateFacebook() {
    self.retrieveFacebokAccessToken { (accessToken, isError) in
      guard let accessToken = accessToken else {
        if isError {
          self.navigationController.showErrorTopBannerMessage(
            with: NSLocalizedString("error", value: "Error", comment: ""),
            message: "Can not get your information from Facebook. Please try again".toBeLocalised(),
            time: 1.5
          )
        }
        return
      }
      self.retrieveFacebookData(accessToken: accessToken, completion: { [weak self] result in
        guard let `self` = self else { return }
        if case .success(let accountData) = result, let data = accountData {
          if self.isSignIn {
            self.proceedSignIn(accountType: data)
          } else {
            self.proceedSignUp(accountType: data)
          }
        } else {
          self.navigationController.showErrorTopBannerMessage(
            with: NSLocalizedString("error", value: "Error", comment: ""),
            message: "Can not get your information from Facebook. Please try again".toBeLocalised(),
            time: 1.5
          )
        }
      })
    }
  }

  // Return (accessToken, isError) (show proper message when user cancelled
  fileprivate func retrieveFacebokAccessToken(completion: @escaping (AccessToken?, Bool) -> Void) {
    if let accessToken = AccessToken.current {
      completion(accessToken, false)
      return
    }
    let loginManager = LoginManager()
    loginManager.logIn(readPermissions: [.publicProfile, .email], viewController: self.navigationController) { loginResult in
      switch loginResult {
      case .failed(let error):
        print("Retrieving facebook access token failed: \(error.prettyError)")
        completion(nil, true)
      case .cancelled:
        completion(nil, false)
      case .success(_, _, let accessToken):
        completion(accessToken, false)
      }
    }
  }

  fileprivate func retrieveFacebookData(accessToken: AccessToken, completion: @escaping (Result<KNSocialAccountsType?, AnyError>) -> Void) {
    let params = ["fields": "id,email,name,first_name,last_name,picture.type(large)"]
    let request = GraphRequest(
      graphPath: "me",
      parameters: params,
      accessToken: AccessToken.current,
      httpMethod: .GET,
      apiVersion: FacebookCore.GraphAPIVersion.defaultVersion
    )
    request.start { (_, result) in
      switch result {
      case .success(let value):
        guard let dict = value.dictionaryValue, let email = dict["email"] as? String, !email.isEmpty else {
          completion(.success(nil))
          return
        }
        let name = dict["name"] as? String ?? ""
        let icon: String = {
          let picture = dict["picture"] as? JSONDictionary ?? [:]
          let data = picture["data"] as? JSONDictionary ?? [:]
          return data["url"] as? String ?? ""
        }()
        let accountType = KNSocialAccountsType.facebook(name: name, email: email, icon: icon, accessToken: accessToken.authenticationToken)
        completion(.success(accountType))
      case .failed(let error):
        print(error)
        completion(.failure(AnyError(error)))
      }
    }
  }
}

// MARK: Handle Google authentication
extension KNProfileHomeCoordinator: GIDSignInDelegate, GIDSignInUIDelegate {
  fileprivate func authenticateGoogle() {
    GIDSignIn.sharedInstance()?.signOut() // TOMO: Remove
    GIDSignIn.sharedInstance()?.clientID = KNEnvironment.default.googleSignInClientID
    GIDSignIn.sharedInstance()?.delegate = self
    GIDSignIn.sharedInstance()?.uiDelegate = self
    GIDSignIn.sharedInstance()?.signIn()
  }

  func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!, withError error: Error!) {
    if error != nil {
      self.navigationController.showErrorTopBannerMessage(
        with: NSLocalizedString("error", value: "Error", comment: ""),
        message: "Can not get your information from Google. Please try again".toBeLocalised(),
        time: 2.0
      )
    } else {
      guard let email = user.profile.email, !email.isEmpty else {
        self.navigationController.showErrorTopBannerMessage(
          with: NSLocalizedString("error", value: "Error", comment: ""),
          message: "Can not get email from your Google account".toBeLocalised(),
          time: 2.0
        )
        return
      }
      let idToken = user.authentication.idToken ?? "" // Safe to send to the server
      let fullName = user.profile.name ?? ""
      let icon: String = {
        let url = user.profile.imageURL(withDimension: 256)
        if url == nil { return "" }
        return url?.absoluteString ?? ""
      }()
      print("Get user information with: \(fullName) \(email) \(icon) \(idToken)")
      let accountType = KNSocialAccountsType.google(name: fullName, email: email, icon: icon, accessToken: idToken)
      if self.isSignIn {
        self.proceedSignIn(accountType: accountType)
      } else {
        self.proceedSignUp(accountType: accountType)
      }
    }
  }

  func sign(_ signIn: GIDSignIn!, didDisconnectWith user: GIDGoogleUser!, withError error: Error!) {
  }

  func sign(_ signIn: GIDSignIn!, dismiss viewController: UIViewController!) {
    self.navigationController.dismiss(animated: true, completion: nil)
  }

  func sign(_ signIn: GIDSignIn!, present viewController: UIViewController!) {
    self.navigationController.present(viewController, animated: true, completion: nil)
  }
}

// MARK: Handle Twitter authentication
extension KNProfileHomeCoordinator {
  fileprivate func authenticateTwitter() {
    TWTRTwitter.sharedInstance().logIn { [weak self] (session, error) in
      guard let `self` = self else { return }
      guard let session = session, error == nil else {
        self.navigationController.showErrorTopBannerMessage(
          with: NSLocalizedString("error", value: "Error", comment: ""),
          message: "Can not get your information from Twitter. Please try again".toBeLocalised(),
          time: 2.0
        )
        return
      }
      let userID = session.userID
      self.requestTwitterUserData(for: userID, completion: { [weak self] result in
        guard let `self` = self else { return }
        switch result {
        case .success(let accountType):
          if self.isSignIn {
            self.proceedSignIn(accountType: accountType)
          } else {
            self.proceedSignUp(accountType: accountType)
          }
        case .failure:
          self.navigationController.showErrorTopBannerMessage(
            with: NSLocalizedString("error", value: "Error", comment: ""),
            message: "Can not get your information from Twitter. Please try again".toBeLocalised(),
            time: 2.0
          )
        }
      })
    }
  }

  fileprivate func requestTwitterUserData(for userID: String, completion: @escaping (Result<KNSocialAccountsType, AnyError>) -> Void) {
    var user: TWTRUser?
    var email: String?
    var error: Error?

    let client = TWTRAPIClient.withCurrentUser()
    let group = DispatchGroup()
    group.enter()
    client.loadUser(withID: userID, completion: { (userData, errorData) in
      user = userData
      if let err = errorData { error = err }
      group.leave()
    })
    group.enter()
    client.requestEmail(forCurrentUser: { (emailData, errorData) in
      email = emailData
      if let err = errorData { error = err }
      group.leave()
    })
    group.notify(queue: .main) {
      if let user = user, let email = email, !email.isEmpty {
        let accountType = KNSocialAccountsType.twitter(
          name: user.name,
          email: email,
          icon: user.profileImageLargeURL,
          userID: user.userID
        )
        completion(.success(accountType))
      } else if let error = error {
        completion(.failure(AnyError(error)))
      }
    }
  }
}

// MARK: Handle sign in/up
extension KNProfileHomeCoordinator {
  fileprivate func proceedSignIn(accountType: KNSocialAccountsType) {
    switch accountType {
    case .normal(_, let email, let password):
      self.signInEmail(email: email, password: password)
    case .facebook(let name, let email, let icon, let accessToken):
      self.signInSocialWithData(type: "facebook", email: email, name: name, photo: icon, accessToken: accessToken)
    case .twitter(let name, let email, let icon, let userID):
      self.signInSocialWithData(type: "twitter", email: email, name: name, photo: icon, accessToken: userID)
    case .google(let name, let email, let icon, let accessToken):
      self.signInSocialWithData(type: "facebook", email: email, name: name, photo: icon, accessToken: accessToken)
    }
  }

  fileprivate func signInEmail(email: String, password: String) {
    self.navigationController.displayLoading()
    KNSocialAccountsCoordinator.shared.signInEmail(email, password: password) { [weak self] result in
      guard let `self` = self else { return }
      switch result {
      case .success(let data):
        let success = data["success"] as? Bool ?? false
        let message = data["message"] as? String ?? ""
        if success {
          self.userDidSignInWithData(data)
        } else {
          self.navigationController.hideLoading()
          self.navigationController.showErrorTopBannerMessage(
            with: NSLocalizedString("error", value: "Error", comment: ""),
            message: message,
            time: 1.5
          )
        }
      case .failure(let error):
        self.navigationController.hideLoading()
        self.navigationController.displayError(error: error)
      }
    }
  }

  fileprivate func signInSocialWithData(type: String, email: String, name: String, photo: String, accessToken: String) {
    self.navigationController.displayLoading()
    KNSocialAccountsCoordinator.shared.signInSocial(
      type: type,
      email: email,
      name: name,
      photo: photo,
      accessToken: accessToken) { [weak self] result in
        guard let `self` = self else { return }
        switch result {
        case .success(let data):
          let success = data["success"] as? Bool ?? false
          let message = data["message"] as? String ?? ""
          if success {
            self.userDidSignInWithData(data)
          } else {
            self.navigationController.hideLoading()
            self.navigationController.showErrorTopBannerMessage(
              with: NSLocalizedString("error", value: "Error", comment: ""),
              message: message,
              time: 1.5
            )
          }
        case .failure(let error):
          self.navigationController.hideLoading()
          self.navigationController.displayError(error: error)
        }
    }
  }

  fileprivate func userDidSignInWithData(_ data: JSONDictionary) {
    guard let authInfoDict = data["auth_info"] as? JSONDictionary, let userInfo = data["user_info"] as? JSONDictionary else {
      return
    }
    let authToken = authInfoDict["auth_token"] as? String ?? ""
    let refreshToken = authInfoDict["refresh_token"] as? String ?? ""
    let expiredTime: Double = {
      let time = authInfoDict["expiration_time"] as? String ?? ""
      let date = DateFormatterUtil.shared.promoCodeDateFormatter.date(from: time)
      return date?.timeIntervalSince1970 ?? 0.0
    }()

    // create and update user info
    let user = IEOUser(dict: userInfo)
    IEOUserStorage.shared.update(objects: [user])
    IEOUserStorage.shared.updateToken(
      object: user,
      type: "",
      accessToken: authToken,
      refreshToken: refreshToken,
      expireTime: expiredTime
    )
    self.timerAccessTokenExpired()
    self.timerLoadUserInfo()
    self.rootViewController.coordinatorUserDidSignInSuccessfully()
    self.lastUpdatedUserInfo = Date()
    if KNAppTracker.isPriceAlertEnabled { KNPriceAlertCoordinator.shared.updateUserSignedInPushTokenWithRetry() }
    KNCrashlyticsUtil.logCustomEvent(withName: "profile_kyc", customAttributes: ["type": "signed_in_successfully"])
    let name = IEOUserStorage.shared.user?.name ?? ""
    let text = NSLocalizedString("welcome.back.user", value: "Welcome back, %@", comment: "")
    let message = String(format: text, name)
    self.navigationController.showSuccessTopBannerMessage(with: "", message: message)
    if KNAppTracker.isPriceAlertEnabled { KNPriceAlertCoordinator.shared.resume() }
  }

  fileprivate func proceedSignUp(accountType: KNSocialAccountsType) {
    switch accountType {
    case .normal(let name, let email, let password):
      self.signUpEmail(email, password: password, name: name, isSubs: self.isSubscribe)
    default:
      self.confirmSignUpVC = nil
      self.confirmSignUpVC = {
        let viewModel = KNConfirmSignUpViewModel(accountType: accountType, isSubscribe: false)
        let controller = KNConfirmSignUpViewController(viewModel: viewModel)
        controller.loadViewIfNeeded()
        controller.delegate = self
        return controller
      }()
      self.navigationController.pushViewController(self.confirmSignUpVC!, animated: true)
    }
  }

  fileprivate func signUpEmail(_ email: String, password: String, name: String, isSubs: Bool) {
    self.navigationController.displayLoading()
    KNSocialAccountsCoordinator.shared.signUpEmail(email, password: password, name: name, isSubs: isSubs) { [weak self] result in
      guard let `self` = self else { return }
      self.navigationController.hideLoading()
      switch result {
      case .success(let data):
        if data.0 {
          // signed up successfully
          self.signUpViewController?.userDidSignedWithEmail()
        } else {
          self.navigationController.showErrorTopBannerMessage(
            with: NSLocalizedString("error", value: "Error", comment: ""),
            message: data.1,
            time: 1.5
          )
        }
      case .failure(let error):
        self.navigationController.displayError(error: error)
      }
    }
  }
}

extension KNProfileHomeCoordinator: KNConfirmSignUpViewControllerDelegate {
  func confirmSignUpViewController(_ controller: KNConfirmSignUpViewController, run event: KNConfirmSignUpViewEvent) {
    switch event {
    case .back: self.navigationController.popViewController(animated: true)
    case .alreadyMemberSignIn: self.navigationController.popToRootViewController(animated: true)
    case .openTAC:
      UIApplication.shared.open(URL(string: "https://files.kyberswap.com/tac.pdf")!, options: [:], completionHandler: nil)
    case .confirmSignUp(let accountType, let isSubscribe):
      print("Proceed confirm sign up is subs: \(isSubscribe)")
    }
  }
}

class KNSocialAccountsCoordinator {
  let provider = MoyaProvider<NativeSignInUpService>()

  static let shared = KNSocialAccountsCoordinator()

  func signUpEmail(_ email: String, password: String, name: String, isSubs: Bool, completion: @escaping (Result<(Bool, String), AnyError>) -> Void) {
    let request = NativeSignInUpService.signUpEmail(
      email: email,
      password: password,
      name: name,
      isSubs: isSubs
    )
    self.sendRequest(request) { [weak self] result in
      guard let _ = self else { return }
      switch result {
      case .success(let json):
        let success = json["success"] as? Bool ?? false
        let message = json["message"] as? String ?? ""
        completion(.success((success, message)))
      case .failure(let error):
        completion(.failure(AnyError(error)))
      }
    }
  }

  func signInEmail(_ email: String, password: String, completion: @escaping (Result<JSONDictionary, AnyError>) -> Void) {
    let request = NativeSignInUpService.signInEmail(email: email, password: password)
    self.sendRequest(request) { [weak self] result in
      guard let _ = self else { return }
      completion(result)
    }
  }

  func resetPassword(_ email: String, completion: @escaping (Result<(Bool, String), AnyError>) -> Void) {
    let request = NativeSignInUpService.resetPassword(email: email)
    self.sendRequest(request) { [weak self] result in
      guard let _ = self else { return }
      switch result {
      case .success(let json):
        let success = json["success"] as? Bool ?? false
        let message = json["message"] as? String ?? ""
        completion(.success((success, message)))
      case .failure(let error):
        completion(.failure(AnyError(error)))
      }
    }
  }

  func signInSocial(type: String, email: String, name: String, photo: String, accessToken: String, completion: @escaping (Result<JSONDictionary, AnyError>) -> Void) {
    let request = NativeSignInUpService.signInSocial(
      type: type,
      email: email,
      name: name,
      photo: photo,
      accessToken: accessToken
    )
    self.sendRequest(request) { [weak self] result in
      guard let _ = self else { return }
      completion(result)
    }
  }

  func updatePassword(_ email: String, oldPassword: String, newPassword: String, accessToken: String, completion: @escaping (Result<(Bool, String), AnyError>) -> Void) {
    let request = NativeSignInUpService.updatePassword(
      email: email,
      oldPassword: oldPassword,
      newPassword: newPassword,
      authenToken: accessToken
    )
    self.sendRequest(request) { [weak self] result in
      guard let _ = self else { return }
      switch result {
      case .success(let json):
        let success = json["success"] as? Bool ?? false
        let message = json["message"] as? String ?? ""
        completion(.success((success, message)))
      case .failure(let error):
        completion(.failure(AnyError(error)))
      }
    }
  }

  func callRefreshToken(_ refreshToken: String, completion: @escaping (Result<JSONDictionary, AnyError>) -> Void) {
    let request = NativeSignInUpService.refreshToken(refreshToken: refreshToken)
    self.sendRequest(request) { [weak self] result in
      guard let _ = self else { return }
      completion(result)
    }
  }

  func getUserAuthData(email: String, password: String, completion: @escaping (Result<JSONDictionary, AnyError>) -> Void) {
    let request = NativeSignInUpService.getUserAuthToken(email: email, password: password)
    self.sendRequest(request) { [weak self] result in
      guard let _ = self else { return }
      completion(result)
    }
  }

  func getUserInfo(authToken: String, completion: @escaping (Result<JSONDictionary, AnyError>) -> Void) {
    let request = NativeSignInUpService.getUserInfo(authToken: authToken)
    self.sendRequest(request) { [weak self] result in
      guard let _ = self else { return }
      completion(result)
    }
  }

  fileprivate func sendRequest(_ request: NativeSignInUpService, completion: @escaping (Result<JSONDictionary, AnyError>) -> Void) {
    DispatchQueue.global(qos: .background).async {
      self.provider.request(request) { [weak self] (result) in
        guard let _ = self else { return }
        DispatchQueue.main.async {
          switch result {
          case .success(let resp):
            do {
              _ = try resp.filterSuccessfulStatusCodes()
              let json = try resp.mapJSON(failsOnEmptyData: false) as? JSONDictionary ?? [:]
              completion(.success(json))
            } catch let err {
              completion(.failure(AnyError(err)))
            }
          case .failure(let error):
            completion(.failure(AnyError(error)))
          }
        }
      }
    }
  }
}
