// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import FacebookCore
import FacebookLogin
import GoogleSignIn
import Result
import TwitterKit

enum KNSocialAccountsType {
  case facebook(name: String, email: String, icon: String, accessToken: String)
  case google(name: String, email: String, icon: String, accessToken: String)
  case twitter(name: String, email: String, icon: String, userID: String)
  case normal(email: String, password: String, name: String)
}

class KNSocialAccountsCoordinator: NSObject, Coordinator {

  let navigationController: UINavigationController
  var coordinators: [Coordinator] = []
  var navController: UINavigationController?

  fileprivate var isSignIn: Bool = false

  lazy var signInViewController: KNSignInViewController = {
    let viewModel = KNSignInViewModel()
    let controller = KNSignInViewController(viewModel: viewModel)
    controller.loadViewIfNeeded()
    controller.delegate = self
    return controller
  }()

  init(
    navigationController: UINavigationController
    ) {
    self.navigationController = navigationController
  }

  func start(isSignIn: Bool) {
    let rootVC = isSignIn ? self.signInViewController : self.signInViewController
    self.navController = UINavigationController(rootViewController: rootVC)
    self.navController?.setNavigationBarHidden(true, animated: false)
    self.navigationController.present(self.navController!, animated: true, completion: nil)
  }

  func stop() {
    self.navigationController.dismiss(animated: true, completion: nil)
  }
}

extension KNSocialAccountsCoordinator: KNSignInViewControllerDelegate {
  func signInViewController(_ controller: KNSignInViewController, run event: KNSignInViewEvent) {
    guard let navController = self.navController else { return }
    self.isSignIn = true
    switch event {
    case .back:
      if navController.viewControllers.count > 2 {
        navController.popViewController(animated: true)
      } else {
        self.stop()
      }
    case .forgotPassword:
      print("Forgot password")
    case .signInWithEmail(let email, let password):
      let accountType = KNSocialAccountsType.normal(email: email, password: password, name: "")
      self.showSuccessTopBannerMessage(with: "Successfully!", message: "You are using \(email) to sign in", time: 2.0) // TODO: Remove
      self.proceedSignIn(accountType: accountType)
    case .signInWithFacebook:
      self.authenticateFacebook()
    case .signInWithGoogle:
      self.authenticateGoogle()
    case .signInWithTwitter:
      self.authenticateTwitter()
    case .signUp:
      print("Sign up")
    }
  }
}

// MARK: Handle Facebook authentication
extension KNSocialAccountsCoordinator {
  fileprivate func authenticateFacebook() {
    LoginManager().logOut() // TODO: Remove
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
    loginManager.logIn(readPermissions: [.publicProfile, .email], viewController: self.navController) { loginResult in
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
        self.navController?.showSuccessTopBannerMessage(with: "Successfully", message: "Hi \(name), you are using \(email)", time: 2.0) // TODO: Remove
        completion(.success(accountType))
      case .failed(let error):
        print(error)
        completion(.failure(AnyError(error)))
      }
    }
  }
}

// MARK: Handle Google authentication
extension KNSocialAccountsCoordinator: GIDSignInDelegate, GIDSignInUIDelegate {
  fileprivate func authenticateGoogle() {
    GIDSignIn.sharedInstance()?.signOut() // TOMO: Remove
    GIDSignIn.sharedInstance()?.clientID = KNEnvironment.default.googleSignInClientID
    GIDSignIn.sharedInstance()?.delegate = self
    GIDSignIn.sharedInstance()?.uiDelegate = self
    GIDSignIn.sharedInstance()?.signIn()
  }

  func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!, withError error: Error!) {
    if error != nil {
      self.navController?.showErrorTopBannerMessage(
        with: NSLocalizedString("error", value: "Error", comment: ""),
        message: "Can not get your information from Google. Please try again".toBeLocalised(),
        time: 2.0
      )
    } else {
      guard let email = user.profile.email, !email.isEmpty else {
        self.navController?.showErrorTopBannerMessage(
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
      self.navController?.showSuccessTopBannerMessage(with: "Successfully", message: "Hi \(fullName), you are using \(email)", time: 2.0) // TODO: Remove
      self.proceedSignIn(accountType: accountType)
    }
  }

  func sign(_ signIn: GIDSignIn!, didDisconnectWith user: GIDGoogleUser!, withError error: Error!) {
  }

  func sign(_ signIn: GIDSignIn!, dismiss viewController: UIViewController!) {
    self.navController?.dismiss(animated: true, completion: nil)
  }

  func sign(_ signIn: GIDSignIn!, present viewController: UIViewController!) {
    self.navController?.present(viewController, animated: true, completion: nil)
  }
}

// MARK: Handle Twitter authentication
extension KNSocialAccountsCoordinator {
  fileprivate func authenticateTwitter() {
    TWTRTwitter.sharedInstance().logIn { [weak self] (session, error) in
      guard let `self` = self else { return }
      guard let session = session, error == nil else {
        self.navController?.showErrorTopBannerMessage(
          with: NSLocalizedString("error", value: "Error", comment: ""),
          message: "Can not get your information from Twitter. Please try again".toBeLocalised(),
          time: 2.0
        )
        return
      }
      let name = session.userName
      let userID = session.userID
      let client = TWTRAPIClient.withCurrentUser()
      client.requestEmail(forCurrentUser: { [weak self] (email, error) in
        guard let `self` = self else { return }
        guard let email = email, !email.isEmpty, error == nil else {
          self.navController?.showErrorTopBannerMessage(
            with: NSLocalizedString("error", value: "Error", comment: ""),
            message: "Can not get your information from Twitter. Please try again".toBeLocalised(),
            time: 2.0
          )
          return
        }
        let accountType = KNSocialAccountsType.twitter(name: name, email: email, icon: "", userID: userID)
        self.navController?.showSuccessTopBannerMessage(with: "Successfully", message: "Hi \(name), you are using \(email)", time: 2.0) // TODO: Remove
        if self.isSignIn {
          self.proceedSignIn(accountType: accountType)
        } else {
          self.proceedSignUp(accountType: accountType)
        }
      })
    }
  }
}

// MARK: Handle sign in/up
extension KNSocialAccountsCoordinator {
  fileprivate func proceedSignIn(accountType: KNSocialAccountsType) {
  }

  fileprivate func proceedSignUp(accountType: KNSocialAccountsType) {
  }
}
