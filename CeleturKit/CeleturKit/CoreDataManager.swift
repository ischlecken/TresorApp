//
//  CoreDataManager.swift
//

import CoreData
import Foundation

public class CoreDataManager {
  
  public typealias CoreDataManagerCompletion = () -> ()
  
  fileprivate let modelName: String
  fileprivate let timer : DispatchSourceTimer
  fileprivate let appGroupContainerId : String
  fileprivate let bundle : Bundle
  
  var cloudKitManager : CloudKitManager?
  
  public init(modelName: String, using bundle:Bundle, inAppGroupContainer appGroupContainerId:String) {
    self.modelName = modelName
    self.appGroupContainerId = appGroupContainerId
    self.bundle = bundle
    self.timer = DispatchSource.makeTimerSource(flags: [], queue: DispatchQueue.global())
    
    setupCoreDataStack()
  }
  
  
  // MARK: - Core Data Stack
  
  public fileprivate(set) lazy var mainManagedObjectContext: NSManagedObjectContext = {
    let managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    
    managedObjectContext.parent = self.privateManagedObjectContext
    
    return managedObjectContext
  }()
  
  fileprivate lazy var privateManagedObjectContext: NSManagedObjectContext = {
    let managedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)

    managedObjectContext.persistentStoreCoordinator = self.persistentStoreCoordinator
    
    return managedObjectContext
  }()
  
  fileprivate lazy var managedObjectModel: NSManagedObjectModel? = {
    return NSManagedObjectModel(contentsOf: self.modelURL)
  }()
  
  public func privateChildManagedObjectContext() -> NSManagedObjectContext {
    let managedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
    
    managedObjectContext.parent = mainManagedObjectContext
    
    return managedObjectContext
  }
  
  fileprivate lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator? = {
    guard let managedObjectModel = self.managedObjectModel else { return nil }
    
    return NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
  }()
  
  // MARK: - Computed Properties
  
  fileprivate var persistentStoreURL: URL {
    let containerUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: self.appGroupContainerId)
    
    guard containerUrl != nil else { celeturKitLogger.fatal("could not find app group container") }
    
    return containerUrl!.appendingPathComponent("\(self.modelName).sqlite")
  }
  
  fileprivate var modelURL: URL {
    let url = self.bundle.url(forResource: modelName, withExtension: "momd")
    
    guard url != nil else { celeturKitLogger.fatal("could not find coredata model") }
    
    return url!
  }
  
  // MARK: - Helper Methods
  
  public func saveChanges() {
    mainManagedObjectContext.performAndWait({
      do {
        if self.mainManagedObjectContext.hasChanges {
          try self.mainManagedObjectContext.save()
          
          celeturKitLogger.debug("Changes of Main Managed Object Context saved.")
        }
      } catch {
        celeturKitLogger.error("Unable to Save Changes of Main Managed Object Context", error: error)
      }
    })
    
    privateManagedObjectContext.perform({
      do {
        if self.privateManagedObjectContext.hasChanges {
          self.dumpManagedObjectContext(moc: self.privateManagedObjectContext)
          
          if let ckm = self.cloudKitManager {
            ckm.saveChanges(moc: self.privateManagedObjectContext)
          }
          
          try self.privateManagedObjectContext.save()
          
          celeturKitLogger.debug("Changes of Private Managed Object Context saved.")
        }
      } catch {
        celeturKitLogger.error("Unable to Save Changes of Private Managed Object Context", error:error)
      }
    })
  }
  
  fileprivate func dumpMetaInfo(o:NSManagedObject) {
    let ed = o.entity
    
    celeturKitLogger.debug("entityname:\(ed.name ?? "nil")")
    
    for (n,p) in ed.attributesByName {
      celeturKitLogger.debug("  \(n):\(p.attributeValueClassName ?? "nil" )")
    }
    
    for (n,p) in ed.relationshipsByName {
      celeturKitLogger.debug("  \(n):\(p.destinationEntity?.name ?? "nil" )")
    }
    
    
  }
  
  fileprivate func dumpManagedObjectContext(moc:NSManagedObjectContext) {
    for o in moc.insertedObjects {
      celeturKitLogger.debug("inserted:\(o)")
      
      self.dumpMetaInfo(o: o)
    }
    
    for o in moc.updatedObjects {
      celeturKitLogger.debug("updated:\(o)")
      
      self.dumpMetaInfo(o: o)
    }
    
    for o in moc.deletedObjects {
      celeturKitLogger.debug("deleted:\(o)")
      
      self.dumpMetaInfo(o: o)
    }
  }
  
  // MARK: - Private Helper Methods
  
  fileprivate func setupCoreDataStack() {
    timer.schedule(deadline: .now(), repeating: .seconds(10))
    timer.setEventHandler {
      self.periodicTask()
    }
    
    let _ = mainManagedObjectContext.persistentStoreCoordinator
  }
  
  func completeSetup(completion: @escaping CoreDataManagerCompletion) {
    DispatchQueue.global().async {
      self.addPersistentStore()
      
      DispatchQueue.main.async {
        self.setupNotificationHandling()
        self.timer.resume()
        
        completion()
      }
    }
  }
  
  // MARK: - Notification Handling
  @objc func saveChanges(_ notification: Notification) {
    celeturKitLogger.debug("call saveChanges triggered by notification..")
    saveChanges()
  }
  
  // MARK: - Helper Methods
  private func setupNotificationHandling() {
    let notificationCenter = NotificationCenter.default
    
    notificationCenter.addObserver(self, selector: #selector(saveChanges(_:)), name: Notification.Name.UIApplicationWillTerminate, object: nil)
    notificationCenter.addObserver(self, selector: #selector(saveChanges(_:)), name: Notification.Name.UIApplicationDidEnterBackground, object: nil)
  }
  
  fileprivate func periodicTask() {
    celeturKitLogger.debug("periodicTask()")
    
    self.saveChanges()
  }
  
  fileprivate static func applicationDocumentsDirectory() -> URL {
    let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask) as [URL]
    
    return urls[0]
  }
  
  fileprivate func addPersistentStore() {
    guard let persistentStoreCoordinator = persistentStoreCoordinator else { celeturKitLogger.fatal("Unable to Initialize Persistent Store Coordinator") }
    
    let persistentStoreURL = self.persistentStoreURL
    do {
      let options = [ NSMigratePersistentStoresAutomaticallyOption : true, NSInferMappingModelAutomaticallyOption : true ]
      try persistentStoreCoordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: persistentStoreURL, options: options)
    } catch {
      celeturKitLogger.error("Unable to Add Persistent Store", error:error)
    }
  }
}
