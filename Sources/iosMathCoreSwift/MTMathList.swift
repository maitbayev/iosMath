import CoreGraphics
import Foundation

/// The type of atom in a `MTMathList`.
///
/// The type of the atom determines how it is rendered, and spacing between the atoms.
@objc public enum MTMathAtomType: UInt {
  /// A number or text in ordinary format - Ord in TeX
  case ordinary = 1
  /// A number - Does not exist in TeX
  case number
  /// A variable (i.e. text in italic format) - Does not exist in TeX
  case variable
  /// A large operator such as (sin/cos, integral etc.) - Op in TeX
  case largeOperator
  /// A binary operator - Bin in TeX
  case binaryOperator
  /// A unary operator - Does not exist in TeX.
  case unaryOperator
  /// A relation, e.g. = > < etc. - Rel in TeX
  case relation
  /// Open brackets - Open in TeX
  case open
  /// Close brackets - Close in TeX
  case close
  /// An fraction e.g 1/2 - generalized fraction noad in TeX
  case fraction
  /// A radical operator e.g. sqrt(2)
  case radical
  /// Punctuation such as , - Punct in TeX
  case punctuation
  /// A placeholder square for future input. Does not exist in TeX
  case placeholder
  /// An inner atom, i.e. an embedded math list - Inner in TeX
  case inner
  /// An underlined atom - Under in TeX
  case underline
  /// An overlined atom - Over in TeX
  case overline
  /// An accented atom - Accent in TeX
  case accent

  // Atoms after this point do not support subscripts or superscripts.

  /// A left atom - Left & Right in TeX. We don't need two since we track boundaries separately.
  case boundary = 101

  // Atoms after this are non-math TeX nodes that are still useful in math mode. They do not have
  // the usual structure.

  /// Spacing between math atoms. This denotes both glue and kern for TeX. We do not
  /// distinguish between glue and kern.
  case space = 201
  /// Denotes style changes during rendering.
  case style
  case color
  case colorbox

  // Atoms after this point are not part of TeX and do not have the usual structure.

  /// A table atom. This atom does not exist in TeX. It is equivalent to the TeX command
  /// `\halign` which is handled outside of the TeX math rendering engine. We bring it into our
  /// math typesetting to handle matrices and other tables.
  case table = 1001
}

/// The font style of a character.
///
/// The fontstyle of the atom determines what style the character is rendered in. This only
/// applies to atoms of type `.variable` and `.number`. None of the other atom types change
/// their font style.
@objc public enum MTFontStyle: UInt {
  /// The default latex rendering style. i.e. variables are italic and numbers are roman.
  case `default` = 0
  /// Roman font style i.e. `\mathrm`
  case roman
  /// Bold font style i.e. `\mathbf`
  case bold
  /// Caligraphic font style i.e. `\mathcal`
  case caligraphic
  /// Typewriter (monospace) style i.e. `\mathtt`
  case typewriter
  /// Italic style i.e. `\mathit`
  case italic
  /// Sans-serif font i.e. `\mathss`
  case sansSerif
  /// Fraktur font i.e. `\mathfrak`
  case fraktur
  /// Blackboard font i.e. `\mathbb`
  case blackboard
  /// Bold italic
  case boldItalic
}

/// Controls how a fraction's children are sized, overriding the current rendering context.
@objc public enum MTFracStyleOverride: UInt {
  /// Follows the current context (`\frac`).
  case normal = 0
  /// Forces display-style sizing (`\dfrac`).
  case display
  /// Forces text-style sizing (`\tfrac`).
  case text
}

/// Styling of a line of math.
@objc public enum MTLineStyle: UInt32 {
  /// Display style.
  case display
  /// Text style (inline).
  case text
  /// Script style (for sub/super scripts).
  case script
  /// Script script style (for scripts of scripts).
  case scriptScript
}

/// Alignment for a column of `MTMathTable`.
@objc public enum MTColumnAlignment: Int {
  /// Align left.
  case left
  /// Align center.
  case center
  /// Align right.
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

/// A `MTMathAtom` is the basic unit of a math list. Each atom represents a single character
/// or mathematical operator in a list. However certain atoms can represent more complex
/// structures such as fractions and radicals. Each atom has a type which determines how the
/// atom is rendered and a nucleus. The nucleus contains the character(s) that need to be
/// rendered. However the nucleus may be empty for certain types of atoms. An atom has an
/// optional subscript or superscript which represents the subscript or superscript that is
/// to be rendered.
///
/// Certain types of atoms inherit from `MTMathAtom` and may have additional fields.
@objc(MTMathAtom)
public class MTMathAtom: NSObject, NSCopying {

  /// The type of the atom.
  @objc public var type: MTMathAtomType
  /// The nucleus of the atom.
  @objc public var nucleus: String

  private var _superScript: MTMathList?
  private var _subScript: MTMathList?

  /// An optional superscript.
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

  /// An optional subscript.
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

  /// The font style to be used for the atom.
  @objc public var fontStyle: MTFontStyle = .default

  /// The index range in the `MTMathList` this atom tracks. Used by the finalizing and
  /// preprocessing steps which fuse atoms to track the position of the current atom in the
  /// original list.
  @objc public internal(set) var indexRange: NSRange = NSRange(location: 0, length: 0)

  internal var _fusedAtoms: [MTMathAtom]?
  /// If this atom was formed by fusion of multiple atoms, then this stores the list of atoms
  /// that were fused to create this one. Used in the finalizing and preprocessing steps.
  @objc public var fusedAtoms: [MTMathAtom]? { return _fusedAtoms }

  /// Designated initializer. Subclasses delegate to this from their own initializers; they
  /// override `init(type:value:)` to assert on incompatible types.
  @objc(initWithType:value:)
  public required init(type: MTMathAtomType, value: String) {
    self.type = type
    self.nucleus = value
    super.init()
  }

  /// Factory function to create an atom with a given type and value.
  ///
  /// - Parameters:
  ///   - type: The type of the atom to instantiate.
  ///   - value: The value of the atom's nucleus. The value is ignored for fractions and
  ///     radicals.
  @objc(atomWithType:value:)
  public class func atom(type: MTMathAtomType, value: String) -> MTMathAtom {
    switch type {
    case .fraction:
      return MTFraction()
    case .placeholder:
      // A placeholder is created with a white square.
      return MTMathAtom(type: .placeholder, value: "\u{25A1}")
    case .radical:
      return MTRadical()
    case .largeOperator:
      // Default setting of limits is true.
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

  /// Returns a string representation of the `MTMathAtom`.
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

  /// Returns true if this atom allows scripts (sub or super).
  @objc public func scriptsAllowed() -> Bool {
    return self.type.rawValue < MTMathAtomType.boundary.rawValue
  }

  public override var description: String {
    return "\(typeToText(self.type)): \(self.stringValue)"
  }

  /// Fuse the given atom with this one by combining their nucleii.
  @objc(fuse:)
  public func fuse(_ atom: MTMathAtom) {
    assert(self.subScript == nil, "Cannot fuse into atom with subscript")
    assert(self.superScript == nil, "Cannot fuse into atom with superscript")
    assert(atom.type == self.type, "Atoms must be of same type to fuse")

    // Update the fused atoms list.
    if _fusedAtoms == nil {
      _fusedAtoms = [self.copy() as! MTMathAtom]
    }
    if let other = atom.fusedAtoms {
      _fusedAtoms!.append(contentsOf: other)
    } else {
      _fusedAtoms!.append(atom)
    }

    // Update the nucleus.
    self.nucleus = self.nucleus + atom.nucleus
    // Update the range.
    var r = self.indexRange
    r.length += atom.indexRange.length
    self.indexRange = r

    // Update super/sub scripts.
    self._subScript = atom.subScript
    self._superScript = atom.superScript
  }

  /// Makes a deep copy of the atom.
  public func copy(with zone: NSZone? = nil) -> Any {
    let atom = Swift.type(of: self).init(type: self.type, value: self.nucleus)
    atom._subScript = self.subScript?.copy() as? MTMathList
    atom._superScript = self.superScript?.copy() as? MTMathList
    atom.indexRange = self.indexRange
    atom.fontStyle = self.fontStyle
    return atom
  }

  /// Returns a finalized copy of the atom. Finalizing recursively finalizes any sub/super
  /// scripts.
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

/// An atom of type fraction. This atom has a numerator and denominator.
@objc(MTFraction)
public final class MTFraction: MTMathAtom {

  /// Numerator of the fraction.
  @objc public var numerator: MTMathList = MTMathList()
  /// Denominator of the fraction.
  @objc public var denominator: MTMathList = MTMathList()
  /// If true, the fraction has a rule (i.e. a line) between the numerator and denominator.
  /// The default value is true.
  @objc public private(set) var hasRule: Bool = true
  /// An optional delimiter for a fraction on the left.
  @objc public var leftDelimiter: String?
  /// An optional delimiter for a fraction on the right.
  @objc public var rightDelimiter: String?
  /// Controls how the fraction's numerator/denominator are sized.
  ///
  /// - `.normal`: follows the current rendering context (`\frac`).
  /// - `.display`: forces display-style sizing (`\dfrac`).
  /// - `.text`: forces text-style sizing (`\tfrac`).
  @objc public var fracStyle: MTFracStyleOverride = .normal

  /// Creates an empty fraction with a rule.
  @objc public convenience init() {
    self.init(rule: true)
  }

  /// Creates an empty fraction with the given value of `hasRule`.
  @objc(initWithRule:)
  public init(rule: Bool) {
    // fractions have no nucleus
    super.init(type: .fraction, value: "")
    self.hasRule = rule
  }

  @objc public required init(type: MTMathAtomType, value: String) {
    if type == .fraction {
      // fractions have no nucleus
      super.init(type: .fraction, value: "")
      self.hasRule = true
    } else {
      fatalError("MTFraction must be initialized with init(rule:)")
    }
  }

  public override var stringValue: String {
    var s = self.hasRule ? "\\frac" : "\\atop"
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

/// An atom of type radical (square root).
@objc(MTRadical)
public final class MTRadical: MTMathAtom {

  /// Denotes the term under the square root sign.
  @objc public var radicand: MTMathList?

  /// Denotes the degree of the radical, i.e. the value to the top left of the radical sign.
  /// This can be `nil` if there is no degree.
  @objc public var degree: MTMathList?

  /// Creates an empty radical.
  @objc public init() {
    // radicals have no nucleus
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

/// A `MTMathAtom` of type `.largeOperator`.
@objc(MTLargeOperator)
public final class MTLargeOperator: MTMathAtom {

  /// Indicates whether the limits (if present) should be displayed above and below the
  /// operator in display mode. If `limits` is false then the limits (if present) are
  /// displayed like a regular subscript/superscript.
  @objc public var limits: Bool = false

  /// Designated initializer. Initialize a large operator with the given value and setting
  /// for limits.
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

/// An inner atom. This denotes an atom which contains a math list inside it. An inner atom
/// has optional boundaries. Note: Only one boundary may be present, it is not required to
/// have both.
@objc(MTInner)
public final class MTInner: MTMathAtom {

  /// The inner math list.
  @objc public var innerList: MTMathList?
  private var _leftBoundary: MTMathAtom?
  private var _rightBoundary: MTMathAtom?

  /// The left boundary atom. This must be a node of type `.boundary`.
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

  /// The right boundary atom. This must be a node of type `.boundary`.
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

  /// Creates an empty inner.
  @objc public init() {
    // inner atoms have no nucleus
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

/// An atom with a line over the contained math list.
@objc(MTOverLine)
public final class MTOverLine: MTMathAtom {

  /// The inner math list.
  @objc public var innerList: MTMathList?

  /// Creates an empty over.
  @objc public init() {
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

/// An atom with a line under the contained math list.
@objc(MTUnderLine)
public final class MTUnderLine: MTMathAtom {

  /// The inner math list.
  @objc public var innerList: MTMathList?

  /// Creates an empty under.
  @objc public init() {
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

/// An atom with an accent.
@objc(MTAccent)
public final class MTAccent: MTMathAtom {

  /// The mathlist under the accent.
  @objc public var innerList: MTMathList?

  /// Creates a new `MTAccent` with the given value as the accent.
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

/// An atom representing space.
///
/// - Note: None of the usual fields of the `MTMathAtom` apply even though this class
///   inherits from `MTMathAtom`. i.e. it is meaningless to have a value in the nucleus,
///   subscript or superscript fields.
@objc(MTMathSpace)
public final class MTMathSpace: MTMathAtom {

  /// The amount of space represented by this object in mu units.
  @objc public private(set) var space: CGFloat

  /// Creates a new `MTMathSpace` with the given spacing.
  ///
  /// - Parameter space: The amount of space in mu units.
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

/// An atom representing a style change.
///
/// - Note: None of the usual fields of the `MTMathAtom` apply even though this class
///   inherits from `MTMathAtom`.
@objc(MTMathStyle)
public final class MTMathStyle: MTMathAtom {

  /// The style represented by this object.
  @objc public private(set) var style: MTLineStyle

  /// Creates a new `MTMathStyle` with the given style.
  ///
  /// - Parameter style: The style to be applied to the rest of the list.
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

/// An atom representing a color element.
///
/// - Note: None of the usual fields of the `MTMathAtom` apply even though this class
///   inherits from `MTMathAtom`.
@objc(MTMathColor)
public final class MTMathColor: MTMathAtom {

  /// The color string represented by this object.
  @objc public var colorString: String?
  /// The inner math list.
  @objc public var innerList: MTMathList?

  /// Creates an empty color with a nil environment.
  @objc public init() {
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

/// An atom representing a colorbox element.
///
/// - Note: None of the usual fields of the `MTMathAtom` apply even though this class
///   inherits from `MTMathAtom`.
@objc(MTMathColorbox)
public final class MTMathColorbox: MTMathAtom {

  /// The color string represented by this object.
  @objc public var colorString: String?
  /// The inner math list.
  @objc public var innerList: MTMathList?

  /// Creates an empty colorbox with a nil environment.
  @objc public init() {
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

/// An atom representing a table element. This atom is not like other atoms and is not
/// present in TeX. We use it to represent the `\halign` command in TeX with some
/// simplifications. This is used for matrices, equation alignments and other uses of
/// multiline environments.
///
/// The cells in the table are represented as a two dimensional array of `MTMathList`
/// objects. The `MTMathList`s could be empty to denote a missing value in the cell.
/// Additionally an array of alignments indicates how each column will be aligned.
@objc(MTMathTable)
public final class MTMathTable: MTMathAtom {

  /// The alignment for each column (left, right, center). The default alignment for a
  /// column (if not set) is center.
  @objc public private(set) var alignments: [NSNumber] = []
  /// The cells in the table as a two dimensional array.
  @objc public private(set) var cells: [[MTMathList]] = []
  /// The name of the environment that this table denotes.
  @objc public var environment: String?
  /// Spacing between each column in mu units.
  @objc public var interColumnSpacing: CGFloat = 0
  /// Additional spacing between rows in jots (one jot is 0.3 times font size). If the
  /// additional spacing is 0, then normal row spacing is used.
  @objc public var interRowAdditionalSpacing: CGFloat = 0

  /// Creates a table with a given environment.
  @objc(initWithEnvironment:)
  public init(environment: String?) {
    super.init(type: .table, value: "")
    self.environment = environment
  }

  /// Creates an empty table with a nil environment.
  @objc public convenience init() {
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

  /// Set the value of a given cell. The table is automatically resized to contain this cell.
  @objc(setCell:forRow:column:)
  public func setCell(_ list: MTMathList, forRow row: Int, column: Int) {
    // Add more rows if needed.
    while self.cells.count <= row {
      self.cells.append([])
    }
    // Add more columns if needed.
    while self.cells[row].count < column {
      self.cells[row].append(MTMathList())
    }
    if self.cells[row].count == column {
      self.cells[row].append(list)
    } else {
      self.cells[row][column] = list
    }
  }

  /// Set the alignment of a particular column. The table is automatically resized to
  /// contain this column and any new columns added have their alignment set to center.
  @objc(setAlignment:forColumn:)
  public func setAlignment(_ alignment: MTColumnAlignment, forColumn column: Int) {
    // Add more columns if needed.
    while self.alignments.count < column {
      self.alignments.append(NSNumber(value: MTColumnAlignment.center.rawValue))
    }
    if self.alignments.count == column {
      self.alignments.append(NSNumber(value: alignment.rawValue))
    } else {
      self.alignments[column] = NSNumber(value: alignment.rawValue)
    }
  }

  /// Gets the alignment for a given column. If the alignment is not specified it defaults
  /// to center.
  @objc(getAlignmentForColumn:)
  public func getAlignmentForColumn(_ column: Int) -> MTColumnAlignment {
    if self.alignments.count <= column {
      return .center
    }
    return MTColumnAlignment(rawValue: self.alignments[column].intValue) ?? .center
  }

  /// Number of columns in the table.
  @objc public func numColumns() -> UInt {
    var n: Int = 0
    for row in self.cells {
      n = max(n, row.count)
    }
    return UInt(n)
  }

  /// Number of rows in the table.
  @objc public func numRows() -> UInt {
    return UInt(self.cells.count)
  }
}

/// A representation of a list of math objects.
///
/// This list can be constructed directly or built with the help of the `MTMathListBuilder`.
/// It is not required that the mathematics represented make sense (i.e. this can represent
/// something like "x 2 = +"). This list can be used for display using `MTLine` or can be a
/// list of tokens to be used by a parser after `finalized()` is called.
///
/// - Note: This class is for ADVANCED usage only.
@objc(MTMathList)
public final class MTMathList: NSObject, NSCopying {

  private var _atoms: [MTMathAtom] = []

  /// A list of `MTMathAtom`s.
  @objc public var atoms: [MTMathAtom] { return _atoms }

  /// Initializes an empty math list.
  @objc public override init() {
    super.init()
  }

  /// Create a `MTMathList` given a list of atoms.
  @objc(mathListWithAtomsArray:)
  public static func mathList(withAtomsArray atoms: [MTMathAtom]) -> MTMathList {
    let list = MTMathList()
    list._atoms.append(contentsOf: atoms)
    return list
  }

  private func isAtomAllowed(_ atom: MTMathAtom) -> Bool {
    return atom.type != .boundary
  }

  /// Add an atom to the end of the list.
  ///
  /// - Parameter atom: The atom to be inserted. Cannot be of type `.boundary`.
  /// - Throws: An `NSException` if the atom is of type `.boundary`.
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

  /// Inserts an atom at the given index. If index is already occupied, the objects at index
  /// and beyond are shifted by adding 1 to their indices to make room.
  ///
  /// - Parameters:
  ///   - atom: The atom to be inserted. Cannot be of type `.boundary`.
  ///   - index: The index where the atom is to be inserted. The index should be less than
  ///     or equal to the number of elements in the math list.
  /// - Throws: An `NSException` if the atom is of type `.boundary` or if the index is out
  ///   of range.
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

  /// Append the given list to the end of the current list.
  @objc(append:)
  public func append(_ list: MTMathList) {
    _atoms.append(contentsOf: list.atoms)
  }

  /// Removes the last atom from the math list. If there are no atoms in the list this does
  /// nothing.
  @objc public func removeLastAtom() {
    if !_atoms.isEmpty {
      _atoms.removeLast()
    }
  }

  /// Removes the atom at the given index.
  ///
  /// - Parameter index: The index at which to remove the atom. Must be less than the number
  ///   of atoms in the list.
  @objc(removeAtomAtIndex:)
  public func removeAtom(at index: UInt) {
    if Int(index) >= _atoms.count {
      NSException(name: .rangeException, reason: "Index out of range", userInfo: nil).raise()
    }
    _atoms.remove(at: Int(index))
  }

  /// Removes all the atoms within the given range.
  @objc(removeAtomsInRange:)
  public func removeAtoms(in range: NSRange) {
    if range.location + range.length > _atoms.count {
      NSException(name: .rangeException, reason: "Range out of bounds", userInfo: nil).raise()
    }
    _atoms.removeSubrange(range.location..<(range.location + range.length))
  }

  /// Converts the `MTMathList` to a string form. Note: This is not the LaTeX form.
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

  /// Create a new math list as a final expression and update atoms by combining like atoms
  /// that occur together and converting unary operators to binary operators. This function
  /// does not modify the current `MTMathList`.
  @objc public func finalized() -> MTMathList {
    let finalized = MTMathList()
    let zeroRange = NSRange(location: 0, length: 0)
    var prev: MTMathAtom?
    for atom in self._atoms {
      let new = atom.finalized()
      // Each character is given a separate index.
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
        // Combine numbers together.
        if let p = prev, p.type == .number, p.subScript == nil, p.superScript == nil {
          p.fuse(new)
          // Skip the current node, we are done here.
          continue
        }
      default:
        break
      }
      finalized.addAtom(new)
      prev = new
    }
    if let p = prev, p.type == .binaryOperator {
      // It isn't a binary operator since there is nothing after it. Make it unary.
      p.type = .unaryOperator
    }
    return finalized
  }

  /// Makes a deep copy of the list.
  public func copy(with zone: NSZone? = nil) -> Any {
    let list = MTMathList()
    list._atoms = self._atoms.map { $0.copy() as! MTMathAtom }
    return list
  }
}
