import Foundation
import Testing
import iosMathCore
import iosMathCoreTestSupport

// MARK: - MTMathList

@Suite("MTMathList")
struct MathListTests {

  @Test func finalized() throws {
    let str = "-52x^{13+y}_{15-} + (-12.3 *)\\frac{-12}{15.2}"
    let raw = try #require(MTMathListBuilder(string: str).build())
    let list = raw.finalized()
    checkFinalizedList(list)
    checkFinalizedList(list.finalized())
  }

  @Test func add() {
    let list = MTMathList()
    #expect(list.atoms.count == 0)

    let a1 = MTMathAtomFactory.placeholder()
    list.addAtom(a1)
    #expect(list.atoms.count == 1)
    #expect(list.atoms[0] === a1)

    let a2 = MTMathAtomFactory.placeholder()
    list.addAtom(a2)
    #expect(list.atoms.count == 2)
    #expect(list.atoms[0] === a1)
    #expect(list.atoms[1] === a2)
  }

  @Test func addErrors() {
    let list = MTMathList()
    let boundary = MTMathAtom(type: .boundary, value: "")
    #expect(ObjCExceptionCatcher.catchException { list.addAtom(boundary) })
  }

  @Test func insert() {
    let list = MTMathList()
    let a1 = MTMathAtomFactory.placeholder()
    list.insertAtom(a1, at: 0)
    #expect(list.atoms.count == 1)
    #expect(list.atoms[0] === a1)

    let a2 = MTMathAtomFactory.placeholder()
    list.insertAtom(a2, at: 0)
    #expect(list.atoms.count == 2)
    #expect(list.atoms[0] === a2)
    #expect(list.atoms[1] === a1)

    let a3 = MTMathAtomFactory.placeholder()
    list.insertAtom(a3, at: 2)
    #expect(list.atoms.count == 3)
    #expect(list.atoms[0] === a2)
    #expect(list.atoms[1] === a1)
    #expect(list.atoms[2] === a3)
  }

  @Test func insertErrors() {
    let list = MTMathList()
    let boundary = MTMathAtom(type: .boundary, value: "")
    #expect(ObjCExceptionCatcher.catchException { list.insertAtom(boundary, at: 0) })
    let valid = MTMathAtomFactory.placeholder()
    #expect(ObjCExceptionCatcher.catchException { list.insertAtom(valid, at: 1) })
  }

  @Test func append() {
    let list1 = MTMathList()
    let a1 = MTMathAtomFactory.placeholder()
    let a2 = MTMathAtomFactory.placeholder()
    let a3 = MTMathAtomFactory.placeholder()
    list1.addAtom(a1)
    list1.addAtom(a2)
    list1.addAtom(a3)

    let list2 = MTMathList()
    let a4 = MTMathAtomFactory.times()
    let a5 = MTMathAtomFactory.divide()
    list2.addAtom(a4)
    list2.addAtom(a5)

    #expect(list1.atoms.count == 3)
    #expect(list2.atoms.count == 2)
    list1.append(list2)
    #expect(list1.atoms.count == 5)
    #expect(list1.atoms[3] === a4)
    #expect(list1.atoms[4] === a5)
  }

  @Test func removeLast() {
    let list = MTMathList()
    let a = MTMathAtomFactory.placeholder()
    list.addAtom(a)
    #expect(list.atoms.count == 1)
    list.removeLastAtom()
    #expect(list.atoms.count == 0)
    list.removeLastAtom()
    #expect(list.atoms.count == 0)

    let b = MTMathAtomFactory.placeholder()
    list.addAtom(a)
    list.addAtom(b)
    #expect(list.atoms.count == 2)
    list.removeLastAtom()
    #expect(list.atoms.count == 1)
    #expect(list.atoms[0] === a)
  }

  @Test func removeAtAtIndex() {
    let list = MTMathList()
    let a1 = MTMathAtomFactory.placeholder()
    let a2 = MTMathAtomFactory.placeholder()
    list.addAtom(a1)
    list.addAtom(a2)
    #expect(list.atoms.count == 2)
    list.removeAtom(at: 0)
    #expect(list.atoms.count == 1)
    #expect(list.atoms[0] === a2)
    #expect(ObjCExceptionCatcher.catchException { list.removeAtom(at: 2) })
  }

  @Test func removeAtomsInRange() {
    let list = MTMathList()
    let a1 = MTMathAtomFactory.placeholder()
    let a2 = MTMathAtomFactory.placeholder()
    let a3 = MTMathAtomFactory.placeholder()
    list.addAtom(a1)
    list.addAtom(a2)
    list.addAtom(a3)
    #expect(list.atoms.count == 3)
    list.removeAtoms(in: NSRange(location: 1, length: 2))
    #expect(list.atoms.count == 1)
    #expect(list.atoms[0] === a1)
    #expect(
      ObjCExceptionCatcher.catchException { list.removeAtoms(in: NSRange(location: 1, length: 3)) })
  }

  @Test func copy() {
    let list = MTMathList()
    list.addAtom(MTMathAtomFactory.placeholder())
    list.addAtom(MTMathAtomFactory.times())
    list.addAtom(MTMathAtomFactory.divide())

    let copy = list.copy() as! MTMathList
    checkListCopy(copy, original: list)
  }

  // MARK: Private helper

  private func checkFinalizedList(_ list: MTMathList) {
    #expect(list.atoms.count == 10)

    let a0 = list.atoms[0]
    #expect(a0.type == .unaryOperator)
    #expect(a0.nucleus == "−")
    #expect(a0.indexRange == NSRange(location: 0, length: 1))

    let a1 = list.atoms[1]
    #expect(a1.type == .number)
    #expect(a1.nucleus == "52")
    #expect(a1.indexRange == NSRange(location: 1, length: 2))

    let a2 = list.atoms[2]
    #expect(a2.type == .variable)
    #expect(a2.nucleus == "x")
    #expect(a2.indexRange == NSRange(location: 3, length: 1))

    let superScr = a2.superScript!
    #expect(superScr.atoms.count == 3)
    #expect(superScr.atoms[0].type == .number)
    #expect(superScr.atoms[0].nucleus == "13")
    #expect(superScr.atoms[0].indexRange == NSRange(location: 0, length: 2))
    #expect(superScr.atoms[1].type == .binaryOperator)
    #expect(superScr.atoms[1].nucleus == "+")
    #expect(superScr.atoms[2].type == .variable)
    #expect(superScr.atoms[2].nucleus == "y")

    let subScr = a2.subScript!
    #expect(subScr.atoms.count == 2)
    #expect(subScr.atoms[0].type == .number)
    #expect(subScr.atoms[0].nucleus == "15")
    #expect(subScr.atoms[1].type == .unaryOperator)
    #expect(subScr.atoms[1].nucleus == "−")

    #expect(list.atoms[3].type == .binaryOperator)
    #expect(list.atoms[3].nucleus == "+")
    #expect(list.atoms[4].type == .open)
    #expect(list.atoms[4].nucleus == "(")
    #expect(list.atoms[5].type == .unaryOperator)
    #expect(list.atoms[5].nucleus == "−")
    #expect(list.atoms[6].type == .number)
    #expect(list.atoms[6].nucleus == "12.3")
    #expect(list.atoms[7].type == .unaryOperator)
    #expect(list.atoms[7].nucleus == "*")
    #expect(list.atoms[8].type == .close)
    #expect(list.atoms[8].nucleus == ")")

    let frac = list.atoms[9] as! MTFraction
    #expect(frac.type == .fraction)
    #expect(frac.indexRange == NSRange(location: 13, length: 1))

    let numer = frac.numerator
    #expect(numer.atoms.count == 2)
    #expect(numer.atoms[0].type == .unaryOperator)
    #expect(numer.atoms[0].nucleus == "−")
    #expect(numer.atoms[1].type == .number)
    #expect(numer.atoms[1].nucleus == "12")

    let denom = frac.denominator
    #expect(denom.atoms.count == 1)
    #expect(denom.atoms[0].type == .number)
    #expect(denom.atoms[0].nucleus == "15.2")
  }
}

// MARK: - MTMathAtom

@Suite("MTMathAtom")
struct MathAtomTests {

  @Test func atomInit() {
    let open = MTMathAtom(type: .open, value: "(")
    #expect(open.nucleus == "(")
    #expect(open.type == .open)

    let radical = MTMathAtom(type: .radical, value: "(")
    #expect(radical.nucleus == "")
    #expect(radical.type == .radical)
  }

  @Test func atomScripts() {
    var atom = MTMathAtom(type: .open, value: "(")
    #expect(atom.scriptsAllowed())
    atom.subScript = MTMathList()
    #expect(atom.subScript != nil)
    atom.superScript = MTMathList()
    #expect(atom.superScript != nil)

    atom = MTMathAtom(type: .boundary, value: "(")
    #expect(!atom.scriptsAllowed())
    atom.subScript = nil
    #expect(atom.subScript == nil)
    atom.superScript = nil
    #expect(atom.superScript == nil)

    let list = MTMathList()
    #expect(ObjCExceptionCatcher.catchException { atom.subScript = list })
    #expect(ObjCExceptionCatcher.catchException { atom.superScript = list })
  }

  @Test func atomCopy() {
    let list = makeSampleList()
    let list2 = makeShortList()
    let atom = MTMathAtom(type: .open, value: "(")
    atom.subScript = list
    atom.superScript = list2
    let copy = atom.copy() as! MTMathAtom
    checkAtomCopy(copy, original: atom)
    checkListCopy(copy.superScript!, original: atom.superScript!)
    checkListCopy(copy.subScript!, original: atom.subScript!)
  }

  @Test func copyFraction() {
    let frac = MTFraction(rule: false)
    #expect(frac.type == .fraction)
    frac.numerator = makeSampleList()
    frac.denominator = makeShortList()
    frac.leftDelimiter = "a"
    frac.rightDelimiter = "b"
    let copy = frac.copy() as! MTFraction
    checkAtomCopy(copy, original: frac)
    checkListCopy(copy.numerator, original: frac.numerator)
    checkListCopy(copy.denominator, original: frac.denominator)
    #expect(!copy.hasRule)
    #expect(copy.leftDelimiter == "a")
    #expect(copy.rightDelimiter == "b")
  }

  @Test func copyRadical() {
    let rad = MTRadical()
    #expect(rad.type == .radical)
    rad.radicand = makeSampleList()
    rad.degree = makeShortList()
    let copy = rad.copy() as! MTRadical
    checkAtomCopy(copy, original: rad)
    checkListCopy(copy.radicand!, original: rad.radicand!)
    checkListCopy(copy.degree!, original: rad.degree!)
  }

  @Test func copyLargeOperator() {
    let lg = MTLargeOperator(value: "lim", limits: true)
    #expect(lg.type == .largeOperator)
    #expect(lg.limits)
    let copy = lg.copy() as! MTLargeOperator
    checkAtomCopy(copy, original: lg)
    #expect(copy.limits == lg.limits)
  }

  @Test func copyInner() {
    let inner = MTInner()
    inner.innerList = makeSampleList()
    inner.leftBoundary = MTMathAtom(type: .boundary, value: "(")
    inner.rightBoundary = MTMathAtom(type: .boundary, value: ")")
    #expect(inner.type == .inner)
    let copy = inner.copy() as! MTInner
    checkAtomCopy(copy, original: inner)
    checkListCopy(copy.innerList!, original: inner.innerList!)
    checkAtomCopy(copy.leftBoundary!, original: inner.leftBoundary!)
    checkAtomCopy(copy.rightBoundary!, original: inner.rightBoundary!)
  }

  @Test func setInnerBoundary() {
    let inner = MTInner()
    inner.leftBoundary = MTMathAtom(type: .boundary, value: "(")
    inner.rightBoundary = MTMathAtom(type: .boundary, value: ")")
    #expect(inner.leftBoundary != nil)
    #expect(inner.rightBoundary != nil)
    inner.leftBoundary = nil
    inner.rightBoundary = nil
    #expect(inner.leftBoundary == nil)
    #expect(inner.rightBoundary == nil)
    let nonBoundary = MTMathAtomFactory.placeholder()
    #expect(ObjCExceptionCatcher.catchException { inner.leftBoundary = nonBoundary })
    #expect(ObjCExceptionCatcher.catchException { inner.rightBoundary = nonBoundary })
  }

  @Test func copyOverline() {
    let over = MTOverLine()
    #expect(over.type == .overline)
    over.innerList = makeSampleList()
    let copy = over.copy() as! MTOverLine
    checkAtomCopy(copy, original: over)
    checkListCopy(copy.innerList!, original: over.innerList!)
  }

  @Test func copyUnderline() {
    let under = MTUnderLine()
    #expect(under.type == .underline)
    under.innerList = makeSampleList()
    let copy = under.copy() as! MTUnderLine
    checkAtomCopy(copy, original: under)
    checkListCopy(copy.innerList!, original: under.innerList!)
  }

  @Test func copyAccent() {
    let accent = MTAccent(value: "^")
    #expect(accent.type == .accent)
    accent.innerList = makeSampleList()
    let copy = accent.copy() as! MTAccent
    checkAtomCopy(copy, original: accent)
    checkListCopy(copy.innerList!, original: accent.innerList!)
  }

  @Test func copySpace() {
    let space = MTMathSpace(space: 3)
    #expect(space.type == .space)
    let copy = space.copy() as! MTMathSpace
    checkAtomCopy(copy, original: space)
    #expect(copy.space == space.space)
  }

  @Test func copyStyle() {
    let style = MTMathStyle(style: .script)
    #expect(style.type == .style)
    let copy = style.copy() as! MTMathStyle
    checkAtomCopy(copy, original: style)
    #expect(copy.style == style.style)
  }

  @Test func createMathTable() {
    let table = MTMathTable()
    #expect(table.type == .table)

    let list1 = makeSampleList()
    let list2 = makeShortList()
    table.setCell(list1, forRow: 3, column: 2)
    table.setCell(list2, forRow: 1, column: 0)
    table.setAlignment(.left, forColumn: 2)
    table.setAlignment(.right, forColumn: 1)

    #expect(table.cells.count == 4)
    #expect(table.cells[0].count == 0)
    #expect(table.cells[1].count == 1)
    #expect(table.cells[2].count == 0)
    #expect(table.cells[3].count == 3)

    #expect(table.cells[1][0].atoms.count == 2)
    #expect(table.cells[1][0] === list2)
    #expect(table.cells[3][0].atoms.count == 0)
    #expect(table.cells[3][1].atoms.count == 0)
    #expect(table.cells[3][2] === list1)

    #expect(table.numRows() == 4)
    #expect(table.numColumns() == 3)

    #expect(table.alignments.count == 3)
    #expect(table.alignments[0].intValue == MTColumnAlignment.center.rawValue)
    #expect(table.alignments[1].intValue == MTColumnAlignment.right.rawValue)
    #expect(table.alignments[2].intValue == MTColumnAlignment.left.rawValue)
  }

  @Test func copyMathTable() {
    let table = MTMathTable()
    let list1 = makeSampleList()
    let list2 = makeShortList()
    table.setCell(list1, forRow: 0, column: 1)
    table.setCell(list2, forRow: 0, column: 2)
    table.setAlignment(.left, forColumn: 2)
    table.setAlignment(.right, forColumn: 1)
    table.interRowAdditionalSpacing = 3
    table.interColumnSpacing = 10

    let copy = table.copy() as! MTMathTable
    checkAtomCopy(copy, original: table)
    #expect(copy.interColumnSpacing == table.interColumnSpacing)
    #expect(copy.interRowAdditionalSpacing == table.interRowAdditionalSpacing)
    #expect(copy.alignments == table.alignments)
    #expect(copy.cells[0].count == table.cells[0].count)
    #expect(copy.cells[0][0].atoms.count == 0)
    #expect(copy.cells[0][0] !== table.cells[0][0])
    checkListCopy(copy.cells[0][1], original: list1)
    checkListCopy(copy.cells[0][2], original: list2)
  }

  // MARK: Private helpers

  private func makeSampleList() -> MTMathList {
    let list = MTMathList()
    list.addAtom(MTMathAtomFactory.placeholder())
    list.addAtom(MTMathAtomFactory.times())
    list.addAtom(MTMathAtomFactory.divide())
    return list
  }

  private func makeShortList() -> MTMathList {
    let list = MTMathList()
    list.addAtom(MTMathAtomFactory.divide())
    list.addAtom(MTMathAtomFactory.times())
    return list
  }
}
