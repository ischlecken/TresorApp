//
//  TresorKeys.swift
//  CeleturKit
//
//  Created by Feldmaus on 06.08.17.
//  Copyright © 2017 prisnoc. All rights reserved.
//

import Foundation
import LocalAuthentication

public struct TresorKey: KeychainGenericPasswordType {
  public let accountName: String
  public let token: String
  
  public let appGroup: String?
  
  
  public var data = [String: Any]()
  
  public var dataToStore: [String: Any] {
    return ["token": token]
  }
  
  public var accessToken: String? {
    return data["token"] as? String
  }
  
  public var accessGroup: String? {
    return self.appGroup
  }
  
  init(name: String, appGroup: String, accessToken: String = "") {
    self.accountName = name
    self.appGroup = appGroup
    self.token = accessToken
  }
}

public class TresorKeys {
  let appGroup : String
  
  public init(appGroup:String) {
    self.appGroup = appGroup
  }
  
  let masterKeyName = "MasterKey"
  
  public func createNewMasterKey() throws -> TresorKey {
    let token =  String(withRandomData:SymmetricCipherAlgorithm.aes_256.requiredKeySize())
    var masterKey = TresorKey(name:masterKeyName,appGroup: self.appGroup,accessToken:token)
    
    try masterKey.saveInKeychain()
    
    return masterKey
  }
  
  public func getMasterKey(masterKeyCompletion: @escaping (TresorKey?,Error?) -> Void) -> Void {
    var key = TresorKey(name: masterKeyName,appGroup: self.appGroup)
    
    key.fetchFromKeychain(completion: { (masterKey:TresorKey?,error:Error?) -> Void in
      if let e = error as? CeleturKitError, case .keychainError(let keychainError) = e, keychainError == errSecItemNotFound {
        celeturKitLogger.debug("item not found")
        
        do {
          let newKey = try self.createNewMasterKey()
          
          masterKeyCompletion(newKey,nil)
        } catch {
          masterKeyCompletion(nil,error)
        }
      } else {
        masterKeyCompletion(masterKey,error)
      }
    })
  }
  
  public func removeMasterKey() throws {
    let key = TresorKey(name: masterKeyName,appGroup: self.appGroup)
    
    try key.removeFromKeychain()
  }
}
