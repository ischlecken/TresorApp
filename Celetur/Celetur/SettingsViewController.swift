//
//  Created by Feldmaus on 27.08.17.
//  Copyright © 2017 ischlecken. All rights reserved.
//

import UIKit

class SettingsViewController: UITableViewController {
  
  var tresorAppState: TresorAppModel?
  
  override func viewDidLoad() {
    super.viewDidLoad()
  }
  
  // MARK: - Table view data source
  
  override func numberOfSections(in tableView: UITableView) -> Int {
    return 2
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return section==0 ? 2 : 2
  }
  
  @IBAction
  func createDummyUsersAction(_ sender: Any) {
    celeturLogger.debug("createDummyUser")
    
    self.tresorAppState?.tresorModel.createDummyUsers()
  }
  
  @IBAction
  func resetDataAction(_ sender: Any) {
    celeturLogger.debug("resetData")
    
    self.tresorAppState?.tresorModel.resetData()
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    var cellIdentifier = "settingCell"
    
    if indexPath.section==0 {
      switch indexPath.row {
      case 0:
        cellIdentifier = "userCell"
      case 1:
        cellIdentifier = "userdeviceCell"
      default:
        cellIdentifier = "settingCell"
      }
    } else if indexPath.section==1 {
      cellIdentifier = "actionCell"
    }
    
    let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
    if indexPath.section==0 {
      switch indexPath.row {
      case 0:
        cell.textLabel?.text = "TresorUser"
        cell.detailTextLabel?.text = "edit the list of known users"
        
      case 1:
        cell.textLabel?.text = "TresorUser Devices"
        cell.detailTextLabel?.text = "edit the list of known user devices"
      default:
        cell.textLabel?.text = "Settings"
        cell.detailTextLabel?.text = ""
      }
    } else if indexPath.section==1 {
      switch indexPath.row {
      case 0:
        
        if let b = cell.contentView.viewWithTag(42) as? UIButton {
          b.setTitle("Create Dummy User", for: .normal)
          b.addTarget(self, action:#selector(createDummyUsersAction(_:)), for: .touchUpInside)
        }
        
      case 1:
        
        if let b = cell.contentView.viewWithTag(42) as? UIButton {
          b.setTitle("Reset Data", for: .normal)
          b.addTarget(self, action:#selector(resetDataAction(_:)), for: .touchUpInside)
        }
        
      default:
        break
      }
    }
    
    return cell
  }
  
  
  
  // MARK: - Navigation
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    
    if segue.identifier == "showUserList" {
      let controller = segue.destination as! UserViewController
      
      controller.tresorAppState = self.tresorAppState
    } else if segue.identifier == "showUserdeviceList" {
      let controller = segue.destination as! UserDeviceViewController
      
      controller.tresorAppState = self.tresorAppState
    }
  }
  
}
