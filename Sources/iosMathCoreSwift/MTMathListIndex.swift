import Foundation

/// The type of the subindex.
///
/// The type of the subindex denotes what branch the path to the atom that this index
/// points to takes.
@objc public enum MTMathListSubIndexType: UInt32 {
  /// The index denotes the whole atom, subIndex is `nil`.
  case none = 0
  /// The position in the subindex is an index into the nucleus.
  case nucleus
  /// The subindex indexes into the superscript.
  case superscript
  /// The subindex indexes into the subscript.
  case `subscript`
  /// The subindex indexes into the numerator (only valid for fractions).
  case numerator
  /// The subindex indexes into the denominator (only valid for fractions).
  case denominator
  /// The subindex indexes into the radicand (only valid for radicals).
  case radicand
  /// The subindex indexes into the degree (only valid for radicals).
  case degree
  /// The subindex indexes into the inner list (only valid for inner).
  case inner
}

/// An index that points to a particular character in the `MTMathList`. The index is a
/// linked list that represents a path from the beginning of the `MTMathList` to reach a
/// particular atom in the list. The next node of the path is represented by the
/// `subIndex`. The path terminates when the `subIndex` is `nil`.
///
/// If there is a `subIndex`, the `subIndexType` denotes what branch the path takes (i.e.
/// superscript, subscript, numerator, denominator etc.).
///
/// e.g in the expression `25^{2/4}` the index of the character 4 is represented as:
/// `(1, superscript) -> (0, denominator) -> (0, none)`. This can be interpreted as start
/// at index 1 (i.e. the 5) go up to the superscript. Then look at index 0 (i.e. 2/4) and
/// go to the denominator. Then look up index 0 (i.e. the 4) which is this final index.
///
/// The level of an index is the number of nodes in the linked list to get to the final
/// path.
@objc(MTMathListIndex)
public final class MTMathListIndex: NSObject {

  /// The index of the associated atom.
  @objc public private(set) var atomIndex: UInt = 0
  /// The type of subindex, e.g. superscript, numerator etc.
  @objc public private(set) var subIndexType: MTMathListSubIndexType = .none
  /// The index into the sublist.
  @objc public private(set) var subIndex: MTMathListIndex?

  private override init() {
    super.init()
  }

  /// Factory function to create a `MTMathListIndex` with no subindexes.
  ///
  /// - Parameter index: The index of the atom that the `MTMathListIndex` points at.
  @objc(level0Index:)
  public static func level0Index(_ index: UInt) -> MTMathListIndex {
    let mlIndex = MTMathListIndex()
    mlIndex.atomIndex = index
    return mlIndex
  }

  /// Factory function to create a `MTMathListIndex` with a given subIndex.
  ///
  /// - Parameters:
  ///   - location: The location at which the subIndex is present.
  ///   - subIndex: The subIndex to be added. Can be `nil`.
  ///   - type: The type of the subIndex.
  @objc(indexAtLocation:withSubIndex:type:)
  public static func indexAtLocation(
    _ location: UInt,
    withSubIndex subIndex: MTMathListIndex?,
    type: MTMathListSubIndexType
  ) -> MTMathListIndex {
    let index = level0Index(location)
    index.subIndexType = type
    index.subIndex = subIndex
    return index
  }

  /// Creates a new index by attaching this index at the end of the current one.
  @objc(levelUpWithSubIndex:type:)
  public func levelUp(withSubIndex subIndex: MTMathListIndex?, type: MTMathListSubIndexType)
    -> MTMathListIndex
  {
    if self.subIndexType == .none {
      return MTMathListIndex.indexAtLocation(self.atomIndex, withSubIndex: subIndex, type: type)
    }
    // We have to recurse.
    return MTMathListIndex.indexAtLocation(
      self.atomIndex,
      withSubIndex: self.subIndex?.levelUp(withSubIndex: subIndex, type: type),
      type: self.subIndexType
    )
  }

  /// Creates a new index by removing the last index item. If this is the last one, then
  /// returns `nil`.
  @objc public func levelDown() -> MTMathListIndex? {
    if self.subIndexType == .none {
      return nil
    }
    // Recurse.
    if let subIndexDown = self.subIndex?.levelDown() {
      return MTMathListIndex.indexAtLocation(
        self.atomIndex, withSubIndex: subIndexDown, type: self.subIndexType)
    } else {
      return MTMathListIndex.level0Index(self.atomIndex)
    }
  }

  /// Returns the previous index if present. Returns `nil` if there is no previous index.
  @objc public func previous() -> MTMathListIndex? {
    if self.subIndexType == .none {
      if self.atomIndex > 0 {
        return MTMathListIndex.level0Index(self.atomIndex - 1)
      }
    } else if let prevSubIndex = self.subIndex?.previous() {
      return MTMathListIndex.indexAtLocation(
        self.atomIndex, withSubIndex: prevSubIndex, type: self.subIndexType)
    }
    return nil
  }

  /// Returns the next index.
  @objc public func next() -> MTMathListIndex {
    switch self.subIndexType {
    case .none:
      return MTMathListIndex.level0Index(self.atomIndex + 1)
    case .nucleus:
      return MTMathListIndex.indexAtLocation(
        self.atomIndex + 1, withSubIndex: self.subIndex, type: self.subIndexType)
    default:
      return MTMathListIndex.indexAtLocation(
        self.atomIndex, withSubIndex: self.subIndex?.next(), type: self.subIndexType)
    }
  }

  /// Returns true if any of the subIndexes of this index have the given type.
  @objc(hasSubIndexOfType:)
  public func hasSubIndex(ofType subIndexType: MTMathListSubIndexType) -> Bool {
    if self.subIndexType == subIndexType {
      return true
    }
    return self.subIndex?.hasSubIndex(ofType: subIndexType) ?? false
  }

  /// Returns true if this index represents the beginning of a line. Note there may be
  /// multiple lines in a `MTMathList`, e.g. a superscript or a fraction numerator. This
  /// returns true if the innermost subindex points to the beginning of a line.
  @objc public func isAtBeginningOfLine() -> Bool {
    return self.finalIndex == 0
  }

  /// Returns whether two indices are at the same level (same path of subindex types and
  /// atom indices).
  @objc(isAtSameLevel:)
  public func isAtSameLevel(_ other: MTMathListIndex) -> Bool {
    if self.subIndexType != other.subIndexType {
      return false
    } else if self.subIndexType == .none {
      // No subindexes, they are at the same level.
      return true
    } else if self.atomIndex != other.atomIndex {
      // The subindexes are used in different atoms.
      return false
    }
    if let s = self.subIndex, let o = other.subIndex {
      return s.isAtSameLevel(o)
    }
    return self.subIndex == nil && other.subIndex == nil
  }

  /// The atom index of the innermost (deepest) subindex.
  @objc public var finalIndex: UInt {
    if self.subIndexType == .none {
      return self.atomIndex
    }
    return self.subIndex?.finalIndex ?? self.atomIndex
  }

  /// Returns the type of the innermost sub index.
  @objc public func finalSubIndexType() -> MTMathListSubIndexType {
    if self.subIndex?.subIndex != nil {
      return self.subIndex!.finalSubIndexType()
    }
    return self.subIndexType
  }

  public override var description: String {
    if let sub = self.subIndex {
      return "[\(self.atomIndex), \(self.subIndexType.rawValue):\(sub)]"
    }
    return "[\(self.atomIndex)]"
  }

  public override func isEqual(_ object: Any?) -> Bool {
    if self === object as AnyObject? { return true }
    guard let other = object as? MTMathListIndex else { return false }
    if self.atomIndex != other.atomIndex || self.subIndexType != other.subIndexType {
      return false
    }
    if let s = self.subIndex {
      return s.isEqual(other.subIndex)
    }
    return other.subIndex == nil
  }

  public override var hash: Int {
    let prime = 31
    var h = Int(self.atomIndex & UInt(Int.max))
    h = h &* prime &+ Int(self.subIndexType.rawValue)
    h = h &* prime &+ (self.subIndex?.hash ?? 0)
    return h
  }
}

/// A range of atoms in a `MTMathList`. This is similar to `NSRange` with a start and
/// length, except that the starting location is defined by a `MTMathListIndex` rather than
/// an ordinary integer.
@objc(MTMathListRange)
public final class MTMathListRange: NSObject {

  /// The starting location of the range. Cannot be `nil`.
  @objc public let start: MTMathListIndex
  /// The size of the range.
  @objc public let length: UInt

  private init(start: MTMathListIndex, length: UInt) {
    self.start = start
    self.length = length
    super.init()
  }

  /// Creates a valid range.
  @objc(makeRange:length:)
  public static func makeRange(_ start: MTMathListIndex, length: UInt) -> MTMathListRange {
    return MTMathListRange(start: start, length: length)
  }

  /// Makes a range of length 1.
  @objc(makeRange:)
  public static func makeRange(_ start: MTMathListIndex) -> MTMathListRange {
    return makeRange(start, length: 1)
  }

  /// Makes a range of length 1 at the level 0 index `start`.
  @objc(makeRangeForIndex:)
  public static func makeRange(forIndex start: UInt) -> MTMathListRange {
    return makeRange(MTMathListIndex.level0Index(start))
  }

  /// Creates a range at level 0 from the given range.
  @objc(makeRangeForRange:)
  public static func makeRange(for range: NSRange) -> MTMathListRange {
    return makeRange(MTMathListIndex.level0Index(UInt(range.location)), length: UInt(range.length))
  }

  public override var description: String {
    return "(\(self.start), \(self.length))"
  }

  @objc public func subIndexRange() -> MTMathListRange? {
    if self.start.subIndexType != .none, let sub = self.start.subIndex {
      return MTMathListRange.makeRange(sub, length: self.length)
    }
    return nil
  }

  @objc public var finalRange: NSRange {
    return NSRange(location: Int(self.start.finalIndex), length: Int(self.length))
  }

  /// Appends the current range to `range` and returns the resulting range. Any elements
  /// between the two are included in the range.
  @objc(unionRange:)
  public func unionRange(_ range: MTMathListRange) -> MTMathListRange? {
    guard self.start.isAtSameLevel(range.start) else {
      assertionFailure("Cannot union ranges at different levels: \(self), \(range)")
      return nil
    }
    let r1 = self.finalRange
    let r2 = range.finalRange
    let unionR = NSUnionRange(r1, r2)
    let start: MTMathListIndex
    if unionR.location == r1.location {
      start = self.start
    } else {
      assert(unionR.location == r2.location)
      start = range.start
    }
    return MTMathListRange.makeRange(start, length: UInt(unionR.length))
  }

  /// Unions all ranges in the given array of ranges.
  ///
  /// - Warning: This implementation faithfully preserves a long-standing bug in the
  ///   original Objective-C: each call to `unionRange(_:)` returns a *new* range rather
  ///   than mutating the receiver, but the loop discards those return values. As a
  ///   result this function effectively returns `ranges[0]` regardless of the rest of
  ///   the input. Do not rely on it to produce a true union.
  @objc(unionRanges:)
  public static func unionRanges(_ ranges: [MTMathListRange]) -> MTMathListRange? {
    assert(ranges.count > 0, "Need to union at least one range")
    let unioned = ranges[0]
    for i in 1..<ranges.count {
      _ = unioned.unionRange(ranges[i])
    }
    return unioned
  }
}
