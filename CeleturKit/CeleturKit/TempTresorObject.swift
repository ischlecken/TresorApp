//
//  TempTresorObject.swift
//  CeleturKit
//
//  Created by Feldmaus on 01.11.17.
//  Copyright © 2017 prisnoc. All rights reserved.
//


public class TempTresorObject {
  public var tempManagedObjectContext : NSManagedObjectContext
  public var tempTresor : Tresor
  public var userDevices : [TresorUserDevice]?
  
  init(context:NSManagedObjectContext, tresor:Tresor, userDevices: [TresorUserDevice]?) {
    self.tempManagedObjectContext = context
    self.tempTresor = tresor
    self.userDevices = userDevices
  }
  
  convenience init?(tresorCoreDataManager:CoreDataManager?, tresor:Tresor?) {
    if let cdm = tresorCoreDataManager {
      do {
        let scratchpadContext = cdm.privateChildManagedObjectContext()
        var tempTresor : Tresor?
        
        if let t = tresor {
          tempTresor = scratchpadContext.object(with: t.objectID) as? Tresor
          tempTresor?.isreadonly = t.isreadonly
        } else {
          tempTresor = try Tresor.createTempTresor(context: scratchpadContext, ckUserId: tresor?.ckuserid)
        }
        
        self.init(context:scratchpadContext, tresor:tempTresor!, userDevices:TresorUserDevice.loadUserDevices(context: cdm.mainManagedObjectContext))
        
        return 
      } catch {
        celeturKitLogger.error("Error creating temp tresor object",error:error)
      }
    }
  
    return nil
  }
}
