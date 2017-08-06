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
  
  public init(_ prefix: String) {
    self.prefix = prefix
  }
  
  public func info<T>(_ object: T) {
    print("INFO", self.prefix, object)
  }
  
  public func debug<T>(_ object: T) {
    print("DEBUG", self.prefix, object)
  }
  
  public func warn<T>(_ object: T) {
    print("WARN", self.prefix, object)
  }

  public func error<T>(_ object: T, error:Error) {
    print("ERROR", self.prefix, object)
  }
}


let celeturKitLogger = Logger("CeleturKit")
