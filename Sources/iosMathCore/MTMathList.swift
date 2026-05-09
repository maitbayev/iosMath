import CoreGraphics
import Foundation

@objc public enum MTMathAtomType: UInt {
  case ordinary = 1
  case number
  case variable
  case largeOperator
  case binaryOperator
  case unaryOperator
  case relation
  case open
  case close
  case fraction
  case radical
  case punctuation
  case placeholder
  case inner
  case underline
  case overline
  case accent

  case boundary = 101

  case space = 201
  case style
  case color
  case colorbox

  case table = 1001
}

@objc public enum MTFontStyle: UInt {
  case `default` = 0
  case roman
  case bold
  case caligraphic
  case typewriter
  case italic
  case sansSerif
  case fraktur
  case blackboard
  case boldItalic
}

@objc public enum MTFracStyleOverride: UInt {
  case normal = 0
  case display
  case text
}

@objc public enum MTLineStyle: UInt32 {
  case display
  case text
  case script
  case scriptScript
}

@objc public enum MTColumnAlignment: Int {
  case left
  case center
  case right
}

private func typeToText(_ type: MTMathAtomType) -> String {
  switch type {
  case .ordinary: return "Ordinary"
  case .number: return "Number"
  case .variable: return "Variable"
  case .binaryOperator: return "Binary Operator"
  case .unaryOperator: return "Unary Operator"
  case .relation: return "Relation"
  case .open: return "Open"
  case .close: return "Close"
  case .fraction: return "Fraction"
  case .radical: return "Radical"
  case .punctuation: return "Punctuation"
  case .placeholder: return "Placeholder"
  case .largeOperator: return "Large Operator"
  case .inner: return "Inner"
  case .underline: return "Underline"
  case .overline: return "Overline"
  case .accent: return "Accent"
  case .boundary: return "Boundary"
  case .space: return "Space"
  case .style: return "Style"
  case .color: return "Color"
  case .colorbox: return "Colorbox"
  case .table: return "Table"
  }
}

private func isNotBinaryOperator(_ prev: MTMathAtom?) -> Bool {
  guard let prev = prev else { return true }
  switch prev.type {
  case .binaryOperator, .relation, .open, .punctuation, .largeOperator:
    return true
  default:
    return false
  }
}

@objc(MTMathAtom)
public class MTMathAtom: NSObject, NSCopying {

  @objc public var type: MTMathAtomType
  @objc public var nucleus: String

  private var _superScript: MTMathList?
  private var _subScript: MTMathList?

  @objc public var superScript: MTMathList? {
    get { return _superScript }
    set {
      if newValue != nil && !self.scriptsAllowed() {
        let reason = "Superscripts not allowed for atom of type \(typeToText(self.type))"
        NSException(name: NSExceptionName("Error"), reason: reason, userInfo: nil).raise()
      }
      _superScript = newValue
    }
  }

  @objc public var subScript: MTMathList? {
    get { return _subScript }
    set {
      if newValue != nil && !self.scriptsAllowed() {
        let reason = "Subscripts not allowed for atom of type \(typeToText(self.type))"
        NSException(name: NSExceptionName("Error"), reason: reason, userInfo: nil).raise()
      }
      _subScript = newValue
    }
  }

  @objc public var fontStyle: MTFontStyle = .default

  @objc public internal(set) var indexRange: NSRange = NSRange(location: 0, length: 0)

  internal var _fusedAtoms: [MTMathAtom]?
  @objc public var fusedAtoms: [MTMathAtom]? { return _fusedAtoms }

  @objc(initWithType:value:)
  public required init(type: MTMathAtomType, value: String) {
    self.type = type
    self.nucleus = value
    super.init()
  }

  @objc(atomWithType:value:)
  public class func atom(type: MTMathAtomType, value: String) -> MTMathAtom {
    switch type {
    case .fraction:
      return MTFraction()
    case .placeholder:
      return MTMathAtom(type: .placeholder, value: "\u{25A1}")
    case .radical:
      return MTRadical()
    case .largeOperator:
      return MTLargeOperator(value: value, limits: true)
    case .inner:
      return MTInner()
    case .overline:
      return MTOverLine()
    case .underline:
      return MTUnderLine()
    case .accent:
      return MTAccent(value: value)
    case .space:
      return MTMathSpace(space: 0)
    case .color:
      return MTMathColor()
    case .colorbox:
      return MTMathColorbox()
    default:
      return MTMathAtom(type: type, value: value)
    }
  }

  @objc public var stringValue: String {
    var s = self.nucleus
    if let sup = self.superScript {
      s += "^{\(sup.stringValue)}"
    }
    if let sub = self.subScript {
      s += "_{\(sub.stringValue)}"
    }
    return s
  }

  @objc public func scriptsAllowed() -> Bool {
    return self.type.rawValue < MTMathAtomType.boundary.rawValue
  }

  public override var description: String {
    return "\(typeToText(self.type)): \(self.stringValue)"
  }

  @objc(fuse:)
  public func fuse(_ atom: MTMathAtom) {
    assert(self.subScript == nil, "Cannot fuse into atom with subscript")
    assert(self.superScript == nil, "Cannot fuse into atom with superscript")
    assert(atom.type == self.type, "Atoms must be of same type to fuse")

    if _fusedAtoms == nil {
      _fusedAtoms = [self.copy() as! MTMathAtom]
    }
    if let other = atom.fusedAtoms {
      _fusedAtoms!.append(contentsOf: other)
    } else {
      _fusedAtoms!.append(atom)
    }

    self.nucleus = self.nucleus + atom.nucleus
    var r = self.indexRange
    r.length += atom.indexRange.length
    self.indexRange = r

    self._subScript = atom.subScript
    self._superScript = atom.superScript
  }

  public func copy(with zone: NSZone? = nil) -> Any {
    let atom = type(of: self).init(type: self.type, value: self.nucleus)
    atom.type = self.type
    atom.nucleus = self.nucleus
    atom._subScript = self.subScript?.copy() as? MTMathList
    atom._superScript = self.superScript?.copy() as? MTMathList
    atom.indexRange = self.indexRange
    atom.fontStyle = self.fontStyle
    return atom
  }

  @objc public func finalized() -> MTMathAtom {
    let new = self.copy() as! MTMathAtom
    if let sup = new.superScript {
      new._superScript = sup.finalized()
    }
    if let sub = new.subScript {
      new._subScript = sub.finalized()
    }
    return new
  }
}

@objc(MTFraction)
public final class MTFraction: MTMathAtom {

  @objc public var numerator: MTMathList = MTMathList()
  @objc public var denominator: MTMathList = MTMathList()
  @objc public private(set) var hasRule: Bool = true
  @objc public var leftDelimiter: String?
  @objc public var rightDelimiter: String?
  @objc public var fracStyle: MTFracStyleOverride = .normal

  @objc public override convenience init() {
    self.init(rule: true)
  }

  @objc(initWithRule:)
  public init(rule: Bool) {
    super.init(type: .fraction, value: "")
    self.hasRule = rule
  }

  @objc public required init(type: MTMathAtomType, value: String) {
    if type == .fraction {
      super.init(type: .fraction, value: "")
      self.hasRule = true
    } else {
      fatalError("MTFraction must be initialized with init(rule:)")
    }
  }

  public override var stringValue: String {
    var s = self.hasRule ? "\\atop" : "\\frac"
    if self.leftDelimiter != nil || self.rightDelimiter != nil {
      s += "[\(self.leftDelimiter ?? "")][\(self.rightDelimiter ?? "")]"
    }
    s += "{\(self.numerator.stringValue)}{\(self.denominator.stringValue)}"
    if let sup = self.superScript {
      s += "^{\(sup.stringValue)}"
    }
    if let sub = self.subScript {
      s += "_{\(sub.stringValue)}"
    }
    return s
  }

  public override func copy(with zone: NSZone? = nil) -> Any {
    let f = super.copy(with: zone) as! MTFraction
    f.numerator = self.numerator.copy() as! MTMathList
    f.denominator = self.denominator.copy() as! MTMathList
    f.hasRule = self.hasRule
    f.leftDelimiter = self.leftDelimiter
    f.rightDelimiter = self.rightDelimiter
    f.fracStyle = self.fracStyle
    return f
  }

  public override func finalized() -> MTMathAtom {
    let f = super.finalized() as! MTFraction
    f.numerator = f.numerator.finalized()
    f.denominator = f.denominator.finalized()
    return f
  }
}

@objc(MTRadical)
public final class MTRadical: MTMathAtom {

  @objc public var radicand: MTMathList?
  @objc public var degree: MTMathList?

  @objc public override init() {
    super.init(type: .radical, value: "")
  }

  @objc public required init(type: MTMathAtomType, value: String) {
    if type == .radical {
      super.init(type: .radical, value: "")
    } else {
      fatalError("MTRadical must be initialized with init()")
    }
  }

  public override var stringValue: String {
    var s = "\\sqrt"
    if let d = self.degree {
      s += "[\(d.stringValue)]"
    }
    s += "{\(self.radicand?.stringValue ?? "")}"
    if let sup = self.superScript {
      s += "^{\(sup.stringValue)}"
    }
    if let sub = self.subScript {
      s += "_{\(sub.stringValue)}"
    }
    return s
  }

  public override func copy(with zone: NSZone? = nil) -> Any {
    let r = super.copy(with: zone) as! MTRadical
    r.radicand = self.radicand?.copy() as? MTMathList
    r.degree = self.degree?.copy() as? MTMathList
    return r
  }

  public override func finalized() -> MTMathAtom {
    let r = super.finalized() as! MTRadical
    r.radicand = r.radicand?.finalized()
    r.degree = r.degree?.finalized()
    return r
  }
}

@objc(MTLargeOperator)
public final class MTLargeOperator: MTMathAtom {

  @objc public var limits: Bool = false

  @objc(initWithValue:limits:)
  public init(value: String, limits: Bool) {
    super.init(type: .largeOperator, value: value)
    self.limits = limits
  }

  @objc public required init(type: MTMathAtomType, value: String) {
    if type == .largeOperator {
      super.init(type: .largeOperator, value: value)
      self.limits = false
    } else {
      fatalError("MTLargeOperator must be initialized with init(value:limits:)")
    }
  }

  public override func copy(with zone: NSZone? = nil) -> Any {
    let o = super.copy(with: zone) as! MTLargeOperator
    o.limits = self.limits
    return o
  }
}

@objc(MTInner)
public final class MTInner: MTMathAtom {

  @objc public var innerList: MTMathList?
  private var _leftBoundary: MTMathAtom?
  private var _rightBoundary: MTMathAtom?

  @objc public var leftBoundary: MTMathAtom? {
    get { return _leftBoundary }
    set {
      if let v = newValue, v.type != .boundary {
        NSException(
          name: NSExceptionName("Error"),
          reason: "Left boundary must be of type boundary", userInfo: nil
        ).raise()
      }
      _leftBoundary = newValue
    }
  }

  @objc public var rightBoundary: MTMathAtom? {
    get { return _rightBoundary }
    set {
      if let v = newValue, v.type != .boundary {
        NSException(
          name: NSExceptionName("Error"),
          reason: "Right boundary must be of type boundary", userInfo: nil
        ).raise()
      }
      _rightBoundary = newValue
    }
  }

  @objc public override init() {
    super.init(type: .inner, value: "")
  }

  @objc public required init(type: MTMathAtomType, value: String) {
    if type == .inner {
      super.init(type: .inner, value: "")
    } else {
      fatalError("MTInner must be initialized with init()")
    }
  }

  public override var stringValue: String {
    var s = "\\inner"
    if let l = self.leftBoundary {
      s += "[\(l.nucleus)]"
    }
    s += "{\(self.innerList?.stringValue ?? "")}"
    if let r = self.rightBoundary {
      s += "[\(r.nucleus)]"
    }
    if let sup = self.superScript {
      s += "^{\(sup.stringValue)}"
    }
    if let sub = self.subScript {
      s += "_{\(sub.stringValue)}"
    }
    return s
  }

  public override func copy(with zone: NSZone? = nil) -> Any {
    let i = super.copy(with: zone) as! MTInner
    i.innerList = self.innerList?.copy() as? MTMathList
    i._leftBoundary = self.leftBoundary?.copy() as? MTMathAtom
    i._rightBoundary = self.rightBoundary?.copy() as? MTMathAtom
    return i
  }

  public override func finalized() -> MTMathAtom {
    let i = super.finalized() as! MTInner
    i.innerList = i.innerList?.finalized()
    return i
  }
}

@objc(MTOverLine)
public final class MTOverLine: MTMathAtom {

  @objc public var innerList: MTMathList?

  @objc public override init() {
    super.init(type: .overline, value: "")
  }

  @objc public required init(type: MTMathAtomType, value: String) {
    if type == .overline {
      super.init(type: .overline, value: "")
    } else {
      fatalError("MTOverLine must be initialized with init()")
    }
  }

  public override func copy(with zone: NSZone? = nil) -> Any {
    let o = super.copy(with: zone) as! MTOverLine
    o.innerList = self.innerList?.copy() as? MTMathList
    return o
  }

  public override func finalized() -> MTMathAtom {
    let o = super.finalized() as! MTOverLine
    o.innerList = o.innerList?.finalized()
    return o
  }
}

@objc(MTUnderLine)
public final class MTUnderLine: MTMathAtom {

  @objc public var innerList: MTMathList?

  @objc public override init() {
    super.init(type: .underline, value: "")
  }

  @objc public required init(type: MTMathAtomType, value: String) {
    if type == .underline {
      super.init(type: .underline, value: "")
    } else {
      fatalError("MTUnderLine must be initialized with init()")
    }
  }

  public override func copy(with zone: NSZone? = nil) -> Any {
    let u = super.copy(with: zone) as! MTUnderLine
    u.innerList = self.innerList?.copy() as? MTMathList
    return u
  }

  public override func finalized() -> MTMathAtom {
    let u = super.finalized() as! MTUnderLine
    u.innerList = u.innerList?.finalized()
    return u
  }
}

@objc(MTAccent)
public final class MTAccent: MTMathAtom {

  @objc public var innerList: MTMathList?

  @objc(initWithValue:)
  public init(value: String) {
    super.init(type: .accent, value: value)
  }

  @objc public required init(type: MTMathAtomType, value: String) {
    if type == .accent {
      super.init(type: .accent, value: value)
    } else {
      fatalError("MTAccent must be initialized with init(value:)")
    }
  }

  public override func copy(with zone: NSZone? = nil) -> Any {
    let a = super.copy(with: zone) as! MTAccent
    a.innerList = self.innerList?.copy() as? MTMathList
    return a
  }

  public override func finalized() -> MTMathAtom {
    let a = super.finalized() as! MTAccent
    a.innerList = a.innerList?.finalized()
    return a
  }
}

@objc(MTMathSpace)
public final class MTMathSpace: MTMathAtom {

  @objc public private(set) var space: CGFloat

  @objc(initWithSpace:)
  public init(space: CGFloat) {
    self.space = space
    super.init(type: .space, value: "")
  }

  @objc public required init(type: MTMathAtomType, value: String) {
    if type == .space {
      self.space = 0
      super.init(type: .space, value: "")
    } else {
      fatalError("MTMathSpace must be initialized with init(space:)")
    }
  }

  public override func copy(with zone: NSZone? = nil) -> Any {
    let s = super.copy(with: zone) as! MTMathSpace
    s.space = self.space
    return s
  }
}

@objc(MTMathStyle)
public final class MTMathStyle: MTMathAtom {

  @objc public private(set) var style: MTLineStyle

  @objc(initWithStyle:)
  public init(style: MTLineStyle) {
    self.style = style
    super.init(type: .style, value: "")
  }

  @objc public required init(type: MTMathAtomType, value: String) {
    if type == .style {
      self.style = .display
      super.init(type: .style, value: "")
    } else {
      fatalError("MTMathStyle must be initialized with init(style:)")
    }
  }

  public override func copy(with zone: NSZone? = nil) -> Any {
    let s = super.copy(with: zone) as! MTMathStyle
    s.style = self.style
    return s
  }
}

@objc(MTMathColor)
public final class MTMathColor: MTMathAtom {

  @objc public var colorString: String?
  @objc public var innerList: MTMathList?

  @objc public override init() {
    super.init(type: .color, value: "")
  }

  @objc public required init(type: MTMathAtomType, value: String) {
    if type == .color {
      super.init(type: .color, value: "")
    } else {
      fatalError("MTMathColor must be initialized with init()")
    }
  }

  public override var stringValue: String {
    return "\\color{\(self.colorString ?? "")}{\(self.innerList?.stringValue ?? "")}"
  }

  public override func copy(with zone: NSZone? = nil) -> Any {
    let c = super.copy(with: zone) as! MTMathColor
    c.innerList = self.innerList?.copy() as? MTMathList
    c.colorString = self.colorString
    return c
  }

  public override func finalized() -> MTMathAtom {
    let c = super.finalized() as! MTMathColor
    c.innerList = c.innerList?.finalized()
    return c
  }
}

@objc(MTMathColorbox)
public final class MTMathColorbox: MTMathAtom {

  @objc public var colorString: String?
  @objc public var innerList: MTMathList?

  @objc public override init() {
    super.init(type: .colorbox, value: "")
  }

  @objc public required init(type: MTMathAtomType, value: String) {
    if type == .colorbox {
      super.init(type: .colorbox, value: "")
    } else {
      fatalError("MTMathColorbox must be initialized with init()")
    }
  }

  public override var stringValue: String {
    return "\\colorbox{\(self.colorString ?? "")}{\(self.innerList?.stringValue ?? "")}"
  }

  public override func copy(with zone: NSZone? = nil) -> Any {
    let c = super.copy(with: zone) as! MTMathColorbox
    c.innerList = self.innerList?.copy() as? MTMathList
    c.colorString = self.colorString
    return c
  }

  public override func finalized() -> MTMathAtom {
    let c = super.finalized() as! MTMathColorbox
    c.innerList = c.innerList?.finalized()
    return c
  }
}

@objc(MTMathTable)
public final class MTMathTable: MTMathAtom {

  @objc public private(set) var alignments: [NSNumber] = []
  @objc public private(set) var cells: [[MTMathList]] = []
  @objc public var environment: String?
  @objc public var interColumnSpacing: CGFloat = 0
  @objc public var interRowAdditionalSpacing: CGFloat = 0

  @objc(initWithEnvironment:)
  public init(environment: String?) {
    super.init(type: .table, value: "")
    self.environment = environment
  }

  @objc public override convenience init() {
    self.init(environment: nil)
  }

  @objc public required init(type: MTMathAtomType, value: String) {
    if type == .table {
      super.init(type: .table, value: "")
    } else {
      fatalError("MTMathTable must be initialized with init() or init(environment:)")
    }
  }

  public override func copy(with zone: NSZone? = nil) -> Any {
    let t = super.copy(with: zone) as! MTMathTable
    t.interRowAdditionalSpacing = self.interRowAdditionalSpacing
    t.interColumnSpacing = self.interColumnSpacing
    t.environment = self.environment
    t.alignments = self.alignments
    t.cells = self.cells.map { row in row.map { $0.copy() as! MTMathList } }
    return t
  }

  public override func finalized() -> MTMathAtom {
    let t = super.finalized() as! MTMathTable
    t.cells = t.cells.map { row in row.map { $0.finalized() } }
    return t
  }

  @objc(setCell:forRow:column:)
  public func setCell(_ list: MTMathList, forRow row: Int, column: Int) {
    while self.cells.count <= row {
      self.cells.append([])
    }
    while self.cells[row].count < column {
      self.cells[row].append(MTMathList())
    }
    if self.cells[row].count == column {
      self.cells[row].append(list)
    } else {
      self.cells[row][column] = list
    }
  }

  @objc(setAlignment:forColumn:)
  public func setAlignment(_ alignment: MTColumnAlignment, forColumn column: Int) {
    while self.alignments.count < column {
      self.alignments.append(NSNumber(value: MTColumnAlignment.center.rawValue))
    }
    if self.alignments.count == column {
      self.alignments.append(NSNumber(value: alignment.rawValue))
    } else {
      self.alignments[column] = NSNumber(value: alignment.rawValue)
    }
  }

  @objc(getAlignmentForColumn:)
  public func getAlignmentForColumn(_ column: Int) -> MTColumnAlignment {
    if self.alignments.count <= column {
      return .center
    }
    return MTColumnAlignment(rawValue: self.alignments[column].intValue) ?? .center
  }

  @objc public func numColumns() -> UInt {
    var n: Int = 0
    for row in self.cells {
      n = max(n, row.count)
    }
    return UInt(n)
  }

  @objc public func numRows() -> UInt {
    return UInt(self.cells.count)
  }
}

@objc(MTMathList)
public final class MTMathList: NSObject, NSCopying {

  private var _atoms: [MTMathAtom] = []

  @objc public var atoms: [MTMathAtom] { return _atoms }

  @objc public override init() {
    super.init()
  }

  @objc(mathListWithAtomsArray:)
  public static func mathList(withAtomsArray atoms: [MTMathAtom]) -> MTMathList {
    let list = MTMathList()
    list._atoms.append(contentsOf: atoms)
    return list
  }

  private func isAtomAllowed(_ atom: MTMathAtom) -> Bool {
    return atom.type != .boundary
  }

  @objc(addAtom:)
  public func addAtom(_ atom: MTMathAtom) {
    if !self.isAtomAllowed(atom) {
      NSException(
        name: NSExceptionName("Error"),
        reason: "Cannot add atom of type \(typeToText(atom.type)) in a mathlist", userInfo: nil
      ).raise()
    }
    _atoms.append(atom)
  }

  @objc(insertAtom:atIndex:)
  public func insertAtom(_ atom: MTMathAtom, at index: UInt) {
    if !self.isAtomAllowed(atom) {
      NSException(
        name: NSExceptionName("Error"),
        reason: "Cannot add atom of type \(typeToText(atom.type)) in a mathlist", userInfo: nil
      ).raise()
    }
    if Int(index) > _atoms.count {
      NSException(name: .rangeException, reason: "Index out of range", userInfo: nil).raise()
    }
    _atoms.insert(atom, at: Int(index))
  }

  @objc(append:)
  public func append(_ list: MTMathList) {
    _atoms.append(contentsOf: list.atoms)
  }

  @objc public func removeLastAtom() {
    if !_atoms.isEmpty {
      _atoms.removeLast()
    }
  }

  @objc(removeAtomAtIndex:)
  public func removeAtom(at index: UInt) {
    if Int(index) >= _atoms.count {
      NSException(name: .rangeException, reason: "Index out of range", userInfo: nil).raise()
    }
    _atoms.remove(at: Int(index))
  }

  @objc(removeAtomsInRange:)
  public func removeAtoms(in range: NSRange) {
    if range.location + range.length > _atoms.count {
      NSException(name: .rangeException, reason: "Range out of bounds", userInfo: nil).raise()
    }
    _atoms.removeSubrange(range.location..<(range.location + range.length))
  }

  @objc public var stringValue: String {
    var s = ""
    for a in self._atoms {
      s += a.stringValue
    }
    return s
  }

  public override var description: String {
    return self._atoms.description
  }

  @objc public func finalized() -> MTMathList {
    let finalized = MTMathList()
    let zeroRange = NSRange(location: 0, length: 0)
    var prev: MTMathAtom?
    for atom in self._atoms {
      let new = atom.finalized()
      if NSEqualRanges(zeroRange, atom.indexRange) {
        let idx: Int
        if let p = prev {
          idx = p.indexRange.location + p.indexRange.length
        } else {
          idx = 0
        }
        new.indexRange = NSRange(location: idx, length: 1)
      }
      switch new.type {
      case .binaryOperator:
        if isNotBinaryOperator(prev) {
          new.type = .unaryOperator
        }
      case .relation, .punctuation, .close:
        if let p = prev, p.type == .binaryOperator {
          p.type = .unaryOperator
        }
      case .number:
        if let p = prev, p.type == .number, p.subScript == nil, p.superScript == nil {
          p.fuse(new)
          continue
        }
      default:
        break
      }
      finalized.addAtom(new)
      prev = new
    }
    if let p = prev, p.type == .binaryOperator {
      p.type = .unaryOperator
    }
    return finalized
  }

  public func copy(with zone: NSZone? = nil) -> Any {
    let list = MTMathList()
    list._atoms = self._atoms.map { $0.copy() as! MTMathAtom }
    return list
  }
}
