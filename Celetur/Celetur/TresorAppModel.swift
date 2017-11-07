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
  
  fileprivate var masterKey: TresorKey?
  fileprivate let timer : DispatchSourceTimer
  
  init() {
    self.timer = DispatchSource.makeTimerSource(flags: [], queue: DispatchQueue.main)
    self.tresorModel = TresorModel()
    self.tresorKeys = TresorKeys(appGroup: appGroup)
    
    self.timer.schedule(deadline: .now(), repeating: .seconds(60))
    self.timer.setEventHandler {
      self.masterKey = nil
      self.appDelegate?.noMasterKeyUIAppearance(refreshViews: true)
    }
    
    self.timer.resume()
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
        }
      }
      
      DispatchQueue.main.async {
        if switchUI {
          self.appDelegate?.hasMasterKeyUIAppearance(refreshViews: true)
        }
        
        completion(self.masterKey,returnedError)
      }
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
    
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(tresorUserInfoChanged(_:)),
                                           name: Notification.Name.onTresorUserInfoChanged,
                                           object:self.tresorModel)
    
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
  
  @objc
  func tresorUserInfoChanged(_ note: Notification) {
    if let userName = self.tresorModel.currentUserInfo?.userDisplayName {
      self.appDelegate?.setTitle(title: "Celetur\n\(userName)")
      
    } else {
      self.appDelegate?.setTitle(title: "Celetur\nno icloud user")
    }
  }
  
  public func encryptAllDocumentItemsThatShouldBeEncryptedByDevice(tresor: Tresor) {
    guard let mk = self.masterKey else { return }
    
    self.tresorModel.encryptAllDocumentItemsThatShouldBeEncryptedByDevice(tresor: tresor, masterKey: mk)
  }
}
