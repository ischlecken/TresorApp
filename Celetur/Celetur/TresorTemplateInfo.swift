//
//  Copyright © 2017-2018 prisnoc. All rights reserved.
//

import Foundation
import CeleturKit
import CloudKit

class TresorTemplateInfo {
  
  var templatenames : [String] = []
  
  fileprivate var templates : [String: PayloadMetainfo] = [:]
  
  init() {
    let templateUrls = Bundle.templateURLs()
    
    for u in templateUrls {
      if let p = PayloadSerializer.payloadMetainfo(jsonUrl: u) {
        
        self.templatenames.append(p.name)
        self.templates[p.name] = p
        
      }
    }
  }
  
  
  public func payloadMetainfoItem(name: String, indexPath: IndexPath) -> PayloadMetainfoItem? {
    guard let t = self.templates[name],
      indexPath.section < t.sections.count && indexPath.row < t.sections[indexPath.section].items.count
      else { return nil }
    
    return t.sections[indexPath.section].items[indexPath.row]
  }
  
  public func payloadMetainfo(name: String) -> PayloadMetainfo? {
    return self.templates[name]
  }
}
