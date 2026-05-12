import Foundation

extension UInt16 {
  /// Convenience initializer matching `Unicode.Scalar(ascii:)` semantics.
  /// Allows `UInt16(ascii: "A")` to work with `unichar` switch patterns.
  init(ascii scalar: Unicode.Scalar) {
    self = UInt16(scalar.value)
  }
}

extension NSString {
  /// Returns the number of Unicode scalars (i.e. UTF-32 code points) in the string.
  ///
  /// `NSString.length` counts UTF-16 code units, so a non-BMP character such as `\u{1D6A4}`
  /// is reported as length 2. This helper returns the user-visible character count.
  @objc public func unicodeLength() -> UInt {
    // Each unicode char is represented as 4 bytes in utf-32.
    return UInt(self.lengthOfBytes(using: String.Encoding.utf32.rawValue) / 4)
  }
}
