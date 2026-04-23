//
//  ContentView.swift
//  iosMathSwiftUIExample
//
//  SwiftUI port of iosMathExample's ViewController.
//

import SwiftUI

struct NamedColor: Identifiable, Hashable {
  let id = UUID()
  let name: String
  let color: Color
  let uiColor: UXColor
}

private let palette: [NamedColor] = [
  NamedColor(name: "Primary", color: .primary, uiColor: .label),
  NamedColor(name: "Black", color: .black, uiColor: .black),
  NamedColor(name: "White", color: .white, uiColor: .white),
  NamedColor(name: "Blue", color: .blue, uiColor: .blue),
  NamedColor(name: "Red", color: .red, uiColor: .red),
  NamedColor(name: "Green", color: .green, uiColor: .green),
]

struct ContentView: View {
  @State private var fontFace: MathFontFace = .latinModern
  @State private var selectedColor: NamedColor = palette[0]
  @State private var latexInput: String = #"x = \frac{-b \pm \sqrt{b^2-4ac}}{2a}"#
  @State private var renderedLatex: String = #"x = \frac{-b \pm \sqrt{b^2-4ac}}{2a}"#

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      controlsSection
      liveEditorSection
      ScrollView {
        sectionHeader("Demo formulae")
        ForEach(Formulae.demoFormulae) { item in
          formulaRow(item)
        }
        sectionHeader("Test formulae")
        ForEach(Formulae.testFormulae) { item in
          formulaRow(item)
        }
      }
      .padding(.top)
    }
    .padding(.horizontal)
    .padding(.bottom, 24)
  }

  private var controlsSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Picker("Font", selection: $fontFace) {
          ForEach(MathFontFace.allCases) { face in
            Text(face.rawValue).tag(face)
          }
        }
        .pickerStyle(.menu)
      }
      HStack {
        Picker("Color", selection: $selectedColor) {
          ForEach(palette) { entry in
            Text(entry.name).tag(entry)
          }
        }
        .pickerStyle(.menu)
        Spacer()
        Circle()
          .fill(selectedColor.color)
          .frame(width: 20, height: 20)
          .overlay(Circle().stroke(Color.gray.opacity(0.3)))
      }
    }
    .padding(.top, 8)
  }

  private var liveEditorSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      sectionHeader("Live LaTeX")
      MathView(
        latex: renderedLatex,
        fontFace: fontFace,
        fontSize: 20,
        textColor: selectedColor.uiColor,
        mode: .text
      )
      .padding(8)
      .frame(height: 80)
      .background(Color(UXColor.secondarySystemFill))
      .cornerRadius(8)

      TextField("Enter LaTeX", text: $latexInput, axis: .vertical)
        .padding()
        .textFieldStyle(.roundedBorder)
        .autocorrectionDisabled(true)
        .lineLimit(1...4)
        .onSubmit { renderedLatex = latexInput }

      Button("Render") { renderedLatex = latexInput }
        .buttonStyle(.borderedProminent)
    }
  }

  private func sectionHeader(_ title: String) -> some View {
    Text(title)
      .font(.headline)
      .padding(.top, 8)
  }

  private func formulaRow(_ item: FormulaItem) -> some View {
    MathView(
      latex: item.latex,
      fontFace: fontFace,
      fontSize: item.fontSize,
      textColor: selectedColor.uiColor,
      backgroundColor: item.backgroundColor,
      alignment: item.alignment,
      mode: item.mode,
      contentInsets: item.contentInsets
    )
    .frame(height: item.height)
    .frame(maxWidth: .infinity)
  }
}

#Preview {
  ContentView()
}
