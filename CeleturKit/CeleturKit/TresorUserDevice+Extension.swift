//
//  TresorUserDevice+Extension.swift
//  CeleturKit
//

extension TresorUserDevice {
  
  class func createUserDevice(context:NSManagedObjectContext, userName:String, deviceName:String) {
    let newUserDevice = TresorUserDevice(context:context)
    
    newUserDevice.createts = Date()
    newUserDevice.devicename = deviceName
    newUserDevice.devicesystemname = "iPhone X"
    newUserDevice.devicesystemversion = "10.0"
    newUserDevice.deviceuitype = Int16(UIUserInterfaceIdiom.phone.rawValue)
    
    newUserDevice.id = String.uuid()
    newUserDevice.apndevicetoken = String.uuid()
    newUserDevice.username = userName
    
    do {
      newUserDevice.messagekey = try Data(withRandomData:SymmetricCipherAlgorithm.aes_256.requiredKeySize())
    } catch {
      celeturKitLogger.error("error create messagekey", error: error)
    }
  }
  
  class func createCurrentUserDevice(context:NSManagedObjectContext, deviceInfo:DeviceInfo) -> TresorUserDevice {
    let newUserDevice = TresorUserDevice(context:context)
    
    newUserDevice.createts = Date()
    newUserDevice.id = deviceInfo.id
    
    
    do {
      newUserDevice.messagekey = try Data(withRandomData:SymmetricCipherAlgorithm.aes_256.requiredKeySize())
    } catch {
      celeturKitLogger.error("error create messagekey", error: error)
    }
    
    return newUserDevice
  }
  
  
  func updateCurrentUserDevice(deviceInfo:DeviceInfo, userName:String) {
    self.devicename = deviceInfo.devicename
    self.devicemodel = deviceInfo.devicemodel
    self.devicesystemname = deviceInfo.devicesystemname
    self.devicesystemversion = deviceInfo.devicesystemversion
    self.deviceuitype = deviceInfo.deviceuitype
    
    self.username = userName
    self.apndevicetoken = deviceInfo.apndevicetoken
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
    
    let aFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: "username", cacheName: nil)
    
    do {
      try aFetchedResultsController.performFetch()
    } catch {
      throw CeleturKitError.creationOfFetchResultsControllerFailed(coreDataError: error as NSError)
    }
    
    return aFetchedResultsController
  }
}
