// Copyright SIX DAY LLC. All rights reserved.

//swiftlint:disable file_length
import UIKit
import Moya
import Result
import Crashlytics

enum KYCFlowViewEvent {
  case back
  case submitted
}

protocol KYCFlowViewControllerDelegate: class {
  func kycFlowViewController(_ controller: KYCFlowViewController, run event: KYCFlowViewEvent)
}

class KYCFlowViewModel {
  let user: IEOUser
  var stepState: KNKYCStepViewState

  fileprivate(set) var firstName: String = ""
  fileprivate(set) var middleName: String = ""
  fileprivate(set) var lastName: String = ""
  fileprivate(set) var nativeFullName: String = ""
  fileprivate(set) var gender: String = ""
  fileprivate(set) var dob: String = ""
  fileprivate(set) var nationality: String = ""
  fileprivate(set) var residenceAddress: String = ""
  fileprivate(set) var residenceCountry: String = ""
  fileprivate(set) var residenceCity: String = ""
  fileprivate(set) var residencePostalCode: String = ""
  fileprivate(set) var proofAddressType: String = ""
  fileprivate(set) var proofAddressImage: UIImage?
  fileprivate(set) var sourceFund: String = ""
  fileprivate(set) var occupationCode: String?
  fileprivate(set) var industryCode: String?
  fileprivate(set) var taxCountry: String?
  fileprivate(set) var taxIDNumber: String?
  fileprivate(set) var docType: String = ""
  fileprivate(set) var docNumber: String = ""
  fileprivate(set) var issueDate: String = ""
  fileprivate(set) var expiryDate: String = ""
  fileprivate(set) var docFrontImage: UIImage!
  fileprivate(set) var docBackImage: UIImage?
  fileprivate(set) var docHoldingImage: UIImage!

  init(user: IEOUser) {
    self.user = user
    self.stepState = {
      let kycStatus = user.kycStatus.lowercased()
      if kycStatus == "blocked" { return .personalInfo }
      if kycStatus != "none" && kycStatus != "draft" && kycStatus != "rejected" { return .done }
      return KNKYCStepViewState(rawValue: user.kycStep - 1) ?? .done
    }()
  }

  var localisedGender: String {
    if self.gender.lowercased() == "male" {
      return NSLocalizedString("male", value: "Male", comment: "")
    }
    if self.gender.lowercased() == "female" {
      return NSLocalizedString("female", value: "Female", comment: "")
    }
    return self.gender
  }

  var localisedDocType: String {
    if self.docType.lowercased() == "national_id" { return "ID" }
    if self.docType.lowercased() == "passport" {
      return NSLocalizedString("passport", value: "Passport", comment: "")
    }
    if self.docType.lowercased() == "driving_license" {
      return NSLocalizedString("driving.license", value: "Driving License", comment: "")
    }
    return self.docType
  }

  func updateStepState(_ step: KNKYCStepViewState) {
    self.stepState = step
  }

  func updateData(with details: UserKYCDetailsInfo) {
    guard !details.firstName.isEmpty else { return }
    self.updatePersonalInfo(
      firstName: details.firstName,
      middleName: details.middleName,
      lastName: details.lastName,
      nativeFullName: details.nativeFullName,
      gender: details.gender ? "Male" : "Female",
      dob: details.dob,
      nationality: details.nationality,
      residenceAddress: details.residentialAddress,
      residenceCountry: details.country,
      residenceCity: details.city,
      residencePostalCode: details.zipCode,
      proofAddressType: details.documentProofAddress,
      proofAddressImage: nil,
      sourceFund: details.sourceFund,
      occupationCode: details.occupationCode,
      industryCode: details.industryCode,
      taxCountry: details.taxResidencyCountry,
      taxIDNumber: details.taxIDNUmber
    )
    guard !details.documentType.isEmpty else { return }
    self.docType = details.documentType
    self.docNumber = details.documentNumber
    let base64Prefix = "data:image/jpeg;base64,"
    if details.photoProofAddress.starts(with: base64Prefix),
      let data = Data(base64Encoded: details.photoProofAddress.substring(from: base64Prefix.count)),
      let image = UIImage(data: data) {
      self.proofAddressImage = image
    }
    if details.documentPhotoFront.starts(with: base64Prefix),
      let data = Data(base64Encoded: details.documentPhotoFront.substring(from: base64Prefix.count)),
      let image = UIImage(data: data) {
      self.docFrontImage = image
    }
    if details.documentPhotoBack.starts(with: base64Prefix),
      let data = Data(base64Encoded: details.documentPhotoBack.substring(from: base64Prefix.count)),
      let image = UIImage(data: data) {
      self.docBackImage = image
    }
    if details.documentSelfiePhoto.starts(with: base64Prefix), let data = Data(base64Encoded: details.documentSelfiePhoto.substring(from: base64Prefix.count)), let image = UIImage(data: data) {
      self.docHoldingImage = image
    }
  }

  func updatePersonalInfo(
    firstName: String,
    middleName: String,
    lastName: String,
    nativeFullName: String,
    gender: String,
    dob: String,
    nationality: String,
    residenceAddress: String,
    residenceCountry: String,
    residenceCity: String,
    residencePostalCode: String,
    proofAddressType: String,
    proofAddressImage: UIImage?,
    sourceFund: String,
    occupationCode: String?,
    industryCode: String?,
    taxCountry: String?,
    taxIDNumber: String?
    ) {
    self.firstName = firstName
    self.middleName = middleName
    self.lastName = lastName
    self.nativeFullName = nativeFullName
    self.gender = gender
    self.dob = dob
    self.nationality = nationality
    self.residenceAddress = residenceAddress
    self.residenceCountry = residenceCountry
    self.residenceCity = residenceCity
    self.residencePostalCode = residencePostalCode
    self.proofAddressType = proofAddressType
    self.proofAddressImage = proofAddressImage
    self.sourceFund = sourceFund
    self.occupationCode = occupationCode
    self.industryCode = industryCode
    self.taxCountry = taxCountry
    self.taxIDNumber = taxIDNumber
  }

  func updateIdentityInfo(
    docType: String,
    docNum: String,
    issueDate: String,
    expiryDate: String,
    docFrontImage: UIImage,
    docBackImage: UIImage?,
    docHoldingImage: UIImage
    ) {
    self.docType = docType
    self.docNumber = docNum
    self.issueDate = issueDate
    self.expiryDate = expiryDate
    self.docFrontImage = docFrontImage
    self.docBackImage = docBackImage
    self.docHoldingImage = docHoldingImage
  }
}

class KYCFlowViewController: KNBaseViewController {

  @IBOutlet weak var headerContainerView: UIView!
  @IBOutlet weak var navigationTitleLabel: UILabel!
  @IBOutlet weak var stepView: KNKYCStepView!
  @IBOutlet weak var scrollView: UIScrollView!
  @IBOutlet weak var bottomPaddingConstraintForScrollView: NSLayoutConstraint!
  fileprivate var personalInfoVC: KYCPersonalInfoViewController?
  fileprivate var identityInfoVC: KYCIdentityInfoViewController?
  fileprivate var statusInfoVC: KYCProfileVerificationStatusViewController?

  fileprivate var submitInfoVC: KYCSubmitInfoViewController!

  fileprivate var viewModel: KYCFlowViewModel
  weak var delegate: KYCFlowViewControllerDelegate?
  fileprivate var isViewSetup: Bool = false

  fileprivate var doneTimer: Timer?
  fileprivate var isUpdatingData: Bool = false

  init(viewModel: KYCFlowViewModel) {
    self.viewModel = viewModel
    super.init(nibName: KYCFlowViewController.className, bundle: nil)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    self.headerContainerView.applyGradient(with: UIColor.Kyber.headerColors)
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    if !self.isViewSetup {
      self.isViewSetup = true
      self.setupUI()
    }
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    self.doneTimer?.invalidate()
    self.doneTimer = nil
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    let padding = self.bottomPaddingSafeArea()
    let width = UIScreen.main.bounds.width
    let height = self.view.frame.height - self.scrollView.frame.minY - padding

    self.scrollView.frame = CGRect(
      x: 0,
      y: self.scrollView.frame.minY,
      width: width,
      height: height
    )
    self.personalInfoVC?.view.frame = CGRect(x: 0, y: 0, width: width, height: height)
    self.identityInfoVC?.view.frame = CGRect(x: width, y: 0, width: width, height: height)
    self.submitInfoVC.view.frame = CGRect(x: 2.0 * width, y: 0, width: width, height: height)
    self.statusInfoVC?.view.frame = CGRect(x: 3.0 * width, y: 0, width: width, height: height)
    self.scrollView.contentSize = CGSize(
      width: width * 4.0,
      height: 1.0
    )

    self.headerContainerView.removeSublayer(at: 0)
    self.headerContainerView.applyGradient(with: UIColor.Kyber.headerColors)
  }

  fileprivate func setupUI() {
    self.setupStepView()
    self.setupControllers()
  }

  fileprivate func setupStepView() {
    self.navigationTitleLabel.text = self.viewModel.stepState.title
    self.stepView.updateView(with: self.viewModel.stepState)
  }

  //swiftlint:disable function_body_length
  fileprivate func setupControllers() {
    let padding = self.bottomPaddingSafeArea()
    self.bottomPaddingConstraintForScrollView.constant = padding
    let width = UIScreen.main.bounds.width
    let height = self.view.frame.height - self.scrollView.frame.minY - padding

    self.scrollView.frame = CGRect(
      x: 0,
      y: self.scrollView.frame.minY,
      width: width,
      height: height
    )

    let personalInfoVC: KYCPersonalInfoViewController = {
      let viewModel = KYCPersonalInfoViewModel(user: self.viewModel.user)
      let controller = KYCPersonalInfoViewController(viewModel: viewModel)
      controller.loadViewIfNeeded()
      controller.delegate = self
      return controller
    }()
    self.addChildViewController(personalInfoVC)
    personalInfoVC.view.frame = CGRect(x: 0, y: 0, width: width, height: height)
    self.scrollView.addSubview(personalInfoVC.view)
    personalInfoVC.didMove(toParentViewController: self)
    self.personalInfoVC = personalInfoVC

    let identityInfoVC: KYCIdentityInfoViewController = {
      let viewModel = KYCIdentityInfoViewModel()
      let controller = KYCIdentityInfoViewController(viewModel: viewModel)
      controller.loadViewIfNeeded()
      controller.delegate = self
      return controller
    }()
    self.addChildViewController(identityInfoVC)
    identityInfoVC.view.frame = CGRect(x: width, y: 0, width: width, height: height)
    self.scrollView.addSubview(identityInfoVC.view)
    identityInfoVC.didMove(toParentViewController: self)
    self.identityInfoVC = identityInfoVC

    self.submitInfoVC = {
      let viewModel = KYCSubmitInfoViewModel(
        firstName: self.viewModel.firstName,
        middleName: self.viewModel.middleName,
        lastName: self.viewModel.lastName,
        nativeFullName: self.viewModel.nativeFullName,
        gender: self.viewModel.localisedGender,
        dob: self.viewModel.dob,
        nationality: self.viewModel.nationality,
        residenceAddress: self.viewModel.residenceAddress,
        country: self.viewModel.residenceCountry,
        city: self.viewModel.residenceCity,
        zipCode: self.viewModel.residencePostalCode,
        proofAddress: self.viewModel.proofAddressType,
        proofAddressImage: self.viewModel.proofAddressImage,
        sourceFund: self.viewModel.sourceFund,
        occupationCode: self.viewModel.occupationCode,
        industryCode: self.viewModel.industryCode,
        taxResidencyCountry: self.viewModel.taxCountry,
        taxIDNumber: self.viewModel.taxIDNumber,
        docType: self.viewModel.localisedDocType,
        docNum: self.viewModel.docNumber,
        issueDate: self.viewModel.issueDate,
        expiryDate: self.viewModel.expiryDate,
        docFrontImage: self.viewModel.docFrontImage,
        docBackImage: self.viewModel.docBackImage,
        docHoldingImage: self.viewModel.docHoldingImage
      )
      let controller = KYCSubmitInfoViewController(viewModel: viewModel)
      controller.loadViewIfNeeded()
      controller.delegate = self
      return controller
    }()
    self.addChildViewController(self.submitInfoVC)
    self.submitInfoVC.view.frame = CGRect(x: 2.0 * width, y: 0, width: width, height: height)
    self.scrollView.addSubview(self.submitInfoVC.view)
    self.submitInfoVC.didMove(toParentViewController: self)

    let statusVC: KYCProfileVerificationStatusViewController = {
      return KYCProfileVerificationStatusViewController()
    }()
    self.addChildViewController(statusVC)
    statusVC.view.frame = CGRect(x: 3.0 * width, y: 0, width: width, height: height)
    self.scrollView.addSubview(statusVC.view)
    statusVC.didMove(toParentViewController: self)
    self.statusInfoVC = statusVC

    self.scrollView.contentSize = CGSize(
      width: self.scrollView.frame.width * 4.0,
      height: 1.0
    )
    self.updateViewState(newState: self.viewModel.stepState)

    if let details = self.viewModel.user.kycDetails {
      self.viewModel.updateData(with: details)
      personalInfoVC.updatePersonalInfoView(with: details)
      identityInfoVC.updateIdentityInfo(with: details)
      self.submitInfoVC.updateSubmitInfo(with: details)
    }
  }

  @IBAction func backButtonPressed(_ sender: Any) {
    if self.viewModel.stepState != .personalInfo && self.viewModel.stepState != .done {
      let newState: KNKYCStepViewState = {
        switch self.viewModel.stepState {
        case .personalInfo:
          return .personalInfo
        default:
          return KNKYCStepViewState(rawValue: self.viewModel.stepState.rawValue - 1) ?? .personalInfo
        }
      }()
      self.updateViewState(newState: newState)
    } else {
      let event: KYCFlowViewEvent = self.isUpdatingData ? .submitted : .back
      self.delegate?.kycFlowViewController(self, run: event)
    }
  }

  fileprivate func updateViewState(newState: KNKYCStepViewState) {
    let padding = self.bottomPaddingSafeArea()
    let width = UIScreen.main.bounds.width
    let height = self.view.frame.height - self.scrollView.frame.minY - padding

    self.viewModel.updateStepState(newState)
    self.stepView.updateView(with: self.viewModel.stepState)
    self.navigationTitleLabel.text = self.viewModel.stepState.title

    let rect = CGRect(
      x: CGFloat(self.viewModel.stepState.rawValue) * width,
      y: 0,
      width: width,
      height: height
    )
    if newState == .submit {
      let viewModel = KYCSubmitInfoViewModel(
        firstName: self.viewModel.firstName,
        middleName: self.viewModel.middleName,
        lastName: self.viewModel.lastName,
        nativeFullName: self.viewModel.nativeFullName,
        gender: self.viewModel.localisedGender,
        dob: self.viewModel.dob,
        nationality: self.viewModel.nationality,
        residenceAddress: self.viewModel.residenceAddress,
        country: self.viewModel.residenceCountry,
        city: self.viewModel.residenceCity,
        zipCode: self.viewModel.residencePostalCode,
        proofAddress: self.viewModel.proofAddressType,
        proofAddressImage: self.viewModel.proofAddressImage,
        sourceFund: self.viewModel.sourceFund,
        occupationCode: self.viewModel.occupationCode,
        industryCode: self.viewModel.industryCode,
        taxResidencyCountry: self.viewModel.taxCountry,
        taxIDNumber: self.viewModel.taxIDNumber,
        docType: self.viewModel.localisedDocType,
        docNum: self.viewModel.docNumber,
        issueDate: self.viewModel.issueDate,
        expiryDate: self.viewModel.expiryDate,
        docFrontImage: self.viewModel.docFrontImage,
        docBackImage: self.viewModel.docBackImage,
        docHoldingImage: self.viewModel.docHoldingImage
      )
      self.submitInfoVC.updateViewModel(viewModel)
    }
    self.scrollView.scrollRectToVisible(rect, animated: true)

    if newState == .done {
      self.doneTimer?.invalidate()
      self.doneTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false, block: { [weak self] timer in
        self?.backButtonPressed(timer)
      })
    }
  }
}

extension KYCFlowViewController: KYCPersonalInfoViewControllerDelegate {
  func kycPersonalInfoViewController(_ controller: KYCPersonalInfoViewController, run event: KYCPersonalInfoViewEvent) {
    switch event {
    case .next(
      let firstName,
      let middleName,
      let lastName,
      let nativeFullname,
      let gender,
      let dob,
      let nationality,
      let residentAddr,
      let countryOfResidence,
      let city,
      let postalCode,
      let proofAddrType,
      let proofAddrImage,
      let sourceFund,
      let occupationCode,
      let industryCode,
      let taxCountry,
      let taxIDNumber):
      self.viewModel.updatePersonalInfo(
        firstName: firstName,
        middleName: middleName,
        lastName: lastName,
        nativeFullName: nativeFullname,
        gender: gender,
        dob: dob,
        nationality: nationality,
        residenceAddress: residentAddr,
        residenceCountry: countryOfResidence,
        residenceCity: city,
        residencePostalCode: postalCode,
        proofAddressType: proofAddrType,
        proofAddressImage: proofAddrImage,
        sourceFund: sourceFund,
        occupationCode: occupationCode,
        industryCode: industryCode,
        taxCountry: taxCountry,
        taxIDNumber: taxIDNumber
      )
      guard let user = IEOUserStorage.shared.user,
        let data = UIImageJPEGRepresentation(proofAddrImage, 0.0) else { return }
      KNCrashlyticsUtil.logCustomEvent(withName: "profile_kyc", customAttributes: ["user": user.userID, "value": "submit_personal_info"])
      let service = ProfileKYCService.personalInfo(
        accessToken: user.accessToken,
        firstName: firstName,
        middleName: middleName,
        lastName: lastName,
        nativeFullName: nativeFullname,
        gender: gender.lowercased() == "male",
        dob: dob,
        nationality: nationality,
        residentialAddress: residentAddr,
        country: countryOfResidence,
        city: city,
        zipCode: postalCode,
        proofAddress: proofAddrType,
        proofAddressImageData: data,
        sourceFund: sourceFund,
        occupationCode: occupationCode,
        industryCode: industryCode,
        taxCountry: taxCountry,
        taxIDNo: taxIDNumber
      )
      self.displayLoading()
      self.sendProfileServiceRequest(service: service) { [weak self] result in
        self?.hideLoading()
        switch result {
        case .success(let resp):
          let success: Bool = resp.0
          let message: String = resp.1
          if success {
            self?.updateViewState(newState: .id)
          } else {
            self?.showWarningTopBannerMessage(
              with: NSLocalizedString("error", value: "Error", comment: ""),
              message: message,
              time: 1.5
            )
          }
        case .failure(let error):
          self?.displayError(error: error)
        }
      }
    }
  }
}

extension KYCFlowViewController: KYCIdentityInfoViewControllerDelegate {
  func identityInfoViewController(_ controller: KYCIdentityInfoViewController, run event: KYCIdentityInfoViewEvent) {
    switch event {
    case .next(let docType, let docNum, let issueDate, let expiryDate, let docFrontImage, let docBackImage, let docHoldingImage):
      self.viewModel.updateIdentityInfo(
        docType: docType,
        docNum: docNum,
        issueDate: issueDate,
        expiryDate: expiryDate,
        docFrontImage: docFrontImage,
        docBackImage: docBackImage,
        docHoldingImage: docHoldingImage
      )
      guard let user = IEOUserStorage.shared.user else { return }
      KNCrashlyticsUtil.logCustomEvent(withName: "profile_kyc", customAttributes: ["user": user.userID, "value": "submit_identity_info"])
      let docBackImageData: Data? = docBackImage == nil ? nil : UIImageJPEGRepresentation(docBackImage!, 0.0)
      guard let docFrontImageData = UIImageJPEGRepresentation(docFrontImage, 0.0),
        let docHoldingImageData = UIImageJPEGRepresentation(docHoldingImage, 0.0) else { return }
      let service = ProfileKYCService.identityInfo(
        accessToken: user.accessToken,
        documentType: docType,
        documentID: docNum,
        issueDate: issueDate,
        expiryDate: expiryDate,
        docFrontImage: docFrontImageData,
        docBackImage: docBackImageData,
        docHoldingImage: docHoldingImageData
      )
      self.displayLoading()
      self.sendProfileServiceRequest(service: service) { [weak self] result in
        self?.hideLoading()
        switch result {
        case .success(let resp):
          let success: Bool = resp.0
          let message: String = resp.1
          if success {
            self?.updateViewState(newState: .submit)
          } else {
            self?.showWarningTopBannerMessage(
              with: NSLocalizedString("error", value: "Error", comment: ""),
              message: message,
              time: 1.5
            )
          }
        case .failure(let error):
          self?.displayError(error: error)
        }
      }
    }
  }
}

extension KYCFlowViewController: KYCSubmitInfoViewControllerDelegate {
  func submitInfoViewController(_ controller: KYCSubmitInfoViewController, run event: KYCSubmitInfoViewEvent) {
    switch event {
    case .submit:
      guard let user = IEOUserStorage.shared.user else { return }
      KNCrashlyticsUtil.logCustomEvent(withName: "profile_kyc", customAttributes: ["user": user.userID, "value": "submit_info"])
      let service = ProfileKYCService.submitKYC(accessToken: user.accessToken)
      self.displayLoading()
      self.sendProfileServiceRequest(service: service) { [weak self] result in
        self?.hideLoading()
        switch result {
        case .success(let resp):
          let success: Bool = resp.0
          let message: String = resp.1
          if success {
            self?.updateViewState(newState: .done)
          } else {
            self?.showWarningTopBannerMessage(
              with: NSLocalizedString("error", value: "Error", comment: ""),
              message: message,
              time: 1.5
            )
          }
        case .failure(let error):
          self?.displayError(error: error)
        }
      }
    }
  }
}

// Sending ProfileKYCService requests
extension KYCFlowViewController {
  /*
   Send Profile Service request
   Return (bool, string): success and error message
   */
  fileprivate func sendProfileServiceRequest(service: ProfileKYCService, completion: @escaping (Result<(Bool, String), AnyError>) -> Void) {
    self.isUpdatingData = true
    let provider = MoyaProvider<ProfileKYCService>(plugins: [MoyaCacheablePlugin()])
    DispatchQueue.global(qos: .background).async {
      provider.request(service, completion: { [weak self] result in
        guard let _ = self else { return }
        DispatchQueue.main.async {
          switch result {
          case .success(let resp):
            do {
              _ = try resp.filterSuccessfulStatusCodes()
              let json: JSONDictionary = try resp.mapJSON(failsOnEmptyData: false) as? JSONDictionary ?? [:]
              let success: Bool = json["success"] as? Bool ?? false
              let message: String = {
                if success { return json["message"] as? String ?? "" }
                let reasons: [String] = json["reason"] as? [String] ?? []
                return reasons.isEmpty ? (json["reason"] as? String ?? "Unknown reason with status code \(resp.statusCode)") : reasons[0]
              }()
              completion(.success((success, message)))
            } catch let error {
              completion(.failure(AnyError(error)))
            }
          case .failure(let error):
            completion(.failure(AnyError(error)))
          }
        }
      })
    }
  }
}
