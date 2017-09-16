//
//  TresorUser+Extension.swift
//  CeleturKit
//
//  Created by Feldmaus on 17.09.17.
//  Copyright © 2017 prisnoc. All rights reserved.
//

import Foundation

extension TresorUser {
  
  class func createUser(context:NSManagedObjectContext,firstName:String, lastName: String, appleid: String) -> TresorUser {
    let newUser = TresorUser(context: context)
    
    newUser.firstname = firstName
    newUser.lastname = lastName
    newUser.email = appleid
    newUser.createts = Date()
    newUser.id = String.uuid()
    
    return newUser
  }
}
