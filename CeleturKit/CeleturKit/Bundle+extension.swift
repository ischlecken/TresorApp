//
//  Created by Feldmaus on 15.10.17.
//  Copyright © 2017-2018 prisnoc. All rights reserved.
//

extension Bundle {
  
  func coreDataModelURL(modelName:String) -> URL {
    guard let url = self.url(forResource: modelName, withExtension: "momd") else { celeturKitLogger.fatal("could not find coredata model") }
    
    return url
  }
  
  public class func templateURLs() -> [URL] {
    var result : [URL] = []
    
    do {
      let fileNames = try FileManager.default.contentsOfDirectory(atPath: Bundle.main.resourcePath!)
      
      for f in fileNames {
        if f.hasSuffix(".ctpl") {
          result.append( URL(fileURLWithPath: f, isDirectory: false, relativeTo: Bundle.main.resourceURL) )
        }
      }
    } catch {
      celeturKitLogger.error("Error while getting templates directory content", error: error)
    }
    
    return result
  }
  
}
