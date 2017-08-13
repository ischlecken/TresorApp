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
  
  public init(_ coreDataStack:CoreDataStack) {
    self.managedContext = coreDataStack.context
  }
  
  public func createTresor() throws -> Tresor {
    let newTresor = Tresor(context: self.managedContext!)
    newTresor.createts = Date()
    newTresor.id = CeleturKitUtil.create()
    newTresor.name = "test"
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
  
  public func createTresorDocumentItem(tresorDocument:TresorDocument,masterKey:TresorKey) throws -> TresorDocumentItem {
    let algorithm = SymmetricCipherAlgorithm.aes_256
    let key = masterKey.accessToken
    let plainText = "{ 'title': 'gmx.de','user':'bla@fasel.de','password':'hugo'}"
    let nonce = try Data(withRandomData:algorithm.requiredBlockSize())
    let cipher = SymmetricCipher(algorithm: algorithm,options: [.PKCS7Padding], iv:nonce)
    let encryptedText = try cipher.crypt(string:plainText,key:key!)
    
    let newTresorDocumentItem = TresorDocumentItem(context: self.managedContext!)
    newTresorDocumentItem.createts = Date()
    newTresorDocumentItem.id = CeleturKitUtil.create()
    newTresorDocumentItem.type = "main"
    newTresorDocumentItem.mimetype = "application/json"
    newTresorDocumentItem.payload = encryptedText
    newTresorDocumentItem.nonce = nonce
    
    tresorDocument.addToItems(newTresorDocumentItem)
    
    celeturKitLogger.debug("plain:\(plainText) key:\(key!) encryptedText:\(encryptedText.hexEncodedString())")
    
    try self.saveContext()
    
    return newTresorDocumentItem
  }
  
  public func decryptTresorDocumentItemPayload(tresorDocumentItem:TresorDocumentItem,masterKey:TresorKey) throws -> Data? {
    let algorithm = SymmetricCipherAlgorithm.aes_256
    let key = masterKey.accessToken
    let nonce = tresorDocumentItem.nonce
    var result:Data? = nil
    
    if nonce != nil {
      let cipher = SymmetricCipher(algorithm: algorithm,options: [.PKCS7Padding], iv:nonce!)
      
      result = try cipher.decrypt(tresorDocumentItem.payload!,key:key!)
    }
    
    return result
  }
  
  func saveContext() throws {
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
  
  public func createAndFetchTresorDocumentFetchedResultsController() throws -> NSFetchedResultsController<TresorDocument> {
    let fetchRequest: NSFetchRequest<TresorDocument> = TresorDocument.fetchRequest()
    
    // Set the batch size to a suitable number.
    fetchRequest.fetchBatchSize = 20
    
    // Edit the sort key as appropriate.
    let sortDescriptor = NSSortDescriptor(key: "createts", ascending: false)
    
    fetchRequest.sortDescriptors = [sortDescriptor]
    
    let aFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.managedContext!, sectionNameKeyPath: nil, cacheName: "TresorDocument")
    
    do {
      try aFetchedResultsController.performFetch()
    } catch {
      throw CeleturKitError.creationOfFetchResultsControllerFailed(coreDataError: error as NSError)
    }
    
    return aFetchedResultsController
  }

  public func createAndFetchTresorDocumentItemFetchedResultsController() throws -> NSFetchedResultsController<TresorDocumentItem> {
    let fetchRequest: NSFetchRequest<TresorDocumentItem> = TresorDocumentItem.fetchRequest()
    
    // Set the batch size to a suitable number.
    fetchRequest.fetchBatchSize = 20
    
    // Edit the sort key as appropriate.
    let sortDescriptor = NSSortDescriptor(key: "createts", ascending: false)
    
    fetchRequest.sortDescriptors = [sortDescriptor]
    
    let aFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.managedContext!, sectionNameKeyPath: nil, cacheName: "TresorDocumentItem")
    
    do {
      try aFetchedResultsController.performFetch()
    } catch {
      throw CeleturKitError.creationOfFetchResultsControllerFailed(coreDataError: error as NSError)
    }
    
    return aFetchedResultsController
  }
}
