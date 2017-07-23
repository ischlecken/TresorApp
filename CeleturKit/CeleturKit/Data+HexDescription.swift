//
//  Data+HexDescription.swift
//  CeleturKit
//
//  Created by Feldmaus on 23.07.17.
//  Copyright © 2017 prisnoc. All rights reserved.
//

import Foundation

public extension Data {
  public var hexDescription: String {
    return self.map { String(format: "%02hhx", $0) }.joined()
  }
}
