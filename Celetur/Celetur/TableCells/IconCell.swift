//

//  Copyright © 2018 prisnoc. All rights reserved.
//

import UIKit

class IconCell: UICollectionViewCell {
  
  @IBOutlet weak var iconView: UIImageView!
  @IBOutlet weak var iconName: UILabel!
  
  override func awakeFromNib() {
    super.awakeFromNib()
    
    self.translatesAutoresizingMaskIntoConstraints = false
  }
  
}
