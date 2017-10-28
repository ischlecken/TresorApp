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
  var appDelegate : AppDelegate?
  let reachability = Reachability()!
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
  
  func completeSetup(appDelegate : AppDelegate?) {
    self.appDelegate = appDelegate
    self.tresorModel.completeSetup()
    
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(reachabilityChanged(_:)),
                                           name: .reachabilityChanged,
                                           object: self.reachability)
    do{
      try self.reachability.startNotifier()
    } catch {
      celeturLogger.error("could not start reachability notifier",error:error)
    }
  }
  
  public func fetchChanges(in databaseScope: CKDatabaseScope, completion: @escaping () -> Void) {
    self.tresorModel.fetchChanges(in: databaseScope,completion: completion)
  }
  
  @objc
  func reachabilityChanged(_ note: Notification) {
    let reachability = note.object as! Reachability
    
    switch reachability.connection {
    case .wifi:
      celeturLogger.debug("Reachable via WiFi")
      self.appDelegate?.setTitle(title: "Celetur")
    case .cellular:
      celeturLogger.debug("Reachable via Cellular")
      self.appDelegate?.setTitle(title: "Celetur")
    case .none:
      celeturLogger.debug("Network not reachable")
      self.appDelegate?.setTitle(title: "Celetur (Offline)")
    }
  }
  
  public func encryptAllDocumentItemsThatShouldBeEncryptedByDevice(tresor: Tresor) {
    guard let mk = self.masterKey else { return }
    
    self.tresorModel.encryptAllDocumentItemsThatShouldBeEncryptedByDevice(tresor: tresor, masterKey: mk)
  }
}
