//
//  TresorKeys.swift
//  CeleturKit
//
//  Created by Feldmaus on 06.08.17.
//  Copyright © 2017 prisnoc. All rights reserved.
//

import Foundation

public struct TresorKey: KeychainGenericPasswordType {
  public let accountName: String
  public let token: String
  
  public var data = [String: Any]()
  
  public var dataToStore: [String: Any] {
    return ["token": token]
  }
  
  public var accessToken: String? {
    return data["token"] as? String
  }
  
  init(name: String, accessToken: String = "") {
    accountName = name
    token = accessToken
  }
}

public class TresorKeys {
  
  public init() {
    
  }
  
  let masterKeyName = "MasterKey"
  
  public func getMasterKey() throws -> TresorKey {
    var key = TresorKey(name: masterKeyName)
    
    do {
      let _ = try key.fetchFromKeychain()
    } catch CeleturKitError.keychainError(let keychainError) {
      
      if keychainError==errSecItemNotFound {
        celeturKitLogger.info("masterkey does not exist, create new one...")
        
        let token = CipherRandomUtil.randomStringOfLength(SymmetricCipherAlgorithm.aes_256.requiredKeySize())
        let masterKey = TresorKey(name:masterKeyName,accessToken:token)
        
        try masterKey.saveInKeychain()
        
        let _ = try key.fetchFromKeychain()
      } else {
        celeturKitLogger.debug("CeleturKitError while fetching masterkey from keychain: \(keychainError)")
      }
    }
    
    return key
  }
  
  public func removeMasterKey() throws {
    let key = TresorKey(name: masterKeyName)
    
    try key.removeFromKeychain()
  }
}
