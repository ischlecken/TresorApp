//
//  CloudKitServerChangeToken+Extension.swift
//  CeleturKit
//
import CloudKit

extension CloudKitServerChangeToken {
  
  class func getCloudKitServerChangeToken(context:NSManagedObjectContext, name:String) -> CloudKitServerChangeToken? {
    var result : CloudKitServerChangeToken?
    
    let fetchRequest: NSFetchRequest<CloudKitServerChangeToken> = CloudKitServerChangeToken.fetchRequest()
    
    // Set the batch size to a suitable number.
    fetchRequest.fetchBatchSize = 1
    fetchRequest.predicate = NSPredicate(format: "name = %@", name)
    
    do {
      let records = try context.fetch(fetchRequest)
      
      if records.count>0 {
        result = records[0]
      }
    } catch {
      celeturKitLogger.error("Error while fetching serverchangetoken",error:error)
    }
    
    return result
  }
  
  class func saveCloudKitServerChangeToken(context:NSManagedObjectContext, name:String, changeToken:CKServerChangeToken) {
    let record = self.getCloudKitServerChangeToken(context:context, name: name)
    
    if let r = record {
      r.data = NSKeyedArchiver.archivedData(withRootObject: changeToken)
      r.createts = Date()
    } else {
      let _ = self.createCloudKitServerChangeToken(context:context, name:name,changeToken: changeToken)
    }
  }
  
  class func getCloudKitCKServerChangeToken(context:NSManagedObjectContext,name:String) -> CKServerChangeToken? {
    let result = self.getCloudKitServerChangeToken(context:context, name: name)
    
    if let r = result {
      return NSKeyedUnarchiver.unarchiveObject(with: r.data!) as? CKServerChangeToken
    }
    
    return nil
  }
  
  
  class func createCloudKitServerChangeToken(context:NSManagedObjectContext,
                                             name:String,
                                             changeToken:CKServerChangeToken) -> CloudKitServerChangeToken {
    let result = CloudKitServerChangeToken(context: context)
    
    result.name = name
    result.createts = Date()
    result.data = NSKeyedArchiver.archivedData(withRootObject: changeToken)
    
    return result
  }
  
}
