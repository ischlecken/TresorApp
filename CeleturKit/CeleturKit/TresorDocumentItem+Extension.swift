//
//  TresorDocumentItem+Extension.swift
//  CeleturKit
//

extension TresorDocumentItem {

  class func createPendingTresorDocumentItem(context:NSManagedObjectContext,
                                             tresorDocument:TresorDocument,
                                             userDevice:TresorUserDevice) -> TresorDocumentItem {
    let result = TresorDocumentItem(context: context)
    
    result.createts = Date()
    result.changets = result.createts
    result.id = String.uuid()
    result.status = "pending"
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
}


