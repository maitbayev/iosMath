//
//  UXCompat.swift
//  iosMathSwiftUIExample
//
//  Created by Madiyar Aitbayev on 23/04/2026.
//
#if os(iOS)

  import UIKit

  public typealias UXColor = UIColor

#elseif os(macOS)

  import AppKit
  public typealias UXColor = NSColor

  extension NSEdgeInsets {
    static let zero = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
  }

  extension NSColor {
    static var label: NSColor { NSColor.labelColor }
  }
#endif
