// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import Moya
import Branch
import Result
import Crashlytics
import FacebookLogin
import FacebookCore
import GoogleSignIn
import TwitterKit

class KNProfileHomeCoordinator: NSObject, Coordinator {

  let navigationController: UINavigationController
  var coordinators: [Coordinator] = []
  var session: KNSession

  fileprivate(set) var accessTokenExpireTimer: Timer?

  fileprivate(set) var webViewSignInVC: KGOInAppSignInViewController?
  fileprivate var newAlertController: KNNewAlertViewController?

  lazy var rootViewController: KNProfileHomeViewController = {
    let viewModel = KNProfileHomeViewModel()
    let controller = KNProfileHomeViewController(viewModel: viewModel)
    controller.loadViewIfNeeded()
    controller.delegate = self
    return controller
  }()

  fileprivate var kycCoordinator: KYCCoordinator?
  fileprivate var manageAlertCoordinator: KNManageAlertCoordinator?

  fileprivate var loadUserInfoTimer: Timer?
  internal var lastUpdatedUserInfo: Date?

  internal var isSignIn: Bool = false
  internal var isSubscribe: Bool = false

  internal var signUpViewController: KNSignUpViewController?
  internal var confirmSignUpVC: KNConfirmSignUpViewController?

  init(
    navigationController: UINavigationController = UINavigationController(),
    session: KNSession
  ) {
    self.navigationController = navigationController
    self.navigationController.setNavigationBarHidden(true, animated: false)
    self.session = session
  }

  deinit { self.stop() }

  func start() {
    self.navigationController.viewControllers = [self.rootViewController]
    self.timerAccessTokenExpired()
    if IEOUserStorage.shared.user != nil {
      if KNAppTracker.isPriceAlertEnabled { KNPriceAlertCoordinator.shared.resume() }
      self.timerLoadUserInfo()
    }
  }

  func stop() {
    if KNAppTracker.isPriceAlertEnabled { KNPriceAlertCoordinator.shared.pause() }
    // Remove notification observer
    self.accessTokenExpireTimer?.invalidate()
    self.accessTokenExpireTimer = nil

    self.loadUserInfoTimer?.invalidate()
    self.loadUserInfoTimer = nil
  }

  internal func timerAccessTokenExpired() {
    if let user = IEOUserStorage.shared.user {
      let time = Date(timeIntervalSince1970: user.expireTime).timeIntervalSinceNow
      guard time > 0 else {
        self.handleUserAccessTokenExpired()
        return
      }
      self.accessTokenExpireTimer?.invalidate()
      self.accessTokenExpireTimer = Timer.scheduledTimer(
        withTimeInterval: time,
        repeats: false,
        block: { [weak self] _ in
          self?.handleUserAccessTokenExpired()
        }
      )
    }
  }

  internal func timerLoadUserInfo() {
    self.loadUserInfoTimer?.invalidate()
    guard let user = IEOUserStorage.shared.user else {
      self.loadUserInfoTimer?.invalidate()
      return
    }
    self.getUserInfo(
      accessToken: user.accessToken,
      refreshToken: user.refreshToken,
      expireTime: user.expireTime,
      hasUser: true,
      showError: false
    ) { success in
        if success {
          self.rootViewController.coordinatorUserDidSignInSuccessfully()
        }
    }

    self.loadUserInfoTimer?.invalidate()
    self.loadUserInfoTimer = Timer.scheduledTimer(
      withTimeInterval: KNEnvironment.default.isMainnet ? 60.0 : 10.0,
      repeats: true,
      block: { [weak self] _ in
        guard let user = IEOUserStorage.shared.user else {
          self?.loadUserInfoTimer?.invalidate()
          return
        }
        self?.getUserInfo(
          accessToken: user.accessToken,
          refreshToken: user.refreshToken,
          expireTime: user.expireTime,
          hasUser: true,
          showError: false
        ) { success in
            if success {
              self?.rootViewController.coordinatorUserDidSignInSuccessfully()
            }
        }
      }
    )
  }

  // MARK: Update from app coordinator
  func updateSession(_ session: KNSession) {
    self.session = session
    self.navigationController.popToRootViewController(animated: false)
  }

  func appCoordinatorDidUpdateWalletObjects() {
  }
}

// MARK: Callbacks, networking
extension KNProfileHomeCoordinator {
  fileprivate func handleUserSignOut() {
    let alertController = UIAlertController(
      title: nil,
      message: NSLocalizedString("do.you.want.to.log.out?", value: "Do you want to log out?", comment: ""),
      preferredStyle: .alert
    )
    alertController.addAction(UIAlertAction(title: NSLocalizedString("cancel", value: "Cancel", comment: ""), style: .cancel, handler: nil))
    alertController.addAction(UIAlertAction(title: NSLocalizedString("log.out", value: "Log Out", comment: ""), style: .default, handler: { _ in
      // log user out of facebook
      if AccessToken.current != nil { LoginManager().logOut() }
      // logout google
      GIDSignIn.sharedInstance().signOut()

      // stop loading data
      self.loadUserInfoTimer?.invalidate()
      self.lastUpdatedUserInfo = nil

      // remove user's data
      IEOUserStorage.shared.signedOut()
      Branch.getInstance().logout()
      self.rootViewController.coordinatorDidSignOut()
      if KNAppTracker.isPriceAlertEnabled { KNPriceAlertCoordinator.shared.pause() }
    }))
    self.rootViewController.present(alertController, animated: true, completion: nil)
  }

  // Get current user's info data, to sync between mobile (iOS + Android) and web
  // this method will be called repeatedly
  func getUserInfo(accessToken: String, refreshToken: String, expireTime: Double, hasUser: Bool, showError: Bool = false, completion: @escaping (Bool) -> Void) {
    // got access token, user access token  to retrieve user information
    KNSocialAccountsCoordinator.shared.getUserInfo(authToken: accessToken) { [weak self] result in
      guard let _ = `self` else { return }
      self?.navigationController.hideLoading()
      if hasUser && IEOUserStorage.shared.user == nil {
        self?.loadUserInfoTimer?.invalidate()
        return
      }
      switch result {
      case .success(let userInfo):
        let success = userInfo["success"] as? Bool ?? true
        let message = userInfo["message"] as? String ?? ""
        guard success else {
          if showError {
            self?.navigationController.showWarningTopBannerMessage(
              with: NSLocalizedString("error", value: "Error", comment: ""),
              message: NSLocalizedString("can.not.get.user.info", value: "Can not get user info", comment: "") + ": \(message)"
            )
            KNCrashlyticsUtil.logCustomEvent(withName: "profile_kyc", customAttributes: ["type": "get_user_info_failed"])
          }
          completion(false)
          return
        }
        let user = IEOUser(dict: userInfo)
        IEOUserStorage.shared.update(objects: [user])
        IEOUserStorage.shared.updateToken(
          object: user,
          type: "",
          accessToken: accessToken,
          refreshToken: refreshToken,
          expireTime: expireTime
        )
        self?.timerAccessTokenExpired()
        if !hasUser { self?.timerLoadUserInfo() }
        self?.rootViewController.coordinatorUserDidSignInSuccessfully()
        self?.lastUpdatedUserInfo = Date()
        if KNAppTracker.isPriceAlertEnabled { KNPriceAlertCoordinator.shared.updateUserSignedInPushTokenWithRetry() }
        completion(true)
      // Already have user
      case .failure(let error):
        KNCrashlyticsUtil.logCustomEvent(withName: "profile_kyc", customAttributes: ["type": "get_user_info_failed"])
        if showError {
          self?.navigationController.displayError(error: error)
        }
        completion(false)
      }
    }
  }

  // Call refresh token API to refresh token
  fileprivate func handleUserAccessTokenExpired() {
    guard let user = IEOUserStorage.shared.user else { return }
    let refreshToken = user.refreshToken
    KNSocialAccountsCoordinator.shared.callRefreshToken(refreshToken) { [weak self] result in
      switch result {
      case .success(let data):
        if let success = data["success"] as? Bool, success,
          let json = data["data"] as? JSONDictionary,
          let authToken = json["auth_token"] as? String,
          let refreshToken = json["refresh_token"] as? String {
          let expireTime: Double = {
            let time = json["expiration_time"] as? String ?? ""
            let date = DateFormatterUtil.shared.promoCodeDateFormatter.date(from: time)
            return date?.timeIntervalSince1970 ?? 0.0
          }()
          IEOUserStorage.shared.updateToken(
            object: user,
            type: "",
            accessToken: authToken,
            refreshToken: refreshToken,
            expireTime: expireTime
          )
          self?.timerAccessTokenExpired()
          KNCrashlyticsUtil.logCustomEvent(withName: "profile_kyc", customAttributes: ["type": "expiry_session_reload_successfully"])
          return
        }
      case .failure:
        break
      }
      // Error for some reason
      KNCrashlyticsUtil.logCustomEvent(withName: "profile_kyc", customAttributes: ["type": "expiry_session_failed_reload"])
      KNNotificationUtil.localPushNotification(
        title: NSLocalizedString("session.expired", value: "Session expired", comment: ""),
        body: NSLocalizedString("your.session.has.expired.sign.in.to.continue", value: "Your session has expired, please sign in again to continue", comment: "")
      )
      IEOUserStorage.shared.signedOut()
      self?.navigationController.popToRootViewController(animated: true)
      self?.rootViewController.coordinatorDidSignOut()
    }
  }
}

extension KNProfileHomeCoordinator: KNProfileHomeViewControllerDelegate {
  func profileHomeViewController(_ controller: KNProfileHomeViewController, run event: KNProfileHomeViewEvent) {
    switch event {
    case .logOut:
      self.handleUserSignOut()
    case .openVerification:
      self.openVerificationView()
    case .managePriceAlerts:
      self.manageAlertCoordinator = KNManageAlertCoordinator(navigationController: self.navigationController)
      self.manageAlertCoordinator?.start()
    case .addPriceAlert:
      KNCrashlyticsUtil.logCustomEvent(withName: "profile_kyc", customAttributes: ["value": "add_new_alert"])
      if KNAlertStorage.shared.isMaximumAlertsReached {
        self.showAlertMaximumPriceAlertsReached()
      } else {
        self.newAlertController = KNNewAlertViewController()
        self.newAlertController?.loadViewIfNeeded()
        self.navigationController.pushViewController(self.newAlertController!, animated: true)
      }
    case .editAlert(let alert):
      KNCrashlyticsUtil.logCustomEvent(withName: "profile_kyc", customAttributes: ["value": "edit_alert"])
      self.newAlertController = KNNewAlertViewController()
      self.newAlertController?.loadViewIfNeeded()
      self.navigationController.pushViewController(self.newAlertController!, animated: true) {
        self.newAlertController?.updateEditAlert(alert)
      }
    case .leaderBoard:
      let leaderBoardVC = KNAlertLeaderBoardViewController(isShowingResult: false)
      leaderBoardVC.loadViewIfNeeded()
      leaderBoardVC.delegate = self
      self.navigationController.pushViewController(leaderBoardVC, animated: true)
    }
  }

  fileprivate func showAlertMaximumPriceAlertsReached() {
    let message = NSLocalizedString("You already have 10 (maximum) alerts in your inbox. Please delete an existing alert to add a new one", comment: "")
    let alertController = UIAlertController(
      title: NSLocalizedString("Alert limit exceeded", value: "Alert limit exceeded", comment: ""),
      message: message,
      preferredStyle: .alert
    )
    alertController.addAction(UIAlertAction(title: NSLocalizedString("ok", value: "OK", comment: ""), style: .cancel, handler: nil))
    self.navigationController.present(alertController, animated: true, completion: nil)
  }

  fileprivate func openVerificationView() {
    guard let user = IEOUserStorage.shared.user else { return }
    if user.kycStatus.lowercased() == "blocked" { return }
    if let date = self.lastUpdatedUserInfo, Date().timeIntervalSince(date) <= 2.0, user.kycStatus.lowercased() != "rejected" {
      if user.kycStatus.lowercased() == "approved" || user.kycStatus.lowercased() == "pending" { return }
      // draft or none, just open the verification
      self.kycCoordinator = KYCCoordinator(navigationController: self.navigationController, user: user)
      self.kycCoordinator?.delegate = self
      self.kycCoordinator?.start()
      return
    }
    self.navigationController.displayLoading(text: "\(NSLocalizedString("checking", value: "Checking", comment: ""))...", animated: true)
    self.getUserInfo(
      accessToken: user.accessToken,
      refreshToken: user.refreshToken,
      expireTime: user.expireTime,
      hasUser: true,
      showError: true) { [weak self] success in
        guard let `self` = self, let user = IEOUserStorage.shared.user else { return }
        if success {
          self.rootViewController.coordinatorUserDidSignInSuccessfully()
          let status = user.kycStatus.lowercased()
          if status == "approved" || status == "pending" || status == "blocked" { return }
          if status == "rejected" {
            self.sendResubmitRequest(for: user)
          } else {
            self.kycCoordinator = KYCCoordinator(navigationController: self.navigationController, user: user)
            self.kycCoordinator?.delegate = self
            self.kycCoordinator?.start()
          }
        }
    }
  }

  fileprivate func sendResubmitRequest(for user: IEOUser) {
    self.navigationController.displayLoading()
    let accessToken = user.accessToken
    DispatchQueue.global(qos: .background).async {
      let provider = MoyaProvider<ProfileKYCService>()
      provider.request(.resubmitKYC(accessToken: accessToken)) { [weak self] result in
        guard let `self` = self else { return }
        DispatchQueue.main.async {
          self.navigationController.hideLoading()
          switch result {
          case .success(let resp):
            var json: JSONDictionary = [:]
            do {
              _ = try resp.filterSuccessfulStatusCodes()
              json = try resp.mapJSON() as? JSONDictionary ?? [:]
            } catch {} // ignore catch error
            let success = json["success"] as? Bool ?? false
            let reason = json["reason"] as? String ?? NSLocalizedString("unknown.reason", value: "Unknown reason", comment: "")
            if success {
              self.kycCoordinator = KYCCoordinator(navigationController: self.navigationController, user: user)
              self.kycCoordinator?.delegate = self
              self.kycCoordinator?.start()
            } else {
              self.navigationController.showWarningTopBannerMessage(
                with: NSLocalizedString("error", value: "Error", comment: ""),
                message: reason,
                time: 1.5
              )
            }
          case .failure(let error):
            self.navigationController.displayError(error: error)
          }
        }
      }
    }
  }
}

extension KNProfileHomeCoordinator: KYCCoordinatorDelegate {
  func kycCoordinatorDidSubmitData() {
    self.kycCoordinator = nil
    guard let user = IEOUserStorage.shared.user else { return }
    self.navigationController.displayLoading(
      text: NSLocalizedString("updating.data", value: "Updating data", comment: ""),
      animated: true
    )
    self.getUserInfo(
      accessToken: user.accessToken,
      refreshToken: user.refreshToken,
      expireTime: user.expireTime,
      hasUser: true,
      showError: true,
      completion: { success in
        if success {
          self.rootViewController.coordinatorUserDidSignInSuccessfully()
        }
      }
    )
  }

  func kycCoordinatorDidBack() {
//    self.kycCoordinator = nil
  }
}

extension KNProfileHomeCoordinator: KNAlertLeaderBoardViewControllerDelegate {
  func alertLeaderBoardViewControllerOpenCampaignResult() {
    guard IEOUserStorage.shared.user != nil else { return }
    let leaderBoardVC = KNAlertLeaderBoardViewController(isShowingResult: true)
    leaderBoardVC.loadViewIfNeeded()
    leaderBoardVC.delegate = self
    self.navigationController.pushViewController(leaderBoardVC, animated: true)
  }

  func alertLeaderBoardViewControllerShouldBack() {
    self.navigationController.popViewController(animated: true)
  }
}
