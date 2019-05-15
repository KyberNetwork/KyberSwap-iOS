// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import NotificationCenter

enum KYCSubmitInfoViewEvent {
  case submit
}

protocol KYCSubmitInfoViewControllerDelegate: class {
  func submitInfoViewController(_ controller: KYCSubmitInfoViewController, run event: KYCSubmitInfoViewEvent)
}

struct KYCSubmitInfoViewModel {
  let firstName: String
  let middleName: String
  let lastName: String
  let nativeFullName: String
  let gender: String
  let dob: String
  let nationality: String
  let residenceAddress: String
  let country: String
  let city: String
  let zipCode: String
  let proofAddress: String
  let proofAddressImage: UIImage?
  let sourceFund: String
  let occupationCode: String?
  let industryCode: String?
  let taxResidencyCountry: String?
  let taxIDNumber: String?
  let docType: String
  let docNum: String
  let issueDate: String
  let expiryDate: String
  let docFrontImage: UIImage?
  let docBackImage: UIImage?
  let docHoldingImage: UIImage?
}

class KYCSubmitInfoViewController: KNBaseViewController {

  fileprivate var viewModel: KYCSubmitInfoViewModel
  weak var delegate: KYCSubmitInfoViewControllerDelegate?

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

  @IBOutlet weak var firstNameLabel: UILabel!
  @IBOutlet weak var middleNameLabel: UILabel!
  @IBOutlet weak var lastNameLabel: UILabel!
  @IBOutlet weak var nativeFullNameLabel: UILabel!
  @IBOutlet weak var genderLabel: UILabel!
  @IBOutlet weak var dobLabel: UILabel!
  @IBOutlet weak var nationalityLabel: UILabel!

  @IBOutlet weak var residenceCountryLabel: UILabel!
  @IBOutlet weak var documentTypeLabel: UILabel!
  @IBOutlet weak var documentNumberLabel: UILabel!

  @IBOutlet weak var addressSepartorView: UIView!
  @IBOutlet weak var residentialAddressTextLabel: UILabel!
  @IBOutlet weak var residentialAddressValueLabel: UILabel!

  @IBOutlet weak var cityTextLabel: UILabel!
  @IBOutlet weak var cityValueLabel: UILabel!

  @IBOutlet weak var zipCodeTextLabel: UILabel!
  @IBOutlet weak var zipCodeValueLabel: UILabel!

  @IBOutlet weak var proofOfAddressContainerTextLabel: UILabel!
  @IBOutlet weak var proofOfAddressTextLabel: UILabel!
  @IBOutlet weak var proofOfAddressValueLabel: UILabel!

  @IBOutlet weak var proofOfAddressPhotoTextLabel: UILabel!
  @IBOutlet weak var proofAddressImageContainerView: UIView!
  @IBOutlet weak var proofOfAddressImageView: UIImageView!

  @IBOutlet weak var infoIncomeTextLabel: UILabel!
  @IBOutlet weak var sourceFundTextLabel: UILabel!
  @IBOutlet weak var sourceFundValueLabel: UILabel!

  @IBOutlet weak var occupationCodeTextLabel: UILabel!
  @IBOutlet weak var occupationCodeValueLabel: UILabel!

  @IBOutlet weak var industryCodeTextLabel: UILabel!
  @IBOutlet weak var industryCodeValueLabel: UILabel!

  @IBOutlet weak var taxResidencyCountryTextLabel: UILabel!
  @IBOutlet weak var taxCountryValueLabel: UILabel!

  @IBOutlet weak var taxIDNumberTextLabel: UILabel!
  @IBOutlet weak var taxIDNumberValueLabel: UILabel!

  @IBOutlet weak var issueDateTextLabel: UILabel!
  @IBOutlet weak var issueDateValueLabel: UILabel!

  @IBOutlet weak var expiryDateTextLabel: UILabel!
  @IBOutlet weak var expiryDateValueLabel: UILabel!

  @IBOutlet weak var documentImageView: UIImageView!
  @IBOutlet weak var documentPhotoContainerView: UIView!

  @IBOutlet weak var documentBackPhotoContainerView: UIView!
  @IBOutlet weak var documentBackImageView: UIImageView!

  @IBOutlet weak var holdingDocumentPhotoContainerView: UIView!
  @IBOutlet weak var holdingDocumentImageView: UIImageView!

  @IBOutlet weak var submitButton: UIButton!

  @IBOutlet weak var personalInfoTextLabel: UILabel!
  @IBOutlet weak var firstNameTextLabel: UILabel!
  @IBOutlet weak var middleNameTextLabel: UILabel!
  @IBOutlet weak var lastNameTextLabel: UILabel!
  @IBOutlet weak var nativeFullNameTextLabel: UILabel!
  @IBOutlet weak var genderTextLabel: UILabel!
  @IBOutlet weak var dateOfBirthTextLabel: UILabel!
  @IBOutlet weak var nationalityTextLabel: UILabel!
  @IBOutlet weak var countryResidenceTextLabel: UILabel!
  @IBOutlet weak var idPassportTextLabel: UILabel!
  @IBOutlet weak var documentTypeTextLabel: UILabel!
  @IBOutlet weak var documentNumberTextLabel: UILabel!
  @IBOutlet weak var photoOfDocumentTextLabel: UILabel!
  @IBOutlet weak var photoHoldingDocumentTextLabel: UILabel!
  @IBOutlet weak var topPaddingPhotoOfYourHoldingDocument: NSLayoutConstraint!
  @IBOutlet weak var photoOfYourDocumentBackTextLabel: UILabel!

  init(viewModel: KYCSubmitInfoViewModel) {
    self.viewModel = viewModel
    super.init(nibName: KYCSubmitInfoViewController.className, bundle: nil)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    self.setupUI()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    self.addressSepartorView.dashLine(width: 1.0, color: UIColor.Kyber.dashLine)
    self.submitButton.removeSublayer(at: 0)
    self.submitButton.applyGradient()
  }

  fileprivate func setupUI() {
    self.proofAddressImageContainerView.rounded(radius: 4.0)
    self.documentPhotoContainerView.rounded(radius: 4.0)
    self.documentBackPhotoContainerView.rounded(radius: 4.0)
    self.holdingDocumentPhotoContainerView.rounded(radius: 4.0)

    self.submitButton.rounded(radius: KNAppStyleType.current.buttonRadius(for: self.submitButton.frame.height))

    // Personal info
    self.personalInfoTextLabel.text = NSLocalizedString("personal.info", value: "Personal Info", comment: "")
    self.personalInfoTextLabel.addLetterSpacing()
    self.firstNameTextLabel.text = NSLocalizedString("first.name", value: "First Name", comment: "")
    self.firstNameTextLabel.addLetterSpacing()
    self.middleNameTextLabel.text = NSLocalizedString("middle.name", value: "Middle Name", comment: "")
    self.middleNameTextLabel.addLetterSpacing()
    self.lastNameTextLabel.text = NSLocalizedString("last.name", value: "Last Name", comment: "")
    self.lastNameTextLabel.addLetterSpacing()
    self.nativeFullNameTextLabel.text = NSLocalizedString("full.name.in.native.characters", value: "Full Name in Native Characters", comment: "")
    self.nativeFullNameTextLabel.addLetterSpacing()

    self.genderTextLabel.text = NSLocalizedString("gender", value: "Gender", comment: "")
    self.genderTextLabel.addLetterSpacing()
    self.dateOfBirthTextLabel.text = "\(NSLocalizedString("date.of.birth", value: "Date of birth", comment: "")) (YYYY-MM-DD)"
    self.dateOfBirthTextLabel.addLetterSpacing()
    self.nationalityTextLabel.text = NSLocalizedString("nationality", value: "Nationality", comment: "")
    self.nationalityLabel.addLetterSpacing()

    // Address
    self.addressSepartorView.dashLine(width: 1.0, color: UIColor.Kyber.dashLine)
    self.residentialAddressTextLabel.text = NSLocalizedString("residential.address", value: "Residential Address", comment: "")
    self.residentialAddressTextLabel.addLetterSpacing()
    self.countryResidenceTextLabel.text = NSLocalizedString("country.of.residence", value: "Country of Residence", comment: "")
    self.countryResidenceTextLabel.addLetterSpacing()
    self.cityTextLabel.text = NSLocalizedString("city", value: "City", comment: "")
    self.cityTextLabel.addLetterSpacing()
    self.zipCodeTextLabel.text = NSLocalizedString("postal.zip.code", value: "Postal / Zip Code", comment: "")
    self.zipCodeTextLabel.addLetterSpacing()

    // Proof of Address
    self.proofOfAddressContainerTextLabel.text = NSLocalizedString("proof.of.address", value: "Proof of Address", comment: "").uppercased()
    self.proofOfAddressContainerTextLabel.addLetterSpacing()
    self.proofOfAddressTextLabel.text = NSLocalizedString("address.document.type", value: "Address/Document Type", comment: "")
    self.proofOfAddressTextLabel.addLetterSpacing()
    self.proofOfAddressPhotoTextLabel.text = NSLocalizedString("your.proof.of.address.image", value: "Your Proof of Address Image", comment: "")
    self.proofOfAddressPhotoTextLabel.addLetterSpacing()

    // Info income
    self.infoIncomeTextLabel.text = NSLocalizedString("info.income", value: "Info Income", comment: "").uppercased()
    self.infoIncomeTextLabel.addLetterSpacing()
    self.sourceFundTextLabel.text = NSLocalizedString("source.of.funds", value: "Source of Funds", comment: "")
    self.sourceFundTextLabel.addLetterSpacing()
    self.occupationCodeTextLabel.text = NSLocalizedString("occupation.code", value: "Occupation Code", comment: "")
    self.occupationCodeTextLabel.addLetterSpacing()
    self.industryCodeTextLabel.text = NSLocalizedString("industry.code", value: "Industry Code", comment: "")
    self.industryCodeTextLabel.addLetterSpacing()
    self.taxResidencyCountryTextLabel.text = NSLocalizedString("tax.residency.country", value: "Tax Residency Country", comment: "")
    self.taxResidencyCountryTextLabel.addLetterSpacing()
    self.taxIDNumberTextLabel.text = NSLocalizedString("tax.identification.number", value: "Tax Identification Number", comment: "")
    self.taxIDNumberTextLabel.addLetterSpacing()

    // Identity info
    self.idPassportTextLabel.text = NSLocalizedString("id.passport", value: "ID/ Passport", comment: "")
    self.idPassportTextLabel.addLetterSpacing()
    self.documentTypeTextLabel.text = NSLocalizedString("document.type", value: "Document Type", comment: "")
    self.documentTypeTextLabel.addLetterSpacing()
    self.documentNumberTextLabel.text = NSLocalizedString("document.number", value: "Document Number", comment: "")
    self.documentNumberTextLabel.addLetterSpacing()
    self.issueDateTextLabel.text = NSLocalizedString("issue.date", value: "Issue Date", comment: "")
    self.issueDateTextLabel.addLetterSpacing()
    self.expiryDateTextLabel.text = NSLocalizedString("expiry.date", value: "Expiry Date", comment: "")
    self.expiryDateTextLabel.addLetterSpacing()
    self.photoOfDocumentTextLabel.text = NSLocalizedString("photo.of.your.document.front", value: "Photo of your Document - Front", comment: "")
    self.photoOfDocumentTextLabel.addLetterSpacing()
    self.photoOfYourDocumentBackTextLabel.text = NSLocalizedString("photo.of.your.document.back", value: "Photo of your Document - Back", comment: "")
    self.photoOfYourDocumentBackTextLabel.addLetterSpacing()
    self.photoHoldingDocumentTextLabel.text = NSLocalizedString("photo.of.your.holding.document", value: "Photo of your holding Document", comment: "")
    self.photoHoldingDocumentTextLabel.addLetterSpacing()
    self.submitButton.setTitle(
      NSLocalizedString("submit", value: "Submit", comment: ""),
      for: .normal
    )
    self.submitButton.addTextSpacing()
    self.submitButton.applyGradient()
    self.updateViewModel(self.viewModel)
  }

  func updateViewModel(_ viewModel: KYCSubmitInfoViewModel) {
    self.viewModel = viewModel

    self.firstNameLabel.text = self.viewModel.firstName
    self.middleNameLabel.text = self.viewModel.middleName
    self.lastNameLabel.text = self.viewModel.lastName
    self.nativeFullNameLabel.text = self.viewModel.nativeFullName
    self.genderLabel.text = self.viewModel.gender
    self.dobLabel.text = self.viewModel.dob
    self.nationalityLabel.text = self.viewModel.nationality

    self.residentialAddressValueLabel.text = self.viewModel.residenceAddress
    self.residenceCountryLabel.text = self.viewModel.country
    self.cityValueLabel.text = self.viewModel.city
    self.zipCodeValueLabel.text = self.viewModel.zipCode
    self.proofOfAddressValueLabel.text = NSLocalizedString(self.viewModel.proofAddress, value: self.viewModel.proofAddress, comment: "")
    if let image = self.viewModel.proofAddressImage {
      let width = self.proofAddressImageContainerView.frame.width - 48.0
      let height = image.size.height / image.size.width * width
      let newImage = image.resizeImage(to: CGSize(width: width, height: height))
      self.proofOfAddressImageView.image = newImage
    }
    self.sourceFundValueLabel.text = NSLocalizedString(self.viewModel.sourceFund, value: self.viewModel.sourceFund, comment: "")
    self.occupationCodeValueLabel.text = {
      guard let code = self.viewModel.occupationCode else { return "N/A" }
      if code.isEmpty { return "N/A" }
      let name = self.occupationCodes.first(where: { $0.key == code })?.value ?? ""
      return name.isEmpty ? code : "\(code) - \(name)"
    }()
    self.industryCodeValueLabel.text = {
      guard let code = self.viewModel.industryCode else { return "N/A" }
      if code.isEmpty { return "N/A" }
      let name = self.industryCodes.first(where: { $0.key == code })?.value ?? ""
      return name.isEmpty ? code : "\(code) - \(name)"
    }()
    self.taxCountryValueLabel.text = {
      guard let taxCountry = self.viewModel.taxResidencyCountry else { return "N/A" }
      return taxCountry.isEmpty ? "N/A" : taxCountry
    }()
    self.taxIDNumberValueLabel.text = {
      guard let taxID = self.viewModel.taxIDNumber else { return "N/A" }
      return taxID.isEmpty ? "N/A" : taxID
    }()

    self.documentTypeLabel.text = self.viewModel.docType
    self.documentNumberLabel.text = self.viewModel.docNum
    self.issueDateValueLabel.text = self.viewModel.issueDate.isEmpty ? "N/A" : self.viewModel.issueDate
    self.expiryDateValueLabel.text = self.viewModel.expiryDate.isEmpty ? "N/A" : self.viewModel.expiryDate

    if let image = self.viewModel.docFrontImage {
      let width = self.documentPhotoContainerView.frame.width - 48.0
      let height = image.size.height / image.size.width * width
      let newImage = image.resizeImage(to: CGSize(width: width, height: height))
      self.documentImageView.image = newImage
    }

    if let image = self.viewModel.docBackImage {
      let width = self.documentBackPhotoContainerView.frame.width - 48.0
      let height = image.size.height / image.size.width * width
      let newImage = image.resizeImage(to: CGSize(width: width, height: height))
      self.documentBackImageView.image = newImage
      self.photoOfYourDocumentBackTextLabel.isHidden = false
      self.documentBackPhotoContainerView.isHidden = false
      self.topPaddingPhotoOfYourHoldingDocument.constant = 24.0
    } else {
      self.documentBackImageView.image = nil
      self.photoOfYourDocumentBackTextLabel.isHidden = true
      self.documentBackPhotoContainerView.isHidden = true
      self.topPaddingPhotoOfYourHoldingDocument.constant = -90.0
    }

    if let image = self.viewModel.docHoldingImage {
      let width = self.holdingDocumentPhotoContainerView.frame.width - 48.0
      let height = image.size.height / image.size.width * width
      let newImage = image.resizeImage(to: CGSize(width: width, height: height))
      self.holdingDocumentImageView.image = newImage
    }

    self.view.layoutIfNeeded()
  }

  @IBAction func submitButonPressed(_ sender: Any) {
    self.delegate?.submitInfoViewController(self, run: .submit)
  }

  func updateSubmitInfo(with details: UserKYCDetailsInfo) {
    let base64Prefix = "data:image/jpeg;base64,"
    let docFrontImage: UIImage? = {
      if details.documentPhotoFront.starts(with: base64Prefix),
        let data = Data(base64Encoded: details.documentPhotoFront.substring(from: base64Prefix.count)),
        let image = UIImage(data: data) {
        return image
      }
      return nil
    }()
    let docBackImage: UIImage? = {
      if details.documentPhotoBack.starts(with: base64Prefix),
        let data = Data(base64Encoded: details.documentPhotoBack.substring(from: base64Prefix.count)),
        let image = UIImage(data: data) {
        return image
      }
      return nil
    }()
    let docHoldingImage: UIImage? = {
      if details.documentSelfiePhoto.starts(with: base64Prefix), let data = Data(base64Encoded: details.documentSelfiePhoto.substring(from: base64Prefix.count)), let image = UIImage(data: data) {
        return image
      }
      return nil
    }()
    let proofAddress: UIImage? = {
      if details.photoProofAddress.starts(with: base64Prefix), let data = Data(base64Encoded: details.photoProofAddress.substring(from: base64Prefix.count)), let image = UIImage(data: data) {
        return image
      }
      return nil
    }()
    let docType: String = {
      if details.documentType == "national_id" {
        return NSLocalizedString("identity.card", value: "Identity Card", comment: "")
      }
      if details.documentType == "passport" {
        return NSLocalizedString("passport", value: "Passport", comment: "")
      }
      return details.documentType
    }()
    let viewModel = KYCSubmitInfoViewModel(
      firstName: details.firstName,
      middleName: details.middleName,
      lastName: details.lastName,
      nativeFullName: details.nativeFullName,
      gender: details.gender ? NSLocalizedString("male", value: "Male", comment: "") : NSLocalizedString("female", value: "Female", comment: ""),
      dob: details.dob,
      nationality: details.nationality,
      residenceAddress: details.residentialAddress,
      country: details.country,
      city: details.city,
      zipCode: details.zipCode,
      proofAddress: details.documentProofAddress,
      proofAddressImage: proofAddress,
      sourceFund: details.sourceFund,
      occupationCode: details.occupationCode,
      industryCode: details.industryCode,
      taxResidencyCountry: details.taxResidencyCountry,
      taxIDNumber: details.taxIDNUmber,
      docType: docType,
      docNum: details.documentNumber,
      issueDate: details.documentIssueDate,
      expiryDate: details.documentExpiryDate,
      docFrontImage: docFrontImage,
      docBackImage: docBackImage,
      docHoldingImage: docHoldingImage
    )
    self.updateViewModel(viewModel)
  }
}
