import Foundation

@objc public enum MTMathListSubIndexType: UInt32 {
  case none = 0
  case nucleus
  case superscript
  case `subscript`
  case numerator
  case denominator
  case radicand
  case degree
  case inner
}

@objc(MTMathListIndex)
public final class MTMathListIndex: NSObject {

  @objc public private(set) var atomIndex: UInt = 0
  @objc public private(set) var subIndexType: MTMathListSubIndexType = .none
  @objc public private(set) var subIndex: MTMathListIndex?

  private override init() {
    super.init()
  }

  @objc(level0Index:)
  public static func level0Index(_ index: UInt) -> MTMathListIndex {
    let mlIndex = MTMathListIndex()
    mlIndex.atomIndex = index
    return mlIndex
  }

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

  @objc(levelUpWithSubIndex:type:)
  public func levelUp(withSubIndex subIndex: MTMathListIndex?, type: MTMathListSubIndexType)
    -> MTMathListIndex
  {
    if self.subIndexType == .none {
      return MTMathListIndex.indexAtLocation(self.atomIndex, withSubIndex: subIndex, type: type)
    }
    return MTMathListIndex.indexAtLocation(
      self.atomIndex,
      withSubIndex: self.subIndex?.levelUp(withSubIndex: subIndex, type: type),
      type: self.subIndexType
    )
  }

  @objc public func levelDown() -> MTMathListIndex? {
    if self.subIndexType == .none {
      return nil
    }
    if let subIndexDown = self.subIndex?.levelDown() {
      return MTMathListIndex.indexAtLocation(
        self.atomIndex, withSubIndex: subIndexDown, type: self.subIndexType)
    } else {
      return MTMathListIndex.level0Index(self.atomIndex)
    }
  }

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

  @objc(hasSubIndexOfType:)
  public func hasSubIndex(ofType subIndexType: MTMathListSubIndexType) -> Bool {
    if self.subIndexType == subIndexType {
      return true
    }
    return self.subIndex?.hasSubIndex(ofType: subIndexType) ?? false
  }

  @objc public func isAtBeginningOfLine() -> Bool {
    return self.finalIndex == 0
  }

  @objc(isAtSameLevel:)
  public func isAtSameLevel(_ other: MTMathListIndex) -> Bool {
    if self.subIndexType != other.subIndexType {
      return false
    } else if self.subIndexType == .none {
      return true
    } else if self.atomIndex != other.atomIndex {
      return false
    }
    if let s = self.subIndex, let o = other.subIndex {
      return s.isAtSameLevel(o)
    }
    return self.subIndex == nil && other.subIndex == nil
  }

  @objc public var finalIndex: UInt {
    if self.subIndexType == .none {
      return self.atomIndex
    }
    return self.subIndex?.finalIndex ?? self.atomIndex
  }

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

@objc(MTMathListRange)
public final class MTMathListRange: NSObject {

  @objc public let start: MTMathListIndex
  @objc public let length: UInt

  private init(start: MTMathListIndex, length: UInt) {
    self.start = start
    self.length = length
    super.init()
  }

  @objc(makeRange:length:)
  public static func makeRange(_ start: MTMathListIndex, length: UInt) -> MTMathListRange {
    return MTMathListRange(start: start, length: length)
  }

  @objc(makeRange:)
  public static func makeRange(_ start: MTMathListIndex) -> MTMathListRange {
    return makeRange(start, length: 1)
  }

  @objc(makeRangeForIndex:)
  public static func makeRange(forIndex start: UInt) -> MTMathListRange {
    return makeRange(MTMathListIndex.level0Index(start))
  }

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
