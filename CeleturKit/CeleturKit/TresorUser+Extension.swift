//
//  TresorUser+Extension.swift
//  CeleturKit
//
import Contacts

extension TresorUser {
  
  class func createUser(context:NSManagedObjectContext,firstName:String, lastName: String, appleid: String) -> TresorUser {
    let newUser = TresorUser(context: context)
    
    newUser.firstname = firstName
    newUser.lastname = lastName
    newUser.email = appleid
    newUser.createts = Date()
    newUser.id = String.uuid()
    
    return newUser
  }
  
  
  class func createTempUser(context: NSManagedObjectContext, contact: CNContact) -> TresorUser {
    let result = TresorUser(context:context)
    
    result.createts = Date()
    result.id = String.uuid()
    
    result.firstname = contact.givenName
    result.lastname = contact.familyName
    result.email = contact.emailAddresses.first?.value as String?
    result.profilepicture = contact.imageData
    
    return result
  }
  
  class func findTresorUser(context:NSManagedObjectContext, withId id:String) -> TresorUser? {
    var result : TresorUser?
    
    let fetchRequest: NSFetchRequest<TresorUser> = TresorUser.fetchRequest()
    
    // Set the batch size to a suitable number.
    fetchRequest.fetchBatchSize = 1
    fetchRequest.predicate = NSPredicate(format: "id = %@", id)
    
    do {
      let records = try context.fetch(fetchRequest)
      
      if records.count>0 {
        result = records[0]
      }
    } catch {
      celeturKitLogger.error("Error while fetching tresoruser",error:error)
    }
    
    return result
  }
  
  class func createAndFetchUserFetchedResultsController(context:NSManagedObjectContext) throws -> NSFetchedResultsController<TresorUser> {
    let fetchRequest: NSFetchRequest<TresorUser> = TresorUser.fetchRequest()
    
    // Set the batch size to a suitable number.
    fetchRequest.fetchBatchSize = 20
    
    // Edit the sort key as appropriate.
    let sortDescriptor = NSSortDescriptor(key: "createts", ascending: false)
    
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
}
