//
//  Created by Feldmaus on 15.08.17.
//  Copyright © 2017 ischlecken. All rights reserved.
//

import UIKit
import CeleturKit

class EditTresorViewController: UIViewController {
  
  var tresorAppState: TresorAppState?
  weak var tresor: Tresor?
  
  @IBOutlet weak var nameTextfield: UITextField!
  @IBOutlet weak var descriptionTextfield: UITextField!
  
  
  @IBAction func saveAction(_ sender: Any) {
    
      do {
        if let t = self.tresor {
          t.name = nameTextfield.text!
          t.tresordescription = descriptionTextfield.text
          
          try self.tresorAppState?.tresorDataModel.saveContext()
        } else {
          self.tresor = try self.tresorAppState?.tresorDataModel.createTresor(name:nameTextfield.text!,description:descriptionTextfield.text)
        }
        
        self.performSegue(withIdentifier: "unwindToTresor", sender: self)
      } catch {
        celeturLogger.error("saving tresor failed", error: error)
      }
    
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    if let t  = self.tresor {
      self.nameTextfield.text = t.name
      self.descriptionTextfield.text = t.tresordescription
    }
    
  }
  
  /*
   // MARK: - Navigation
   
   // In a storyboard-based application, you will often want to do a little preparation before navigation
   override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
   // Get the new view controller using segue.destinationViewController.
   // Pass the selected object to the new view controller.
   }
   */
  
}
