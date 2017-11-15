//
//  GradientView.swift
//  Celetur
//
//  Created by Feldmaus on 15.11.17.
//  Copyright © 2017 ischlecken. All rights reserved.
//

import UIKit


class GradientView : UIView
{
  var dimmedColors           : [Any]!
  var normalColors           : [Any]!
  let dimGradientAnimation   = CABasicAnimation(keyPath: "colors")
  let resetGradientAnimation = CABasicAnimation(keyPath: "colors")
  var runningAnimation       : String?
  
  override init(frame: CGRect)
  { super.init(frame: frame)
    
    self.commonInit()
  }
  
  required init?(coder aDecoder: NSCoder)
  { super.init(coder: aDecoder)
    
    self.commonInit()
  }
  
  override class var layerClass : AnyClass
  { return CAGradientLayer.self }
  
  var gradientLayer : CAGradientLayer
  { return self.layer as! CAGradientLayer }
  
  func commonInit() {
    celeturLogger.debug("commonInit()")
    
    self.gradientLayer.startPoint = CGPoint(x: 0.5,y: 0.0)
    self.gradientLayer.endPoint   = CGPoint(x: 0.5,y: 1.0)
    self.gradientLayer.type       = kCAGradientLayerAxial
    self.gradientLayer.colors     = [UIColor.red.cgColor,
                                     UIColor.purple.cgColor]
    
    self.dimmedColors = [UIColor.gray.cgColor,UIColor.white.cgColor]
    self.normalColors = self.gradientLayer.colors
    
    self.dimGradientAnimation.duration    = 20
    self.dimGradientAnimation.fromValue   = self.normalColors
    self.dimGradientAnimation.toValue     = self.dimmedColors
    
    self.resetGradientAnimation.duration  = 8
    self.resetGradientAnimation.fromValue = self.dimmedColors
    self.resetGradientAnimation.toValue   = self.normalColors
  }
  
  func dimGradient () {
    self.runningAnimation = "dimGradient"
    self.gradientLayer.removeAllAnimations()
    self.gradientLayer.add(self.dimGradientAnimation, forKey: runningAnimation)
    self.gradientLayer.colors = self.dimmedColors
  }
  
  func resetGradient() {
    self.runningAnimation = "resetGradient"
    self.gradientLayer.removeAllAnimations()
    self.gradientLayer.add(self.resetGradientAnimation, forKey: runningAnimation)
    self.gradientLayer.colors = self.normalColors
  }
  
}

