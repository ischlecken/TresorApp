import UIKit

class TresorDocumentCell: UITableViewCell {
  
  @IBOutlet weak var nameLabel: UILabel!
  @IBOutlet weak var descriptionLabel: UILabel!
  @IBOutlet weak var documentIdLabel: UILabel!
  @IBOutlet weak var createdLabel: UILabel!
  
  @IBOutlet weak var documentImage: UIImageView!
  
  override func awakeFromNib() {
    super.awakeFromNib()
   
  }
  
}
