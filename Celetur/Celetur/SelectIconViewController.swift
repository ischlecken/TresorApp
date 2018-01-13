//
//  Copyright © 2018 prisnoc. All rights reserved.
//

import UIKit
import CeleturKit

private let reuseIdentifier = "IconCell"

class SelectIconViewController: UICollectionViewController {
  
  var tresorAppState: TresorAppModel?
  var selectedIcon : IconCatalogItem?
  
  fileprivate var iconCatalog : IconCatalog?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    self.collectionView!.register(UINib(nibName:"IconCell",bundle:nil), forCellWithReuseIdentifier: reuseIdentifier)
    
    self.iconCatalog = tresorAppState?.iconCatalogInfo.iconCatalog
  }
  
  
  
  // MARK: UICollectionViewDataSource
  
  override func numberOfSections(in collectionView: UICollectionView) -> Int {
    return self.iconCatalog?.sections.count ?? 0
  }
  
  
  override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return self.iconCatalog?.sections[section].icons.count ?? 0
  }
  
  override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    self.selectedIcon = self.iconCatalog?.sections[indexPath.section].icons[indexPath.row]
    
    let cell = collectionView.cellForItem(at: indexPath)
    cell?.contentView.backgroundColor = UIColor.celeturPrimary
  }
  
  override func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
    let cell = collectionView.cellForItem(at: indexPath)
    cell?.contentView.backgroundColor = UIColor.clear
  }
  
  override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! IconCell
    
    let icon = self.iconCatalog?.sections[indexPath.section].icons[indexPath.row]
    
    cell.iconView.image = UIImage(named:icon!.name)
    cell.iconName.text = icon?.description
    
    return cell
  }
  
  // MARK: UICollectionViewDelegate
  
  override func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
    return true
  }
  
  override func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
    return true
  }
  
  /*
   // Uncomment these methods to specify if an action menu should be displayed for the specified item, and react to actions performed on the item
   override func collectionView(_ collectionView: UICollectionView, shouldShowMenuForItemAt indexPath: IndexPath) -> Bool {
   return false
   }
   
   override func collectionView(_ collectionView: UICollectionView, canPerformAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
   return false
   }
   
   override func collectionView(_ collectionView: UICollectionView, performAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) {
   
   }
   */
  
}
