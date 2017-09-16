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
    return 1
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return 2
  }
  
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    var cellIdentifier : String
    
    switch indexPath.row {
    case 0:
      cellIdentifier = "userCell"
    case 1:
      cellIdentifier = "userdeviceCell"
    default:
      cellIdentifier = "settingCell"
    }
    
    let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
    
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
