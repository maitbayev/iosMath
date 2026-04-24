import Testing
import iosMathCore

func checkAtomTypes(
    _ list: MTMathList,
    types: [MTMathAtomType],
    sourceLocation: SourceLocation = #_sourceLocation
) {
    #expect(list.atoms.count == types.count, sourceLocation: sourceLocation)
    let count = min(list.atoms.count, types.count)
    for i in 0..<count {
        let atom = list.atoms[i]
        #expect(atom.type == types[i], "atom[\(i)]", sourceLocation: sourceLocation)
    }
}

func checkAtomCopy(
    _ copy: MTMathAtom,
    original: MTMathAtom,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    #expect(copy.type == original.type, sourceLocation: sourceLocation)
    #expect(copy.nucleus == original.nucleus, sourceLocation: sourceLocation)
    #expect(copy !== original, sourceLocation: sourceLocation)
}

func checkListCopy(
    _ copy: MTMathList,
    original: MTMathList,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    #expect(copy.atoms.count == original.atoms.count, sourceLocation: sourceLocation)
    let count = min(copy.atoms.count, original.atoms.count)
    for i in 0..<count {
        checkAtomCopy(copy.atoms[i], original: original.atoms[i], sourceLocation: sourceLocation)
    }
}
