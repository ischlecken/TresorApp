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

let celeturLogger = Logger("Celetur")
let appGroup = "group.net.prisnoc.Celetur"
let celeturKitIdentifier = "net.prisnoc.CeleturKit"

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {

  var window: UIWindow?
  lazy var persistentContainer: CoreDataStack = CoreDataStack("CeleturKit",using:Bundle(identifier:celeturKitIdentifier)!,inAppGroupContainer:appGroup)
  
  var tresorKeys: TresorKeys = TresorKeys(appGroup: appGroup)
  
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    // Override point for customization after application launch.
    let splitViewController = self.window!.rootViewController as! UISplitViewController
    let navigationController = splitViewController.viewControllers[splitViewController.viewControllers.count-1] as! UINavigationController
    navigationController.topViewController!.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem
    splitViewController.delegate = self

    let masterNavigationController = splitViewController.viewControllers[0] as! UINavigationController
    let controller = masterNavigationController.topViewController as! TresorViewController
    controller.tresorDataModel = TresorDataModel(self.persistentContainer)
    
    /*
    do {
      try tresorKeys.removeMasterKey()
    } catch CeleturKitError.keychainError(let keychainError){
      celeturLogger.debug("error fetching tresor masterkey: \(keychainError)")
    } catch {
      celeturLogger.error("error fetching tresor masterkey",error:error)
    } */
    
    tresorKeys.getMasterKey(masterKeyCompletion:{ (masterKey:TresorKey?, error:Error?) -> Void in
      if let e = error {
        celeturLogger.debug("error:\(e)")
      } else if let mk = masterKey {
        celeturLogger.info("masterKey:\(mk.accountName),\(mk.accessToken ?? "not set")")
      }
    })
    
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
    persistentContainer.saveContext()
  }

  // MARK: - Split view

  func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController:UIViewController, onto primaryViewController:UIViewController) -> Bool {
      guard let secondaryAsNavController = secondaryViewController as? UINavigationController else { return false }
      guard let topAsDetailController = secondaryAsNavController.topViewController as? DetailViewController else { return false }
      if topAsDetailController.detailItem == nil {
          // Return true to indicate that we have handled the collapse by doing nothing; the secondary controller will be discarded.
          return true
      }
      return false
  }
  

}

