import Foundation

public let MTParseError = "ParseError"

@objc public enum MTParseErrors: UInt {
  case mismatchBraces = 1
  case invalidCommand
  case characterNotFound
  case missingDelimiter
  case invalidDelimiter
  case missingRight
  case missingLeft
  case invalidEnv
  case missingEnv
  case missingBegin
  case missingEnd
  case invalidNumColumns
  case internalError
  case invalidLimits
}

private final class MTEnvProperties {
  let envName: String?
  var ended: Bool = false
  var numRows: Int = 0
  init(name: String?) {
    self.envName = name
  }
}

@objc(MTMathListBuilder)
public final class MTMathListBuilder: NSObject {

  @objc public private(set) var error: NSError?

  private var chars: [unichar]
  private var currentChar: Int = 0
  private var length: Int { return chars.count }
  private var currentInnerAtom: MTInner?
  private var currentEnv: MTEnvProperties?
  private var currentFontStyle: MTFontStyle = .default
  private var spacesAllowed: Bool = false

  @objc(initWithString:)
  public init(string str: String) {
    let nsstr = str as NSString
    var buf = [unichar](repeating: 0, count: nsstr.length)
    nsstr.getCharacters(&buf, range: NSRange(location: 0, length: nsstr.length))
    self.chars = buf
    super.init()
  }

  private func hasCharacters() -> Bool { return currentChar < length }

  private func getNextCharacter() -> unichar {
    let c = chars[currentChar]
    currentChar += 1
    return c
  }

  private func unlookCharacter() {
    currentChar -= 1
  }

  @objc public func build() -> MTMathList? {
    let list = self.buildInternal(oneCharOnly: false)
    if hasCharacters() && error == nil {
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
          unlookCharacter()
          return list
        }
      }
      if stopChar > 0 && ch == stopChar {
        return list
      }

      if ch == UInt16(ascii: "^") {
        if prevAtom == nil || prevAtom!.superScript != nil || !prevAtom!.scriptsAllowed() {
          prevAtom = MTMathAtom.atom(type: .ordinary, value: "")
          list.addAtom(prevAtom!)
        }
        prevAtom!.superScript = self.buildInternal(oneCharOnly: true)
        continue
      } else if ch == UInt16(ascii: "_") {
        if prevAtom == nil || prevAtom!.subScript != nil || !prevAtom!.scriptsAllowed() {
          prevAtom = MTMathAtom.atom(type: .ordinary, value: "")
          list.addAtom(prevAtom!)
        }
        prevAtom!.subScript = self.buildInternal(oneCharOnly: true)
        continue
      } else if ch == UInt16(ascii: "{") {
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
        setError(.mismatchBraces, message: "Mismatched braces.")
        return nil
      } else if ch == UInt16(ascii: "\\") {
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
          spacesAllowed = (command == "text")
          let oldFontStyle = currentFontStyle
          currentFontStyle = fontStyle
          let sublist = self.buildInternal(oneCharOnly: true)
          currentFontStyle = oldFontStyle
          spacesAllowed = oldSpacesAllowed
          prevAtom = sublist?.atoms.last
          if let s = sublist { list.append(s) }
          if oneCharOnly { return list }
          continue
        }
        atom = atomForCommand(command)
        if atom == nil {
          setError(.internalError, message: "Internal error")
          return nil
        }
      } else if ch == UInt16(ascii: "&") {
        if currentEnv != nil {
          return list
        } else {
          if let table = buildTable(env: nil, firstList: list, isRow: false) {
            return MTMathList.mathList(withAtomsArray: [table])
          }
          return nil
        }
      } else if spacesAllowed && ch == UInt16(ascii: " ") {
        atom = MTMathAtomFactory.atom(forLatexSymbolName: " ")
      } else {
        atom = MTMathAtomFactory.atom(forCharacter: ch)
        if atom == nil { continue }
      }

      atom!.fontStyle = currentFontStyle
      list.addAtom(atom!)
      prevAtom = atom

      if oneCharOnly { return list }
    }
    if stopChar > 0 {
      if stopChar == UInt16(ascii: "}") {
        setError(.mismatchBraces, message: "Missing closing brace")
      } else {
        setError(.characterNotFound, message: "Expected character not found: \(stopChar)")
      }
    }
    return list
  }

  private func readString() -> String {
    var s: [unichar] = []
    while hasCharacters() {
      let ch = getNextCharacter()
      if (ch >= UInt16(ascii: "a") && ch <= UInt16(ascii: "z"))
        || (ch >= UInt16(ascii: "A") && ch <= UInt16(ascii: "Z"))
      {
        s.append(ch)
      } else {
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

  private func skipSpaces() {
    while hasCharacters() {
      let ch = getNextCharacter()
      if ch < 0x21 || ch > 0x7E { continue }
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
        let command = readCommand()
        if command == "|" { return "||" }
        return command
      } else {
        return String(utf16CodeUnits: [ch], count: 1)
      }
    }
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
      let frac = MTFraction(rule: false)
      frac.numerator = self.buildInternal(oneCharOnly: true) ?? MTMathList()
      frac.denominator = self.buildInternal(oneCharOnly: true) ?? MTMathList()
      frac.leftDelimiter = "("
      frac.rightDelimiter = ")"
      return frac
    case "sqrt":
      let rad = MTRadical()
      let ch = getNextCharacter()
      if ch == UInt16(ascii: "[") {
        rad.degree = self.buildInternal(oneCharOnly: false, stopChar: UInt16(ascii: "]"))
        rad.radicand = self.buildInternal(oneCharOnly: true)
      } else {
        unlookCharacter()
        rad.radicand = self.buildInternal(oneCharOnly: true)
      }
      return rad
    case "left":
      let oldInner = currentInnerAtom
      currentInnerAtom = MTInner()
      let leftBoundary = getBoundaryAtom(delimiterType: "left")
      if leftBoundary == nil { return nil }
      currentInnerAtom!.leftBoundary = leftBoundary
      currentInnerAtom!.innerList = self.buildInternal(oneCharOnly: false)
      if currentInnerAtom!.rightBoundary == nil {
        setError(.missingRight, message: "Missing \\right")
        return nil
      }
      let newInner = currentInnerAtom!
      currentInnerAtom = oldInner
      return newInner
    case "overline":
      let over = MTOverLine()
      over.innerList = self.buildInternal(oneCharOnly: true)
      return over
    case "underline":
      let under = MTUnderLine()
      under.innerList = self.buildInternal(oneCharOnly: true)
      return under
    case "begin":
      guard let env = readEnvironment() else { return nil }
      return buildTable(env: env, firstList: nil, isRow: false)
    case "color":
      let mc = MTMathColor()
      mc.colorString = readColor()
      mc.innerList = self.buildInternal(oneCharOnly: true)
      return mc
    case "colorbox":
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
        env.numRows += 1
        return list
      } else {
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
      currentEnv!.ended = true
      return list
    }
    return nil
  }

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

  private func setError(_ code: MTParseErrors, message: String) {
    if error == nil {
      error = NSError(
        domain: MTParseError, code: Int(code.rawValue),
        userInfo: [NSLocalizedDescriptionKey: message])
    }
  }

  private func buildTable(env: String?, firstList: MTMathList?, isRow: Bool) -> MTMathAtom? {
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
    currentEnv = oldEnv
    return table
  }

  // MARK: - Static API

  @objc(buildFromString:)
  public class func build(fromString str: String) -> MTMathList? {
    return MTMathListBuilder(string: str).build()
  }

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

  @objc(mathListToString:)
  public class func mathList(toString ml: MTMathList) -> String {
    var s = ""
    var currentFontStyle: MTFontStyle = .default
    for atom in ml.atoms {
      if currentFontStyle != atom.fontStyle {
        if currentFontStyle != .default {
          s += "}"
        }
        if atom.fontStyle != .default {
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
        s += ":"
      } else if atom.nucleus == "\u{2212}" {
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
