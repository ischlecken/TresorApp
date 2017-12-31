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
  
  let maxMasterKeyAvailable = 10
  var actMasterKeyAvailable = 0
  
  fileprivate var masterKey: TresorKey?
  fileprivate var lastMasterKey: TresorKey?
  fileprivate let timer : DispatchSourceTimer
  
  init() {
    self.timer = DispatchSource.makeTimerSource(flags: [], queue: DispatchQueue.main)
    self.tresorModel = TresorModel()
    self.tresorKeys = TresorKeys(appGroup: appGroup)
    
    self.timer.schedule(deadline: .now(), repeating:.seconds(5))
    self.timer.setEventHandler {
      if self.actMasterKeyAvailable>0 {
        self.actMasterKeyAvailable = self.actMasterKeyAvailable - 1
        
        DispatchQueue.main.async {
          if self.lastMasterKey == nil && self.masterKey != nil {
            self.appDelegate?.masterKeyIsAvailable()
            self.lastMasterKey = self.masterKey
          }
          
          self.appDelegate?.updateMasterKeyAvailablity(self.actMasterKeyAvailable,maxAvailablityInTimeron: self.maxMasterKeyAvailable)
        }
      } else if self.actMasterKeyAvailable == 0 && self.masterKey != nil {
        self.makeMasterKeyUnavailable()
      }
    }
    self.timer.resume()
  }
  
  func makeMasterKeyUnavailable() {
    self.masterKey = nil
    self.actMasterKeyAvailable = 0
    
    DispatchQueue.main.async {
      self.appDelegate?.updateMasterKeyAvailablity(self.actMasterKeyAvailable,maxAvailablityInTimeron: self.maxMasterKeyAvailable)
      
      if self.lastMasterKey != nil {
        self.appDelegate?.masterKeyIsNotAvailable()
        self.lastMasterKey = nil
      }
    }
  }
  
  func removeMasterKey() {
    do {
      try self.tresorKeys.removeMasterKey()
    } catch CeleturKitError.keychainError(let keychainError){
      celeturLogger.debug("error fetching tresor masterkey: \(keychainError)")
    } catch {
      celeturLogger.error("error fetching tresor masterkey",error:error)
    }
  }
  
  func getMasterKey(completion: @escaping (TresorKey?,Error?) -> Void) {
    if self.masterKey == nil {
      self.tresorKeys.getMasterKey() { (masterKey:TresorKey?, error:Error?) -> Void in
        var returnedError: Error?
        var switchUI = false
        
        if self.masterKey == nil {
          if let e = error {
            celeturLogger.debug("error:\(e)")
            returnedError = error
          } else if let mk = masterKey {
            celeturLogger.info("masterKey:\(mk.accountName),\(mk.accessToken?.hexEncodedString() ?? "---")")
            
            self.masterKey = mk
            switchUI = true
            self.actMasterKeyAvailable = self.maxMasterKeyAvailable
          }
        }
        
        DispatchQueue.main.async {
          if switchUI {
            self.appDelegate?.updateMasterKeyAvailablity(self.actMasterKeyAvailable,maxAvailablityInTimeron: self.maxMasterKeyAvailable)
          }
          
          completion(self.masterKey,returnedError)
        }
      }
    } else {
      self.actMasterKeyAvailable = self.maxMasterKeyAvailable
      self.appDelegate?.updateMasterKeyAvailablity(self.actMasterKeyAvailable,maxAvailablityInTimeron: self.maxMasterKeyAvailable)
      completion(self.masterKey,nil)
    }
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
      self.appDelegate?.onOnline()
    case .cellular:
      celeturLogger.debug("Reachable via Cellular")
      self.appDelegate?.onOnline()
    case .none:
      celeturLogger.debug("Network not reachable")
      self.appDelegate?.onOffline()
    }
  }
  
  public func encryptAllDocumentItemsThatShouldBeEncryptedByDevice(tresor: Tresor) {
    guard self.tresorModel.shouldEncryptAllDocumentItemsThatShouldBeEncryptedByDevice(tresor:tresor)  else { return }
    
    self.getMasterKey { (tresorKey, error) in
      if let mk = tresorKey {
        self.tresorModel.encryptAllDocumentItemsThatShouldBeEncryptedByDevice(tresor: tresor, masterKey: mk)
      }
    }
  }
}
