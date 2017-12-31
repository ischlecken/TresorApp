//
//  InfoViewController.swift
//  Celetur
//
//  Created by Feldmaus on 20.11.17.
//  Copyright © 2017 ischlecken. All rights reserved.
//

import UIKit

class InfoViewController: UIViewController, CAAnimationDelegate {
  
  let infoLabel : UILabel
  
  init(info:String) {
    self.infoLabel = UILabel()
    
    self.infoLabel.text = info
    self.infoLabel.textAlignment = .center
    self.infoLabel.textColor = UIColor.celeturPrimary
    
    //self.infoLabel.layer.borderColor = UIColor.white.cgColor
    //self.infoLabel.layer.borderWidth = CGFloat(2.0)
    self.infoLabel.layer.cornerRadius = CGFloat(8.0)
    self.infoLabel.layer.backgroundColor = UIColor.white.withAlphaComponent(0.8).cgColor
    self.infoLabel.layer.shadowColor = UIColor.white.cgColor
    self.infoLabel.layer.shadowOpacity = 0.8
    self.infoLabel.layer.shadowOffset = CGSize(width: 4, height: 4)
    
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder aDecoder: NSCoder) {
    self.infoLabel = UILabel()
    
    super.init(coder: aDecoder)
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
  }
  
  
  func showInfo() {
    if let window = UIApplication.shared.windows.first {
      let width = window.frame.size.width
      
      self.infoLabel.frame = CGRect(origin: CGPoint(x:10.0,y:60.0), size: CGSize(width: width-20.0, height: CGFloat(40)))
      
      window.addSubview(self.infoLabel)
      
      let flyTop = CASpringAnimation(keyPath: "position.y")
      flyTop.fromValue = -20.0
      flyTop.toValue = 80.0
      flyTop.duration = 2.0
      
      flyTop.initialVelocity = 40.0
      flyTop.mass = 10.0
      flyTop.stiffness = 1500.0
      flyTop.damping = 100.0
      
      self.infoLabel.layer.add(flyTop, forKey: nil)
    }
  }
  
  func dismissInfo() {
    let scale = CABasicAnimation(keyPath: "transform.scale")
    scale.fromValue = [1,1]
    scale.toValue = [0.5,0.5]
    scale.duration = 0.6
    
    let disappear = CABasicAnimation(keyPath: "opacity")
    disappear.fromValue = 1.0
    disappear.toValue = 0.0
    disappear.duration = 0.6
    disappear.setValue("disappear", forKey: "name")
    disappear.delegate = self
    
    self.infoLabel.layer.add(scale, forKey: nil)
    self.infoLabel.layer.add(disappear, forKey: nil)
  }
  
  func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
    guard let name = anim.value(forKey: "name") as? String else { return }
    
    if name == "disappear" {
      celeturLogger.debug("animation for disappear finished.")
      self.infoLabel.removeFromSuperview()
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
