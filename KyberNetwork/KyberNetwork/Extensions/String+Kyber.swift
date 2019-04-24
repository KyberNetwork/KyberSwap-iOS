// Copyright SIX DAY LLC. All rights reserved.

import BigInt

extension String {

  func removeGroupSeparator() -> String {
    return self.replacingOccurrences(of: EtherNumberFormatter.short.groupingSeparator, with: "")
  }

  func cleanStringToNumber() -> String {
    let decimals: Character = EtherNumberFormatter.short.decimalSeparator.first!
    var valueString = ""
    var hasDecimals: Bool = false
    for char in self {
      if (char >= "0" && char <= "9") || (char == decimals && !hasDecimals) {
        valueString += "\(char)"
        if char == decimals { hasDecimals = true }
      }
    }
    return valueString
  }

  func shortBigInt(decimals: Int) -> BigInt? {
    if let double = Double(self) {
      return BigInt(double * pow(10.0, Double(decimals)))
    }
    return EtherNumberFormatter.short.number(
      from: self,
      decimals: decimals
    )
  }

  func shortBigInt(units: EthereumUnit) -> BigInt? {
    if let double = Double(self) {
      return BigInt(double * Double(units.rawValue))
    }
    return EtherNumberFormatter.short.number(
      from: self,
      units: units
    )
  }

  func fullBigInt(decimals: Int) -> BigInt? {
    if let double = Double(self) {
      return BigInt(double * pow(10.0, Double(decimals)))
    }
    return EtherNumberFormatter.full.number(
      from: self,
      decimals: decimals
    )
  }

  func fullBigInt(units: EthereumUnit) -> BigInt? {
    if let double = Double(self) {
      return BigInt(double * Double(units.rawValue))
    }
    return EtherNumberFormatter.full.number(
      from: self,
      units: units
    )
  }

  func displayRate() -> String {
    return KNRateHelper.displayRate(from: self)
  }

  func isValidEmail() -> Bool {
    let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
    let emailTest = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
    return emailTest.evaluate(with: self)
  }

  func isValidPassword() -> Bool {
    let passRegEx = "^(?=.*[A-Z])(?=.*[a-z])(?=.*\\d)[A-Za-z\\d$@$!%*#?&]{8,}$"
    let passTest = NSPredicate(format: "SELF MATCHES %@", passRegEx)
    return passTest.evaluate(with: self)
  }
}
