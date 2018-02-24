//
//  Tresor+Extension.swift
//  CeleturKit
//

public extension Tresor {
  
  public var modifyts: Date {
    get {
      var result = self.createts!
      
      if let c = self.changets {
        result = c
      }
      
      return result
    }
  }
  
  public class func createTempTresor(context: NSManagedObjectContext, ckUserId: String?) throws -> Tresor {
    let newTresor = Tresor(context: context)
    newTresor.createts = Date()
    newTresor.changets = newTresor.createts
    newTresor.id = String.uuid()
    newTresor.ckuserid = ckUserId
    newTresor.iconname = "vault"
    newTresor.nonce = try Data(withRandomData: SymmetricCipherAlgorithm.aes_256.requiredBlockSize())
    newTresor.cksyncstatus = CloudKitEntitySyncState.pending.rawValue
    
    return newTresor
  }
  
  
  class func createAndFetchTresorFetchedResultsController(context: NSManagedObjectContext) throws -> NSFetchedResultsController<Tresor> {
    let fetchRequest: NSFetchRequest<Tresor> = Tresor.fetchRequest()
    
    // Set the batch size to a suitable number.
    fetchRequest.fetchBatchSize = 20
    
    // Edit the sort key as appropriate.
    let sortDescriptor0 = NSSortDescriptor(key: "ckuserid", ascending: false)
    let sortDescriptor1 = NSSortDescriptor(key: "changets", ascending: false)
    
    fetchRequest.sortDescriptors = [sortDescriptor0,sortDescriptor1]
    
    let aFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                               managedObjectContext: context,
                                                               sectionNameKeyPath: "ckuserid",
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
    var logEntries = [TresorLogInfo]()
    
    logEntries.append(TresorLogInfo(messageIndentLevel: 0, messageName: .deleteObject, messageParameter1:self.name,
                                    objectType: .Tresor, objectId: self.id!))
    
    if let docs = self.documents {
      for doc in docs {
        if let o = doc as? TresorDocument {
          o.deleteTresorDocument(logEntries: &logEntries, intentLevelOffset: 1)
        }
      }
    }
    
    TresorLog.createLogEntries(context: self.managedObjectContext!, ckUserId: self.ckuserid, entries: logEntries)
    
    self.managedObjectContext!.delete(self)
  }
  
  public func shouldEncryptAllDocumentItemsThatShouldBeEncryptedByDevice() -> Bool {
    guard let documents = self.documents else { return false }
    
    var result = false
    
    for case let tresorDocument as TresorDocument in documents {
      if let items = tresorDocument.documentitems {
        for case let item as TresorDocumentItem in items where item.itemStatus == .shouldBeEncryptedByDevice {
          result = true
          break
        }
      }
    }
    
    return result
  }
  
  public func encryptAllDocumentItemsThatShouldBeEncryptedByDevice(context: NSManagedObjectContext, masterKey: TresorKey) {
    guard let tempTresor = context.object(with: self.objectID) as? Tresor,
      let documents = tempTresor.documents
      else { return }
    
    celeturKitLogger.debug("encryptAllDocumentItemsThatShouldBeEncryptedByDevice()")
    
    context.perform {
      do {
        for case let tresorDocument as TresorDocument in documents {
          if let items = tresorDocument.documentitems {
            for case let item as TresorDocumentItem in items where item.itemStatus == .shouldBeEncryptedByDevice {
              let _ = item.encryptMessagePayload(masterKey: masterKey)
            }
          }
        }
        
        celeturKitLogger.debug("save for encryptAllDocumentItemsThatShouldBeEncryptedByDevice...")
        try context.save()
      } catch {
        celeturKitLogger.error("Error while saving encryptAllDocumentItemsThatShouldBeEncryptedByDevice...",error:error)
      }
    }
  }
}
