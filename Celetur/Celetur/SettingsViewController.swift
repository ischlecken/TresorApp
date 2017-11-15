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
  
  override func viewWillAppear(_ animated: Bool) {
    
    if let parent = self.view.superview {
      let backgroundView = GradientView()
      backgroundView.translatesAutoresizingMaskIntoConstraints = false
      
      parent.insertSubview(backgroundView, at: 0)
      
      let left = NSLayoutConstraint(item: backgroundView, attribute: .left, relatedBy: .equal, toItem: parent, attribute: .left, multiplier: 1.0, constant: 0.0)
      let top = NSLayoutConstraint(item: backgroundView, attribute: .top, relatedBy: .equal, toItem: parent, attribute: .top, multiplier: 1.0, constant: 0.0)
      let width = NSLayoutConstraint(item: backgroundView, attribute: .width, relatedBy: .equal, toItem: parent, attribute: .width, multiplier: 1.0, constant: 0.0)
      let height = NSLayoutConstraint(item: backgroundView, attribute: .height, relatedBy: .equal, toItem: parent, attribute: .height, multiplier: 1.0, constant: 0.0)
      
      parent.addConstraints([left,top,width,height])
      
      DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
        backgroundView.dimGradient()
      }
    }
  }
  
  // MARK: - Table view data source
  
  override func numberOfSections(in tableView: UITableView) -> Int {
    return 2
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return section==0 ? 1 : 4
  }
  
  
  @IBAction
  func resetChangeTokensAction(_ sender: Any) {
    self.tresorAppState?.tresorModel.resetChangeTokens()
  }
  
  @IBAction
  func removeAllCloudKitDataAction(_ sender: Any) {
    self.tresorAppState?.tresorModel.removeAllCloudKitData()
  }
  
  @IBAction
  func removeAllCoreDataAction(_ sender: Any) {
    self.tresorAppState?.tresorModel.removeAllCoreData()
  }
  
  @IBAction
  func resetAllAction(_ sender: Any) {
    self.tresorAppState?.tresorModel.resetAll()
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    var cellIdentifier = "settingCell"
    
    if indexPath.section==0 {
      switch indexPath.row {
      case 0:
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
          b.setTitle("Reset Change Tokens", for: .normal)
          b.addTarget(self, action:#selector(self.resetChangeTokensAction(_:)), for: .touchUpInside)
        }
     
      case 1:
        
        if let b = cell.contentView.viewWithTag(42) as? UIButton {
          b.setTitle("Remove All CloudKit Data", for: .normal)
          b.addTarget(self, action:#selector(self.removeAllCloudKitDataAction(_:)), for: .touchUpInside)
        }
        
      case 2:
        
        if let b = cell.contentView.viewWithTag(42) as? UIButton {
          b.setTitle("Remove All Core Data", for: .normal)
          b.addTarget(self, action:#selector(self.removeAllCoreDataAction(_:)), for: .touchUpInside)
        }
      
      case 3:
        
        if let b = cell.contentView.viewWithTag(42) as? UIButton {
          b.setTitle("Reset All", for: .normal)
          b.addTarget(self, action:#selector(self.resetAllAction(_:)), for: .touchUpInside)
        }
        
        
      default:
        break
      }
    }
    
    return cell
  }
  
  
  
  // MARK: - Navigation
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    
    if segue.identifier == "showUserdeviceList" {
      let controller = segue.destination as! UserDeviceViewController
      
      controller.tresorAppState = self.tresorAppState
    }
  }
  
}
