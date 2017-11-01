//
//  Tresor+Extension.swift
//  CeleturKit
//

public extension Tresor {
  
  public class func createTempTresor(context: NSManagedObjectContext) throws -> Tresor {
    let newTresor = Tresor(context: context)
    newTresor.createts = Date()
    newTresor.changets = newTresor.createts
    newTresor.id = String.uuid()
    newTresor.nonce = try Data(withRandomData: SymmetricCipherAlgorithm.aes_256.requiredBlockSize())
    
    return newTresor
  }
  
  
  class func createAndFetchTresorFetchedResultsController(context: NSManagedObjectContext) throws -> NSFetchedResultsController<Tresor> {
    let fetchRequest: NSFetchRequest<Tresor> = Tresor.fetchRequest()
    
    // Set the batch size to a suitable number.
    fetchRequest.fetchBatchSize = 20
    
    // Edit the sort key as appropriate.
    let sortDescriptor = NSSortDescriptor(key: "changets", ascending: false)
    
    fetchRequest.sortDescriptors = [sortDescriptor]
    
    let aFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                               managedObjectContext: context,
                                                               sectionNameKeyPath: nil,
                                                               cacheName: nil)
    
    do {
      try aFetchedResultsController.performFetch()
    } catch {
      throw CeleturKitError.creationOfFetchResultsControllerFailed(coreDataError: error as NSError)
    }
    
    return aFetchedResultsController
  }
  
  public func findUserDevice(userDevice:TresorUserDevice) -> TresorUserDevice? {
    var result : TresorUserDevice?
    
    if let udlist = self.userdevices {
      for case let ud as TresorUserDevice in udlist  {
        if ud.id == userDevice.id {
          result = ud
          
          break
        }
      }
    }
    
    return result
  }
  
  public func deleteTresor() {
    if let docs = self.documents {
      for doc in docs {
        if let o = doc as? TresorDocument {
          o.deleteTresorDocument()
        }
      }
    }
    
    self.managedObjectContext?.delete(self)
  }
}
