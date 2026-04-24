import Testing
import Foundation
import iosMathCore
import iosMathCoreTestSupport

// MARK: - Test case types

struct BuilderCase: @unchecked Sendable, CustomTestStringConvertible {
    let input: String
    let types: [MTMathAtomType]
    let latex: String
    var testDescription: String { "\"\(input)\"" }
}

struct SuperScriptCase: @unchecked Sendable, CustomTestStringConvertible {
    let input: String
    let mainTypes: [MTMathAtomType]
    let superTypes: [MTMathAtomType]
    let nestedSuperTypes: [MTMathAtomType]?
    let latex: String
    var testDescription: String { "\"\(input)\"" }
}

struct SubScriptCase: @unchecked Sendable, CustomTestStringConvertible {
    let input: String
    let mainTypes: [MTMathAtomType]
    let subTypes: [MTMathAtomType]
    let nestedSubTypes: [MTMathAtomType]?
    let latex: String
    var testDescription: String { "\"\(input)\"" }
}

struct SuperSubScriptCase: @unchecked Sendable, CustomTestStringConvertible {
    let input: String
    let mainTypes: [MTMathAtomType]
    let subTypes: [MTMathAtomType]
    let superTypes: [MTMathAtomType]
    let latex: String
    var testDescription: String { "\"\(input)\"" }
}

struct LeftRightCase: @unchecked Sendable, CustomTestStringConvertible {
    let input: String
    let outerTypes: [MTMathAtomType]
    let innerLocation: Int
    let innerTypes: [MTMathAtomType]
    let leftBoundary: String
    let rightBoundary: String
    let latex: String
    var testDescription: String { "\"\(input)\"" }
}

struct ParseErrorCase: @unchecked Sendable, CustomTestStringConvertible {
    let input: String
    let error: MTParseErrors
    var testDescription: String { "\"\(input)\"" }
}

// MARK: - Test data

private let builderCases: [BuilderCase] = [
    BuilderCase(input: "x",              types: [.variable],                         latex: "x"),
    BuilderCase(input: "1",              types: [.number],                           latex: "1"),
    BuilderCase(input: "*",              types: [.binaryOperator],                   latex: "*"),
    BuilderCase(input: "+",              types: [.binaryOperator],                   latex: "+"),
    BuilderCase(input: ".",              types: [.number],                           latex: "."),
    BuilderCase(input: "(",              types: [.open],                             latex: "("),
    BuilderCase(input: ")",              types: [.close],                            latex: ")"),
    BuilderCase(input: ",",              types: [.punctuation],                      latex: ","),
    BuilderCase(input: "!",              types: [.close],                            latex: "!"),
    BuilderCase(input: "=",              types: [.relation],                         latex: "="),
    BuilderCase(input: "x+2",           types: [.variable, .binaryOperator, .number], latex: "x+2"),
    BuilderCase(input: "(2.3 * 8)",
                types: [.open, .number, .number, .number, .binaryOperator, .number, .close],
                latex: "(2.3*8)"),
    BuilderCase(input: "5{3+4}",
                types: [.number, .number, .binaryOperator, .number],
                latex: "53+4"),
    BuilderCase(input: "\\pi+\\theta\\geq 3",
                types: [.variable, .binaryOperator, .variable, .relation, .number],
                latex: "\\pi +\\theta \\geq 3"),
    BuilderCase(input: "\\pi\\ne 5 \\land 3",
                types: [.variable, .relation, .number, .binaryOperator, .number],
                latex: "\\pi \\neq 5\\wedge 3"),
    BuilderCase(input: "x \\ y",
                types: [.variable, .ordinary, .variable],
                latex: "x\\  y"),
    BuilderCase(input: "x \\quad y \\; z \\! q",
                types: [.variable, .space, .variable, .space, .variable, .space, .variable],
                latex: "x\\quad y\\; z\\! q"),
]

private let superScriptCases: [SuperScriptCase] = [
    SuperScriptCase(input: "x^2",     mainTypes: [.variable],            superTypes: [.number],                         nestedSuperTypes: nil, latex: "x^{2}"),
    SuperScriptCase(input: "x^23",    mainTypes: [.variable, .number],   superTypes: [.number],                         nestedSuperTypes: nil, latex: "x^{2}3"),
    SuperScriptCase(input: "x^{23}",  mainTypes: [.variable],            superTypes: [.number, .number],                nestedSuperTypes: nil, latex: "x^{23}"),
    SuperScriptCase(input: "x^2^3",   mainTypes: [.variable, .ordinary], superTypes: [.number],                         nestedSuperTypes: nil, latex: "x^{2}{}^{3}"),
    SuperScriptCase(input: "x^{2^3}", mainTypes: [.variable],            superTypes: [.number],                         nestedSuperTypes: [.number], latex: "x^{2^{3}}"),
    SuperScriptCase(input: "x^{^2*}", mainTypes: [.variable],            superTypes: [.ordinary, .binaryOperator],      nestedSuperTypes: [.number], latex: "x^{{}^{2}*}"),
    SuperScriptCase(input: "^2",      mainTypes: [.ordinary],            superTypes: [.number],                         nestedSuperTypes: nil, latex: "{}^{2}"),
    SuperScriptCase(input: "{}^2",    mainTypes: [.ordinary],            superTypes: [.number],                         nestedSuperTypes: nil, latex: "{}^{2}"),
    SuperScriptCase(input: "x^^2",    mainTypes: [.variable, .ordinary], superTypes: [],                                nestedSuperTypes: nil, latex: "x^{}{}^{2}"),
    SuperScriptCase(input: "5{x}^2",  mainTypes: [.number, .variable],   superTypes: [],                                nestedSuperTypes: nil, latex: "5x^{2}"),
]

private let subScriptCases: [SubScriptCase] = [
    SubScriptCase(input: "x_2",     mainTypes: [.variable],            subTypes: [.number],           nestedSubTypes: nil, latex: "x_{2}"),
    SubScriptCase(input: "x_23",    mainTypes: [.variable, .number],   subTypes: [.number],           nestedSubTypes: nil, latex: "x_{2}3"),
    SubScriptCase(input: "x_{23}",  mainTypes: [.variable],            subTypes: [.number, .number],  nestedSubTypes: nil, latex: "x_{23}"),
    SubScriptCase(input: "x_2_3",   mainTypes: [.variable, .ordinary], subTypes: [.number],           nestedSubTypes: nil, latex: "x_{2}{}_{3}"),
    SubScriptCase(input: "x_{2_3}", mainTypes: [.variable],            subTypes: [.number],           nestedSubTypes: [.number], latex: "x_{2_{3}}"),
    SubScriptCase(input: "x_{_2*}", mainTypes: [.variable],            subTypes: [.ordinary, .binaryOperator], nestedSubTypes: [.number], latex: "x_{{}_{2}*}"),
    SubScriptCase(input: "_2",      mainTypes: [.ordinary],            subTypes: [.number],           nestedSubTypes: nil, latex: "{}_{2}"),
    SubScriptCase(input: "{}_2",    mainTypes: [.ordinary],            subTypes: [.number],           nestedSubTypes: nil, latex: "{}_{2}"),
    SubScriptCase(input: "x__2",    mainTypes: [.variable, .ordinary], subTypes: [],                  nestedSubTypes: nil, latex: "x_{}{}_{2}"),
    SubScriptCase(input: "5{x}_2",  mainTypes: [.number, .variable],   subTypes: [],                  nestedSubTypes: nil, latex: "5x_{2}"),
]

private let superSubScriptCases: [SuperSubScriptCase] = [
    SuperSubScriptCase(input: "x_2^*",   mainTypes: [.variable], subTypes: [.number], superTypes: [.binaryOperator], latex: "x^{*}_{2}"),
    SuperSubScriptCase(input: "x^*_2",   mainTypes: [.variable], subTypes: [.number], superTypes: [.binaryOperator], latex: "x^{*}_{2}"),
    SuperSubScriptCase(input: "x_^*",    mainTypes: [.variable], subTypes: [],        superTypes: [.binaryOperator], latex: "x^{*}_{}"),
    SuperSubScriptCase(input: "x^_2",    mainTypes: [.variable], subTypes: [.number], superTypes: [],               latex: "x^{}_{2}"),
    SuperSubScriptCase(input: "x_{2^*}", mainTypes: [.variable], subTypes: [.number], superTypes: [],               latex: "x_{2^{*}}"),
    SuperSubScriptCase(input: "x^{*_2}", mainTypes: [.variable], subTypes: [],        superTypes: [.binaryOperator], latex: "x^{*_{2}}"),
    SuperSubScriptCase(input: "_2^*",    mainTypes: [.ordinary], subTypes: [.number], superTypes: [.binaryOperator], latex: "{}^{*}_{2}"),
]

private let leftRightCases: [LeftRightCase] = [
    LeftRightCase(input: "\\left( 2 \\right)",
                  outerTypes: [.inner], innerLocation: 0, innerTypes: [.number],
                  leftBoundary: "(", rightBoundary: ")",
                  latex: "\\left( 2\\right) "),
    LeftRightCase(input: "\\left ( 2 \\right )",
                  outerTypes: [.inner], innerLocation: 0, innerTypes: [.number],
                  leftBoundary: "(", rightBoundary: ")",
                  latex: "\\left( 2\\right) "),
    LeftRightCase(input: "\\left\\{ 2 \\right\\}",
                  outerTypes: [.inner], innerLocation: 0, innerTypes: [.number],
                  leftBoundary: "{", rightBoundary: "}",
                  latex: "\\left\\{ 2\\right\\} "),
    LeftRightCase(input: "\\left\\langle x \\right\\rangle",
                  outerTypes: [.inner], innerLocation: 0, innerTypes: [.variable],
                  leftBoundary: "\u{2329}", rightBoundary: "\u{232A}",
                  latex: "\\left< x\\right> "),
    LeftRightCase(input: "\\left| x \\right\\|",
                  outerTypes: [.inner], innerLocation: 0, innerTypes: [.variable],
                  leftBoundary: "|", rightBoundary: "\u{2016}",
                  latex: "\\left| x\\right\\| "),
    LeftRightCase(input: "5 + \\left( 2 \\right) - 2",
                  outerTypes: [.number, .binaryOperator, .inner, .binaryOperator, .number],
                  innerLocation: 2, innerTypes: [.number],
                  leftBoundary: "(", rightBoundary: ")",
                  latex: "5+\\left( 2\\right) -2"),
    LeftRightCase(input: "\\left( 2 + \\frac12\\right)",
                  outerTypes: [.inner], innerLocation: 0,
                  innerTypes: [.number, .binaryOperator, .fraction],
                  leftBoundary: "(", rightBoundary: ")",
                  latex: "\\left( 2+\\frac{1}{2}\\right) "),
    LeftRightCase(input: "\\left[ 2 + \\left|\\frac{-x}{2}\\right| \\right]",
                  outerTypes: [.inner], innerLocation: 0,
                  innerTypes: [.number, .binaryOperator, .inner],
                  leftBoundary: "[", rightBoundary: "]",
                  latex: "\\left[ 2+\\left| \\frac{-x}{2}\\right| \\right] "),
    LeftRightCase(input: "\\left( 2 \\right)^2",
                  outerTypes: [.inner], innerLocation: 0, innerTypes: [.number],
                  leftBoundary: "(", rightBoundary: ")",
                  latex: "\\left( 2\\right) ^{2}"),
    LeftRightCase(input: "\\left(^2 \\right )",
                  outerTypes: [.inner], innerLocation: 0, innerTypes: [.ordinary],
                  leftBoundary: "(", rightBoundary: ")",
                  latex: "\\left( {}^{2}\\right) "),
    LeftRightCase(input: "\\left( 2 \\right.",
                  outerTypes: [.inner], innerLocation: 0, innerTypes: [.number],
                  leftBoundary: "(", rightBoundary: "",
                  latex: "\\left( 2\\right. "),
]

private let parseErrorCases: [ParseErrorCase] = [
    ParseErrorCase(input: "}a",                                              error: .mismatchBraces),
    ParseErrorCase(input: "\\notacommand",                                   error: .invalidCommand),
    ParseErrorCase(input: "\\sqrt[5+3",                                      error: .characterNotFound),
    ParseErrorCase(input: "{5+3",                                            error: .mismatchBraces),
    ParseErrorCase(input: "5+3}",                                            error: .mismatchBraces),
    ParseErrorCase(input: "{1+\\frac{3+2",                                   error: .mismatchBraces),
    ParseErrorCase(input: "1+\\left",                                        error: .missingDelimiter),
    ParseErrorCase(input: "\\left(\\frac12\\right",                          error: .missingDelimiter),
    ParseErrorCase(input: "\\left 5 + 3 \\right)",                           error: .invalidDelimiter),
    ParseErrorCase(input: "\\left(\\frac12\\right + 3",                      error: .invalidDelimiter),
    ParseErrorCase(input: "\\left\\lmoustache 5 + 3 \\right)",               error: .invalidDelimiter),
    ParseErrorCase(input: "\\left(\\frac12\\right\\rmoustache + 3",          error: .invalidDelimiter),
    ParseErrorCase(input: "5 + 3 \\right)",                                  error: .missingLeft),
    ParseErrorCase(input: "\\left(\\frac12",                                 error: .missingRight),
    ParseErrorCase(input: "\\left(5 + \\left| \\frac12 \\right)",            error: .missingRight),
    ParseErrorCase(input: "5+ \\left|\\frac12\\right| \\right)",             error: .missingLeft),
    ParseErrorCase(input: "\\begin matrix \\end matrix",                     error: .characterNotFound),
    ParseErrorCase(input: "\\begin",                                         error: .characterNotFound),
    ParseErrorCase(input: "\\begin{",                                        error: .characterNotFound),
    ParseErrorCase(input: "\\begin{matrix parens}",                          error: .characterNotFound),
    ParseErrorCase(input: "\\begin{matrix} x",                              error: .missingEnd),
    ParseErrorCase(input: "\\begin{matrix} x \\end",                        error: .characterNotFound),
    ParseErrorCase(input: "\\begin{matrix} x \\end + 3",                    error: .characterNotFound),
    ParseErrorCase(input: "\\begin{matrix} x \\end{",                       error: .characterNotFound),
    ParseErrorCase(input: "\\begin{matrix} x \\end{matrix + 3",             error: .characterNotFound),
    ParseErrorCase(input: "\\begin{matrix} x \\end{pmatrix}",               error: .invalidEnv),
    ParseErrorCase(input: "x \\end{matrix}",                                error: .missingBegin),
    ParseErrorCase(input: "\\begin{notanenv} x \\end{notanenv}",            error: .invalidEnv),
    ParseErrorCase(input: "\\begin{matrix} \\notacommand \\end{matrix}",    error: .invalidCommand),
    ParseErrorCase(input: "\\begin{displaylines} x & y \\end{displaylines}", error: .invalidNumColumns),
    ParseErrorCase(input: "\\begin{eqalign} x \\end{eqalign}",             error: .invalidNumColumns),
    ParseErrorCase(input: "\\nolimits",                                      error: .invalidLimits),
    ParseErrorCase(input: "\\frac\\limits{1}{2}",                           error: .invalidLimits),
]

// MARK: - Tests

@Suite("MathListBuilder")
struct MathListBuilderTests {

    // MARK: Basic

    @Test(arguments: builderCases)
    func builder(_ tc: BuilderCase) throws {
        let builder = MTMathListBuilder(string: tc.input)
        let list = try #require(builder.build(), "parse failed for \"\(tc.input)\"")
        #expect(builder.error == nil)
        checkAtomTypes(list, types: tc.types)
        #expect(MTMathListBuilder.mathList(toString: list) == tc.latex)
    }

    // MARK: Scripts

    @Test(arguments: superScriptCases)
    func superScript(_ tc: SuperScriptCase) throws {
        let builder = MTMathListBuilder(string: tc.input)
        let list = try #require(builder.build())
        #expect(builder.error == nil)
        checkAtomTypes(list, types: tc.mainTypes)

        let first = list.atoms[0]
        if !tc.superTypes.isEmpty {
            #expect(first.superScript != nil)
        }
        let superList = first.superScript
        checkAtomTypes(superList ?? MTMathList(), types: tc.superTypes)

        if let nested = tc.nestedSuperTypes {
            let superFirst = try #require(superList?.atoms[0])
            checkAtomTypes(superFirst.superScript ?? MTMathList(), types: nested)
        }

        #expect(MTMathListBuilder.mathList(toString: list) == tc.latex)
    }

    @Test(arguments: subScriptCases)
    func subScript(_ tc: SubScriptCase) throws {
        let builder = MTMathListBuilder(string: tc.input)
        let list = try #require(builder.build())
        #expect(builder.error == nil)
        checkAtomTypes(list, types: tc.mainTypes)

        let first = list.atoms[0]
        if !tc.subTypes.isEmpty {
            #expect(first.subScript != nil)
        }
        let subList = first.subScript
        checkAtomTypes(subList ?? MTMathList(), types: tc.subTypes)

        if let nested = tc.nestedSubTypes {
            let subFirst = try #require(subList?.atoms[0])
            checkAtomTypes(subFirst.subScript ?? MTMathList(), types: nested)
        }

        #expect(MTMathListBuilder.mathList(toString: list) == tc.latex)
    }

    @Test(arguments: superSubScriptCases)
    func superSubScript(_ tc: SuperSubScriptCase) throws {
        let list = try #require(MTMathListBuilder(string: tc.input).build())
        checkAtomTypes(list, types: tc.mainTypes)

        let first = list.atoms[0]
        if !tc.subTypes.isEmpty {
            let subList = try #require(first.subScript)
            checkAtomTypes(subList, types: tc.subTypes)
        }
        if !tc.superTypes.isEmpty {
            let superList = try #require(first.superScript)
            checkAtomTypes(superList, types: tc.superTypes)
        }

        #expect(MTMathListBuilder.mathList(toString: list) == tc.latex)
    }

    // MARK: Symbols

    @Test func symbols() throws {
        let list = try #require(MTMathListBuilder(string: "5\\times3^{2\\div2}").build())
        #expect(list.atoms.count == 3)

        let a0 = list.atoms[0]
        #expect(a0.type == .number)
        #expect(a0.nucleus == "5")

        let a1 = list.atoms[1]
        #expect(a1.type == .binaryOperator)
        #expect(a1.nucleus == "\u{00D7}")

        let a2 = list.atoms[2]
        #expect(a2.type == .number)
        #expect(a2.nucleus == "3")

        let superList = try #require(a2.superScript)
        #expect(superList.atoms.count == 3)
        #expect(superList.atoms[0].type == .number);    #expect(superList.atoms[0].nucleus == "2")
        #expect(superList.atoms[1].type == .binaryOperator); #expect(superList.atoms[1].nucleus == "\u{00F7}")
        #expect(superList.atoms[2].type == .number);    #expect(superList.atoms[2].nucleus == "2")
    }

    // MARK: Fractions

    @Test func frac() throws {
        let list = try #require(MTMathListBuilder(string: "\\frac1c").build())
        #expect(list.atoms.count == 1)
        let frac = try #require(list.atoms[0] as? MTFraction)
        #expect(frac.type == .fraction)
        #expect(frac.nucleus == "")
        #expect(frac.hasRule)
        #expect(frac.rightDelimiter == nil)
        #expect(frac.leftDelimiter == nil)

        let numer = frac.numerator
        #expect(numer.atoms.count == 1)
        #expect(numer.atoms[0].type == .number)
        #expect(numer.atoms[0].nucleus == "1")

        let denom = frac.denominator
        #expect(denom.atoms.count == 1)
        #expect(denom.atoms[0].type == .variable)
        #expect(denom.atoms[0].nucleus == "c")

        #expect(MTMathListBuilder.mathList(toString: list) == "\\frac{1}{c}")
    }

    @Test func fracInFrac() throws {
        let list = try #require(MTMathListBuilder(string: "\\frac1\\frac23").build())
        #expect(list.atoms.count == 1)
        let outerFrac = try #require(list.atoms[0] as? MTFraction)
        #expect(outerFrac.type == .fraction)
        #expect(outerFrac.hasRule)

        let numer = outerFrac.numerator
        #expect(numer.atoms.count == 1)
        #expect(numer.atoms[0].type == .number)
        #expect(numer.atoms[0].nucleus == "1")

        let denom = outerFrac.denominator
        #expect(denom.atoms.count == 1)
        let innerFrac = try #require(denom.atoms[0] as? MTFraction)
        #expect(innerFrac.type == .fraction)

        let innerNumer = innerFrac.numerator
        #expect(innerNumer.atoms[0].nucleus == "2")
        let innerDenom = innerFrac.denominator
        #expect(innerDenom.atoms[0].nucleus == "3")

        #expect(MTMathListBuilder.mathList(toString: list) == "\\frac{1}{\\frac{2}{3}}")
    }

    // MARK: Radicals

    @Test func sqrt() throws {
        let list = try #require(MTMathListBuilder(string: "\\sqrt2").build())
        #expect(list.atoms.count == 1)
        let rad = try #require(list.atoms[0] as? MTRadical)
        #expect(rad.type == .radical)
        #expect(rad.nucleus == "")

        let radicand = try #require(rad.radicand)
        #expect(radicand.atoms.count == 1)
        #expect(radicand.atoms[0].type == .number)
        #expect(radicand.atoms[0].nucleus == "2")

        #expect(MTMathListBuilder.mathList(toString: list) == "\\sqrt{2}")
    }

    @Test func sqrtInSqrt() throws {
        let list = try #require(MTMathListBuilder(string: "\\sqrt\\sqrt2").build())
        #expect(list.atoms.count == 1)
        let outer = try #require(list.atoms[0] as? MTRadical)
        #expect(outer.type == .radical)

        let outerRadicand = try #require(outer.radicand)
        #expect(outerRadicand.atoms.count == 1)
        let inner = try #require(outerRadicand.atoms[0] as? MTRadical)
        #expect(inner.type == .radical)

        let innerRadicand = try #require(inner.radicand)
        #expect(innerRadicand.atoms.count == 1)
        #expect(innerRadicand.atoms[0].type == .number)
        #expect(innerRadicand.atoms[0].nucleus == "2")

        #expect(MTMathListBuilder.mathList(toString: list) == "\\sqrt{\\sqrt{2}}")
    }

    @Test func nthRoot() throws {
        let list = try #require(MTMathListBuilder(string: "\\sqrt[3]2").build())
        #expect(list.atoms.count == 1)
        let rad = try #require(list.atoms[0] as? MTRadical)
        #expect(rad.type == .radical)
        #expect(rad.nucleus == "")

        let radicand = try #require(rad.radicand)
        #expect(radicand.atoms.count == 1)
        #expect(radicand.atoms[0].type == .number)
        #expect(radicand.atoms[0].nucleus == "2")

        let degree = try #require(rad.degree)
        #expect(degree.atoms.count == 1)
        #expect(degree.atoms[0].type == .number)
        #expect(degree.atoms[0].nucleus == "3")

        #expect(MTMathListBuilder.mathList(toString: list) == "\\sqrt[3]{2}")
    }

    // MARK: Left/Right

    @Test(arguments: leftRightCases)
    func leftRight(_ tc: LeftRightCase) throws {
        let builder = MTMathListBuilder(string: tc.input)
        let list = try #require(builder.build())
        #expect(builder.error == nil)

        checkAtomTypes(list, types: tc.outerTypes)

        let inner = try #require(list.atoms[tc.innerLocation] as? MTInner)
        #expect(inner.type == .inner)
        #expect(inner.nucleus == "")

        let innerList = try #require(inner.innerList)
        checkAtomTypes(innerList, types: tc.innerTypes)

        let left = try #require(inner.leftBoundary)
        #expect(left.type == .boundary)
        #expect(left.nucleus == tc.leftBoundary)

        let right = try #require(inner.rightBoundary)
        #expect(right.type == .boundary)
        #expect(right.nucleus == tc.rightBoundary)

        #expect(MTMathListBuilder.mathList(toString: list) == tc.latex)
    }

    // MARK: Over / Atop variants

    @Test func over() throws {
        try checkFractionVariant(
            input: "1 \\over c",
            hasRule: true, leftDelim: nil, rightDelim: nil,
            numerNucleus: "1", numerType: .number,
            denomNucleus: "c", denomType: .variable,
            latex: "\\frac{1}{c}"
        )
    }

    @Test func overInParens() throws {
        let list = try #require(MTMathListBuilder(string: "5 + {1 \\over c} + 8").build())
        #expect(list.atoms.count == 5)
        checkAtomTypes(list, types: [.number, .binaryOperator, .fraction, .binaryOperator, .number])

        let frac = try #require(list.atoms[2] as? MTFraction)
        #expect(frac.hasRule)
        #expect(frac.rightDelimiter == nil)
        #expect(frac.leftDelimiter == nil)
        #expect(frac.numerator.atoms[0].nucleus == "1")
        #expect(frac.denominator.atoms[0].nucleus == "c")
        #expect(MTMathListBuilder.mathList(toString: list) == "5+\\frac{1}{c}+8")
    }

    @Test func atop() throws {
        try checkFractionVariant(
            input: "1 \\atop c",
            hasRule: false, leftDelim: nil, rightDelim: nil,
            numerNucleus: "1", numerType: .number,
            denomNucleus: "c", denomType: .variable,
            latex: "{1 \\atop c}"
        )
    }

    @Test func atopInParens() throws {
        let list = try #require(MTMathListBuilder(string: "5 + {1 \\atop c} + 8").build())
        #expect(list.atoms.count == 5)
        let frac = try #require(list.atoms[2] as? MTFraction)
        #expect(!frac.hasRule)
        #expect(MTMathListBuilder.mathList(toString: list) == "5+{1 \\atop c}+8")
    }

    @Test func choose() throws {
        try checkFractionVariant(
            input: "n \\choose k",
            hasRule: false, leftDelim: "(", rightDelim: ")",
            numerNucleus: "n", numerType: .variable,
            denomNucleus: "k", denomType: .variable,
            latex: "{n \\choose k}"
        )
    }

    @Test func brack() throws {
        try checkFractionVariant(
            input: "n \\brack k",
            hasRule: false, leftDelim: "[", rightDelim: "]",
            numerNucleus: "n", numerType: .variable,
            denomNucleus: "k", denomType: .variable,
            latex: "{n \\brack k}"
        )
    }

    @Test func brace() throws {
        try checkFractionVariant(
            input: "n \\brace k",
            hasRule: false, leftDelim: "{", rightDelim: "}",
            numerNucleus: "n", numerType: .variable,
            denomNucleus: "k", denomType: .variable,
            latex: "{n \\brace k}"
        )
    }

    @Test func binom() throws {
        try checkFractionVariant(
            input: "\\binom{n}{k}",
            hasRule: false, leftDelim: "(", rightDelim: ")",
            numerNucleus: "n", numerType: .variable,
            denomNucleus: "k", denomType: .variable,
            latex: "{n \\choose k}"
        )
    }

    // MARK: Decorations

    @Test func overLine() throws {
        let list = try #require(MTMathListBuilder(string: "\\overline 2").build())
        #expect(list.atoms.count == 1)
        let over = try #require(list.atoms[0] as? MTOverLine)
        #expect(over.type == .overline)
        #expect(over.nucleus == "")
        let inner = try #require(over.innerList)
        #expect(inner.atoms.count == 1)
        #expect(inner.atoms[0].type == .number)
        #expect(inner.atoms[0].nucleus == "2")
        #expect(MTMathListBuilder.mathList(toString: list) == "\\overline{2}")
    }

    @Test func underline() throws {
        let list = try #require(MTMathListBuilder(string: "\\underline 2").build())
        #expect(list.atoms.count == 1)
        let under = try #require(list.atoms[0] as? MTUnderLine)
        #expect(under.type == .underline)
        #expect(under.nucleus == "")
        let inner = try #require(under.innerList)
        #expect(inner.atoms[0].type == .number)
        #expect(inner.atoms[0].nucleus == "2")
        #expect(MTMathListBuilder.mathList(toString: list) == "\\underline{2}")
    }

    @Test func accent() throws {
        let list = try #require(MTMathListBuilder(string: "\\bar x").build())
        #expect(list.atoms.count == 1)
        let accent = try #require(list.atoms[0] as? MTAccent)
        #expect(accent.type == .accent)
        #expect(accent.nucleus == "\u{0304}")
        let inner = try #require(accent.innerList)
        #expect(inner.atoms.count == 1)
        #expect(inner.atoms[0].type == .variable)
        #expect(inner.atoms[0].nucleus == "x")
        #expect(MTMathListBuilder.mathList(toString: list) == "\\bar{x}")
    }

    @Test func mathSpace() throws {
        let list = try #require(MTMathListBuilder(string: "\\!").build())
        #expect(list.atoms.count == 1)
        let space = try #require(list.atoms[0] as? MTMathSpace)
        #expect(space.type == .space)
        #expect(space.nucleus == "")
        #expect(space.space == -3)
        #expect(MTMathListBuilder.mathList(toString: list) == "\\! ")
    }

    @Test func mathStyle() throws {
        let list = try #require(MTMathListBuilder(string: "\\textstyle y \\scriptstyle x").build())
        #expect(list.atoms.count == 4)

        let style1 = try #require(list.atoms[0] as? MTMathStyle)
        #expect(style1.type == .style)
        #expect(style1.nucleus == "")
        #expect(style1.style == .text)

        let style2 = try #require(list.atoms[2] as? MTMathStyle)
        #expect(style2.type == .style)
        #expect(style2.style == .script)

        #expect(MTMathListBuilder.mathList(toString: list) == "\\textstyle y\\scriptstyle x")
    }

    // MARK: Tables

    @Test func matrix() throws {
        let list = try #require(MTMathListBuilder(string: "\\begin{matrix} x & y \\\\ z & w \\end{matrix}").build())
        #expect(list.atoms.count == 1)
        let table = try #require(list.atoms[0] as? MTMathTable)
        #expect(table.type == .table)
        #expect(table.nucleus == "")
        #expect(table.environment == "matrix")
        #expect(table.interRowAdditionalSpacing == 0)
        #expect(table.interColumnSpacing == 18)
        #expect(table.numRows() == 2)
        #expect(table.numColumns() == 2)

        for col in 0..<2 {
            #expect(table.getAlignmentForColumn(col) == .center)
            for row in 0..<2 {
                let cell = table.cells[row][col]
                #expect(cell.atoms.count == 2)
                #expect((cell.atoms[0] as? MTMathStyle)?.style == .text)
                #expect(cell.atoms[1].type == .variable)
            }
        }
        #expect(MTMathListBuilder.mathList(toString: list) == "\\begin{matrix}x&y\\\\ z&w\\end{matrix}")
    }

    @Test func pmatrix() throws {
        let list = try #require(MTMathListBuilder(string: "\\begin{pmatrix} x & y \\\\ z & w \\end{pmatrix}").build())
        #expect(list.atoms.count == 1)
        let inner = try #require(list.atoms[0] as? MTInner)
        #expect(inner.type == .inner)
        #expect(inner.leftBoundary?.nucleus == "(")
        #expect(inner.rightBoundary?.nucleus == ")")

        let innerList = try #require(inner.innerList)
        #expect(innerList.atoms.count == 1)
        let table = try #require(innerList.atoms[0] as? MTMathTable)
        #expect(table.environment == "matrix")
        #expect(table.numRows() == 2)
        #expect(table.numColumns() == 2)
        #expect(MTMathListBuilder.mathList(toString: list) == "\\left( \\begin{matrix}x&y\\\\ z&w\\end{matrix}\\right) ")
    }

    @Test func defaultTable() throws {
        let list = try #require(MTMathListBuilder(string: "x \\\\ y").build())
        #expect(list.atoms.count == 1)
        let table = try #require(list.atoms[0] as? MTMathTable)
        #expect(table.environment == nil)
        #expect(table.interRowAdditionalSpacing == 1)
        #expect(table.interColumnSpacing == 0)
        #expect(table.numRows() == 2)
        #expect(table.numColumns() == 1)
        #expect(table.getAlignmentForColumn(0) == .left)
        for row in 0..<2 {
            let cell = table.cells[row][0]
            #expect(cell.atoms.count == 1)
            #expect(cell.atoms[0].type == .variable)
        }
        #expect(MTMathListBuilder.mathList(toString: list) == "x\\\\ y")
    }

    @Test func defaultTableWithCols() throws {
        let list = try #require(MTMathListBuilder(string: "x & y \\\\ z & w").build())
        #expect(list.atoms.count == 1)
        let table = try #require(list.atoms[0] as? MTMathTable)
        #expect(table.numRows() == 2)
        #expect(table.numColumns() == 2)
        for col in 0..<2 {
            #expect(table.getAlignmentForColumn(col) == .left)
            for row in 0..<2 {
                #expect(table.cells[row][col].atoms.count == 1)
                #expect(table.cells[row][col].atoms[0].type == .variable)
            }
        }
        #expect(MTMathListBuilder.mathList(toString: list) == "x&y\\\\ z&w")
    }

    @Test(arguments: [
        "\\begin{eqalign}x&y\\\\ z&w\\end{eqalign}",
        "\\begin{split}x&y\\\\ z&w\\end{split}",
        "\\begin{aligned}x&y\\\\ z&w\\end{aligned}",
    ])
    func eqalign(_ str: String) throws {
        let list = try #require(MTMathListBuilder(string: str).build())
        #expect(list.atoms.count == 1)
        let table = try #require(list.atoms[0] as? MTMathTable)
        #expect(table.interRowAdditionalSpacing == 1)
        #expect(table.interColumnSpacing == 0)
        #expect(table.numRows() == 2)
        #expect(table.numColumns() == 2)

        for col in 0..<2 {
            let expectedAlign: MTColumnAlignment = col == 0 ? .right : .left
            #expect(table.getAlignmentForColumn(col) == expectedAlign)
            for row in 0..<2 {
                let cell = table.cells[row][col]
                if col == 0 {
                    #expect(cell.atoms.count == 1)
                    #expect(cell.atoms[0].type == .variable)
                } else {
                    #expect(cell.atoms.count == 2)
                    checkAtomTypes(cell, types: [.ordinary, .variable])
                }
            }
        }
        #expect(MTMathListBuilder.mathList(toString: list) == str)
    }

    @Test(arguments: [
        "\\begin{displaylines}x\\\\ y\\end{displaylines}",
        "\\begin{gather}x\\\\ y\\end{gather}",
    ])
    func displayLines(_ str: String) throws {
        let list = try #require(MTMathListBuilder(string: str).build())
        let table = try #require(list.atoms[0] as? MTMathTable)
        #expect(table.interRowAdditionalSpacing == 1)
        #expect(table.numRows() == 2)
        #expect(table.numColumns() == 1)
        #expect(table.getAlignmentForColumn(0) == .center)
        for row in 0..<2 {
            let cell = table.cells[row][0]
            #expect(cell.atoms.count == 1)
            #expect(cell.atoms[0].type == .variable)
        }
        #expect(MTMathListBuilder.mathList(toString: list) == str)
    }

    // MARK: Errors

    @Test(arguments: parseErrorCases)
    func parseError(_ tc: ParseErrorCase) {
        let builder = MTMathListBuilder(string: tc.input)
        #expect(builder.build() == nil)
        let error = builder.error as? NSError
        #expect(error != nil)
        #expect(error?.domain == MTParseError)
        #expect(error?.code == Int(tc.error.rawValue))
    }

    // MARK: Custom symbols

    @Test func customSymbol() {
        let str = "\\lcm(a,b)"
        let builder = MTMathListBuilder(string: str)
        #expect(builder.build() == nil)
        #expect(builder.error != nil)

        MTMathAtomFactory.addLatexSymbol("lcm", value: MTMathAtomFactory.operator(withName: "lcm", limits: false))

        let list = MTMathListBuilder(string: str).build()
        #expect(list != nil)
        checkAtomTypes(
            list!,
            types: [.largeOperator, .open, .variable, .punctuation, .variable, .close]
        )
        #expect(MTMathListBuilder.mathList(toString: list!) == "\\lcm (a,b)")
    }

    // MARK: Fonts

    @Test func fontSingle() throws {
        let list = try #require(MTMathListBuilder(string: "\\mathbf x").build())
        #expect(list.atoms.count == 1)
        #expect(list.atoms[0].type == .variable)
        #expect(list.atoms[0].nucleus == "x")
        #expect(list.atoms[0].fontStyle == .bold)
        #expect(MTMathListBuilder.mathList(toString: list) == "\\mathbf{x}")
    }

    @Test func fontOneChar() throws {
        let list = try #require(MTMathListBuilder(string: "\\cal xy").build())
        #expect(list.atoms.count == 2)
        #expect(list.atoms[0].type == .variable); #expect(list.atoms[0].nucleus == "x"); #expect(list.atoms[0].fontStyle == .caligraphic)
        #expect(list.atoms[1].type == .variable); #expect(list.atoms[1].nucleus == "y"); #expect(list.atoms[1].fontStyle == .default)
        #expect(MTMathListBuilder.mathList(toString: list) == "\\mathcal{x}y")
    }

    @Test func fontMultipleChars() throws {
        let list = try #require(MTMathListBuilder(string: "\\frak{xy}").build())
        #expect(list.atoms.count == 2)
        #expect(list.atoms[0].fontStyle == .fraktur)
        #expect(list.atoms[1].fontStyle == .fraktur)
        #expect(MTMathListBuilder.mathList(toString: list) == "\\mathfrak{xy}")
    }

    @Test func fontOneCharInside() throws {
        let list = try #require(MTMathListBuilder(string: "\\sqrt \\mathrm x y").build())
        #expect(list.atoms.count == 2)
        let rad = try #require(list.atoms[0] as? MTRadical)
        let radicandAtom = try #require(rad.radicand?.atoms[0])
        #expect(radicandAtom.fontStyle == .roman)
        #expect(list.atoms[1].fontStyle == .default)
        #expect(MTMathListBuilder.mathList(toString: list) == "\\sqrt{\\mathrm{x}}y")
    }

    @Test func text() throws {
        let list = try #require(MTMathListBuilder(string: "\\text{x y}").build())
        #expect(list.atoms.count == 3)
        #expect(list.atoms[0].type == .variable); #expect(list.atoms[0].fontStyle == .roman)
        #expect(list.atoms[1].type == .ordinary); #expect(list.atoms[1].nucleus == " ")
        #expect(list.atoms[2].type == .variable); #expect(list.atoms[2].fontStyle == .roman)
        #expect(MTMathListBuilder.mathList(toString: list) == "\\mathrm{x\\  y}")
    }

    // MARK: Limits

    @Test func limits() throws {
        var list = try #require(MTMathListBuilder(string: "\\int").build())
        #expect(list.atoms.count == 1)
        var op = try #require(list.atoms[0] as? MTLargeOperator)
        #expect(op.type == .largeOperator)
        #expect(!op.limits)
        #expect(MTMathListBuilder.mathList(toString: list) == "\\int ")

        list = try #require(MTMathListBuilder(string: "\\int\\limits").build())
        op = try #require(list.atoms[0] as? MTLargeOperator)
        #expect(op.limits)
        #expect(MTMathListBuilder.mathList(toString: list) == "\\int \\limits ")
    }

    @Test func noLimits() throws {
        var list = try #require(MTMathListBuilder(string: "\\sum").build())
        var op = try #require(list.atoms[0] as? MTLargeOperator)
        #expect(op.limits)
        #expect(MTMathListBuilder.mathList(toString: list) == "\\sum ")

        list = try #require(MTMathListBuilder(string: "\\sum\\nolimits").build())
        op = try #require(list.atoms[0] as? MTLargeOperator)
        #expect(!op.limits)
        #expect(MTMathListBuilder.mathList(toString: list) == "\\sum \\nolimits ")
    }

    // MARK: Private helpers

    private func checkFractionVariant(
        input: String,
        hasRule: Bool,
        leftDelim: String?,
        rightDelim: String?,
        numerNucleus: String,
        numerType: MTMathAtomType,
        denomNucleus: String,
        denomType: MTMathAtomType,
        latex: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let list = try #require(MTMathListBuilder(string: input).build(), sourceLocation: sourceLocation)
        #expect(list.atoms.count == 1, sourceLocation: sourceLocation)
        let frac = try #require(list.atoms[0] as? MTFraction, sourceLocation: sourceLocation)
        #expect(frac.type == .fraction, sourceLocation: sourceLocation)
        #expect(frac.nucleus == "", sourceLocation: sourceLocation)
        #expect(frac.hasRule == hasRule, sourceLocation: sourceLocation)
        #expect(frac.leftDelimiter == leftDelim, sourceLocation: sourceLocation)
        #expect(frac.rightDelimiter == rightDelim, sourceLocation: sourceLocation)

        let numer = frac.numerator
        #expect(numer.atoms.count == 1, sourceLocation: sourceLocation)
        #expect(numer.atoms[0].type == numerType, sourceLocation: sourceLocation)
        #expect(numer.atoms[0].nucleus == numerNucleus, sourceLocation: sourceLocation)

        let denom = frac.denominator
        #expect(denom.atoms.count == 1, sourceLocation: sourceLocation)
        #expect(denom.atoms[0].type == denomType, sourceLocation: sourceLocation)
        #expect(denom.atoms[0].nucleus == denomNucleus, sourceLocation: sourceLocation)

        #expect(MTMathListBuilder.mathList(toString: list) == latex, sourceLocation: sourceLocation)
    }
}
