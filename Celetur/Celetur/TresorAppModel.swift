//
//  TresorAppState.swift
//  Celetur
//
//  Created by Feldmaus on 07.08.17.
//  Copyright © 2017 ischlecken. All rights reserved.
//

import Foundation
import CeleturKit

class TresorAppModel {
  let coreDataManager: CoreDataManager
  let tresorKeys: TresorKeys
  let tresorModel: TresorModel
  let ckManager: CloudKitManager
  
  var masterKey: TresorKey?
  
  init() {
    self.coreDataManager = CoreDataManager(modelName: "CeleturKit", using:Bundle(identifier:celeturKitIdentifier)!, inAppGroupContainer:appGroup) {
    }
    
    self.tresorKeys = TresorKeys(appGroup: appGroup)
    self.tresorModel = TresorModel(self.coreDataManager)
    
    self.ckManager = CloudKitManager(tresorModel: self.tresorModel)
    
    /*
    do {
      try tresorKeys.removeMasterKey()
    } catch CeleturKitError.keychainError(let keychainError){
      celeturLogger.debug("error fetching tresor masterkey: \(keychainError)")
    } catch {
      celeturLogger.error("error fetching tresor masterkey",error:error)
    }*/
    
    tresorKeys.getMasterKey(masterKeyCompletion:{ (masterKey:TresorKey?, error:Error?) -> Void in
      if let e = error {
        celeturLogger.debug("error:\(e)")
      } else if let mk = masterKey {
        celeturLogger.info("masterKey:\(mk.accountName),\(mk.accessToken?.hexEncodedString() ?? "not set")")
        
        self.masterKey = mk
      }
    })
  }
  
  func mainManagedObjectContext() -> NSManagedObjectContext {
    return self.coreDataManager.mainManagedObjectContext
  }
  
}
