//
//  Created by Feldmaus on 01.01.18.
//  Copyright © 2017-2018 prisnoc. All rights reserved.
//

public extension NSFetchedResultsController where ResultType == Tresor {
  
  public func updateReadonlyInfo(ckUserId: String?) {
    if let fetchedObjects = self.fetchedObjects {
      for o in fetchedObjects {
        o.isreadonly = true
        
        if o.ckuserid == nil {
          o.isreadonly = false
        } else {
          if let userid = ckUserId, let ckuserid = o.ckuserid, ckuserid==userid {
            o.isreadonly = false
          }
        }
      }
    }
  }
}
