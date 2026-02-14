import Foundation

extension String {
    /// Formats an E.164 phone number for display.
    /// e.g. "+14155551234" -> "(415) 555-1234"
    var formattedPhoneNumber: String {
        let digits = self.filter(\.isNumber)

        // US/Canada 10-digit (with or without country code)
        if digits.count == 11 && digits.hasPrefix("1") {
            let area = digits[digits.index(digits.startIndex, offsetBy: 1)..<digits.index(digits.startIndex, offsetBy: 4)]
            let prefix = digits[digits.index(digits.startIndex, offsetBy: 4)..<digits.index(digits.startIndex, offsetBy: 7)]
            let line = digits[digits.index(digits.startIndex, offsetBy: 7)...]
            return "(\(area)) \(prefix)-\(line)"
        }

        if digits.count == 10 {
            let area = digits[digits.startIndex..<digits.index(digits.startIndex, offsetBy: 3)]
            let prefix = digits[digits.index(digits.startIndex, offsetBy: 3)..<digits.index(digits.startIndex, offsetBy: 6)]
            let line = digits[digits.index(digits.startIndex, offsetBy: 6)...]
            return "(\(area)) \(prefix)-\(line)"
        }

        // International or other format: return as-is
        return self
    }

    /// Normalizes a phone number to E.164 format for Twilio.
    /// Assumes US if no country code is present.
    var toE164: String {
        let digits = self.filter(\.isNumber)
        if digits.count == 10 {
            return "+1\(digits)"
        }
        if digits.count == 11 && digits.hasPrefix("1") {
            return "+\(digits)"
        }
        if self.hasPrefix("+") {
            return self
        }
        return "+\(digits)"
    }

    /// Returns initials from a phone number (last 2 digits) for avatar display.
    var phoneInitials: String {
        let digits = self.filter(\.isNumber)
        if digits.count >= 2 {
            return String(digits.suffix(2))
        }
        return digits.isEmpty ? "?" : digits
    }
}
