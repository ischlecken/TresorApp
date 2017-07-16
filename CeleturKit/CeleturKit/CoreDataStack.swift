import CoreData

public class CoreDataStack {
  
  public let context:NSManagedObjectContext
  public let psc:NSPersistentStoreCoordinator
  public let model:NSManagedObjectModel
  public let store:NSPersistentStore?
  
  public init(_ dbName:String) {
    let modelName = dbName
    let databaseName = dbName+".sqlite"
    let bundle = Bundle.main
    let modelURL = bundle.url(forResource: modelName, withExtension: "momd")
    
    model = NSManagedObjectModel(contentsOf: modelURL!)!
    psc = NSPersistentStoreCoordinator(managedObjectModel:model)
    
    context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    context.persistentStoreCoordinator = psc
    
    let documentsURL = CoreDataStack.applicationDocumentsDirectory()
    let storeURL = documentsURL.appendingPathComponent(databaseName)
    
    do {
      let options = [NSInferMappingModelAutomaticallyOption:true,
                     NSMigratePersistentStoresAutomaticallyOption:true]
      
      try store = psc.addPersistentStore(ofType: NSSQLiteStoreType,
                                         configurationName: nil,
                                         at: storeURL,
                                         options: options)
      
    } catch {
      print("Error adding persistent store: \(error)")
      abort()
    }
  }
  
  static func applicationDocumentsDirectory() -> NSURL {
    let fileManager = FileManager.default
    
    let urls =
      fileManager.urls(for: .documentDirectory,
                       in: .userDomainMask) as [NSURL]
    
    return urls[0]
  }
  
  public func saveContext() {
    context.perform { () -> Void in
      
      do {
        if self.context.hasChanges {
          try self.context.save()
        }
      } catch {
        print("Could not save: \(error)")
        abort()
      }
    }
  }
}

