//
//  UserInfo.swift
//  CeleturKit
//
//  Created by Feldmaus on 14.10.17.
//  Copyright © 2017 prisnoc. All rights reserved.
//

import CloudKit

public class UserInfo {
  var userGivenName:String?
  var userFamilyName:String?
  var userEMailAddress:String?
  var userDisplayName:String?
  var userRecordID:String?
  
  public func updateUserIdentityInfo(userIdentity:CKUserIdentity) {
    if let u = userIdentity.nameComponents,let li = userIdentity.lookupInfo {
      let formatter = PersonNameComponentsFormatter()
      
      formatter.style = PersonNameComponentsFormatter.Style.long
      
      self.userDisplayName = formatter.string(from: u)
      self.userGivenName = u.givenName
      self.userFamilyName = u.familyName
      self.userEMailAddress = li.emailAddress
      self.userRecordID = li.userRecordID?.recordName
      
      if self.userEMailAddress == nil {
        self.userEMailAddress = "john.doe@dev.null"
      }
      
      celeturKitLogger.debug("  LoggedIn Cloud User DisplayName:\(self.userDisplayName ?? "-")")
      celeturKitLogger.debug("                     userRecordID:\(self.userRecordID ?? "-" )")
    }
  }
}
