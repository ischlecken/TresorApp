//
//  Copyright © 2018 prisnoc. All rights reserved.
//

import UIKit
import CloudKit
import UserNotifications
import CeleturKit

class TresorSplitViewController: UISplitViewController {

  fileprivate var gradientView : GradientView?
  fileprivate var progressView : UIProgressView?
  fileprivate var infoViewController : InfoViewController?
  
  var tresorAppModel : TresorAppModel?
  
  override func awakeFromNib() {
    self.delegate = self.tresorViewController
  }
  
  func completeSetup() {
    UNUserNotificationCenter.current().delegate = self
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
      if granted && error == nil {
        DispatchQueue.main.async {
          UIApplication.shared.registerForRemoteNotifications()
        }
      } else {
        celeturLogger.debug(error?.localizedDescription ?? "authorization is not granted. check your app notification setting in the setting app")
      }
    }
    
    self.tresorAppModel?.completeSetup(appDelegate:UIApplication.shared.delegate as? AppDelegate)
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    self.preferredDisplayMode = .allVisible
    self.view.backgroundColor = UIColor.clear
    self.tresorViewController.tresorAppModel = self.tresorAppModel
    
    self.createGradientView()
    self.createProgressView()
    
    self.completeSetup()
  }
  
  override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    
    celeturLogger.debug("viewWillTransition() toSize:\(size)")
    
    self.gradientView?.frame = CGRect(origin: CGPoint.zero, size: size)
    
  }
  
  var tresorViewController: TresorViewController {
    get {
      let navigationController = self.viewControllers.first as! UINavigationController
      
      return navigationController.topViewController as! TresorViewController
    }
  }
  
  var masterViewController: UIViewController {
    get {
      return self.viewControllers.first!
    }
  }
  
  var detailViewController: UIViewController? {
    get {
      return self.viewControllers.count>1 ? self.viewControllers.last : nil
    }
  }
  
  
  var tresorDocumentItemViewController: TresorDocumentItemViewController? {
    get {
      let navigationController = self.viewControllers.count>1 ? self.viewControllers.last as? UINavigationController : nil
      
      return navigationController?.topViewController as? TresorDocumentItemViewController
    }
  }
  
  lazy var tdivc : TresorDocumentItemViewController = {
    let vc = UIStoryboard(name: "Editor", bundle: nil).instantiateInitialViewController()
    
    return ((vc as! UINavigationController).topViewController as? TresorDocumentItemViewController)!
  }()
  
  fileprivate func createGradientView() {
    let window = (UIApplication.shared.delegate?.window!)!
    
    let gradientView = GradientView(frame:window.frame)
    window.addSubview(gradientView)
    window.sendSubview(toBack: gradientView)
    
    gradientView.dimGradient()
    self.gradientView = gradientView
  }
  
  fileprivate func createProgressView() {
    if let navigationBar = self.tresorViewController.navigationController?.navigationBar {
      let progressView = UIProgressView(progressViewStyle: .bar)
      
      progressView.progress = 1.0
      progressView.translatesAutoresizingMaskIntoConstraints = false
      
      navigationBar.addSubview(progressView)
      
      let left = NSLayoutConstraint(item: progressView, attribute: .left, relatedBy: .equal, toItem: navigationBar, attribute: .left, multiplier: 1.0, constant: 0.0)
      let bottom = NSLayoutConstraint(item: progressView, attribute: .top, relatedBy: .equal, toItem: navigationBar, attribute: .bottom, multiplier: 1.0, constant: 0.0)
      let width = NSLayoutConstraint(item: progressView, attribute: .width, relatedBy: .equal, toItem: navigationBar, attribute: .width, multiplier: 1.0, constant: 0.0)
      
      navigationBar.addConstraints([left,bottom,width])
      
      self.progressView = progressView
      self.progressView?.setProgress(0.0, animated: true)
    }
  }
  
  
  // MARK: - MasterKey UI
  
  
  func updateMasterKeyAvailablity(_ actAvailablityInTimeron: Int,maxAvailablityInTimeron: Int) {
    let progress = round(Float(actAvailablityInTimeron)/Float(maxAvailablityInTimeron) * 100.0) * 0.01
    
    self.progressView?.setProgress(progress, animated: true)
  }
  
  func masterKeyIsAvailable() {
    self.gradientView?.resetGradient()
  }
  
  func masterKeyIsNotAvailable() {
    self.gradientView?.dimGradient()
  }
  
  // MARK: - UI
  
  func setTitle(title:String) {
    let masterNavigationController = self.viewControllers[0] as! UINavigationController
    let controller = masterNavigationController.topViewController as! TresorViewController
    
    controller.navigationController?.title = title
  }
  
  func onOffline() {
    if self.infoViewController != nil {
      self.infoViewController?.dismissInfo()
      self.infoViewController = nil
    }
    
    self.infoViewController = InfoViewController(info: "Device is offline")
    self.infoViewController?.showInfo()
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
      if let ivc = self.infoViewController {
        ivc.dismissInfo()
        self.infoViewController = nil
      }
    }
  }
  
  func onOnline() {
    if self.infoViewController != nil {
      self.infoViewController?.dismissInfo()
      self.infoViewController = nil
    }
  }


  
}

//
// MARK: - UNUserNotificationCenterDelegate
//
extension TresorSplitViewController: UNUserNotificationCenterDelegate {
  
  func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       didReceive response: UNNotificationResponse,
                                       withCompletionHandler completionHandler: @escaping () -> Void) {
    celeturLogger.debug("UNUserNotificationCenterDelegate didReceive!")
    
    let userInfo = response.notification.request.content.userInfo
    
    guard let notification:CKDatabaseNotification = CKNotification(fromRemoteNotificationDictionary:userInfo) as? CKDatabaseNotification else { return }
    
    self.tresorAppModel?.fetchCloudKitChanges(in: notification.databaseScope) {
      completionHandler()
    }
  }
}

//
// MARK: - UIViewController+Extension
//
extension UIViewController {
  var tresorSplitViewController : TresorSplitViewController {
    get {
      return self.splitViewController as! TresorSplitViewController
    }
  }
}

