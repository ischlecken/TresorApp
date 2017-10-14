//
//  TresorUserDevice+Extension.swift
//  CeleturKit
//

extension TresorUserDevice {
  
  class func createUserDevice(context:NSManagedObjectContext,deviceName:String) {
    let newUserDevice = TresorUserDevice(context:context)
    
    newUserDevice.createts = Date()
    newUserDevice.devicename = deviceName
    newUserDevice.id = String.uuid()
    newUserDevice.apndevicetoken = String.uuid()
  }
  
  class func createCurrentUserDevice(context:NSManagedObjectContext, userName:String, apndeviceToken:String) {
    let newUserDevice = TresorUserDevice(context:context)
    
    newUserDevice.createts = Date()
    newUserDevice.devicename = UIDevice.current.name
    newUserDevice.devicesystemname = UIDevice.current.systemName
    newUserDevice.devicesystemversion = UIDevice.current.systemVersion
    newUserDevice.deviceuitype = Int16(UIDevice.current.userInterfaceIdiom.rawValue)
    
    newUserDevice.id = UIDevice.current.identifierForVendor?.uuidString
    newUserDevice.apndevicetoken = apndeviceToken
    newUserDevice.username = userName
  }
  
  
  class public func loadUserDevices(context:NSManagedObjectContext) -> [TresorUserDevice]? {
    var result : [TresorUserDevice]?
    
    do {
      result = try context.fetch(TresorUserDevice.fetchRequest())
      
    } catch {
      celeturKitLogger.error("Error while loading user devices...",error:error)
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
