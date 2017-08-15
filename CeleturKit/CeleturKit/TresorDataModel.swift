//
//  TresorDataModel.swift
//  CeleturKit
//
//  Created by Feldmaus on 06.08.17.
//  Copyright © 2017 prisnoc. All rights reserved.
//

import Foundation

public class TresorDataModel {
  
  var managedContext : NSManagedObjectContext? = nil
  let cipherQueue = OperationQueue()
  
  public init(_ coreDataStack:CoreDataStack) {
    self.managedContext = coreDataStack.context
  }
  
  public func createTresor(name:String, description:String?) throws -> Tresor {
    let newTresor = Tresor(context: self.managedContext!)
    newTresor.createts = Date()
    newTresor.id = CeleturKitUtil.create()
    newTresor.name = name
    newTresor.tresordescription = description
    newTresor.nonce = try Data(withRandomData: SymmetricCipherAlgorithm.aes_256.requiredBlockSize())
    
    try self.saveContext()
    
    return newTresor
  }
  
  public func createTresorDocument(tresor:Tresor) throws -> TresorDocument {
    let newTresorDocument = TresorDocument(context: self.managedContext!)
    newTresorDocument.createts = Date()
    newTresorDocument.id = CeleturKitUtil.create()
    newTresorDocument.tresorid = tresor
    newTresorDocument.nonce = try Data(withRandomData:SymmetricCipherAlgorithm.aes_256.requiredBlockSize())
    
    try self.saveContext()
    
    return newTresorDocument
  }
  
  public func createTresorDocumentItem(tresorDocument:TresorDocument,masterKey:TresorKey, onCompleted:(()->Void)? = nil) throws {
    let key = masterKey.accessToken
    let plainText = "{ 'title': 'gmx.de','user':'bla@fasel.de','password':'hugo'}"
    
    let operation = AES256EncryptionOperation(key:masterKey.accessToken!,inputString: plainText, iv:nil)
    try operation.createRandomIV()
    
    operation.mainQueueCompletionBlock = { (cipherOperation) in
      let newTresorDocumentItem = TresorDocumentItem(context: self.managedContext!)
      
      newTresorDocumentItem.createts = Date()
      newTresorDocumentItem.id = CeleturKitUtil.create()
      newTresorDocumentItem.type = "main"
      newTresorDocumentItem.mimetype = "application/json"
      newTresorDocumentItem.payload = cipherOperation.outputData
      newTresorDocumentItem.nonce = cipherOperation.iv
      
      tresorDocument.addToItems(newTresorDocumentItem)
      
      celeturKitLogger.debug("plain:\(plainText) key:\(key!) encryptedText:\(String(describing: cipherOperation.outputData?.hexEncodedString()))")
      
      do {
        try self.saveContext()
        
        onCompleted?()
      } catch {
        celeturKitLogger.error("Error while saving tresordocumentitem", error: error)
      }
    }
    
    self.cipherQueue.addOperation(operation)
  }
  
  public func decryptTresorDocumentItemPayload(tresorDocumentItem:TresorDocumentItem,masterKey:TresorKey, completionBlock: SymmetricCipherCompletionType?) {
    let operation = AES256DecryptionOperation(key:masterKey.accessToken!,inputData: tresorDocumentItem.payload!, iv:tresorDocumentItem.nonce)
    
    if let c = completionBlock {
      operation.mainQueueCompletionBlock = c
    }
    
    self.cipherQueue.addOperation(operation)
  }
  
  public func saveContext() throws {
    do {
      try self.managedContext!.save()
    } catch {
      throw CeleturKitError.dataSaveFailed(coreDataError: error as NSError)
    }
  }
  
  
  public func createAndFetchTresorFetchedResultsController() throws -> NSFetchedResultsController<Tresor> {
    let fetchRequest: NSFetchRequest<Tresor> = Tresor.fetchRequest()
    
    // Set the batch size to a suitable number.
    fetchRequest.fetchBatchSize = 20
    
    // Edit the sort key as appropriate.
    let sortDescriptor = NSSortDescriptor(key: "createts", ascending: false)
    
    fetchRequest.sortDescriptors = [sortDescriptor]
    
    let aFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.managedContext!, sectionNameKeyPath: nil, cacheName: "Tresor")
    
    do {
      try aFetchedResultsController.performFetch()
    } catch {
      throw CeleturKitError.creationOfFetchResultsControllerFailed(coreDataError: error as NSError)
    }
    
    return aFetchedResultsController
  }
 
}
