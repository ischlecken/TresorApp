//
//  URL+extension.swift
//  CeleturKit
//
//  Created by Feldmaus on 15.10.17.
//  Copyright © 2017 prisnoc. All rights reserved.
//

extension URL {
  
  static func applicationDocumentDirectory() -> URL {
    let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask) as [URL]
    
    return urls[0]
  }
  
  static func coreDataPersistentStoreURL(appGroupId:String, storeName:String) -> URL {
    guard let containerUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId)
      else { celeturKitLogger.fatal("could not find app group container") }
    
    return containerUrl.appendingPathComponent("\(storeName).sqlite")
  }
  
  static func appGroupSubdirectoryURL(appGroupId:String, dirName:String) throws -> URL  {
    guard let containerUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId)
      else { celeturKitLogger.fatal("could not find app group container") }
    
    let dirURL = containerUrl.appendingPathComponent("\(dirName)")
    if !FileManager.default.fileExists(atPath: dirURL.path) {
      try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: false, attributes: nil)
    }
    
    return dirURL
    
  }
  
}
