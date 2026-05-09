import Foundation

/// The error domain for parse errors raised while building a `MTMathList` from LaTeX.
public let MTParseError = "ParseError"

/// The error encountered when parsing a LaTeX string.
///
/// The `code` in the `NSError` is one of the following indicating why the LaTeX string
/// could not be parsed.
@objc public enum MTParseErrors: UInt {
  /// The braces { } do not match.
  case mismatchBraces = 1
  /// A command in the string is not recognized.
  case invalidCommand
  /// An expected character such as ] was not found.
  case characterNotFound
  /// The `\left` or `\right` command was not followed by a delimiter.
  case missingDelimiter
  /// The delimiter following `\left` or `\right` was not a valid delimiter.
  case invalidDelimiter
  /// There is no `\right` corresponding to the `\left` command.
  case missingRight
  /// There is no `\left` corresponding to the `\right` command.
  case missingLeft
  /// The environment given to the `\begin` command is not recognized.
  case invalidEnv
  /// A command is used which is only valid inside a `\begin`,`\end` environment.
  case missingEnv
  /// There is no `\begin` corresponding to the `\end` command.
  case missingBegin
  /// There is no `\end` corresponding to the `\begin` command.
  case missingEnd
  /// The number of columns does not match the environment.
  case invalidNumColumns
  /// Internal error, due to a programming mistake.
  case internalError
  /// Limit control applied incorrectly.
  case invalidLimits
}

/// Tracks state for a `\begin{...}...\end{...}` environment while it is being parsed.
private final class MTEnvProperties {
  let envName: String?
  var ended: Bool = false
  var numRows: Int = 0
  init(name: String?) {
    self.envName = name
  }
}

/// `MTMathListBuilder` is a class for parsing LaTeX into a `MTMathList` that can be rendered
/// and processed mathematically.
@objc(MTMathListBuilder)
public final class MTMathListBuilder: NSObject {

  /// Contains any error that occurred during parsing.
  @objc public private(set) var error: NSError?

  private var chars: [unichar]
  private var currentChar: Int = 0
  private var length: Int { return chars.count }
  private var currentInnerAtom: MTInner?
  private var currentEnv: MTEnvProperties?
  private var currentFontStyle: MTFontStyle = .default
  private var spacesAllowed: Bool = false

  /// Create a `MTMathListBuilder` for the given string. After instantiating, use `build()`
  /// to build the math list. Create a new `MTMathListBuilder` for each string that needs
  /// to be parsed; do not reuse the object.
  ///
  /// - Parameter str: The LaTeX string to be used to build the `MTMathList`.
  @objc(initWithString:)
  public init(string str: String) {
    let nsstr = str as NSString
    var buf = [unichar](repeating: 0, count: nsstr.length)
    nsstr.getCharacters(&buf, range: NSRange(location: 0, length: nsstr.length))
    self.chars = buf
    super.init()
  }

  private func hasCharacters() -> Bool { return currentChar < length }

  /// Gets the next character and moves the pointer ahead.
  private func getNextCharacter() -> unichar {
    let c = chars[currentChar]
    currentChar += 1
    return c
  }

  private func unlookCharacter() {
    currentChar -= 1
  }

  /// Builds a math list from the parser's input. Returns `nil` if there is an error;
  /// inspect `error` for details.
  @objc public func build() -> MTMathList? {
    let list = self.buildInternal(oneCharOnly: false)
    if hasCharacters() && error == nil {
      // Something went wrong, most likely braces mismatched.
      let str = String(utf16CodeUnits: chars, count: chars.count)
      setError(.mismatchBraces, message: "Mismatched braces: \(str)")
    }
    if error != nil {
      return nil
    }
    return list
  }

  private func buildInternal(oneCharOnly: Bool, stopChar: unichar = 0) -> MTMathList? {
    let list = MTMathList()
    assert(!(oneCharOnly && stopChar > 0))
    var prevAtom: MTMathAtom?
    while hasCharacters() {
      if error != nil { return nil }
      var atom: MTMathAtom?
      let ch = getNextCharacter()
      if oneCharOnly {
        let stops: [unichar] = [
          UInt16(ascii: "^"), UInt16(ascii: "}"), UInt16(ascii: "_"), UInt16(ascii: "&"),
        ]
        if stops.contains(ch) {
          // This is not the character we are looking for. They are meant for the caller
          // to look at.
          unlookCharacter()
          return list
        }
      }
      // If there is a stop character, keep scanning till we find it.
      if stopChar > 0 && ch == stopChar {
        return list
      }

      if ch == UInt16(ascii: "^") {
        if prevAtom == nil || prevAtom!.superScript != nil || !prevAtom!.scriptsAllowed() {
          // If there is no previous atom, or if it already has a superscript or if scripts
          // are not allowed for it, then add an empty node.
          prevAtom = MTMathAtom.atom(type: .ordinary, value: "")
          list.addAtom(prevAtom!)
        }
        // This is a superscript for the previous atom.
        // Note: if the next char is the stopChar it will be consumed by the ^ and so it
        // doesn't count as stop.
        prevAtom!.superScript = self.buildInternal(oneCharOnly: true)
        continue
      } else if ch == UInt16(ascii: "_") {
        if prevAtom == nil || prevAtom!.subScript != nil || !prevAtom!.scriptsAllowed() {
          // If there is no previous atom, or if it already has a subscript or if scripts
          // are not allowed for it, then add an empty node.
          prevAtom = MTMathAtom.atom(type: .ordinary, value: "")
          list.addAtom(prevAtom!)
        }
        // This is a subscript for the previous atom.
        prevAtom!.subScript = self.buildInternal(oneCharOnly: true)
        continue
      } else if ch == UInt16(ascii: "{") {
        // Recurse with oneCharOnly false and no stop character.
        let sublist = self.buildInternal(oneCharOnly: false, stopChar: UInt16(ascii: "}"))
        prevAtom = sublist?.atoms.last
        if let s = sublist {
          list.append(s)
        }
        if oneCharOnly {
          return list
        }
        continue
      } else if ch == UInt16(ascii: "}") {
        // We encountered a closing brace when there is no stop set, that means there was
        // no corresponding opening brace.
        setError(.mismatchBraces, message: "Mismatched braces.")
        return nil
      } else if ch == UInt16(ascii: "\\") {
        // \ means a command.
        let command = readCommand()
        if let done = stopCommand(command, list: list, stopChar: stopChar) {
          return done
        } else if error != nil {
          return nil
        }
        if applyModifier(command, atom: prevAtom) {
          continue
        }
        if let fontStyle = MTMathAtomFactory.lookupFontStyle(name: command) {
          let oldSpacesAllowed = spacesAllowed
          // Text has special consideration where it allows spaces without escaping.
          spacesAllowed = (command == "text")
          let oldFontStyle = currentFontStyle
          currentFontStyle = fontStyle
          let sublist = self.buildInternal(oneCharOnly: true)
          // Restore the font style.
          currentFontStyle = oldFontStyle
          spacesAllowed = oldSpacesAllowed
          prevAtom = sublist?.atoms.last
          if let s = sublist { list.append(s) }
          if oneCharOnly { return list }
          continue
        }
        atom = atomForCommand(command)
        if atom == nil {
          // Unknown command — flag an error and return.
          setError(.internalError, message: "Internal error")
          return nil
        }
      } else if ch == UInt16(ascii: "&") {
        // Used for column separation in tables.
        if currentEnv != nil {
          return list
        } else {
          // Create a new table with the current list and a default env.
          if let table = buildTable(env: nil, firstList: list, isRow: false) {
            return MTMathList.mathList(withAtomsArray: [table])
          }
          return nil
        }
      } else if spacesAllowed && ch == UInt16(ascii: " ") {
        // If spaces are allowed then spaces do not need escaping with a \ before being used.
        atom = MTMathAtomFactory.atom(forLatexSymbolName: " ")
      } else {
        atom = MTMathAtomFactory.atom(forCharacter: ch)
        if atom == nil {
          // Not a recognized character.
          continue
        }
      }

      atom!.fontStyle = currentFontStyle
      list.addAtom(atom!)
      prevAtom = atom

      if oneCharOnly {
        // We consumed our one char.
        return list
      }
    }
    if stopChar > 0 {
      if stopChar == UInt16(ascii: "}") {
        // We did not find a corresponding closing brace.
        setError(.mismatchBraces, message: "Missing closing brace")
      } else {
        // We never found our stop character.
        setError(.characterNotFound, message: "Expected character not found: \(stopChar)")
      }
    }
    return list
  }

  /// Reads a string of all upper and lower case characters.
  private func readString() -> String {
    var s: [unichar] = []
    while hasCharacters() {
      let ch = getNextCharacter()
      if (ch >= UInt16(ascii: "a") && ch <= UInt16(ascii: "z"))
        || (ch >= UInt16(ascii: "A") && ch <= UInt16(ascii: "Z"))
      {
        s.append(ch)
      } else {
        // We went too far.
        unlookCharacter()
        break
      }
    }
    return String(utf16CodeUnits: s, count: s.count)
  }

  private func readColor() -> String? {
    if !expectCharacter(UInt16(ascii: "{")) {
      setError(.characterNotFound, message: "Missing {")
      return nil
    }
    skipSpaces()
    var s: [unichar] = []
    while hasCharacters() {
      let ch = getNextCharacter()
      if ch == UInt16(ascii: "#") || (ch >= UInt16(ascii: "A") && ch <= UInt16(ascii: "F"))
        || (ch >= UInt16(ascii: "a") && ch <= UInt16(ascii: "f"))
        || (ch >= UInt16(ascii: "0") && ch <= UInt16(ascii: "9"))
      {
        s.append(ch)
      } else {
        unlookCharacter()
        break
      }
    }
    if !expectCharacter(UInt16(ascii: "}")) {
      setError(.characterNotFound, message: "Missing }")
      return nil
    }
    return String(utf16CodeUnits: s, count: s.count)
  }

  /// Skips non-ascii characters and spaces.
  private func skipSpaces() {
    while hasCharacters() {
      let ch = getNextCharacter()
      if ch < 0x21 || ch > 0x7E {
        // Skip non-ascii characters and spaces.
        continue
      }
      unlookCharacter()
      return
    }
  }

  private func expectCharacter(_ ch: unichar) -> Bool {
    skipSpaces()
    if hasCharacters() {
      let c = getNextCharacter()
      if c == ch { return true }
      unlookCharacter()
    }
    return false
  }

  private static let singleCharCommands: Set<unichar> = {
    let chs: [Character] = ["{", "}", "$", "#", "%", "_", "|", " ", ",", ">", ";", "!", "\\"]
    return Set(chs.map { $0.utf16.first! })
  }()

  private func readCommand() -> String {
    if hasCharacters() {
      let ch = getNextCharacter()
      if MTMathListBuilder.singleCharCommands.contains(ch) {
        return String(utf16CodeUnits: [ch], count: 1)
      }
      unlookCharacter()
    }
    return readString()
  }

  private func readDelimiter() -> String? {
    skipSpaces()
    while hasCharacters() {
      let ch = getNextCharacter()
      if ch == UInt16(ascii: "\\") {
        // \ means a command.
        let command = readCommand()
        if command == "|" {
          // | is a command and also a regular delimiter. We use the || command to
          // distinguish between the 2 cases for the caller.
          return "||"
        }
        return command
      } else {
        return String(utf16CodeUnits: [ch], count: 1)
      }
    }
    // We ran out of characters for delimiter.
    return nil
  }

  private func readEnvironment() -> String? {
    if !expectCharacter(UInt16(ascii: "{")) {
      setError(.characterNotFound, message: "Missing {")
      return nil
    }
    skipSpaces()
    let env = readString()
    if !expectCharacter(UInt16(ascii: "}")) {
      setError(.characterNotFound, message: "Missing }")
      return nil
    }
    return env
  }

  private func getBoundaryAtom(delimiterType: String) -> MTMathAtom? {
    guard let delim = readDelimiter() else {
      setError(.missingDelimiter, message: "Missing delimiter for \\\(delimiterType)")
      return nil
    }
    guard let boundary = MTMathAtomFactory.boundaryAtom(forDelimiterName: delim) else {
      setError(.invalidDelimiter, message: "Invalid delimiter for \\\(delimiterType): \(delim)")
      return nil
    }
    return boundary
  }

  private func atomForCommand(_ command: String) -> MTMathAtom? {
    if let atom = MTMathAtomFactory.atom(forLatexSymbolName: command) {
      return atom
    }
    if let accent = MTMathAtomFactory.accent(withName: command) {
      accent.innerList = self.buildInternal(oneCharOnly: true)
      return accent
    }
    switch command {
    case "frac":
      // A fraction command has 2 arguments.
      let frac = MTFraction()
      frac.numerator = self.buildInternal(oneCharOnly: true) ?? MTMathList()
      frac.denominator = self.buildInternal(oneCharOnly: true) ?? MTMathList()
      return frac
    case "dfrac":
      let frac = MTFraction()
      frac.numerator = self.buildInternal(oneCharOnly: true) ?? MTMathList()
      frac.denominator = self.buildInternal(oneCharOnly: true) ?? MTMathList()
      frac.fracStyle = .display
      return frac
    case "tfrac":
      let frac = MTFraction()
      frac.numerator = self.buildInternal(oneCharOnly: true) ?? MTMathList()
      frac.denominator = self.buildInternal(oneCharOnly: true) ?? MTMathList()
      frac.fracStyle = .text
      return frac
    case "binom":
      // A binom command has 2 arguments.
      let frac = MTFraction(rule: false)
      frac.numerator = self.buildInternal(oneCharOnly: true) ?? MTMathList()
      frac.denominator = self.buildInternal(oneCharOnly: true) ?? MTMathList()
      frac.leftDelimiter = "("
      frac.rightDelimiter = ")"
      return frac
    case "sqrt":
      // A sqrt command with one argument.
      let rad = MTRadical()
      let ch = getNextCharacter()
      if ch == UInt16(ascii: "[") {
        // Special handling for sqrt[degree]{radicand}.
        rad.degree = self.buildInternal(oneCharOnly: false, stopChar: UInt16(ascii: "]"))
        rad.radicand = self.buildInternal(oneCharOnly: true)
      } else {
        unlookCharacter()
        rad.radicand = self.buildInternal(oneCharOnly: true)
      }
      return rad
    case "left":
      // Save the current inner while a new one gets built.
      let oldInner = currentInnerAtom
      currentInnerAtom = MTInner()
      let leftBoundary = getBoundaryAtom(delimiterType: "left")
      if leftBoundary == nil { return nil }
      currentInnerAtom!.leftBoundary = leftBoundary
      currentInnerAtom!.innerList = self.buildInternal(oneCharOnly: false)
      if currentInnerAtom!.rightBoundary == nil {
        // A right node would have set the right boundary so we must be missing the right
        // node.
        setError(.missingRight, message: "Missing \\right")
        return nil
      }
      // Reinstate the old inner atom.
      let newInner = currentInnerAtom!
      currentInnerAtom = oldInner
      return newInner
    case "overline":
      // The overline command has 1 argument.
      let over = MTOverLine()
      over.innerList = self.buildInternal(oneCharOnly: true)
      return over
    case "underline":
      // The underline command has 1 argument.
      let under = MTUnderLine()
      under.innerList = self.buildInternal(oneCharOnly: true)
      return under
    case "begin":
      guard let env = readEnvironment() else { return nil }
      return buildTable(env: env, firstList: nil, isRow: false)
    case "color":
      // A color command has 2 arguments.
      let mc = MTMathColor()
      mc.colorString = readColor()
      mc.innerList = self.buildInternal(oneCharOnly: true)
      return mc
    case "colorbox":
      // A colorbox command has 2 arguments.
      let mc = MTMathColorbox()
      mc.colorString = readColor()
      mc.innerList = self.buildInternal(oneCharOnly: true)
      return mc
    default:
      setError(.invalidCommand, message: "Invalid command \\\(command)")
      return nil
    }
  }

  private static let fractionCommands: [String: [String]] = [
    "over": [],
    "atop": [],
    "choose": ["(", ")"],
    "brack": ["[", "]"],
    "brace": ["{", "}"],
  ]

  private func stopCommand(_ command: String, list: MTMathList, stopChar: unichar) -> MTMathList? {
    if command == "right" {
      if currentInnerAtom == nil {
        setError(.missingLeft, message: "Missing \\left")
        return nil
      }
      currentInnerAtom!.rightBoundary = getBoundaryAtom(delimiterType: "right")
      if currentInnerAtom!.rightBoundary == nil { return nil }
      return list
    }
    if let delims = MTMathListBuilder.fractionCommands[command] {
      let frac: MTFraction
      if command == "over" {
        frac = MTFraction()
      } else {
        frac = MTFraction(rule: false)
      }
      if delims.count == 2 {
        frac.leftDelimiter = delims[0]
        frac.rightDelimiter = delims[1]
      }
      frac.numerator = list
      frac.denominator = self.buildInternal(oneCharOnly: false, stopChar: stopChar) ?? MTMathList()
      if error != nil { return nil }
      let fracList = MTMathList()
      fracList.addAtom(frac)
      return fracList
    }
    if command == "\\" || command == "cr" {
      if let env = currentEnv {
        // Stop the current list and increment the row count.
        env.numRows += 1
        return list
      } else {
        // Create a new table with the current list and a default env.
        if let table = buildTable(env: nil, firstList: list, isRow: true) {
          return MTMathList.mathList(withAtomsArray: [table])
        }
        return nil
      }
    }
    if command == "end" {
      if currentEnv == nil {
        setError(.missingBegin, message: "Missing \\begin")
        return nil
      }
      guard let env = readEnvironment() else { return nil }
      if env != currentEnv!.envName {
        setError(
          .invalidEnv,
          message:
            "Begin environment name \(currentEnv!.envName ?? "") does not match end name: \(env)")
        return nil
      }
      // Finish the current environment.
      currentEnv!.ended = true
      return list
    }
    return nil
  }

  /// Applies the modifier to the atom. Returns true if a modifier was applied.
  private func applyModifier(_ modifier: String, atom: MTMathAtom?) -> Bool {
    if modifier == "limits" {
      if atom?.type != .largeOperator {
        setError(.invalidLimits, message: "limits can only be applied to an operator.")
      } else if let op = atom as? MTLargeOperator {
        op.limits = true
      }
      return true
    }
    if modifier == "nolimits" {
      if atom?.type != .largeOperator {
        setError(.invalidLimits, message: "nolimits can only be applied to an operator.")
        return true
      } else if let op = atom as? MTLargeOperator {
        op.limits = false
      }
      return true
    }
    return false
  }

  /// Records the first error to occur during parsing. Subsequent errors are ignored.
  private func setError(_ code: MTParseErrors, message: String) {
    // Only record the first error.
    if error == nil {
      error = NSError(
        domain: MTParseError, code: Int(code.rawValue),
        userInfo: [NSLocalizedDescriptionKey: message])
    }
  }

  private func buildTable(env: String?, firstList: MTMathList?, isRow: Bool) -> MTMathAtom? {
    // Save the current env until a new one gets built.
    let oldEnv = currentEnv
    currentEnv = MTEnvProperties(name: env)
    var currentRow = 0
    var currentCol = 0
    var rows: [[MTMathList]] = [[]]
    if let first = firstList {
      rows[currentRow].append(first)
      if isRow {
        currentEnv!.numRows += 1
        currentRow += 1
        rows.append([])
      } else {
        currentCol += 1
      }
    }
    while !currentEnv!.ended && hasCharacters() {
      guard let list = self.buildInternal(oneCharOnly: false) else {
        return nil
      }
      // Pad current row up to currentCol if needed
      while rows[currentRow].count < currentCol {
        rows[currentRow].append(MTMathList())
      }
      if rows[currentRow].count == currentCol {
        rows[currentRow].append(list)
      } else {
        rows[currentRow][currentCol] = list
      }
      currentCol += 1
      if currentEnv!.numRows > currentRow {
        currentRow = currentEnv!.numRows
        if rows.count > currentRow {
          rows[currentRow] = []
        } else {
          rows.append([])
        }
        currentCol = 0
      }
    }
    if !currentEnv!.ended && currentEnv!.envName != nil {
      setError(.missingEnd, message: "Missing \\end")
      return nil
    }
    var tableErr: NSError?
    let table = MTMathAtomFactory.table(
      withEnvironment: currentEnv!.envName, rows: rows, error: &tableErr)
    if table == nil && error == nil {
      error = tableErr
      return nil
    }
    // Reinstate the old env.
    currentEnv = oldEnv
    return table
  }

  // MARK: - Static API

  /// Construct a math list from a given string. If there is a parse error, returns `nil`.
  /// To retrieve the error use `build(fromString:error:)`.
  @objc(buildFromString:)
  public class func build(fromString str: String) -> MTMathList? {
    return MTMathListBuilder(string: str).build()
  }

  /// Construct a math list from a given string. If there is an error while constructing
  /// the string, this returns `nil`. The error is returned in the `error` parameter.
  @objc(buildFromString:error:)
  public class func build(fromString str: String, error: NSErrorPointer) -> MTMathList? {
    let builder = MTMathListBuilder(string: str)
    let output = builder.build()
    if let e = builder.error {
      error?.pointee = e
      return nil
    }
    return output
  }

  // MARK: - Output

  private static let spaceToCommands: [Int: String] = [
    3: ",", 4: ">", 5: ";", -3: "!", 18: "quad", 36: "qquad",
  ]

  private static let styleToCommands: [MTLineStyle: String] = [
    .display: "displaystyle", .text: "textstyle",
    .script: "scriptstyle", .scriptScript: "scriptscriptstyle",
  ]

  private class func delimToString(_ delim: MTMathAtom) -> String {
    if let command = MTMathAtomFactory.delimiterName(forBoundaryAtom: delim) {
      let singleChars: Set<String> = ["(", ")", "[", "]", "<", ">", "|", ".", "/"]
      if singleChars.contains(command) {
        return command
      }
      if command == "||" { return "\\|" }
      return "\\\(command)"
    }
    return ""
  }

  /// Converts the `MTMathList` to LaTeX.
  @objc(mathListToString:)
  public class func mathList(toString ml: MTMathList) -> String {
    var s = ""
    var currentFontStyle: MTFontStyle = .default
    for atom in ml.atoms {
      if currentFontStyle != atom.fontStyle {
        if currentFontStyle != .default {
          // Close the previous font style.
          s += "}"
        }
        if atom.fontStyle != .default {
          // Open new font style.
          let name = MTMathAtomFactory.fontName(for: atom.fontStyle)
          s += "\\\(name){"
        }
        currentFontStyle = atom.fontStyle
      }
      if atom.type == .fraction {
        let frac = atom as! MTFraction
        if frac.hasRule {
          let cmd: String
          switch frac.fracStyle {
          case .display: cmd = "dfrac"
          case .text: cmd = "tfrac"
          default: cmd = "frac"
          }
          s +=
            "\\\(cmd){\(self.mathList(toString: frac.numerator))}{\(self.mathList(toString: frac.denominator))}"
        } else {
          let command: String
          if frac.leftDelimiter == nil && frac.rightDelimiter == nil {
            command = "atop"
          } else if frac.leftDelimiter == "(" && frac.rightDelimiter == ")" {
            command = "choose"
          } else if frac.leftDelimiter == "{" && frac.rightDelimiter == "}" {
            command = "brace"
          } else if frac.leftDelimiter == "[" && frac.rightDelimiter == "]" {
            command = "brack"
          } else {
            command =
              "atopwithdelims\(frac.leftDelimiter ?? "")\(frac.rightDelimiter ?? "")"
          }
          s +=
            "{\(self.mathList(toString: frac.numerator)) \\\(command) \(self.mathList(toString: frac.denominator))}"
        }
      } else if atom.type == .radical {
        s += "\\sqrt"
        let rad = atom as! MTRadical
        if let degree = rad.degree {
          s += "[\(self.mathList(toString: degree))]"
        }
        s += "{\(self.mathList(toString: rad.radicand ?? MTMathList()))}"
      } else if atom.type == .inner {
        let inner = atom as! MTInner
        if inner.leftBoundary != nil || inner.rightBoundary != nil {
          if let lb = inner.leftBoundary {
            s += "\\left\(self.delimToString(lb)) "
          } else {
            s += "\\left. "
          }
          s += self.mathList(toString: inner.innerList ?? MTMathList())
          if let rb = inner.rightBoundary {
            s += "\\right\(self.delimToString(rb)) "
          } else {
            s += "\\right. "
          }
        } else {
          s += "{\(self.mathList(toString: inner.innerList ?? MTMathList()))}"
        }
      } else if atom.type == .table {
        let table = atom as! MTMathTable
        if let env = table.environment {
          s += "\\begin{\(env)}"
        }
        for i in 0..<Int(table.numRows()) {
          let row = table.cells[i]
          for j in 0..<row.count {
            var cell = row[j]
            if table.environment == "matrix" {
              if cell.atoms.count >= 1 && cell.atoms[0].type == .style {
                let atomsArr = Array(cell.atoms.dropFirst())
                cell = MTMathList.mathList(withAtomsArray: atomsArr)
              }
            }
            if table.environment == "eqalign" || table.environment == "aligned"
              || table.environment == "split"
            {
              if j == 1 && cell.atoms.count >= 1 && cell.atoms[0].type == .ordinary
                && cell.atoms[0].nucleus.isEmpty
              {
                let atomsArr = Array(cell.atoms.dropFirst())
                cell = MTMathList.mathList(withAtomsArray: atomsArr)
              }
            }
            s += self.mathList(toString: cell)
            if j < row.count - 1 {
              s += "&"
            }
          }
          if i < Int(table.numRows()) - 1 {
            s += "\\\\ "
          }
        }
        if let env = table.environment {
          s += "\\end{\(env)}"
        }
      } else if atom.type == .overline {
        s += "\\overline"
        let over = atom as! MTOverLine
        s += "{\(self.mathList(toString: over.innerList ?? MTMathList()))}"
      } else if atom.type == .underline {
        s += "\\underline"
        let under = atom as! MTUnderLine
        s += "{\(self.mathList(toString: under.innerList ?? MTMathList()))}"
      } else if atom.type == .accent {
        let accent = atom as! MTAccent
        let name = MTMathAtomFactory.accentName(accent) ?? ""
        s += "\\\(name){\(self.mathList(toString: accent.innerList ?? MTMathList()))}"
      } else if atom.type == .largeOperator {
        let op = atom as! MTLargeOperator
        let command = MTMathAtomFactory.latexSymbolName(for: atom) ?? ""
        let originalOp =
          MTMathAtomFactory.atom(forLatexSymbolName: command) as? MTLargeOperator
        s += "\\\(command) "
        if originalOp?.limits != op.limits {
          s += op.limits ? "\\limits " : "\\nolimits "
        }
      } else if atom.type == .space {
        let space = atom as! MTMathSpace
        let intSpace = Int(space.space)
        if let cmd = MTMathListBuilder.spaceToCommands[intSpace] {
          s += "\\\(cmd) "
        } else {
          s += String(format: "\\mkern%.1fmu", Double(space.space))
        }
      } else if atom.type == .style {
        let style = atom as! MTMathStyle
        if let cmd = MTMathListBuilder.styleToCommands[style.style] {
          s += "\\\(cmd) "
        }
      } else if atom.nucleus.isEmpty {
        s += "{}"
      } else if atom.nucleus == "\u{2236}" {
        // Math colon.
        s += ":"
      } else if atom.nucleus == "\u{2212}" {
        // Math minus.
        s += "-"
      } else {
        if let command = MTMathAtomFactory.latexSymbolName(for: atom) {
          s += "\\\(command) "
        } else {
          s += atom.nucleus
        }
      }

      if let sup = atom.superScript {
        s += "^{\(self.mathList(toString: sup))}"
      }
      if let sub = atom.subScript {
        s += "_{\(self.mathList(toString: sub))}"
      }
    }
    if currentFontStyle != .default {
      s += "}"
    }
    return s
  }
}
