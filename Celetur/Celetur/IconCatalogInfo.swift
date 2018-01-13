//
//  Copyright © 2017-2018 prisnoc. All rights reserved.
//

import Foundation
import CeleturKit

class IconCatalogInfo {
  
  var iconCatalog : IconCatalog {
    get {
      return self.getIconCatalog()
    }
  }
  
  fileprivate var _iconCatalog : IconCatalog?
  
  fileprivate func getIconCatalog() -> IconCatalog {
    if self._iconCatalog == nil {
      let urls = Bundle.iconCatalogURLs()
      
      for u in urls {
        if let p = IconCatalogSerializer.iconCatalog(jsonUrl: u) {
          
          self._iconCatalog = p
        }
      }
      
    }
    
    return self._iconCatalog!
  }
}
