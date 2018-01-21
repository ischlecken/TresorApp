//
//  AppDelegate.swift
//  Celetur
//
//  Created by Feldmaus on 09.07.17.
//  Copyright © 2017 ischlecken. All rights reserved.
//

import UIKit
import CeleturKit
import CloudKit

let celeturLogger = Logger("Celetur")

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

  var window: UIWindow?
  var tresorAppModel = TresorAppModel()
  var tresorSplitViewContainer : TresorSplitViewContainer?
  
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    self.celeturUIAppearance()
    
    self.tresorSplitViewContainer = self.window!.rootViewController as? TresorSplitViewContainer
    self.tresorSplitViewContainer?.tresorAppModel = self.tresorAppModel
    
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
  
  /*
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
 */
  
  // MARK:- UI
  
  
  func onOffline() {
    self.tresorSplitViewContainer?.onOffline()
  }
  
  func onOnline() {
    self.tresorSplitViewContainer?.onOnline()
  }
  
  
  func updateMasterKeyAvailablity(_ actAvailablityInTimeron: Int,maxAvailablityInTimeron: Int) {
    self.tresorSplitViewContainer?.updateMasterKeyAvailablity(actAvailablityInTimeron, maxAvailablityInTimeron: maxAvailablityInTimeron)
  }
  
  func masterKeyIsAvailable() {
    self.tresorSplitViewContainer?.masterKeyIsAvailable()
  }
  
  func masterKeyIsNotAvailable() {
    self.tresorSplitViewContainer?.masterKeyIsNotAvailable()
  }
  
  fileprivate func celeturUIAppearance() {
    UINavigationBar.appearance().barTintColor = .celeturPrimary
    UINavigationBar.appearance().tintColor = .celeturSecondary
    UINavigationBar.appearance().largeTitleTextAttributes = [NSAttributedStringKey.foregroundColor: UIColor.celeturSecondary]
    UINavigationBar.appearance().titleTextAttributes = [NSAttributedStringKey.foregroundColor: UIColor.celeturSecondary]
    UINavigationBar.appearance().isTranslucent = false
  }
}


