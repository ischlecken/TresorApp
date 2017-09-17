//
//  TresorAppState.swift
//  Celetur
//
//  Created by Feldmaus on 07.08.17.
//  Copyright © 2017 ischlecken. All rights reserved.
//

import Foundation
import CeleturKit
import CloudKit

class TresorAppModel {
  let tresorKeys: TresorKeys
  let tresorModel: TresorModel
  var masterKey: TresorKey?
  
  init() {
    self.tresorModel = TresorModel()
    self.tresorKeys = TresorKeys(appGroup: appGroup)
    
    /*
    do {
      try tresorKeys.removeMasterKey()
    } catch CeleturKitError.keychainError(let keychainError){
      celeturLogger.debug("error fetching tresor masterkey: \(keychainError)")
    } catch {
      celeturLogger.error("error fetching tresor masterkey",error:error)
    }*/
    
    self.tresorKeys.getMasterKey(masterKeyCompletion:{ (masterKey:TresorKey?, error:Error?) -> Void in
      if let e = error {
        celeturLogger.debug("error:\(e)")
      } else if let mk = masterKey {
        celeturLogger.info("masterKey:\(mk.accountName),\(mk.accessToken?.hexEncodedString() ?? "not set")")
        
        self.masterKey = mk
      }
    })
  }
  
  func completeSetup() {
    self.tresorModel.completeSetup()
  }
  
  func mainManagedContext() -> NSManagedObjectContext {
    return self.tresorModel.mainManagedContext
  }
  
  public func fetchChanges(in databaseScope: CKDatabaseScope, completion: @escaping () -> Void) {
    self.tresorModel.fetchChanges(in: databaseScope,completion: completion)
  }
}
