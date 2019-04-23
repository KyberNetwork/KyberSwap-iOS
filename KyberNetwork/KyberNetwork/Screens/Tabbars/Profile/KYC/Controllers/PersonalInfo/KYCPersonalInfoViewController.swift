// Copyright SIX DAY LLC. All rights reserved.

//swiftlint:disable file_length

import UIKit
import Moya
import Result
import QRCodeReaderViewController
import TrustCore
import Photos
import MobileCoreServices
import AVFoundation
import Crashlytics

enum KYCPersonalInfoViewEvent {
  case next(
    firstName: String, middleName: String, lastName: String, nativeFullName: String,
    gender: String, dob: String, nationality: String, wallets: [(String, String)],
    residentAddr: String, countryOfResidence: String, city: String, postalCode: String,
    proofAddrType: String, proofAddrImage: UIImage,
    sourceFund: String, occupationCode: String?, industryCode: String?,
    taxCountry: String?, taxIDNumber: String?)
  case updateWallets(_ wallets: [(String, String)])
}

enum KYCPersonalPickerType {
  case unknown
  case nationality
  case countryOfResidence
  case proofOfAddressType
  case sourceFund
  case occupationCode
  case industryCode
  case taxCountry
}

class KYCPersonalInfoViewModel {

  let user: IEOUser
  let nationalities: [String]
  let countries: [String]
  let proofOfAddressTypes: [String]
  let sourceFunds: [String]

  lazy var occupationCodes: [String: String] = {
    guard let json = KNJSONLoaderUtil.jsonDataFromFile(with: "kyc_occupation_code") else { return [:] }
    let data = json["data"] as? [String: String] ?? [:]
    return data
  }()

  lazy var industryCodes: [String: String] = {
    guard let json = KNJSONLoaderUtil.jsonDataFromFile(with: "kyc_industry_code") else { return [:] }
    let data = json["data"] as? [String: String] ?? [:]
    return data
  }()

  fileprivate(set) var gender: String = ""
  fileprivate(set) var dob: String = ""

  fileprivate(set) var wallets: [(String, String)] = []
  fileprivate(set) var currentWallets: [(String, String)] = []
  fileprivate(set) var hasModifiedWallets: Bool = false

  init(user: IEOUser) {
    self.user = user
    self.wallets = []
    let json = KNJSONLoaderUtil.jsonDataFromFile(with: "kyc_data") ?? [:]
    self.nationalities = json["nationalities"] as? [String] ?? []
    self.countries = json["countries"] as? [String] ?? []
    self.proofOfAddressTypes = json["proof_address"] as? [String] ?? []
    self.sourceFunds = json["source_funds"] as? [String] ?? []
  }

  func updateGender(_ gender: String) { self.gender = gender }
  func updateDoB(_ dob: String) { self.dob = dob }
  func removeAddress(at id: Int) {
    self.wallets.remove(at: id)
    self.hasModifiedWallets = true
  }

  func updateWallets(_ wallets: [(String, String)]) {
    self.wallets = wallets
    self.currentWallets = wallets
  }

  @discardableResult
  func addAddress(_ address: String, label: String) -> Bool {
    guard self.wallets.first(where: { $0.1.lowercased() == address.lowercased() }) == nil else { return false }
    self.wallets.append((label, address))
    self.hasModifiedWallets = true
    return true
  }

  @discardableResult
  func updateAddress(_ address: String, label: String) -> Bool {
    if let id = self.wallets.firstIndex(where: { $0.1.lowercased() == address.lowercased() }) {
      if self.wallets[id].0 != label { self.hasModifiedWallets = true }
      self.wallets[id] = (label, address)
      return true
    }
    return false
  }

  func getUserWallets(completion: @escaping (Result<[(String, String)], AnyError>) -> Void) {
    let provider = MoyaProvider<ProfileKYCService>()
    provider.request(.userWallets(accessToken: self.user.accessToken)) { result in
      switch result {
      case .success(let resp):
        do {
          _ = try resp.filterSuccessfulStatusCodes()
          let json: JSONDictionary = try resp.mapJSON(failsOnEmptyData: false) as? JSONDictionary ?? [:]
          let dataArr = json["data"] as? [JSONDictionary] ?? []
          let values = dataArr.map({ ($0["label"] as? String ?? "", $0["address"] as? String ?? "") })
          if !self.hasModifiedWallets {
            self.wallets = values
          }
          self.currentWallets = values
          KNNotificationUtil.postNotification(
            for: kUserWalletsListUpdatedNotificationKey,
            object: values,
            userInfo: nil
          )
          completion(.success(values))
        } catch let error {
          completion(.failure(AnyError(error)))
        }
      case .failure(let error):
        completion(.failure(AnyError(error)))
      }
    }
  }

  func checkWalletExist(wallet: String, completion: @escaping (Result<Bool, AnyError>) -> Void) {
    guard self.wallets.first(where: { $0.1.lowercased() == wallet.lowercased() }) == nil else {
      completion(.success(true))
      return
    }
    let provider = MoyaProvider<ProfileKYCService>()
    provider.request(.checkWalletExist(accessToken: user.accessToken, wallet: wallet)) { result in
      switch result {
      case .success(let resp):
        do {
          _ = try resp.filterSuccessfulStatusCodes()
          let json: JSONDictionary = try resp.mapJSON(failsOnEmptyData: false) as? JSONDictionary ?? [:]
          let existed: Bool = json["wallet_existed"] as? Bool ?? false
          completion(.success(!existed))
        } catch let error {
          completion(.failure(AnyError(error)))
        }
      case .failure(let error):
        completion(.failure(AnyError(error)))
      }
    }
  }
}

protocol KYCPersonalInfoViewControllerDelegate: class {
  func kycPersonalInfoViewController(_ controller: KYCPersonalInfoViewController, run event: KYCPersonalInfoViewEvent)
}

//swiftlint:disable type_body_length
class KYCPersonalInfoViewController: KNBaseViewController {

  let kWalletTableViewCellID = "kWalletTableViewCellID"
  let kWalletCellRowHeight: CGFloat = 84.0

  @IBOutlet weak var scrollView: UIScrollView!
  @IBOutlet weak var firstNameTextField: UITextField!
  @IBOutlet weak var middleNameTextField: UITextField!
  @IBOutlet weak var lastNameTextField: UITextField!
  @IBOutlet weak var nativeFullNameTextField: UITextField!
  @IBOutlet weak var maleButton: UIButton!
  @IBOutlet weak var femaleButton: UIButton!
  @IBOutlet weak var dateOfBirthTextField: UITextField!
  @IBOutlet weak var nationalityTextField: UITextField!
  @IBOutlet weak var genderTextLabel: UILabel!
  @IBOutlet weak var maleTextLabel: UILabel!
  @IBOutlet weak var femaleTextLabel: UILabel!

  @IBOutlet weak var mywalletsLabel: UILabel!
  @IBOutlet weak var maximumWalletsLabel: UILabel!
  @IBOutlet weak var walletWarningMessageLabel: UILabel!
  @IBOutlet weak var walletsDataView: UIView!
  @IBOutlet weak var walletsTableView: UITableView!
  @IBOutlet weak var noWalletsTextLabel: UILabel!
  @IBOutlet weak var heightConstraintWalletsDataView: NSLayoutConstraint!
  @IBOutlet weak var addWalletContainerView: UIView!
  @IBOutlet weak var heightConstraintForAddWalletView: NSLayoutConstraint!
  @IBOutlet weak var addWalletButton: UIButton!
  @IBOutlet weak var walletLabelTextField: UITextField!
  @IBOutlet weak var walletAddressTextField: UITextField!

  @IBOutlet weak var addressSeparatorView: UIView!
  @IBOutlet weak var residentialAddressTextLabel: UILabel!
  @IBOutlet weak var residentialAddressTextField: UITextField!
  @IBOutlet weak var countryOfResidenceTextField: UITextField!
  @IBOutlet weak var cityTextField: UITextField!
  @IBOutlet weak var postalCodeTextField: UITextField!

  @IBOutlet weak var proofOfAddressTextLabel: UILabel!
  @IBOutlet weak var proofOfAddressDescTextLabel: UILabel!
  @IBOutlet weak var proofAddressDocTypeTextField: UITextField!
  @IBOutlet weak var uploadProofAddressDocButton: UIButton!
  fileprivate var proofAddressImage: UIImage?
  @IBOutlet weak var proofOfAddressContainerView: UIView!
  @IBOutlet weak var heightConstraintForProofOfAddressContainerView: NSLayoutConstraint!
  @IBOutlet weak var proofOfAddressImageView: UIImageView!
  @IBOutlet weak var topPaddingConstraintProofOfAddressImageView: NSLayoutConstraint!

  @IBOutlet weak var primarySourceOfFundTextLabel: UILabel!
  @IBOutlet weak var primaraySourceOfFundDescTextLabel: UILabel!
  @IBOutlet weak var primarySourceOfFundTextField: UITextField!

  @IBOutlet weak var optionalDataView: KYCPersonalOptionalDataView!
  @IBOutlet weak var heightConstraintForOptionalData: NSLayoutConstraint!

  @IBOutlet weak var nextButton: UIButton!

  fileprivate var fakeTextField: UITextField = UITextField(frame: CGRect.zero)
  fileprivate var currentValue: String = ""
  fileprivate var dataPickerType: KYCPersonalPickerType = .unknown
  fileprivate var pickerViewController: KYCSelectOptionViewController?

  lazy var datePicker: UIDatePicker = {
    let frame = CGRect(
      x: 0,
      y: self.view.frame.height - 200.0,
      width: self.view.frame.width,
      height: 200.0
    )
    let picker = UIDatePicker(frame: frame)
    picker.datePickerMode = .date
    picker.minimumDate = Date().addingTimeInterval(-100.0 * 360.0 * 24.0 * 60.0 * 60.0)
    picker.maximumDate = Date()
    picker.addTarget(self, action: #selector(self.dateOfBirthDidChange(_:)), for: .valueChanged)
    picker.date = Date()
    return picker
  }()

  lazy var pickerView: UIPickerView = {
    let pickerView = UIPickerView(frame: CGRect.zero)
    pickerView.showsSelectionIndicator = true
    pickerView.dataSource = self
    pickerView.delegate = self
    return pickerView
  }()

  lazy var toolBar: UIToolbar = {
    let frame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: 44)
    let toolBar = UIToolbar(frame: frame)
    toolBar.barStyle = .default
    let doneBtn = UIBarButtonItem(
      barButtonSystemItem: .done,
      target: self,
      action: #selector(self.countryPickerDonePressed(_:))
    )
    let flexibleSpaceBtn = UIBarButtonItem(
      barButtonSystemItem: UIBarButtonSystemItem.flexibleSpace,
      target: nil,
      action: nil
    )
    doneBtn.tintColor = UIColor.Kyber.dark
    let cancelBtn = UIBarButtonItem(
      barButtonSystemItem: .cancel,
      target: self,
      action: #selector(self.countryPickerCancelPressed(_:))
    )
    cancelBtn.tintColor = UIColor.Kyber.dark
    toolBar.setItems([cancelBtn, flexibleSpaceBtn, doneBtn], animated: false)
    return toolBar
  }()

  weak var delegate: KYCPersonalInfoViewControllerDelegate?
  fileprivate var viewModel: KYCPersonalInfoViewModel
  fileprivate var imagePicker: UIImagePickerController = UIImagePickerController()

  init(viewModel: KYCPersonalInfoViewModel) {
    self.viewModel = viewModel
    super.init(nibName: KYCPersonalInfoViewController.className, bundle: nil)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    self.setupUI()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    self.viewModel.getUserWallets { _ in
      self.updateWalletsData()
      self.delegate?.kycPersonalInfoViewController(self, run: .updateWallets(self.viewModel.currentWallets))
    }
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    self.optionalDataView.layoutSubviews()
    self.addressSeparatorView.dashLine(width: 1.0, color: UIColor.Kyber.dashLine)
    self.nextButton.removeSublayer(at: 0)
    self.nextButton.applyGradient()
  }

  fileprivate func setupUI() {
    self.setupDataContent()
    self.setupWalletsDataView()
    self.setupAddressDetails()
    self.setupProofOfAddress()
    self.setupSourceOfFunds()
    self.setupOptionalData()
  }

  fileprivate func setupDataContent() {
    self.firstNameTextField.placeholder = NSLocalizedString("first.name", value: "First Name", comment: "")
    self.firstNameTextField.addPlaceholderSpacing()
    self.middleNameTextField.placeholder = NSLocalizedString("middle.name", value: "Middle Name", comment: "")
    self.middleNameTextField.addPlaceholderSpacing()
    self.lastNameTextField.placeholder = NSLocalizedString("last.name", value: "Last Name", comment: "")
    self.lastNameTextField.addPlaceholderSpacing()
    self.nativeFullNameTextField.placeholder = NSLocalizedString("full.name.in.native.characters", value: "Full Name in Native Characters", comment: "")
    self.nativeFullNameTextField.addPlaceholderSpacing()
    self.genderTextLabel.text = NSLocalizedString("gender", value: "Gender", comment: "")
    self.genderTextLabel.addLetterSpacing()
    self.maleTextLabel.text = NSLocalizedString("male", value: "Male", comment: "")
    self.maleTextLabel.addLetterSpacing()
    self.femaleTextLabel.text = NSLocalizedString("female", value: "Female", comment: "")
    self.femaleTextLabel.addLetterSpacing()
    self.dateOfBirthTextField.placeholder = "\(NSLocalizedString("date.of.birth", value: "Date of birth", comment: "")) (YYYY-MM-DD)"
    self.dateOfBirthTextField.addPlaceholderSpacing()
    self.nationalityTextField.placeholder = NSLocalizedString("nationality", value: "Nationality", comment: "")
    self.nationalityTextField.addPlaceholderSpacing()
    self.mywalletsLabel.text = NSLocalizedString("my.wallets", value: "My wallet(s)", comment: "")
    self.mywalletsLabel.addLetterSpacing()
    self.maximumWalletsLabel.text = NSLocalizedString("maximum.three.wallets", value: "Maximum 3 wallets", comment: "")
    self.maximumWalletsLabel.addLetterSpacing()
    self.walletWarningMessageLabel.text = NSLocalizedString("kyc.submit.wallet.warning.message.personal.info", value: "", comment: "You can only delete/edit your wallets here. Once your profile is submitted for review, you won't be able to do so.")
    self.walletWarningMessageLabel.addLetterSpacing()
    self.walletLabelTextField.placeholder = NSLocalizedString("label", value: "Label", comment: "")
    self.walletLabelTextField.addPlaceholderSpacing()
    self.walletAddressTextField.placeholder = NSLocalizedString("address", value: "Address", comment: "")
    self.walletAddressTextField.addPlaceholderSpacing()
    self.maleButton.rounded(
      color: UIColor.Kyber.border,
      width: 1.0,
      radius: self.maleButton.frame.height / 2.0
    )
    self.femaleButton.rounded(
      color: UIColor.Kyber.border,
      width: 1.0,
      radius: self.femaleButton.frame.height / 2.0
    )

    self.nationalityTextField.delegate = self
    self.dateOfBirthTextField.inputView = self.datePicker
    self.dateOfBirthTextField.delegate = self

    let maleTap = UITapGestureRecognizer(target: self, action: #selector(self.maleButtonPressed(_:)))
    self.maleTextLabel.isUserInteractionEnabled = true
    self.maleTextLabel.addGestureRecognizer(maleTap)

    let femaleTap = UITapGestureRecognizer(target: self, action: #selector(self.femaleButtonPressed(_:)))
    self.femaleTextLabel.isUserInteractionEnabled = true
    self.femaleTextLabel.addGestureRecognizer(femaleTap)
    self.view.addSubview(self.fakeTextField)
  }

  fileprivate func setupWalletsDataView() {
    self.addWalletButton.rounded(
      color: UIColor.Kyber.border,
      width: 1.0,
      radius: KNAppStyleType.current.buttonRadius(for: self.addWalletButton.frame.height)
    )
    self.addWalletButton.setTitle(
      NSLocalizedString("add", value: "Add", comment: ""),
      for: .normal
    )
    self.noWalletsTextLabel.text = NSLocalizedString("you.have.not.added.any.wallets.yet", value: "You haven't added any wallets yet.", comment: "")
    self.noWalletsTextLabel.addLetterSpacing()

    self.walletsTableView.register(UITableViewCell.self, forCellReuseIdentifier: kWalletTableViewCellID)
    self.walletsTableView.rowHeight = kWalletCellRowHeight
    self.walletsTableView.delegate = self
    self.walletsTableView.dataSource = self
    self.updateWalletsData()

    self.nextButton.setTitle(NSLocalizedString("next", value: "Next", comment: ""), for: .normal)
    self.nextButton.applyGradient()
    self.nextButton.rounded(radius: KNAppStyleType.current.buttonRadius(for: self.nextButton.frame.height))
  }

  fileprivate func setupAddressDetails() {
    self.addressSeparatorView.dashLine(width: 1.0, color: UIColor.Kyber.dashLine)
    self.residentialAddressTextLabel.text = NSLocalizedString(
      "residential.address",
      value: "Residential Address",
      comment: ""
    )
    self.residentialAddressTextLabel.addLetterSpacing()
    self.residentialAddressTextField.placeholder = NSLocalizedString(
      "street.address.apartment.unit",
      value: "Street address, P.O. box, apartment, suite, unit, building, floor,…",
      comment: ""
    )
    self.residentialAddressTextField.addPlaceholderSpacing()
    self.countryOfResidenceTextField.placeholder = NSLocalizedString("country.of.residence", value: "Country of Residence", comment: "")
    self.countryOfResidenceTextField.addPlaceholderSpacing()
    self.cityTextField.placeholder = NSLocalizedString("city", value: "City", comment: "")
    self.cityTextField.addPlaceholderSpacing()
    self.postalCodeTextField.placeholder = NSLocalizedString("postal.zip.code", value: "Postal / Zip Code", comment: "")
    self.postalCodeTextField.addPlaceholderSpacing()
    self.countryOfResidenceTextField.delegate = self
  }

  fileprivate func setupProofOfAddress() {
    self.proofOfAddressTextLabel.text = NSLocalizedString("proof.of.address", value: "Proof of Address", comment: "").uppercased()
    self.proofOfAddressTextLabel.addLetterSpacing()
    self.proofOfAddressDescTextLabel.text = NSLocalizedString(
      "document.must.display.your.name.and.address",
      value: "Document must display your name and current residential address in 6 months",
      comment: ""
    )
    self.proofOfAddressDescTextLabel.addLetterSpacing()
    self.proofAddressDocTypeTextField.placeholder = NSLocalizedString("document.types", value: "Document Types", comment: "")
    self.proofAddressDocTypeTextField.addPlaceholderSpacing()
    self.proofAddressDocTypeTextField.delegate = self
    self.uploadProofAddressDocButton.setTitle(
      NSLocalizedString("browse", value: "Browse", comment: ""),
      for: .normal
    )
    self.uploadProofAddressDocButton.addTextSpacing()
    self.uploadProofAddressDocButton.rounded(
      color: UIColor.Kyber.border,
      width: 1.0,
      radius: KNAppStyleType.current.buttonRadius(for: self.uploadProofAddressDocButton.frame.height)
    )
    self.heightConstraintForProofOfAddressContainerView.constant = 0.0
    self.topPaddingConstraintProofOfAddressImageView.constant = 0.0
    self.proofOfAddressImageView.image = nil
  }

  fileprivate func setupSourceOfFunds() {
    self.primarySourceOfFundTextLabel.text = NSLocalizedString("primary.source.of.funds", value: "Primary source of funds", comment: "").uppercased()
    self.primarySourceOfFundTextLabel.addLetterSpacing()
    self.primaraySourceOfFundDescTextLabel.text = NSLocalizedString(
      "primary.source.of.funds.desc",
      value: "Please indicate below the primary professional activity that generate the funds that will be transferred into the wallet. Filling up this field will help us better understand your primary professional activity.",
      comment: ""
    )
    self.primaraySourceOfFundDescTextLabel.addLetterSpacing()
    self.primarySourceOfFundTextField.placeholder = NSLocalizedString("source.of.funds", value: "Source of Funds", comment: "")
    self.primarySourceOfFundTextField.addPlaceholderSpacing()
  }

  fileprivate func setupOptionalData() {
    self.optionalDataView.collapse()
    self.optionalDataView.delegate = self
    self.heightConstraintForOptionalData.constant = self.optionalDataView.height
    self.optionalDataView.occupationCodeTextField.delegate = self
    self.optionalDataView.industryCodeTextField.delegate = self
    self.optionalDataView.countryTextField.delegate = self
  }

  @IBAction func maleButtonPressed(_ sender: Any) {
    self.viewModel.updateGender(self.viewModel.gender == "Male" ? "" : "Male")
    self.updateGenderUI()
  }

  @IBAction func femaleButtonPressed(_ sender: Any) {
    self.viewModel.updateGender(self.viewModel.gender == "Female" ? "" : "Female")
    self.updateGenderUI()
  }

  fileprivate func updateGenderUI() {
    self.maleButton.rounded(
      color: self.viewModel.gender == "Male" ? UIColor.Kyber.enygold : UIColor.Kyber.border,
      width: self.viewModel.gender == "Male" ? 6.0 : 1.0,
      radius: self.maleButton.frame.height / 2.0
    )
    self.femaleButton.rounded(
      color: self.viewModel.gender == "Female" ? UIColor.Kyber.enygold : UIColor.Kyber.border,
      width: self.viewModel.gender == "Female" ? 6.0 : 1.0,
      radius: self.maleButton.frame.height / 2.0
    )
  }

  @IBAction func nationalityButtonPressed(_ sender: Any) {
    self.dataPickerType = .nationality
    self.pickerViewController = nil
    self.pickerViewController = KYCSelectOptionViewController(
      title: NSLocalizedString("nationality", value: "Nationality", comment: ""), dataSources: self.viewModel.nationalities
    )
    self.pickerViewController?.delegate = self
    self.parent?.navigationController?.pushViewController(self.pickerViewController!, animated: true)
  }

  @IBAction func countryOfResidenceButtonPressed(_ sender: Any) {
    self.dataPickerType = .countryOfResidence
    self.pickerViewController = nil
    self.pickerViewController = KYCSelectOptionViewController(
      title: NSLocalizedString("country.of.residence", value: "Country of Residence", comment: ""), dataSources: self.viewModel.countries
    )
    self.pickerViewController?.delegate = self
    self.parent?.navigationController?.pushViewController(self.pickerViewController!, animated: true)
  }

  @IBAction func proofAddressChooseDocumentTypeButtonPressed(_ sender: Any) {
    self.dataPickerType = .proofOfAddressType
    self.fakeTextField.inputView = self.pickerView

    self.fakeTextField.inputAccessoryView = self.toolBar
    self.currentValue = self.proofAddressDocTypeTextField.text ?? ""

    if let id = self.viewModel.proofOfAddressTypes.firstIndex(where: { NSLocalizedString($0, value: $0, comment: "") == self.currentValue }) {
      self.currentValue = NSLocalizedString(
        self.viewModel.proofOfAddressTypes[id],
        value: self.viewModel.proofOfAddressTypes[id],
        comment: ""
      )
      self.pickerView.selectRow(id, inComponent: 0, animated: false)
    } else {
      self.currentValue = NSLocalizedString(
        self.viewModel.proofOfAddressTypes[0],
        value: self.viewModel.proofOfAddressTypes[0],
        comment: ""
      )
      self.pickerView.selectRow(0, inComponent: 0, animated: false)
    }

    self.fakeTextField.becomeFirstResponder()
  }

  @IBAction func qrcodeButtonPressed(_ sender: Any) {
    KNCrashlyticsUtil.logCustomEvent(withName: "profile_kyc", customAttributes: ["value": "qrcode_button"])
    let qrcodeReader = QRCodeReaderViewController()
    qrcodeReader.delegate = self
    self.present(qrcodeReader, animated: true, completion: nil)
  }

  @IBAction func uploadProofOfAddressDocButtonPressed(_ sender: Any) {
    self.openImagePickerController()
  }

  @IBAction func addWalletButtonPressed(_ sender: Any) {
    KNCrashlyticsUtil.logCustomEvent(withName: "profile_kyc", customAttributes: ["value": "add_wallet_personal_info"])
    guard let label = self.walletLabelTextField.text, !label.isEmpty else {
      self.showWarningTopBannerMessage(
        with: NSLocalizedString("invalid.input", value: "Invalid Input", comment: ""),
        message: NSLocalizedString("please.enter.a.valid.wallet.label", value: "Please enter a valid wallet label", comment: ""),
        time: 1.5
      )
      return
    }
    guard let address = self.walletAddressTextField.text, Address(string: address) != nil else {
      self.showWarningTopBannerMessage(
        with: NSLocalizedString("invalid.input", value: "Invalid Input", comment: ""),
        message: NSLocalizedString("please.enter.a.valid.address", value: "Please enter a valid address", comment: ""),
        time: 1.5
      )
      return
    }
    self.displayLoading(text: NSLocalizedString("checking", value: "Checking", comment: ""), animated: true)
    self.viewModel.checkWalletExist(wallet: address) { [weak self] result in
      guard let `self` = self else { return }
      self.hideLoading()
      switch result {
      case .success(let ok):
        if ok {
          var updated = self.viewModel.updateAddress(address, label: label)
          if !updated {
            // in case user has removed this wallet and added again
            updated = self.viewModel.addAddress(address, label: label)
          }
          self.updateWalletsData()
        } else {
          self.showWarningTopBannerMessage(
            with: NSLocalizedString("error", value: "Error", comment: ""),
            message: NSLocalizedString("address.has.already.been.taken", value: "Address has already been taken", comment: ""),
            time: 1.5
          )
        }
      case .failure:
        self.showWarningTopBannerMessage(
          with: NSLocalizedString("error", value: "Error", comment: ""),
          message: NSLocalizedString("some.thing.went.wrong.please.try.again", value: "Something went wrong. Please try again", comment: "")
        )
      }
    }
  }

  //swiftlint:disable function_body_length
  @IBAction func nextButtonPressed(_ sender: Any) {
    // Check first + last name
    let firstName = self.firstNameTextField.text ?? ""
    let lastName = self.lastNameTextField.text ?? ""
    let middleName = self.middleNameTextField.text ?? ""
    let nativeFullName = self.nativeFullNameTextField.text ?? ""
    guard !firstName.isEmpty && !lastName.isEmpty else {
      self.showWarningTopBannerMessage(
        with: NSLocalizedString("invalid.name", value: "Invalid name", comment: ""),
        message: NSLocalizedString("please.enter.a.valid.name", value: "Please enter a valid name", comment: ""),
        time: 1.5
      )
      return
    }
    // Check gender selected
    guard !self.viewModel.gender.isEmpty else {
      self.showWarningTopBannerMessage(
        with: NSLocalizedString("invalid.gender", value: "Invalid gender", comment: ""),
        message: NSLocalizedString("please.select.your.gender.to.continue", value: "Please select your gender to continue", comment: ""),
        time: 1.5
      )
      return
    }
    // Check date of birth
    guard !self.viewModel.dob.isEmpty else {
      self.showWarningTopBannerMessage(
        with: NSLocalizedString("invalid.date.of.birth", value: "Invalid date of birth", comment: ""),
        message: NSLocalizedString("please.select.your.date.of.birth.to.continue", value: "Please select your date of birth to continue", comment: ""),
        time: 1.5
      )
      return
    }
    // Check nationality
    let nationality = self.nationalityTextField.text ?? ""
    guard self.viewModel.nationalities.contains(nationality) else {
      self.showWarningTopBannerMessage(
        with: NSLocalizedString("invalid.nationality", value: "Invalid nationality", comment: ""),
        message: NSLocalizedString("please.enter.select.a.valid.nationality.to.continue", value: "Please enter/select a valid nationality to continue", comment: ""),
        time: 1.5
      )
      return
    }
    // Check country of residences
    let residenceAddr: String = self.residentialAddressTextField.text ?? ""
    let countryOfResidence = self.countryOfResidenceTextField.text ?? ""
    guard self.viewModel.countries.contains(countryOfResidence) else {
      self.showWarningTopBannerMessage(
        with: NSLocalizedString("invalid.country", value: "Invalid country", comment: ""),
        message: NSLocalizedString("please.enter.select.a.valid.country.to.continue", value: "Please enter/select a valid country to continue", comment: ""),
        time: 1.5
      )
      return
    }
    let city: String = self.cityTextField.text ?? ""
    if city.isEmpty {
      self.showWarningTopBannerMessage(
        with: NSLocalizedString("invalid.input", value: "Invalid Input", comment: ""),
        message: NSLocalizedString("please.enter.your.city", value: "Please enter your city", comment: ""),
        time: 1.5
      )
      return
    }
    let postalCode: String = self.postalCodeTextField.text ?? ""
    if postalCode.isEmpty {
      self.showWarningTopBannerMessage(
        with: NSLocalizedString("invalid.input", value: "Invalid Input", comment: ""),
        message: NSLocalizedString("please.enter.postal.zip.code", value: "Please enter your Postal/Zip Code", comment: ""),
        time: 1.5
      )
      return
    }
    let proofAddressTypeLocalised = self.proofAddressDocTypeTextField.text ?? ""
    guard let proofAddressType = self.viewModel.proofOfAddressTypes.first(where: { NSLocalizedString($0, value: $0, comment: "") == proofAddressTypeLocalised }) else {
      self.showWarningTopBannerMessage(
        with: NSLocalizedString("invalid.input", value: "Invalid Input", comment: ""),
        message: NSLocalizedString("please.enter.select.a.valid.document.type.for.proof.of.address.document", value: "Please enter/select a valid document type for proof of address", comment: ""),
        time: 1.5
      )
      return
    }
    guard let proofAddressImage = self.proofAddressImage else {
      self.showWarningTopBannerMessage(
        with: NSLocalizedString("invalid.input", value: "Invalid Input", comment: ""),
        message: NSLocalizedString("please.provide.your.proof.of.address.photo", value: "Please provide your proof of address photo", comment: ""),
        time: 1.5
      )
      return
    }
    let sourceLocalisedFund = self.primarySourceOfFundTextField.text ?? ""
    if sourceLocalisedFund.isEmpty {
      self.showWarningTopBannerMessage(
        with: NSLocalizedString("invalid.input", value: "Invalid Input", comment: ""),
        message: NSLocalizedString("please.provide.a.valid.source.of.funds", value: "Please provide a valid Source of Funds", comment: ""),
        time: 1.5
      )
      return
    }
    let sourceFund = self.viewModel.sourceFunds.first(where: { NSLocalizedString($0, value: $0, comment: "") == sourceLocalisedFund }) ?? sourceLocalisedFund
    let occupationCode = self.optionalDataView.getOccupationCode()
    if !occupationCode.isEmpty && self.viewModel.occupationCodes[occupationCode] == nil {
      self.showWarningTopBannerMessage(
        with: NSLocalizedString("invalid.input", value: "Invalid Input", comment: ""),
        message: NSLocalizedString("please.check.your.occupation.code", value: "Please check your occupation code", comment: ""),
        time: 1.5
      )
      return
    }
    KNCrashlyticsUtil.logCustomEvent(withName: "profile_kyc", customAttributes: ["value": "occupation_code_\(occupationCode.isEmpty ? "empty" : "nonempty")"])
    let industryCode = self.optionalDataView.getIndustryCode()
    if !industryCode.isEmpty && self.viewModel.industryCodes[industryCode] == nil {
      self.showWarningTopBannerMessage(
        with: NSLocalizedString("invalid.input", value: "Invalid Input", comment: ""),
        message: NSLocalizedString("please.check.your.industry.code", value: "Please check your industry code", comment: ""),
        time: 1.5
      )
      return
    }
    KNCrashlyticsUtil.logCustomEvent(withName: "profile_kyc", customAttributes: ["value": "industry_code_\(industryCode.isEmpty ? "empty" : "nonempty")"])
    let taxCountry = self.optionalDataView.getTaxCountry()
    if !taxCountry.isEmpty && !self.viewModel.countries.contains(taxCountry) {
      self.showWarningTopBannerMessage(
        with: NSLocalizedString("invalid.input", value: "Invalid Input", comment: ""),
        message: NSLocalizedString("please.check.your.tax.residency.country", value: "Please check your Tax Residency country", comment: ""),
        time: 1.5
      )
      return
    }
    KNCrashlyticsUtil.logCustomEvent(withName: "profile_kyc", customAttributes: ["value": "tax_country_\(taxCountry.isEmpty ? "empty" : "nonempty")"])
    let taxIDNumber: String? = {
      if !self.optionalDataView.getHasTaxIDNumber() {
        return nil
      }
      return self.optionalDataView.getTaxIDNumber()
    }()
    if let taxID = taxIDNumber, taxID.isEmpty {
      self.showWarningTopBannerMessage(
        with: NSLocalizedString("invalid.input", value: "Invalid Input", comment: ""),
        message: NSLocalizedString("please.provide.your.tax.id.number", value: "Please provide your Tax ID Number", comment: ""),
        time: 1.5
      )
      return
    }
    let nextEvent = KYCPersonalInfoViewEvent.next(
      firstName: firstName,
      middleName: middleName,
      lastName: lastName,
      nativeFullName: nativeFullName,
      gender: self.viewModel.gender,
      dob: self.viewModel.dob,
      nationality: nationality,
      wallets: self.viewModel.wallets,
      residentAddr: residenceAddr,
      countryOfResidence: countryOfResidence,
      city: city,
      postalCode: postalCode,
      proofAddrType: proofAddressType,
      proofAddrImage: proofAddressImage,
      sourceFund: sourceFund,
      occupationCode: occupationCode.isEmpty ? nil : occupationCode,
      industryCode: industryCode.isEmpty ? nil : industryCode,
      taxCountry: taxCountry.isEmpty ? nil : taxCountry,
      taxIDNumber: taxIDNumber
    )
    self.delegate?.kycPersonalInfoViewController(self, run: nextEvent)
  }

  @objc func dateOfBirthDidChange(_ sender: Any) {
    let dob = DateFormatterUtil.shared.kycDateFormatter.string(from: self.datePicker.date)
    self.dateOfBirthTextField.text = dob
    self.viewModel.updateDoB(dob)
  }

  @objc func countryPickerDonePressed(_ sender: Any) {
    self.fakeTextField.resignFirstResponder()
    if self.dataPickerType == .proofOfAddressType {
      self.proofAddressDocTypeTextField.text = self.currentValue
    } else if self.dataPickerType == .sourceFund {
      self.primarySourceOfFundTextField.text = self.currentValue
    }
  }

  @objc func countryPickerCancelPressed(_ sender: Any) {
    self.fakeTextField.resignFirstResponder()
  }

  @IBAction func primarySourceOfFundButtonPressed(_ sender: Any) {
    KNCrashlyticsUtil.logCustomEvent(withName: "profile_kyc", customAttributes: ["value": "primary_source_fund_picker"])
    self.dataPickerType = .sourceFund
    self.fakeTextField.inputView = self.pickerView

    self.fakeTextField.inputAccessoryView = self.toolBar
    self.currentValue = self.primarySourceOfFundTextField.text ?? ""

    if let id = self.viewModel.sourceFunds.firstIndex(where: { NSLocalizedString($0, value: $0, comment: "") == self.currentValue }) {
      self.currentValue = NSLocalizedString(
        self.viewModel.sourceFunds[id],
        value: self.viewModel.sourceFunds[id],
        comment: ""
      )
      self.pickerView.selectRow(id, inComponent: 0, animated: false)
    } else {
      self.currentValue = NSLocalizedString(
        self.viewModel.sourceFunds[0],
        value: self.viewModel.sourceFunds[0],
        comment: ""
      )
      self.pickerView.selectRow(0, inComponent: 0, animated: false)
    }

    self.fakeTextField.becomeFirstResponder()
  }

  fileprivate func updateWalletsData() {
    if self.viewModel.wallets.isEmpty {
      self.noWalletsTextLabel.isHidden = false
      self.walletsTableView.isHidden = true
      self.heightConstraintWalletsDataView.constant = 260.0
      self.heightConstraintForAddWalletView.constant = 200.0
      self.addWalletContainerView.isHidden = false
    } else {
      // Only allow add up to 3 wallets
      let hasAddWallet: Bool = self.viewModel.wallets.count < 3
      let addWalletHeight: CGFloat = hasAddWallet ? 200.0 : 0.0
      self.heightConstraintWalletsDataView.constant = CGFloat(self.viewModel.wallets.count) * kWalletCellRowHeight + addWalletHeight
      self.addWalletContainerView.isHidden = !hasAddWallet
      self.heightConstraintForAddWalletView.constant = addWalletHeight
      self.noWalletsTextLabel.isHidden = true
      self.walletsTableView.isHidden = false
      self.walletsTableView.reloadData()
    }
  }

  func updatePersonalInfoView(with details: UserKYCDetailsInfo) {
    guard !details.firstName.isEmpty else { return }
    self.firstNameTextField.text = details.firstName
    self.middleNameTextField.text = details.middleName
    self.lastNameTextField.text = details.lastName
    self.nativeFullNameTextField.text = details.nativeFullName
    self.viewModel.updateGender(details.gender ? "Male": "Female")
    self.updateGenderUI()
    self.viewModel.updateDoB(details.dob)
    if let dob = DateFormatterUtil.shared.kycDateFormatter.date(from: details.dob) {
      self.dateOfBirthTextField.text = details.dob
      self.datePicker.setDate(dob, animated: false)
    }
    self.nationalityTextField.text = details.nationality
    self.residentialAddressTextField.text = details.residentialAddress
    self.countryOfResidenceTextField.text = details.country
    self.cityTextField.text = details.city
    self.postalCodeTextField.text = details.zipCode
    self.proofAddressDocTypeTextField.text = NSLocalizedString(details.documentProofAddress, value: details.documentProofAddress, comment: "")

    let base64Prefix = "data:image/jpeg;base64,"
    if details.photoProofAddress.starts(with: base64Prefix),
      let data = Data(base64Encoded: details.photoProofAddress.substring(from: base64Prefix.count)),
      let image = UIImage(data: data) {
      self.updateProofAddressDocumentType(with: image, animate: false)
    }

    self.primarySourceOfFundTextField.text = NSLocalizedString(details.sourceFund, value: details.sourceFund, comment: "")
    let occupation = self.viewModel.occupationCodes.first(where: { $0.key == details.occupationCode })?.value ?? ""
    let industry = self.viewModel.industryCodes.first(where: { $0.key == details.industryCode })?.value ?? ""
    self.optionalDataView.updateOptionalData(with: details, occupation: occupation, industry: industry)
    self.view.layoutIfNeeded()
  }

  fileprivate func openImagePickerController() {
    let alertController = UIAlertController(
      title: NSLocalizedString("choose.method", value: "Choose Method", comment: ""),
      message: NSLocalizedString("where.do.you.want.to.get.your.image", value: "Where do you want to get your image?", comment: ""),
      preferredStyle: .alert
    )
    alertController.addAction(UIAlertAction(title: NSLocalizedString("camera", value: "Camera", comment: ""), style: .default, handler: { _ in
      self.openImagePickerCamera()
    }))
    alertController.addAction(UIAlertAction(title: NSLocalizedString("photo.library", value: "Photo Library", comment: ""), style: .default, handler: { _ in
      self.openImagePickerPhotoLibrary()
    }))
    alertController.addAction(UIAlertAction(title: NSLocalizedString("cancel", value: "Cancel", comment: ""), style: .destructive, handler: nil))
    self.present(alertController, animated: true, completion: nil)
  }

  fileprivate func openImagePickerCamera() {
    self.imagePicker = UIImagePickerController()
    self.imagePicker.mediaTypes = [kUTTypeImage as String]
    self.imagePicker.sourceType = .camera
    self.imagePicker.cameraFlashMode = .off
    self.imagePicker.videoQuality = .typeHigh
    self.imagePicker.delegate = self
    self.navigationController?.present(self.imagePicker, animated: true, completion: nil)
  }

  fileprivate func openImagePickerPhotoLibrary() {
    self.imagePicker.mediaTypes = [kUTTypeImage as String]
    self.imagePicker.sourceType = .photoLibrary
    self.imagePicker.delegate = self
    self.navigationController?.present(self.imagePicker, animated: true, completion: nil)
  }
}

extension KYCPersonalInfoViewController: UITableViewDelegate {
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    let id = indexPath.row
    if id < self.viewModel.wallets.count && self.viewModel.wallets.count < 3 {
      let wallet = self.viewModel.wallets[id]
      self.walletLabelTextField.text = wallet.0
      self.walletAddressTextField.text = wallet.1
    }
  }
}

extension KYCPersonalInfoViewController: UITableViewDataSource {
  func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return self.viewModel.wallets.count
  }

  func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
    return UIView()
  }

  func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    return true
  }

  func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
    let deleteAction = UITableViewRowAction(style: .destructive, title: NSLocalizedString("remove", value: "Remove", comment: "")) { (_, _) in
      self.removeAddress(at: indexPath)
    }
    deleteAction.backgroundColor = UIColor.Kyber.fire
    return [deleteAction]
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: kWalletTableViewCellID, for: indexPath)
    cell.textLabel?.isUserInteractionEnabled = false
    let wallets = self.viewModel.wallets
    cell.tintColor = UIColor.Kyber.shamrock
    let wallet = wallets[indexPath.row]
    cell.textLabel?.attributedText = {
      let attributedString = NSMutableAttributedString()
      let nameAttributes: [NSAttributedStringKey: Any] = [
        NSAttributedStringKey.font: UIFont.Kyber.medium(with: 14),
        NSAttributedStringKey.foregroundColor: UIColor.Kyber.mirage,
        NSAttributedStringKey.kern: 0.0,
      ]
      let addressAttributes: [NSAttributedStringKey: Any] = [
        NSAttributedStringKey.font: UIFont.Kyber.medium(with: 14),
        NSAttributedStringKey.foregroundColor: UIColor.Kyber.grayChateau,
        NSAttributedStringKey.kern: 0.0,
      ]
      attributedString.append(NSAttributedString(string: "    \(wallet.0)", attributes: nameAttributes))
      let addressString: String = "      \(wallet.1.prefix(16))...\(wallet.1.suffix(10))"
      attributedString.append(NSAttributedString(string: "\n\(addressString)", attributes: addressAttributes))
      return attributedString
    }()
    cell.textLabel?.numberOfLines = 2
    cell.backgroundColor = {
      return indexPath.row % 2 == 0 ? UIColor(red: 242, green: 243, blue: 246) : UIColor.Kyber.whisper
    }()
    return cell
  }

  fileprivate func removeAddress(at indexPath: IndexPath) {
    KNCrashlyticsUtil.logCustomEvent(withName: "profile_kyc", customAttributes: ["value": "remove_wallet_address"])
    self.viewModel.removeAddress(at: indexPath.row)
    self.walletsTableView.deleteRows(at: [indexPath], with: .automatic)
    self.updateWalletsData()
  }
}

extension KYCPersonalInfoViewController: UIPickerViewDelegate {
  func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
    if self.dataPickerType == .proofOfAddressType {
      self.currentValue = NSLocalizedString(
        self.viewModel.proofOfAddressTypes[row],
        value: self.viewModel.proofOfAddressTypes[row],
        comment: ""
      )
    } else if self.dataPickerType == .sourceFund {
      self.currentValue = NSLocalizedString(
        self.viewModel.sourceFunds[row],
        value: self.viewModel.sourceFunds[row],
        comment: ""
      )
    }
  }
}

extension KYCPersonalInfoViewController: UIPickerViewDataSource {
  func numberOfComponents(in pickerView: UIPickerView) -> Int {
    return 1
  }

  func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
    if self.dataPickerType == .proofOfAddressType {
      return self.viewModel.proofOfAddressTypes.count
    } else if self.dataPickerType == .sourceFund {
      return self.viewModel.sourceFunds.count
    }
    return 0
  }

  func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
    return 32
  }

  func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
    let attributes: [NSAttributedStringKey: Any] = [
      NSAttributedStringKey.foregroundColor: UIColor.Kyber.dark,
      NSAttributedStringKey.font: UIFont.Kyber.medium(with: 14),
    ]
    let string: String = {
      if self.dataPickerType == .proofOfAddressType {
        return self.viewModel.proofOfAddressTypes[row]
      } else if self.dataPickerType == .sourceFund {
        return self.viewModel.sourceFunds[row]
      }
      return ""
    }()
    let localisedString = NSLocalizedString(string, value: string, comment: "")
    return NSAttributedString(
      string: localisedString,
      attributes: attributes
    )
  }
}

extension KYCPersonalInfoViewController: UITextFieldDelegate {
  func textFieldDidBeginEditing(_ textField: UITextField) {
    if textField == self.dateOfBirthTextField {
      self.dateOfBirthDidChange(textField)
    }
  }

  func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
    if textField == self.nationalityTextField {
      self.nationalityButtonPressed(textField)
      return false
    } else if textField == self.countryOfResidenceTextField {
      self.countryOfResidenceButtonPressed(textField)
      return false
    } else if textField == self.optionalDataView.occupationCodeTextField {
      self.kycPersonalOptionalDataViewOccupationPressed(current: self.optionalDataView.getOccupationCode())
      return false
    } else if textField == self.optionalDataView.industryCodeTextField {
      self.kycPersonalOptionalDataViewIndustryPressed(current: self.optionalDataView.getIndustryCode())
      return false
    } else if textField == self.optionalDataView.countryTextField {
      self.kycPersonalOptionalDataViewCountryPressed(current: self.optionalDataView.getTaxCountry())
      return false
    } else if textField == self.proofAddressDocTypeTextField {
      self.proofAddressChooseDocumentTypeButtonPressed(textField)
      return false
    }
    return true
  }
}

extension KYCPersonalInfoViewController: QRCodeReaderDelegate {
  func readerDidCancel(_ reader: QRCodeReaderViewController!) {
    reader.dismiss(animated: true, completion: nil)
  }

  func reader(_ reader: QRCodeReaderViewController!, didScanResult result: String!) {
    reader.dismiss(animated: true) {
      self.walletAddressTextField.text = result
    }
  }
}

extension KYCPersonalInfoViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    picker.dismiss(animated: true, completion: nil)
  }

  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String: Any]) {
    picker.dismiss(animated: true) {
      guard let image = info[UIImagePickerControllerOriginalImage] as? UIImage else {
        return
      }
      self.updateProofAddressDocumentType(with: image, animate: true)
    }
  }

  fileprivate func updateProofAddressDocumentType(with image: UIImage, animate: Bool) {
    if animate { self.displayLoading() }
    DispatchQueue.global().async {
      self.proofAddressImage = image.compress(to: 0.75)
      DispatchQueue.main.async {
        if animate { self.hideLoading() }
        let width = self.proofOfAddressContainerView.frame.width - 48.0
        let height = image.size.height / image.size.width * width
        let newImage = image.resizeImage(to: CGSize(width: width, height: height))
        self.proofOfAddressImageView.image = newImage
        self.topPaddingConstraintProofOfAddressImageView.constant = 24.0
        self.heightConstraintForProofOfAddressContainerView.constant = height + 24.0 * 2.0
        self.view.layoutIfNeeded()
      }
    }
  }
}

extension KYCPersonalInfoViewController: KYCPersonalOptionalDataViewDelegate {
  func kycPersonalOptionalDataViewActionPressed(isCollapsed: Bool) {
    if isCollapsed {
      self.optionalDataView.expand()
      KNCrashlyticsUtil.logCustomEvent(withName: "profile_kyc", customAttributes: ["value": "optional_view_expand"])
    } else {
      self.optionalDataView.collapse()
      KNCrashlyticsUtil.logCustomEvent(withName: "profile_kyc", customAttributes: ["value": "optional_view_collapse"])
    }
    self.heightConstraintForOptionalData.constant = self.optionalDataView.height
    self.view.layoutSubviews()
  }

  func kycPersonalOptionalDataViewOccupationPressed(current: String) {
    self.dataPickerType = .occupationCode
    self.pickerViewController = nil
    self.pickerViewController = KYCSelectOptionViewController(
      title: NSLocalizedString("occupation.code", value: "Occupation Code", comment: ""), dataSources: Array(self.viewModel.occupationCodes.values)
    )
    self.pickerViewController?.delegate = self
    self.parent?.navigationController?.pushViewController(self.pickerViewController!, animated: true)
  }

  func kycPersonalOptionalDataViewIndustryPressed(current: String) {
    self.dataPickerType = .industryCode
    self.pickerViewController = nil
    self.pickerViewController = KYCSelectOptionViewController(
      title: NSLocalizedString("industry.code", value: "Industry Code", comment: ""), dataSources: Array(self.viewModel.industryCodes.values)
    )
    self.pickerViewController?.delegate = self
    self.parent?.navigationController?.pushViewController(self.pickerViewController!, animated: true)
  }

  func kycPersonalOptionalDataViewCountryPressed(current: String) {
    self.dataPickerType = .taxCountry
    self.pickerViewController = nil
    self.pickerViewController = KYCSelectOptionViewController(
      title: NSLocalizedString("tax.residency.country", value: "Tax Residency Country", comment: ""), dataSources: self.viewModel.countries
    )
    self.pickerViewController?.delegate = self
    self.parent?.navigationController?.pushViewController(self.pickerViewController!, animated: true)
  }
}

extension KYCPersonalInfoViewController: KYCSelectOptionViewControllerDelegate {
  func kycSelectOptionViewControllerShouldBack(_ controller: KYCSelectOptionViewController) {
    controller.navigationController?.popViewController(animated: true)
  }

  func kycSelectOptionViewController(_ controller: KYCSelectOptionViewController, didSelect data: String) {
    controller.navigationController?.popViewController(animated: true, completion: {
      switch self.dataPickerType {
      case .nationality: self.nationalityTextField.text = data
      case .countryOfResidence: self.countryOfResidenceTextField.text = data
      case .occupationCode:
        for (key, value) in self.viewModel.occupationCodes where value == data {
          self.optionalDataView.updateOccupationCodeData(key, value: value)
        }
      case .industryCode:
        for (key, value) in self.viewModel.industryCodes where value == data {
          self.optionalDataView.updateIndustryCodeData(key, value: value)
        }
      case .taxCountry:
        self.optionalDataView.updateCountryData(data)
      default: break
      }
    })
  }
}
