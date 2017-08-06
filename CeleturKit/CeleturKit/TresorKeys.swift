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
  
  public func getMasterKey(masterKeyCompletion: @escaping (TresorKey?,Error?)->Void) throws -> Void {
    var key = TresorKey(name: masterKeyName,appGroup: self.appGroup)
    
    do {
      let _ = try key.fetchFromKeychain(completion:{ (error:Error?) -> Void in
        
        masterKeyCompletion(key,error)
      })
    } catch CeleturKitError.keychainError(let keychainError) {
      
      if keychainError==errSecItemNotFound {
        celeturKitLogger.info("masterkey does not exist, create new one...")
        
        let token = CipherRandomUtil.randomStringOfLength(SymmetricCipherAlgorithm.aes_256.requiredKeySize())
        let masterKey = TresorKey(name:masterKeyName,appGroup: self.appGroup,accessToken:token)
        
        try masterKey.saveInKeychain()
        
        let _ = try key.fetchFromKeychain(completion:{ (error:Error?) -> Void in
          
          masterKeyCompletion(key,error)
        })
      } else {
        celeturKitLogger.debug("CeleturKitError while fetching masterkey from keychain: \(keychainError)")
      }
    }
  }
  
  public func removeMasterKey() throws {
    let key = TresorKey(name: masterKeyName,appGroup: self.appGroup)
    
    try key.removeFromKeychain()
  }
}
