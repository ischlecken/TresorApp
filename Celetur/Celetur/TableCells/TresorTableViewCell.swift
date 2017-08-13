//
//  Created by Feldmaus on 13.08.17.
//  Copyright © 2017 ischlecken. All rights reserved.
//

import UIKit

class TresorTableViewCell: UITableViewCell {
  
  @IBOutlet weak var tresorImage: UIImageView!
  @IBOutlet weak var nameLabel: UILabel!
  @IBOutlet weak var createdLabel: UILabel!
  
  override func awakeFromNib() {
    super.awakeFromNib()
    
    print("awake from nib")
  }
  
}
