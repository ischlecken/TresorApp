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
        celeturKitLogger.debug("save for \(contextInfo)...")
        try self.save()
        
        if let c = completion {
          c()
        }
      } catch {
        celeturKitLogger.error("Error while saving \(contextInfo)...",error:error)
      }
    }
  }
  
  public func updateReadonlyInfo(ckUserId:String?) {
    for case let t as Tresor in self.registeredObjects {
      t.updateReadonly(ckUserId: ckUserId)
    }
    
    for o in self.registeredObjects {
      for (n,_) in o.entity.attributesByName {
        if n == "ckuserid" {
          
          if o.value(forKey: n) == nil {
            o.setValue(CloudKitEntitySyncState.successful.rawValue, forKey: "cksyncstatus")
          }
          
          break
        }
      }
    }
  }
}
