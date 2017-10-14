//
//  DeviceInfo.swift
//  CeleturKit
//
//  Created by Feldmaus on 14.10.17.
//  Copyright © 2017 prisnoc. All rights reserved.
//

import Foundation

public class DeviceInfo {
  public var apnToken : String?
  public var userDevice: TresorUserDevice?
  
  public func updateAPNToken(deviceToken: Data) {
    self.apnToken = deviceToken.hexEncodedString()
  }
  
  public func selectUserDevice(userDevices:[TresorUserDevice]) -> TresorUserDevice? {
    var result : TresorUserDevice?
    
    if let deviceId = UIDevice.current.identifierForVendor?.uuidString {
      for ud in userDevices {
        if ud.id == deviceId {
          
          self.userDevice = ud
          
          result = ud
          
          break
        }
      }
    }
    
    return result
  }
}
