//
//  Logger.swift
//  CeleturLibrary
//
//  Created by Feldmaus on 09.07.17.
//  Copyright © 2017 ischlecken. All rights reserved.
//

import Foundation

public class Logger
{
  var prefix: String
  
  public init(_ prefix: String)
  {
    self.prefix = prefix
  }
  
  public func log<T>(object: T)
  {
    print(prefix)
    print(object)
  }
}
