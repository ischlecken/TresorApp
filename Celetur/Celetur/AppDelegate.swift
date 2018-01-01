//
//  AppDelegate.swift
//  Celetur
//
//  Created by Feldmaus on 09.07.17.
//  Copyright © 2017 ischlecken. All rights reserved.
//

import UIKit
import CoreData
import CeleturKit
import CloudKit
import UserNotifications

let celeturLogger = Logger("Celetur")

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {

  var window: UIWindow?
  var tresorAppModel = TresorAppModel()
  var progressView : UIProgressView?
  var infoViewController : InfoViewController?
  var gradientView : GradientView?
  
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    self.celeturUIAppearance()
    
    let splitViewController = self.window!.rootViewController as! UISplitViewController
    
    splitViewController.view.backgroundColor = UIColor.clear
    
    let gradientView = GradientView(frame:(self.window?.frame)!)
    self.window?.addSubview(gradientView)
    self.window?.sendSubview(toBack: gradientView)
    self.gradientView = gradientView
    
    let navigationController = splitViewController.viewControllers[splitViewController.viewControllers.count-1] as! UINavigationController
    navigationController.topViewController!.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem
    splitViewController.delegate = self
    
    let masterNavigationController = splitViewController.viewControllers[0] as! UINavigationController
    let controller = masterNavigationController.topViewController as! TresorViewController
    controller.tresorAppState = self.tresorAppModel
    
    self.gradientView?.dimGradient()
    
    if let navigationBar = controller.navigationController?.navigationBar {
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
  
    UNUserNotificationCenter.current().delegate = self
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
      if granted && error == nil {
        DispatchQueue.main.async {
            application.registerForRemoteNotifications()
        }
      } else {
        celeturLogger.debug(error?.localizedDescription ?? "authorization is not granted. check your app notification setting in the setting app")
      }
    }
    
    self.tresorAppModel.completeSetup(appDelegate:self)
    
    return true
  }
  
  func applicationWillResignActive(_ application: UIApplication) {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
  }

  func applicationDidEnterBackground(_ application: UIApplication) {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
  }

  func applicationWillEnterForeground(_ application: UIApplication) {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
  }

  func applicationDidBecomeActive(_ application: UIApplication) {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
  }

  func applicationWillTerminate(_ application: UIApplication) {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    // Saves changes in the application's managed object context before the application terminates.
   
  }

  // MARK: - Split view

  func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController:UIViewController, onto primaryViewController:UIViewController) -> Bool {
      guard let secondaryAsNavController = secondaryViewController as? UINavigationController else { return false }
      guard let topAsDetailController = secondaryAsNavController.topViewController as? TresorDocumentItemViewController else { return false }
      if topAsDetailController.tresorDocumentItem == nil {
          // Return true to indicate that we have handled the collapse by doing nothing; the secondary controller will be discarded.
          return true
      }
      return false
  }
  
  // MARK: - Remote Notification
  
  func application(_ application: UIApplication,didFailToRegisterForRemoteNotificationsWithError error: Error) {
    celeturLogger.error("Registration for remote notifications failed", error:error)
    
    // TEST-TOKEN
    // 7000000000000000000000aaaaaaabbbbbbbcccccccdddddddeeeeeeefffffff
    // 703115609b3d27416922deee926a38697601f2c713185bfd2c80055b0cf7dfda
    
    #if (arch(i386) || arch(x86_64))
      let fakeId = "\(UIDevice.current.identifierForVendor?.uuidString ?? "")"
      
      if let deviceToken = fakeId.data(using: .utf8) {
        celeturLogger.info("Emulate registration in Simulator using \(fakeId)")
        
        self.tresorAppModel.tresorModel.setCurrentDeviceAPNToken(deviceToken:deviceToken)
      }
    #endif
  }
  
  // 2
  func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    celeturLogger.debug("Registration for remote notifications successfull with token \(deviceToken.hexEncodedString())")
    
    self.tresorAppModel.tresorModel.setCurrentDeviceAPNToken(deviceToken:deviceToken)
  }
  
  func application(_ application: UIApplication,
                   didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                   fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    celeturLogger.debug("Received notification!")
    
    let dict = userInfo as! [String: NSObject]
    guard let notification:CKDatabaseNotification = CKNotification(fromRemoteNotificationDictionary:dict) as? CKDatabaseNotification else { return }
    
    self.tresorAppModel.fetchCloudKitChanges(in: notification.databaseScope) {
      completionHandler( .newData )
    }
  }
  
  // MARK:- GUI
  func setTitle(title:String) {
    let splitViewController = self.window!.rootViewController as! UISplitViewController
    let masterNavigationController = splitViewController.viewControllers[0] as! UINavigationController
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
  
  fileprivate func celeturUIAppearance() {
    
    UINavigationBar.appearance().barTintColor = .celeturPrimary
    UINavigationBar.appearance().tintColor = .celeturSecondary
    UINavigationBar.appearance().largeTitleTextAttributes = [NSAttributedStringKey.foregroundColor: UIColor.celeturSecondary]
    UINavigationBar.appearance().titleTextAttributes = [NSAttributedStringKey.foregroundColor: UIColor.celeturSecondary]
    
    UINavigationBar.appearance().isTranslucent = false
  }
  
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
  
  
  func refreshViewsAfterChangeOfAppearance() {
    let windows = UIApplication.shared.windows
    for window in windows {
      for view in window.subviews {
        view.removeFromSuperview()
        window.addSubview(view)
      }
    }
  }
}

// MARK:- UNUserNotificationCenterDelegate

extension AppDelegate : UNUserNotificationCenterDelegate {
  func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
    
    celeturLogger.debug("UNUserNotificationCenterDelegate didReceive!")
    
    let userInfo = response.notification.request.content.userInfo
    
    guard let notification:CKDatabaseNotification = CKNotification(fromRemoteNotificationDictionary:userInfo) as? CKDatabaseNotification else { return }
    
    self.tresorAppModel.fetchCloudKitChanges(in: notification.databaseScope) {
       completionHandler()
    }
    
  }
}
