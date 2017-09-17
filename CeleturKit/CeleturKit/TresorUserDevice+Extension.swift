//
//  TresorUserDevice+Extension.swift
//  CeleturKit
//

extension TresorUserDevice {
  
  class func createUserDevice(context:NSManagedObjectContext,user:TresorUser, deviceName:String) {
    let newUserDevice = TresorUserDevice(context:context)
    
    newUserDevice.createts = Date()
    newUserDevice.devicename = deviceName
    newUserDevice.id = String.uuid()
    newUserDevice.apndevicetoken = String.uuid()
    newUserDevice.user = user
    
    user.addToUserdevices(newUserDevice)
  }
  
  class func createCurrentUserDevice(context:NSManagedObjectContext,user:TresorUser) {
    let newUserDevice = TresorUserDevice(context:context)
    
    newUserDevice.createts = Date()
    newUserDevice.devicename = UIDevice.current.name
    newUserDevice.id = UIDevice.current.identifierForVendor?.uuidString
    newUserDevice.apndevicetoken = String.uuid()
    newUserDevice.user = user
    
    user.addToUserdevices(newUserDevice)
  }
  
  class func getCurrentUserDevice(userList:[TresorUser]) -> TresorUserDevice? {
    var result:TresorUserDevice? = nil
    
    let vendorDeviceId = UIDevice.current.identifierForVendor?.uuidString
    
    for u in userList {
      for ud in u.userdevices! {
        let userDevice = ud as! TresorUserDevice
        
        if let udi = userDevice.id, let vdi = vendorDeviceId, udi == vdi {
          result = userDevice
          break;
        }
      }
      
      if result != nil {
        break
      }
    }
    
    return result
  }
  
  class func createAndFetchUserdeviceFetchedResultsController(context:NSManagedObjectContext) throws -> NSFetchedResultsController<TresorUserDevice> {
    let fetchRequest: NSFetchRequest<TresorUserDevice> = TresorUserDevice.fetchRequest()
    
    // Set the batch size to a suitable number.
    fetchRequest.fetchBatchSize = 20
    
    // Edit the sort key as appropriate.
    let sortDescriptor = NSSortDescriptor(key: "createts", ascending: false)
    
    fetchRequest.sortDescriptors = [sortDescriptor]
    
    let aFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: "user.email", cacheName: nil)
    
    do {
      try aFetchedResultsController.performFetch()
    } catch {
      throw CeleturKitError.creationOfFetchResultsControllerFailed(coreDataError: error as NSError)
    }
    
    return aFetchedResultsController
  }
}
