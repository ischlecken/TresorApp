//
//  CoreDataManager.swift
//

import CoreData
import CloudKit


public class CoreDataManager {
  
  public typealias CoreDataManagerCompletion = (Error?) -> ()
  
  fileprivate let modelName: String
  fileprivate let timer : DispatchSourceTimer
  fileprivate let appGroupContainerId : String
  fileprivate let bundle : Bundle
  fileprivate var saveToCKIsRunning = false
  fileprivate var cloudKitManager : CloudKitManager?
  
  public init(modelName: String, using bundle:Bundle, inAppGroupContainer appGroupContainerId:String) {
    self.modelName = modelName
    self.appGroupContainerId = appGroupContainerId
    self.bundle = bundle
    self.timer = DispatchSource.makeTimerSource(flags: [], queue: DispatchQueue.global())
    
    self.setupCoreDataStack()
    self.startTimer()
  }
  
  func connectToCloudKitManager(ckm: CloudKitManager) {
    self.cloudKitManager = ckm
  }
  
  func disconnectFromCloudKitManager() {
    self.cloudKitManager = nil
  }
  
  func resetChangeTokens() {
    self.cloudKitManager?.ckPersistenceState.flushChangedIds()
    self.cloudKitManager?.ckPersistenceState.flushServerChangeTokens()
  }
  
  func removeAllCloudKitData() {
    self.cloudKitManager?.deleteAllRecordsForZone()
  }
  
  public func fetchCloudKitChanges(in databaseScope: CKDatabaseScope, completion: @escaping () -> Void) {
    self.cloudKitManager?.fetchChanges(in: databaseScope, completion: completion)
  }
  
  // MARK: - Core Data Stack
  
  fileprivate lazy var managedObjectModel: NSManagedObjectModel? = {
    return NSManagedObjectModel(contentsOf: self.bundle.coreDataModelURL(modelName: modelName))
  }()
  
  fileprivate func addPersistentStore() throws {
    guard let persistentStoreCoordinator = persistentStoreCoordinator else { celeturKitLogger.fatal("Unable to Initialize Persistent Store Coordinator") }
    
    let persistentStoreURL = URL.coreDataPersistentStoreURL(appGroupId: appGroupContainerId, storeName:modelName)
    do {
      let options = [ NSMigratePersistentStoresAutomaticallyOption : true, NSInferMappingModelAutomaticallyOption : true ]
      try persistentStoreCoordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: persistentStoreURL, options: options)
    } catch {
      celeturKitLogger.error("Unable to Add Persistent Store", error:error)
    }
  }
  
  fileprivate lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator? = {
    guard let managedObjectModel = self.managedObjectModel else { return nil }
    
    return NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
  }()
  
  public fileprivate(set) lazy var privateManagedObjectContext: NSManagedObjectContext = {
    let managedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
    
    managedObjectContext.persistentStoreCoordinator = self.persistentStoreCoordinator
    
    return managedObjectContext
  }()
  
  public fileprivate(set) lazy var mainManagedObjectContext: NSManagedObjectContext = {
    let managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    
    managedObjectContext.parent = self.privateManagedObjectContext
    //managedObjectContext.automaticallyMergesChangesFromParent = true
    
    return managedObjectContext
  }()
  
  
  public func privateChildManagedObjectContext() -> NSManagedObjectContext {
    let managedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
    
    managedObjectContext.parent = mainManagedObjectContext
    
    return managedObjectContext
  }
  
  
  
  // MARK: - Save changes in main and private MOC
  
  public func saveChanges(notifyChangesToCloudKit:Bool) {
    celeturKitLogger.debug("CoreDataManager.saveChanges(notifyChangesToCloudKit:\(notifyChangesToCloudKit))...")
    
    if self.mainManagedObjectContext.hasChanges || self.privateManagedObjectContext.hasChanges {
      if( notifyChangesToCloudKit ) {
        self.updateInfoForChangedObjects()
      }
      
      mainManagedObjectContext.performAndWait({
        do {
          if self.mainManagedObjectContext.hasChanges {
            try self.mainManagedObjectContext.save()
            
            celeturKitLogger.debug("CoreDataManager.saveChanges() changes of Main Managed Object Context saved.")
          }
        } catch {
          celeturKitLogger.error("Unable to Save Changes of Main Managed Object Context", error: error)
        }
      })
      
      privateManagedObjectContext.perform({
        do {
          if self.privateManagedObjectContext.hasChanges {
            try self.privateManagedObjectContext.save()
            
            celeturKitLogger.debug("CoreDataManager.saveChanges() changes of Private Managed Object Context saved.")
          }
        } catch {
          celeturKitLogger.error("Unable to Save Changes of Private Managed Object Context", error:error)
        }
      })
    }
  }
  
  fileprivate func saveChangesToCloudKit() {
    if let ckm = self.cloudKitManager {
      guard !self.saveToCKIsRunning else { return }
      
      self.saveToCKIsRunning = true
      defer {
        self.saveToCKIsRunning = false
      }
      
      ckm.saveChanges(context: self.privateManagedObjectContext)
    }
  }
  
  fileprivate func updateInfoForChangedObjects() {
    if let ckm = self.cloudKitManager, (self.mainManagedObjectContext.hasChanges || self.privateManagedObjectContext.hasChanges) {
      ckm.updateInfoForChangedObjects(moc: self.mainManagedObjectContext)
      ckm.updateInfoForChangedObjects(moc: self.privateManagedObjectContext)
    }
  }
  
  
  // MARK: - Private Helper Methods
  
  fileprivate func setupCoreDataStack() {
    let _ = mainManagedObjectContext.persistentStoreCoordinator
  }
 
  fileprivate func startTimer() {
    self.timer.schedule(deadline: .now(), repeating: .seconds(15))
    self.timer.setEventHandler { [weak self] in
      self?.saveChangesToCloudKit()
    }
      
    self.timer.resume()
  }
  
  func completeSetup(completion: @escaping CoreDataManagerCompletion) {
    DispatchQueue.global().async {
      var errorInfo : Error?
      
      do {
        try self.addPersistentStore()
      } catch {
        celeturKitLogger.error("Error adding persistent store",error:error)
        
        errorInfo = error
      }
      
      DispatchQueue.main.async {
        if errorInfo == nil {
          self.setupNotificationHandling()
        }
        
        completion(errorInfo)
      }
    }
  }
  
  
  // MARK: - Notification Handling
  private func setupNotificationHandling() {
    let notificationCenter = NotificationCenter.default
    
    notificationCenter.addObserver(self, selector: #selector(saveChanges(_:)), name: Notification.Name.UIApplicationWillTerminate, object: nil)
    notificationCenter.addObserver(self, selector: #selector(saveChanges(_:)), name: Notification.Name.UIApplicationDidEnterBackground, object: nil)
  }
  
  @objc
  func saveChanges(_ notification: Notification) {
    self.saveChanges(notifyChangesToCloudKit: true)
  }
  
  func removeAllEntities(context: NSManagedObjectContext,entityName:String) {
    let fr = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
    
    do {
      let fetchResult = try context.fetch(fr)
      
      for i in fetchResult {
        if let o = i as? NSManagedObject {
          celeturKitLogger.debug("  delete \(entityName): \(o.value(forKey: "id") ?? "-")")
          
          context.delete(o)
        }
      }
      
    } catch {
      celeturKitLogger.error("error deleted all entities \(entityName)", error: error)
    }
  }
}
