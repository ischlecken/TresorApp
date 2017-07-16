//
//  UUID.swift
//  CeleturLibrary
//
//  Created by Feldmaus on 10.07.17.
//  Copyright © 2017 ischlecken. All rights reserved.
//

import Foundation

public class CeleturUtil {
  
  public static func create() -> String {
    return UUID().uuidString
  }
}
