//
//  UIRefreshControl+Extension.swift
//  Celetur
//
//  Created by Feldmaus on 01.11.17.
//  Copyright © 2017 ischlecken. All rights reserved.
//

import UIKit

extension UIRefreshControl {
  
  func beginRefreshingManually() {
    if let scrollView = superview as? UIScrollView {
      scrollView.setContentOffset(CGPoint(x: 0, y: scrollView.contentOffset.y - frame.height), animated: true)
    }
    beginRefreshing()
  }
}
