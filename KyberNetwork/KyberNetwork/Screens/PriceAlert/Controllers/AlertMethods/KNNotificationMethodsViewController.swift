// Copyright SIX DAY LLC. All rights reserved.

import UIKit

class KNNotificationMethodsViewController: KNBaseViewController {

  @IBOutlet weak var headerContainerView: UIView!
  @IBOutlet weak var navTitleLabel: UILabel!
  @IBOutlet weak var getAlertByTextLabel: UILabel!

  @IBOutlet weak var emailTextLabel: UILabel!
  @IBOutlet weak var emailTextField: UITextField!
  @IBOutlet weak var chooseImageIcon: UIImageView!
  @IBOutlet weak var emailTextFieldSeparator: UIView!

  @IBOutlet weak var telegramTextLabel: UILabel!
  @IBOutlet weak var telegramTextField: UITextField!
  @IBOutlet weak var chooseTeleIcon: UIImageView!
  @IBOutlet weak var teleTextFieldSeparator: UIView!
  @IBOutlet weak var topPaddingEmailConstraint: NSLayoutConstraint!

  fileprivate var emails: [JSONDictionary] = []
  fileprivate var activeEmail: String?
  fileprivate var telegrams: [JSONDictionary] = []
  fileprivate var activeTelegram: String?

  fileprivate var isSelectingEmail: Bool = false
  fileprivate var fakeTextField: UITextField = UITextField(frame: CGRect.zero)
  fileprivate var currentValue: String = ""

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
      action: #selector(self.dataPickerDonePressed(_:))
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
      action: #selector(self.dataPickerCancelPressed(_:))
    )
    cancelBtn.tintColor = UIColor.Kyber.dark
    toolBar.setItems([cancelBtn, flexibleSpaceBtn, doneBtn], animated: false)
    return toolBar
  }()

  override func viewDidLoad() {
    super.viewDidLoad()
    self.headerContainerView.applyGradient(with: UIColor.Kyber.headerColors)
    self.navTitleLabel.text = NSLocalizedString("Alert Method", comment: "")

    self.emailTextLabel.isHidden = true
    self.emailTextField.isHidden = true
    self.emailTextFieldSeparator.isHidden = true
    self.chooseImageIcon.isHidden = true
    self.emailTextField.delegate = self

    let tapEmail = UITapGestureRecognizer(target: self, action: #selector(self.selectEmailPickerPresed(_:)))
    self.chooseImageIcon.addGestureRecognizer(tapEmail)
    self.chooseImageIcon.isUserInteractionEnabled = true

    self.telegramTextLabel.isHidden = true
    self.telegramTextField.isHidden = true
    self.teleTextFieldSeparator.isHidden = true
    self.chooseTeleIcon.isHidden = true
    self.telegramTextField.delegate = self

    let tapTele = UITapGestureRecognizer(target: self, action: #selector(self.selectTelegramPickerPressed(_:)))
    self.chooseTeleIcon.addGestureRecognizer(tapTele)
    self.chooseTeleIcon.isUserInteractionEnabled = true

    self.view.addSubview(self.fakeTextField)
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if IEOUserStorage.shared.user == nil { self.navigationController?.popViewController(animated: true) }
    self.reloadAlertMethods()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    self.headerContainerView.removeSublayer(at: 0)
    self.headerContainerView.applyGradient(with: UIColor.Kyber.headerColors)
  }

  fileprivate func reloadAlertMethods() {
    guard let accessToken = IEOUserStorage.shared.user?.accessToken else { return }
    self.displayLoading()
    KNPriceAlertCoordinator.shared.getAlertMethods(accessToken: accessToken) { [weak self] (resp, error) in
      guard let `self` = self else { return }
      self.hideLoading()
      if error == nil {
        self.emails = resp["emails"] as? [JSONDictionary] ?? []
        self.telegrams = {
          if let tele = resp["telegram"] as? JSONDictionary { return [tele] }
          return []
        }()
        if let email = self.emails.first(where: { return ($0["active"] as? Bool ?? false) }) {
          self.activeEmail = email["id"] as? String
        } else {
          self.activeEmail = "Not enabled".toBeLocalised()
        }
        self.emailTextField.text = self.activeEmail
        if let tele = self.telegrams.first(where: { return ($0["active"] as? Bool ?? false) }) {
          self.activeTelegram = tele["name"] as? String
        } else {
          self.activeTelegram = "Not enabled".toBeLocalised()
        }
        self.telegramTextField.text = self.activeTelegram
        if resp["emails"] == nil || self.emails.isEmpty {
          self.emailTextLabel.isHidden = true
          self.emailTextField.isHidden = true
          self.emailTextFieldSeparator.isHidden = true
          self.chooseImageIcon.isHidden = true
          self.topPaddingEmailConstraint.constant = 0.0
        } else {
          self.emailTextLabel.isHidden = false
          self.emailTextField.isHidden = false
          self.emailTextFieldSeparator.isHidden = false
          self.chooseImageIcon.isHidden = false
          self.topPaddingEmailConstraint.constant = 44.0
        }
        if resp["telegram"] == nil || self.telegrams.isEmpty {
          self.telegramTextLabel.isHidden = true
          self.telegramTextField.isHidden = true
          self.teleTextFieldSeparator.isHidden = true
          self.chooseTeleIcon.isHidden = true
        } else {
          self.telegramTextLabel.isHidden = false
          self.telegramTextField.isHidden = false
          self.teleTextFieldSeparator.isHidden = false
          self.chooseTeleIcon.isHidden = false
        }
        self.telegramTextField.text = self.activeTelegram
      } else {
        self.showAlertCanNotLoadAlertMethods()
      }
    }
  }

  fileprivate func showAlertCanNotLoadAlertMethods() {
    let alert = UIAlertController(
      title: NSLocalizedString("error", value: "Error", comment: ""),
      message: NSLocalizedString("Can not load alert methods. Please try again", comment: ""),
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: NSLocalizedString("reload", value: "Reload", comment: ""), style: .default, handler: { _ in
      self.reloadAlertMethods()
    }))
    alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", value: "Cancel", comment: ""), style: .cancel, handler: { _ in
      self.navigationController?.popViewController(animated: true)
    }))
    self.present(alert, animated: true, completion: nil)
  }

  @objc func selectEmailPickerPresed(_ sender: Any) {
    self.isSelectingEmail = true
    self.fakeTextField.inputView = self.pickerView
    self.fakeTextField.inputAccessoryView = self.toolBar
    self.currentValue = self.emailTextField.text ?? ""
    self.pickerView.reloadAllComponents()

    if let id = self.emails.firstIndex(where: { return ($0["id"] as? String ?? "") == self.currentValue }) {
      self.pickerView.selectRow(id + 1, inComponent: 0, animated: false)
    } else {
      self.currentValue = "Not enabled".toBeLocalised()
      self.pickerView.selectRow(0, inComponent: 0, animated: false)
    }
    self.fakeTextField.becomeFirstResponder()
  }

  @objc func selectTelegramPickerPressed(_ sender: Any) {
    self.isSelectingEmail = false
    self.fakeTextField.inputView = self.pickerView
    self.fakeTextField.inputAccessoryView = self.toolBar
    self.currentValue = self.telegramTextField.text ?? ""
    self.pickerView.reloadAllComponents()

    if let id = self.telegrams.firstIndex(where: { return ($0["name"] as? String ?? "") == self.currentValue }) {
      self.pickerView.selectRow(id + 1, inComponent: 0, animated: false)
    } else {
      self.currentValue = "Not enabled".toBeLocalised()
      self.pickerView.selectRow(0, inComponent: 0, animated: false)
    }
    self.fakeTextField.becomeFirstResponder()
  }

  @objc func dataPickerDonePressed(_ sender: Any) {
    if self.isSelectingEmail {
      self.emailTextField.text = self.currentValue
    } else {
      self.telegramTextField.text = self.currentValue
    }
    self.fakeTextField.resignFirstResponder()
  }

  @objc func dataPickerCancelPressed(_ sender: Any) {
    self.fakeTextField.resignFirstResponder()
  }

  @IBAction func saveButtonPressed(_ sender: Any) {
    guard let accessToken = IEOUserStorage.shared.user?.accessToken else { return }
    self.emails = self.emails.map({
      var json = $0
      if let id = json["id"] as? String, let active = self.emailTextField.text, id == active {
        json["active"] = true
      } else {
        json["active"] = false
      }
      return json
    })
    self.telegrams = self.telegrams.map({
      var json = $0
      if let id = json["name"] as? String, let active = self.telegramTextField.text, id == active {
        json["active"] = true
      } else {
        json["active"] = false
      }
      return json
    })
    self.displayLoading(text: NSLocalizedString("Updating", comment: ""), animated: true)
    KNPriceAlertCoordinator.shared.updateAlertMethods(accessToken: accessToken, email: self.emails, telegram: self.telegrams) { [weak self] (message, error) in
      guard let `self` = self else { return }
      self.hideLoading()
      if error == nil {
        self.showSuccessTopBannerMessage(
          with: NSLocalizedString("success", value: "Success", comment: ""),
          message: NSLocalizedString("Updated alert methods successfully!", comment: ""),
          time: 1.5
        )
      } else {
        self.showSuccessTopBannerMessage(
          with: NSLocalizedString("error", value: "Error", comment: ""),
          message: message.isEmpty ? NSLocalizedString("Can not update alert methods!", value: "Can not update alert methods!", comment: "") : message,
          time: 1.5
        )
      }
    }
  }

  @IBAction func backButtonPressed(_ sender: Any) {
    self.navigationController?.popViewController(animated: true)
  }

  @IBAction func screenEdgePanAction(_ sender: UIScreenEdgePanGestureRecognizer) {
    self.navigationController?.popViewController(animated: true)
  }
}

extension KNNotificationMethodsViewController: UIPickerViewDelegate {
  func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
    let string: String = {
      if row == 0 { return "Not enabled".toBeLocalised() }
      if self.isSelectingEmail {
        return self.emails[row - 1]["id"] as? String ?? ""
      }
      return self.telegrams[row - 1]["name"] as? String ?? ""
    }()
    self.currentValue = string
  }
}

extension KNNotificationMethodsViewController: UIPickerViewDataSource {
  func numberOfComponents(in pickerView: UIPickerView) -> Int {
    return 1
  }

  func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
    return self.isSelectingEmail ? self.emails.count + 1 : self.telegrams.count + 1
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
      if row == 0 { return "Not enabled".toBeLocalised() }
      if self.isSelectingEmail {
        return self.emails[row - 1]["id"] as? String ?? ""
      }
      return self.telegrams[row - 1]["name"] as? String ?? ""
    }()
    let localisedString = NSLocalizedString(string, value: string, comment: "")
    return NSAttributedString(
      string: localisedString,
      attributes: attributes
    )
  }
}

extension KNNotificationMethodsViewController: UITextFieldDelegate {
  func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
    if textField == self.emailTextField {
      self.selectEmailPickerPresed(textField)
      return false
    } else if textField == self.telegramTextField {
      self.selectTelegramPickerPressed(textField)
      return false
    }
    return true
  }
}
