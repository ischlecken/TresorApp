//
//  NSManagedObjectContext+Extension.swift
//  CeleturKit
//
//  Created by Feldmaus on 01.11.17.
//  Copyright © 2017 prisnoc. All rights reserved.
//

public extension NSManagedObjectContext {
  
  public func performSave(contextInfo: String, completion: (()->Void)? = nil) {
    self.perform {
      do {
        try self.save()
        
        if let c = completion {
          c()
        }
      } catch {
        celeturKitLogger.error("Error while saving \(contextInfo)...",error:error)
      }
    }
  }
}
