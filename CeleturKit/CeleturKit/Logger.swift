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
  var name: String
  
  public init(_ name: String) {
    self.name = name
  }
  
  private var prefix : String {
    let threadName = Thread.current.isMainThread ? "M" : "B"
    
    return "\(self.name) [\(threadName)]"
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
    print("ERROR", self.prefix, String(describing:object)+":"+String(describing:error))
  }

  public func fatal<T>(_ object: T) -> Never {
    print("FATAL", self.prefix, object)
    
    fatalError()
  }
}


let celeturKitLogger = Logger("CeleturKit")
