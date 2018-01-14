//
//  CollectionViewHeader.swift
//  Celetur
//
//  Created by Feldmaus on 14.01.18.
//  Copyright © 2018 ischlecken. All rights reserved.
//

import UIKit

class CollectionViewHeader: UICollectionReusableView {
  
  @IBOutlet weak var headerLabel: UILabel!
  
  override func awakeFromNib() {
    super.awakeFromNib()
    
    celeturLogger.debug("CollectionViewHeader.awakeFromNib")
  }
  
}
