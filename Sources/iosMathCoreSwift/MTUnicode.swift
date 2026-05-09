import Foundation

extension NSString {
  @objc public func unicodeLength() -> UInt {
    return UInt(self.lengthOfBytes(using: String.Encoding.utf32.rawValue) / 4)
  }
}
