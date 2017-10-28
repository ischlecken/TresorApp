//
//  TresorDocumentItem+Extension.swift
//  CeleturKit
//

public enum TresorDocumentItemStatus : String {
  case pending
  case failed
  case encrypted
  case shouldBeEncryptedByDevice
}


extension TresorDocumentItem {

  class func createPendingTresorDocumentItem(context:NSManagedObjectContext,
                                             tresorDocument:TresorDocument,
                                             userDevice:TresorUserDevice) -> TresorDocumentItem {
    let result = TresorDocumentItem(context: context)
    
    result.createts = Date()
    result.changets = result.createts
    result.id = String.uuid()
    result.status = TresorDocumentItemStatus.pending.rawValue
    result.document = tresorDocument
    result.userdevice = userDevice
    
    return result
  }

  class func createAndFetchTresorDocumentItemFetchedResultsController(context:NSManagedObjectContext,
                                                                      tresor:Tresor?) throws -> NSFetchedResultsController<TresorDocumentItem> {
    let fetchRequest: NSFetchRequest<TresorDocumentItem> = TresorDocumentItem.fetchRequest()
    
    // Set the batch size to a suitable number.
    fetchRequest.fetchBatchSize = 20
    fetchRequest.predicate = NSPredicate(format: "document.tresor.id = %@", (tresor?.id)!)
    
    
    // Edit the sort key as appropriate.
    let sortDescriptor = NSSortDescriptor(key: "createts", ascending: false)
    
    fetchRequest.sortDescriptors = [sortDescriptor]
    
    let aFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                               managedObjectContext: context,
                                                               sectionNameKeyPath: "document.id",
                                                               cacheName: nil)
    
    do {
      try aFetchedResultsController.performFetch()
    } catch {
      throw CeleturKitError.creationOfFetchResultsControllerFailed(coreDataError: error as NSError)
    }
    
    return aFetchedResultsController
  }
  
  public var itemStatus: TresorDocumentItemStatus? {
    get {
      var result : TresorDocumentItemStatus?
      
      if let s=self.status {
        result = TresorDocumentItemStatus(rawValue:s)
      }
      
      return result
    }
  }
  
  public var itemStatusColor: UIColor {
    get {
      var result = UIColor.lightGray
      
      if let s = self.itemStatus {
        switch s {
        case .pending:
          result = UIColor.blue
        case .encrypted:
          result = UIColor.black
        case .shouldBeEncryptedByDevice:
          result = UIColor.magenta
        case .failed:
          result = UIColor.red
        }
      }
      
      return result
    }
  }
  
  
}


