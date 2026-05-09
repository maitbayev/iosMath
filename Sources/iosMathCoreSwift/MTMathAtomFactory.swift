import Foundation

public let MTSymbolMultiplication = "\u{00D7}"
public let MTSymbolDivision = "\u{00F7}"
public let MTSymbolFractionSlash = "\u{2044}"
public let MTSymbolWhiteSquare = "\u{25A1}"
public let MTSymbolBlackSquare = "\u{25A0}"
public let MTSymbolLessEqual = "\u{2264}"
public let MTSymbolGreaterEqual = "\u{2265}"
public let MTSymbolNotEqual = "\u{2260}"
public let MTSymbolSquareRoot = "\u{221A}"
public let MTSymbolCubeRoot = "\u{221B}"
public let MTSymbolInfinity = "\u{221E}"
public let MTSymbolAngle = "\u{2220}"
public let MTSymbolDegree = "\u{00B0}"

/// A factory to create commonly used `MTMathAtom`s.
@objc(MTMathAtomFactory)
public final class MTMathAtomFactory: NSObject {

  // MARK: - Static state

  private static var _supportedLatexSymbols: [String: MTMathAtom] = makeSupportedLatexSymbols()
  private static var _textToLatexSymbolNames: [String: String] = makeTextToLatexSymbolNames(
    from: _supportedLatexSymbols)

  private static let _aliases: [String: String] = [
    "lnot": "neg",
    "land": "wedge",
    "lor": "vee",
    "ne": "neq",
    "le": "leq",
    "ge": "geq",
    "lbrace": "{",
    "rbrace": "}",
    "Vert": "|",
    "gets": "leftarrow",
    "to": "rightarrow",
    "iff": "Longleftrightarrow",
    "AA": "angstrom",
  ]

  private static let _accents: [String: String] = [
    "grave": "\u{0300}",
    "acute": "\u{0301}",
    "hat": "\u{0302}",
    "tilde": "\u{0303}",
    "bar": "\u{0304}",
    "breve": "\u{0306}",
    "dot": "\u{0307}",
    "ddot": "\u{0308}",
    "check": "\u{030C}",
    "vec": "\u{20D7}",
    "widehat": "\u{0302}",
    "widetilde": "\u{0303}",
  ]

  private static let _accentValueToName: [String: String] = computeReverseMap(_accents)

  private static let _delimiters: [String: String] = [
    ".": "",
    "(": "(",
    ")": ")",
    "[": "[",
    "]": "]",
    "<": "\u{2329}",
    ">": "\u{232A}",
    "/": "/",
    "\\": "\\",
    "|": "|",
    "lgroup": "\u{27EE}",
    "rgroup": "\u{27EF}",
    "||": "\u{2016}",
    "Vert": "\u{2016}",
    "vert": "|",
    "uparrow": "\u{2191}",
    "downarrow": "\u{2193}",
    "updownarrow": "\u{2195}",
    "Uparrow": "21D1",
    "Downarrow": "21D3",
    "Updownarrow": "21D5",
    "backslash": "\\",
    "rangle": "\u{232A}",
    "langle": "\u{2329}",
    "rbrace": "}",
    "}": "}",
    "{": "{",
    "lbrace": "{",
    "lceil": "\u{2308}",
    "rceil": "\u{2309}",
    "lfloor": "\u{230A}",
    "rfloor": "\u{230B}",
  ]

  private static let _delimValueToName: [String: String] = computeReverseMap(_delimiters)

  private static let _fontStyles: [String: MTFontStyle] = [
    "mathnormal": .default,
    "mathrm": .roman,
    "textrm": .roman,
    "rm": .roman,
    "mathbf": .bold,
    "bf": .bold,
    "textbf": .bold,
    "mathcal": .caligraphic,
    "cal": .caligraphic,
    "mathtt": .typewriter,
    "texttt": .typewriter,
    "mathit": .italic,
    "textit": .italic,
    "mit": .italic,
    "mathsf": .sansSerif,
    "textsf": .sansSerif,
    "mathfrak": .fraktur,
    "frak": .fraktur,
    "mathbb": .blackboard,
    "mathbfit": .boldItalic,
    "bm": .boldItalic,
    "text": .roman,
  ]

  private static func computeReverseMap(_ map: [String: String]) -> [String: String] {
    var result: [String: String] = [:]
    for (command, value) in map {
      if let existing = result[value] {
        if command.count > existing.count { continue }
        if command.count == existing.count && command > existing { continue }
      }
      result[value] = command
    }
    return result
  }

  // MARK: - Symbol factories

  /// Returns an atom for the multiplication sign (`\times` or `*`).
  @objc public class func times() -> MTMathAtom {
    return MTMathAtom.atom(type: .binaryOperator, value: MTSymbolMultiplication)
  }

  /// Returns an atom for the division sign (`\div` or `/`).
  @objc public class func divide() -> MTMathAtom {
    return MTMathAtom.atom(type: .binaryOperator, value: MTSymbolDivision)
  }

  // MARK: - Placeholders

  /// Returns an atom which is a placeholder square.
  @objc public class func placeholder() -> MTMathAtom {
    return MTMathAtom.atom(type: .placeholder, value: MTSymbolWhiteSquare)
  }

  /// Returns a fraction with a placeholder for the numerator and denominator.
  @objc public class func placeholderFraction() -> MTFraction {
    let frac = MTFraction()
    frac.numerator = MTMathList()
    frac.numerator.addAtom(self.placeholder())
    frac.denominator = MTMathList()
    frac.denominator.addAtom(self.placeholder())
    return frac
  }

  /// Returns a radical with a placeholder as the radicand.
  @objc public class func placeholderRadical() -> MTRadical {
    let rad = MTRadical()
    rad.degree = MTMathList()
    rad.radicand = MTMathList()
    rad.degree?.addAtom(self.placeholder())
    rad.radicand?.addAtom(self.placeholder())
    return rad
  }

  /// Returns a square root with a placeholder as the radicand.
  @objc public class func placeholderSquareRoot() -> MTRadical {
    let rad = MTRadical()
    rad.radicand = MTMathList()
    rad.radicand?.addAtom(self.placeholder())
    return rad
  }

  // MARK: - Lookups

  /// Returns a large operator for the given name. If `limits` is true, limits are set up
  /// on the operator and displayed differently.
  @objc(operatorWithName:limits:)
  public class func `operator`(withName name: String, limits: Bool) -> MTLargeOperator {
    return MTLargeOperator(value: name, limits: limits)
  }

  /// Gets the atom with the right type for the given character. If an atom cannot be
  /// determined for a given character this returns `nil`. This function follows latex
  /// conventions for assigning types to the atoms.
  ///
  /// The following characters are not supported and will return `nil`:
  /// - Any non-ascii character.
  /// - Any control character or space (< 0x21).
  /// - Latex control chars: `$ % # & ~ '`.
  /// - Chars with special meaning in latex: `^ _ { } \`.
  ///
  /// All other characters will have a non-nil atom returned.
  @objc(atomForCharacter:)
  public class func atom(forCharacter ch: unichar) -> MTMathAtom? {
    let chStr = String(utf16CodeUnits: [ch], count: 1)
    if ch > 0x0410 && ch < 0x044F {
      // Show basic cyrillic alphabet. Latin Modern Math font is not good for cyrillic
      // symbols.
      return MTMathAtom.atom(type: .ordinary, value: chStr)
    }
    if ch < 0x21 || ch > 0x7E {
      // Skip non-ascii characters and spaces.
      return nil
    }
    switch ch {
    case UInt16(ascii: "$"), UInt16(ascii: "%"), UInt16(ascii: "#"),
      UInt16(ascii: "&"), UInt16(ascii: "~"), UInt16(ascii: "'"):
      // These are latex control characters that have special meanings. We don't support
      // them.
      return nil
    case UInt16(ascii: "^"), UInt16(ascii: "_"), UInt16(ascii: "{"),
      UInt16(ascii: "}"), UInt16(ascii: "\\"):
      // More special characters for Latex.
      return nil
    case UInt16(ascii: "("), UInt16(ascii: "["):
      return MTMathAtom.atom(type: .open, value: chStr)
    case UInt16(ascii: ")"), UInt16(ascii: "]"), UInt16(ascii: "!"), UInt16(ascii: "?"):
      return MTMathAtom.atom(type: .close, value: chStr)
    case UInt16(ascii: ","), UInt16(ascii: ";"):
      return MTMathAtom.atom(type: .punctuation, value: chStr)
    case UInt16(ascii: "="), UInt16(ascii: ">"), UInt16(ascii: "<"):
      return MTMathAtom.atom(type: .relation, value: chStr)
    case UInt16(ascii: ":"):
      // Math colon is ratio. Regular colon is `\colon`.
      return MTMathAtom.atom(type: .relation, value: "\u{2236}")
    case UInt16(ascii: "-"):
      // Use the math minus sign.
      return MTMathAtom.atom(type: .binaryOperator, value: "\u{2212}")
    case UInt16(ascii: "+"), UInt16(ascii: "*"):
      return MTMathAtom.atom(type: .binaryOperator, value: chStr)
    default:
      if ch == UInt16(ascii: ".") || (ch >= UInt16(ascii: "0") && ch <= UInt16(ascii: "9")) {
        return MTMathAtom.atom(type: .number, value: chStr)
      }
      if (ch >= UInt16(ascii: "a") && ch <= UInt16(ascii: "z"))
        || (ch >= UInt16(ascii: "A") && ch <= UInt16(ascii: "Z"))
      {
        return MTMathAtom.atom(type: .variable, value: chStr)
      }
      if ch == UInt16(ascii: "\"") || ch == UInt16(ascii: "/") || ch == UInt16(ascii: "@")
        || ch == UInt16(ascii: "`") || ch == UInt16(ascii: "|")
      {
        // Just an ordinary character. The following are allowed ordinary chars: | / ` @ "
        return MTMathAtom.atom(type: .ordinary, value: chStr)
      }
      assertionFailure("Unknown ascii character \(ch). Should have been accounted for.")
      return nil
    }
  }

  /// Returns a `MTMathList` with one atom per character in the given string. This function
  /// does not do any LaTeX conversion or interpretation. It simply uses
  /// `atom(forCharacter:)` to convert the characters to atoms. Any character that cannot
  /// be converted is ignored.
  @objc(mathListForCharacters:)
  public class func mathList(forCharacters chars: String) -> MTMathList {
    let list = MTMathList()
    let nsstr = chars as NSString
    for i in 0..<nsstr.length {
      let ch = nsstr.character(at: i)
      if let atom = self.atom(forCharacter: ch) {
        list.addAtom(atom)
      }
    }
    return list
  }

  /// Returns an atom with the right type for a given latex symbol (e.g. `theta`). If the
  /// latex symbol is unknown this will return `nil`. This supports LaTeX aliases as well.
  @objc(atomForLatexSymbolName:)
  public class func atom(forLatexSymbolName symbolName: String) -> MTMathAtom? {
    var name = symbolName
    // First check if this is an alias.
    if let canonical = _aliases[name] {
      // Switch to the canonical name.
      name = canonical
    }
    if let atom = _supportedLatexSymbols[name] {
      // Return a copy of the atom since atoms are mutable.
      return atom.copy() as? MTMathAtom
    }
    return nil
  }

  /// Finds the name of the LaTeX symbol name for the given atom. If no latex symbol name
  /// corresponds to the atom, then this returns `nil`. If the nucleus of the atom is
  /// empty, then this will return `nil`.
  ///
  /// - Note: This is not an exact reverse of `atom(forLatexSymbolName:)` in the case of
  ///   aliases. If a LaTeX alias points to a given symbol, then this function will return
  ///   the original symbol name and not the alias.
  /// - Note: This function does not convert math spaces to latex command names either.
  @objc(latexSymbolNameForAtom:)
  public class func latexSymbolName(for atom: MTMathAtom) -> String? {
    if atom.nucleus.isEmpty { return nil }
    return _textToLatexSymbolNames[atom.nucleus]
  }

  /// Define a latex symbol for rendering. This function allows defining custom symbols
  /// that are not already present in the default set, or override existing symbols with
  /// new meaning.
  ///
  /// e.g. to define a symbol for "lcm":
  /// `MTMathAtomFactory.addLatexSymbol("lcm", value: MTMathAtomFactory.operator(withName: "lcm", limits: false))`
  @objc(addLatexSymbol:value:)
  public class func addLatexSymbol(_ name: String, value atom: MTMathAtom) {
    _supportedLatexSymbols[name] = atom
    if !atom.nucleus.isEmpty {
      _textToLatexSymbolNames[atom.nucleus] = name
    }
  }

  /// Returns a list of all supported latex symbol names.
  @objc public class func supportedLatexSymbolNames() -> [String] {
    return Array(_supportedLatexSymbols.keys)
  }

  /// Returns an accent with the given name. The name of the accent is the LaTeX name such
  /// as `grave`, `hat` etc. If the name is not a recognized accent name, this returns
  /// `nil`. The `innerList` of the returned `MTAccent` is `nil`.
  @objc(accentWithName:)
  public class func accent(withName name: String) -> MTAccent? {
    if let value = _accents[name] {
      return MTAccent(value: value)
    }
    return nil
  }

  /// Returns the accent name for the given accent. This is the reverse of
  /// `accent(withName:)`.
  @objc(accentName:)
  public class func accentName(_ accent: MTAccent) -> String? {
    return _accentValueToName[accent.nucleus]
  }

  /// Creates a new boundary atom for the given delimiter name. If the delimiter name is
  /// not recognized it returns `nil`. A delimiter name can be a single character such as
  /// `(` or a latex command such as `uparrow`.
  ///
  /// - Note: In order to distinguish between the delimiter `|` and the delimiter `\|` the
  ///   delimiter `\|` has been renamed to `||`.
  @objc(boundaryAtomForDelimiterName:)
  public class func boundaryAtom(forDelimiterName name: String) -> MTMathAtom? {
    guard let value = _delimiters[name] else { return nil }
    return MTMathAtom.atom(type: .boundary, value: value)
  }

  /// Returns the delimiter name for a boundary atom. This is the reverse of
  /// `boundaryAtom(forDelimiterName:)`. If the atom is not a boundary atom or if the
  /// delimiter value is unknown this returns `nil`.
  ///
  /// - Note: This is not an exact reverse. Some delimiters have two names (e.g. `<` and
  ///   `langle`) and this function always returns the shorter name.
  @objc(delimiterNameForBoundaryAtom:)
  public class func delimiterName(forBoundaryAtom boundary: MTMathAtom) -> String? {
    if boundary.type != .boundary { return nil }
    return _delimValueToName[boundary.nucleus]
  }

  /// Internal lookup that distinguishes "no such style" from `.default`.
  internal class func lookupFontStyle(name: String) -> MTFontStyle? {
    return _fontStyles[name]
  }

  /// Returns a font style associated with the name. If none is found, returns `.default`.
  ///
  /// - Note: This diverges from the original Objective-C API, which returned `NSNotFound`
  ///   for unknown names. The Swift port cannot fit `NSNotFound` into the `MTFontStyle`
  ///   raw value space, so it falls back to `.default`. Internal callers should use
  ///   `lookupFontStyle(name:)` to distinguish "no match" from `.default`.
  @objc(fontStyleWithName:)
  public class func fontStyle(withName name: String) -> MTFontStyle {
    return _fontStyles[name] ?? .default
  }

  /// Returns the latex font name for a given style.
  @objc(fontNameForStyle:)
  public class func fontName(for fontStyle: MTFontStyle) -> String {
    switch fontStyle {
    case .default: return "mathnormal"
    case .roman: return "mathrm"
    case .bold: return "mathbf"
    case .fraktur: return "mathfrak"
    case .caligraphic: return "mathcal"
    case .italic: return "mathit"
    case .sansSerif: return "mathsf"
    case .blackboard: return "mathbb"
    case .typewriter: return "mathtt"
    case .boldItalic: return "bm"
    }
  }

  /// Returns a fraction with the given numerator and denominator.
  @objc(fractionWithNumerator:denominator:)
  public class func fraction(withNumerator num: MTMathList, denominator denom: MTMathList)
    -> MTFraction
  {
    let frac = MTFraction()
    frac.numerator = num
    frac.denominator = denom
    return frac
  }

  /// Convenience overload for when the numerator and denominator are simple strings. Uses
  /// `mathList(forCharacters:)` to convert the strings to `MTMathList`s.
  @objc(fractionWithNumeratorStr:denominatorStr:)
  public class func fraction(withNumeratorStr numStr: String, denominatorStr denomStr: String)
    -> MTFraction
  {
    let num = self.mathList(forCharacters: numStr)
    let denom = self.mathList(forCharacters: denomStr)
    return self.fraction(withNumerator: num, denominator: denom)
  }

  /// Builds a table for a given environment with the given rows. Returns a `MTMathAtom`
  /// containing the table and any other atoms necessary for the given environment.
  /// Returns `nil` and sets `error` if the table could not be built.
  ///
  /// - Parameters:
  ///   - env: The environment to use to build the table. If `nil`, then the default table
  ///     is built.
  ///   - rows: The cells of the table.
  ///   - error: Out-parameter populated with a parse error if the table could not be
  ///     built.
  /// - Note: The reason this function returns a `MTMathAtom` and not a `MTMathTable` is
  ///   because some matrix environments have builtin delimiters added to the table and
  ///   hence are returned as inner atoms.
  @objc(tableWithEnvironment:rows:error:)
  public class func table(
    withEnvironment env: String?,
    rows: [[MTMathList]],
    error: NSErrorPointer
  ) -> MTMathAtom? {
    let table = MTMathTable(environment: env)
    for i in 0..<rows.count {
      for j in 0..<rows[i].count {
        table.setCell(rows[i][j], forRow: i, column: j)
      }
    }
    let matrixEnvs: [String: [String]] = [
      "matrix": [],
      "pmatrix": ["(", ")"],
      "bmatrix": ["[", "]"],
      "Bmatrix": ["{", "}"],
      "vmatrix": ["vert", "vert"],
      "Vmatrix": ["Vert", "Vert"],
    ]
    if let env = env, let delims = matrixEnvs[env] {
      // It is set to matrix as the delimiters are converted to latex outside the table.
      table.environment = "matrix"
      table.interRowAdditionalSpacing = 0
      table.interColumnSpacing = 18
      // All the lists are in textstyle.
      let style = MTMathStyle(style: .text)
      for i in 0..<table.cells.count {
        for j in 0..<table.cells[i].count {
          table.cells[i][j].insertAtom(style, at: 0)
        }
      }
      // Add delimiters.
      if delims.count == 2 {
        let inner = MTInner()
        inner.leftBoundary = self.boundaryAtom(forDelimiterName: delims[0])
        inner.rightBoundary = self.boundaryAtom(forDelimiterName: delims[1])
        inner.innerList = MTMathList.mathList(withAtomsArray: [table])
        return inner
      }
      return table
    } else if env == nil {
      // The default env.
      table.interRowAdditionalSpacing = 1
      table.interColumnSpacing = 0
      let cols = Int(table.numColumns())
      for i in 0..<cols {
        table.setAlignment(.left, forColumn: i)
      }
      return table
    } else if env == "eqalign" || env == "split" || env == "aligned" {
      if table.numColumns() != 2 {
        let message = "\(env!) environment can only have 2 columns"
        error?.pointee = NSError(
          domain: MTParseError, code: Int(MTParseErrors.invalidNumColumns.rawValue),
          userInfo: [NSLocalizedDescriptionKey: message])
        return nil
      }
      // Add a spacer before each of the second column elements. This is to create the
      // correct spacing for `=` and other relations.
      let spacer = MTMathAtom.atom(type: .ordinary, value: "")
      for i in 0..<table.cells.count {
        if table.cells[i].count > 1 {
          table.cells[i][1].insertAtom(spacer, at: 0)
        }
      }
      table.interRowAdditionalSpacing = 1
      table.interColumnSpacing = 0
      table.setAlignment(.right, forColumn: 0)
      table.setAlignment(.left, forColumn: 1)
      return table
    } else if env == "displaylines" || env == "gather" {
      if table.numColumns() != 1 {
        let message = "\(env!) environment can only have 1 column"
        error?.pointee = NSError(
          domain: MTParseError, code: Int(MTParseErrors.invalidNumColumns.rawValue),
          userInfo: [NSLocalizedDescriptionKey: message])
        return nil
      }
      table.interRowAdditionalSpacing = 1
      table.interColumnSpacing = 0
      table.setAlignment(.center, forColumn: 0)
      return table
    } else if env == "eqnarray" {
      if table.numColumns() != 3 {
        let message = "eqnarray environment can only have 3 columns"
        error?.pointee = NSError(
          domain: MTParseError, code: Int(MTParseErrors.invalidNumColumns.rawValue),
          userInfo: [NSLocalizedDescriptionKey: message])
        return nil
      }
      table.interRowAdditionalSpacing = 1
      table.interColumnSpacing = 18
      table.setAlignment(.right, forColumn: 0)
      table.setAlignment(.center, forColumn: 1)
      table.setAlignment(.left, forColumn: 2)
      return table
    } else if env == "cases" {
      if table.numColumns() != 2 {
        let message = "cases environment can only have 2 columns"
        error?.pointee = NSError(
          domain: MTParseError, code: Int(MTParseErrors.invalidNumColumns.rawValue),
          userInfo: [NSLocalizedDescriptionKey: message])
        return nil
      }
      table.interRowAdditionalSpacing = 0
      table.interColumnSpacing = 18
      table.setAlignment(.left, forColumn: 0)
      table.setAlignment(.left, forColumn: 1)
      // All the lists are in textstyle.
      let style = MTMathStyle(style: .text)
      for i in 0..<table.cells.count {
        for j in 0..<table.cells[i].count {
          table.cells[i][j].insertAtom(style, at: 0)
        }
      }
      // Add delimiters.
      let inner = MTInner()
      inner.leftBoundary = self.boundaryAtom(forDelimiterName: "{")
      inner.rightBoundary = self.boundaryAtom(forDelimiterName: ".")
      let space = self.atom(forLatexSymbolName: ",")!
      inner.innerList = MTMathList.mathList(withAtomsArray: [space, table])
      return inner
    }
    let message = "Unknown environment: \(env ?? "")"
    error?.pointee = NSError(
      domain: MTParseError, code: Int(MTParseErrors.invalidEnv.rawValue),
      userInfo: [NSLocalizedDescriptionKey: message])
    return nil
  }
}

private func makeSupportedLatexSymbols() -> [String: MTMathAtom] {
  func ord(_ v: String) -> MTMathAtom { return MTMathAtom(type: .ordinary, value: v) }
  func variable(_ v: String) -> MTMathAtom { return MTMathAtom(type: .variable, value: v) }
  func openA(_ v: String) -> MTMathAtom { return MTMathAtom(type: .open, value: v) }
  func closeA(_ v: String) -> MTMathAtom { return MTMathAtom(type: .close, value: v) }
  func rel(_ v: String) -> MTMathAtom { return MTMathAtom(type: .relation, value: v) }
  func bin(_ v: String) -> MTMathAtom { return MTMathAtom(type: .binaryOperator, value: v) }
  func punct(_ v: String) -> MTMathAtom { return MTMathAtom(type: .punctuation, value: v) }
  func op(_ name: String, _ limits: Bool) -> MTMathAtom {
    return MTLargeOperator(value: name, limits: limits)
  }

  var d: [String: MTMathAtom] = [:]
  d["square"] = MTMathAtomFactory.placeholder()

  // Greek
  let lowerGreek: [(String, String)] = [
    ("alpha", "\u{03B1}"), ("beta", "\u{03B2}"), ("gamma", "\u{03B3}"), ("delta", "\u{03B4}"),
    ("varepsilon", "\u{03B5}"), ("zeta", "\u{03B6}"), ("eta", "\u{03B7}"), ("theta", "\u{03B8}"),
    ("iota", "\u{03B9}"), ("kappa", "\u{03BA}"), ("lambda", "\u{03BB}"), ("mu", "\u{03BC}"),
    ("nu", "\u{03BD}"), ("xi", "\u{03BE}"), ("omicron", "\u{03BF}"), ("pi", "\u{03C0}"),
    ("rho", "\u{03C1}"), ("varsigma", "\u{03C2}"), ("sigma", "\u{03C3}"), ("tau", "\u{03C4}"),
    ("upsilon", "\u{03C5}"), ("varphi", "\u{03C6}"), ("chi", "\u{03C7}"), ("psi", "\u{03C8}"),
    ("omega", "\u{03C9}"),
    ("vartheta", "\u{03D1}"), ("phi", "\u{03D5}"), ("varpi", "\u{03D6}"),
    ("varkappa", "\u{03F0}"), ("varrho", "\u{03F1}"), ("epsilon", "\u{03F5}"),
  ]
  for (k, v) in lowerGreek { d[k] = variable(v) }

  let upperGreek: [(String, String)] = [
    ("Gamma", "\u{0393}"), ("Delta", "\u{0394}"), ("Theta", "\u{0398}"),
    ("Lambda", "\u{039B}"), ("Xi", "\u{039E}"), ("Pi", "\u{03A0}"),
    ("Sigma", "\u{03A3}"), ("Upsilon", "\u{03A5}"), ("Phi", "\u{03A6}"),
    ("Psi", "\u{03A8}"), ("Omega", "\u{03A9}"),
  ]
  for (k, v) in upperGreek { d[k] = variable(v) }

  // Open/Close
  d["lceil"] = openA("\u{2308}")
  d["lfloor"] = openA("\u{230A}")
  d["langle"] = openA("\u{27E8}")
  d["lgroup"] = openA("\u{27EE}")
  d["rceil"] = closeA("\u{2309}")
  d["rfloor"] = closeA("\u{230B}")
  d["rangle"] = closeA("\u{27E9}")
  d["rgroup"] = closeA("\u{27EF}")

  // Arrows / Relations (rel)
  let rels: [(String, String)] = [
    ("leftarrow", "\u{2190}"), ("uparrow", "\u{2191}"), ("rightarrow", "\u{2192}"),
    ("downarrow", "\u{2193}"), ("leftrightarrow", "\u{2194}"), ("updownarrow", "\u{2195}"),
    ("nwarrow", "\u{2196}"), ("nearrow", "\u{2197}"), ("searrow", "\u{2198}"),
    ("swarrow", "\u{2199}"), ("mapsto", "\u{21A6}"),
    ("Leftarrow", "\u{21D0}"), ("Uparrow", "\u{21D1}"), ("Rightarrow", "\u{21D2}"),
    ("Downarrow", "\u{21D3}"), ("Leftrightarrow", "\u{21D4}"), ("Updownarrow", "\u{21D5}"),
    ("longleftarrow", "\u{27F5}"), ("longrightarrow", "\u{27F6}"),
    ("longleftrightarrow", "\u{27F7}"), ("Longleftarrow", "\u{27F8}"),
    ("Longrightarrow", "\u{27F9}"), ("Longleftrightarrow", "\u{27FA}"),
    ("leq", MTSymbolLessEqual), ("geq", MTSymbolGreaterEqual), ("neq", MTSymbolNotEqual),
    ("in", "\u{2208}"), ("notin", "\u{2209}"), ("ni", "\u{220B}"), ("propto", "\u{221D}"),
    ("mid", "\u{2223}"), ("parallel", "\u{2225}"), ("sim", "\u{223C}"),
    ("simeq", "\u{2243}"), ("cong", "\u{2245}"), ("approx", "\u{2248}"),
    ("asymp", "\u{224D}"), ("doteq", "\u{2250}"), ("equiv", "\u{2261}"),
    ("gg", "\u{226B}"), ("ll", "\u{226A}"), ("prec", "\u{227A}"), ("succ", "\u{227B}"),
    ("subset", "\u{2282}"), ("supset", "\u{2283}"), ("subseteq", "\u{2286}"),
    ("supseteq", "\u{2287}"), ("sqsubset", "\u{228F}"), ("sqsupset", "\u{2290}"),
    ("sqsubseteq", "\u{2291}"), ("sqsupseteq", "\u{2292}"), ("models", "\u{22A7}"),
    ("perp", "\u{27C2}"),
  ]
  for (k, v) in rels { d[k] = rel(v) }

  // Operators
  d["times"] = MTMathAtomFactory.times()
  d["div"] = MTMathAtomFactory.divide()
  let bins: [(String, String)] = [
    ("pm", "\u{00B1}"), ("dagger", "\u{2020}"), ("ddagger", "\u{2021}"),
    ("mp", "\u{2213}"), ("setminus", "\u{2216}"), ("ast", "\u{2217}"),
    ("circ", "\u{2218}"), ("bullet", "\u{2219}"), ("wedge", "\u{2227}"),
    ("vee", "\u{2228}"), ("cap", "\u{2229}"), ("cup", "\u{222A}"),
    ("wr", "\u{2240}"), ("uplus", "\u{228E}"), ("sqcap", "\u{2293}"),
    ("sqcup", "\u{2294}"), ("oplus", "\u{2295}"), ("ominus", "\u{2296}"),
    ("otimes", "\u{2297}"), ("oslash", "\u{2298}"), ("odot", "\u{2299}"),
    ("star", "\u{22C6}"), ("cdot", "\u{22C5}"), ("amalg", "\u{2A3F}"),
  ]
  for (k, v) in bins { d[k] = bin(v) }

  // No-limit operators
  for n in [
    "log", "lg", "ln", "sin", "arcsin", "sinh", "cos", "arccos", "cosh",
    "tan", "arctan", "tanh", "cot", "coth", "sec", "csc", "arg", "ker",
    "dim", "hom", "exp", "deg",
  ] {
    d[n] = op(n, false)
  }

  // Limit operators
  d["lim"] = op("lim", true)
  d["limsup"] = op("lim sup", true)
  d["liminf"] = op("lim inf", true)
  for n in ["max", "min", "sup", "inf", "det", "Pr", "gcd"] {
    d[n] = op(n, true)
  }

  // Large operators
  let largeLimits: [(String, String)] = [
    ("prod", "\u{220F}"), ("coprod", "\u{2210}"), ("sum", "\u{2211}"),
    ("bigwedge", "\u{22C0}"), ("bigvee", "\u{22C1}"), ("bigcap", "\u{22C2}"),
    ("bigcup", "\u{22C3}"), ("bigodot", "\u{2A00}"), ("bigoplus", "\u{2A01}"),
    ("bigotimes", "\u{2A02}"), ("biguplus", "\u{2A04}"), ("bigsqcup", "\u{2A06}"),
  ]
  for (k, v) in largeLimits { d[k] = op(v, true) }
  d["int"] = op("\u{222B}", false)
  d["oint"] = op("\u{222E}", false)

  // Latex command chars
  d["{"] = openA("{")
  d["}"] = closeA("}")
  d["$"] = ord("$")
  d["&"] = ord("&")
  d["#"] = ord("#")
  d["%"] = ord("%")
  d["_"] = ord("_")
  d[" "] = ord(" ")
  d["backslash"] = ord("\\")

  // Punctuation
  d["colon"] = punct(":")
  d["cdotp"] = punct("\u{00B7}")

  // Other ordinaries
  let ords: [(String, String)] = [
    ("degree", "\u{00B0}"), ("neg", "\u{00AC}"), ("angstrom", "\u{00C5}"),
    ("|", "\u{2016}"), ("vert", "|"), ("ldots", "\u{2026}"),
    ("prime", "\u{2032}"), ("hbar", "\u{210F}"), ("Im", "\u{2111}"),
    ("ell", "\u{2113}"), ("wp", "\u{2118}"), ("Re", "\u{211C}"),
    ("mho", "\u{2127}"), ("aleph", "\u{2135}"), ("forall", "\u{2200}"),
    ("exists", "\u{2203}"), ("emptyset", "\u{2205}"), ("nabla", "\u{2207}"),
    ("infty", "\u{221E}"), ("angle", "\u{2220}"), ("top", "\u{22A4}"),
    ("bot", "\u{22A5}"), ("vdots", "\u{22EE}"), ("cdots", "\u{22EF}"),
    ("ddots", "\u{22F1}"), ("triangle", "\u{25B3}"),
    ("imath", "\u{1D6A4}"), ("jmath", "\u{1D6A5}"), ("partial", "\u{1D715}"),
  ]
  for (k, v) in ords { d[k] = ord(v) }

  // Spacing
  d[","] = MTMathSpace(space: 3)
  d[">"] = MTMathSpace(space: 4)
  d[";"] = MTMathSpace(space: 5)
  d["!"] = MTMathSpace(space: -3)
  d["quad"] = MTMathSpace(space: 18)
  d["qquad"] = MTMathSpace(space: 36)

  // Style
  d["displaystyle"] = MTMathStyle(style: .display)
  d["textstyle"] = MTMathStyle(style: .text)
  d["scriptstyle"] = MTMathStyle(style: .script)
  d["scriptscriptstyle"] = MTMathStyle(style: .scriptScript)

  return d
}

private func makeTextToLatexSymbolNames(from commands: [String: MTMathAtom]) -> [String: String] {
  var result: [String: String] = [:]
  for (command, atom) in commands {
    if atom.nucleus.isEmpty { continue }
    if let existing = result[atom.nucleus] {
      if command.count > existing.count { continue }
      if command.count == existing.count && command > existing { continue }
    }
    result[atom.nucleus] = command
  }
  return result
}
