//
//  Created by Feldmaus on 01.01.18.
//  Copyright © 2017-2018 prisnoc. All rights reserved.
//


extension CoreDataManager {

  func loadCurrentDeviceInfo(apnDeviceToken: Data?) {
    DeviceInfo.loadCurrentDeviceInfo(context: self.mainManagedObjectContext, apnDeviceToken: apnDeviceToken)
    
    self.saveChanges(notifyChangesToCloudKit:false)
  }
}
