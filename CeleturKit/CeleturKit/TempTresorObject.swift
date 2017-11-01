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
  
  init(context:NSManagedObjectContext, tresor:Tresor) {
    self.tempManagedObjectContext = context
    self.tempTresor = tresor
  }
  
  convenience init?(tresorModel:TresorModel, tresor:Tresor?) {
    if let cdm = tresorModel.tresorCoreDataManager {
      do {
        let scratchpadContext = cdm.privateChildManagedObjectContext()
        var tempTresor : Tresor?
        
        if let t = tresor {
          tempTresor = scratchpadContext.object(with: t.objectID) as? Tresor
        } else {
          tempTresor = try Tresor.createTempTresor(context: scratchpadContext)
        }
        
        self.init(context:scratchpadContext, tresor:tempTresor!)
        
        return 
      } catch {
        celeturKitLogger.error("Error creating temp tresor object",error:error)
      }
    }
  
    return nil
  }
}
