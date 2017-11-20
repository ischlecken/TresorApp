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
  
  var shapeLayer : CAShapeLayer?
  
  override init(frame: CGRect)
  { super.init(frame: frame)
    
    self.commonInit()
  }
  
  override var frame: CGRect {
    didSet {
      //celeturLogger.debug("GradientView.frame didSet:\(self.frame)")
      
      let newShapeFrame = CGRect(origin: CGPoint.zero, size: self.frame.size)
      self.shapeLayer?.frame = newShapeFrame
      self.shapeLayer?.path  = self.updatePath(rect: newShapeFrame)
      
      self.setNeedsDisplay()
    }
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
    self.gradientLayer.startPoint = CGPoint(x: 0.5,y: 0.0)
    self.gradientLayer.endPoint   = CGPoint(x: 0.5,y: 1.0)
    self.gradientLayer.type       = kCAGradientLayerAxial
    self.gradientLayer.colors     = [UIColor.celeturBarTintColor.cgColor,
                                     UIColor.celeturTintColor.cgColor]
    
    self.dimmedColors = [UIColor.gray.cgColor,UIColor.white.cgColor]
    self.normalColors = self.gradientLayer.colors
    
    self.dimGradientAnimation.duration    = 20
    self.dimGradientAnimation.fromValue   = self.normalColors
    self.dimGradientAnimation.toValue     = self.dimmedColors
    
    self.resetGradientAnimation.duration  = 8
    self.resetGradientAnimation.fromValue = self.dimmedColors
    self.resetGradientAnimation.toValue   = self.normalColors
    
    let shapeLayer = CAShapeLayer()
    shapeLayer.fillColor        = UIColor.celeturBarTintColor.withAlphaComponent(0.8).cgColor
    shapeLayer.strokeColor      = UIColor.white.cgColor
    shapeLayer.strokeStart      = 0.0
    shapeLayer.strokeEnd        = 0.0
    shapeLayer.lineCap          = kCALineCapRound
    shapeLayer.lineWidth        = CGFloat(2.0)
    shapeLayer.frame            = self.frame
    shapeLayer.path             = self.updatePath(rect: shapeLayer.frame)
    
    self.shapeLayer = shapeLayer
    
    self.layer.addSublayer(shapeLayer)
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
 
  /*
  override func layoutSubviews() {
    celeturLogger.debug("GradientView.layoutSubviews() --begin--")
    
    super.layoutSubviews()
    
    self.shapeLayer?.frame = CGRect(origin: CGPoint.zero, size: self.layer.frame.size)
    self.shapeLayer?.path  = self.updatePath(rect: self.layer.frame)
    self.setNeedsDisplay()
    
    celeturLogger.debug("GradientView.layoutSubviews() ---end--")
  }*/
  
  func updatePath(rect:CGRect) -> CGPath {
    let path         = CGMutablePath()
    let sliceAngle   = 2.0 * Double.pi
    let startAngle   = 0.0
    let stopAngle    = sliceAngle
    let circleX      = rect.size.width*0.5
    let circleY      = rect.size.height*0.5
    let circleRadius = Double.minimum(Double(circleX), Double(circleY)) - 10.0
    
    path.addArc(center: CGPoint(x: circleX, y: circleY), radius: CGFloat(circleRadius),
                startAngle: CGFloat(startAngle-Double.pi*0.5), endAngle: CGFloat(stopAngle-Double.pi*0.5),
                clockwise: false)
    
    return path
  }
  
  func createContraints(parentView:UIView) {
    self.translatesAutoresizingMaskIntoConstraints = false
    
    let left = NSLayoutConstraint(item: self, attribute: .left, relatedBy: .equal, toItem: parentView, attribute: .left, multiplier: 1.0, constant: 0.0)
    let top = NSLayoutConstraint(item: self, attribute: .top, relatedBy: .equal, toItem: parentView, attribute: .top, multiplier: 1.0, constant: 0.0)
    let width = NSLayoutConstraint(item: self, attribute: .width, relatedBy: .equal, toItem: parentView, attribute: .width, multiplier: 1.0, constant: 0.0)
    let height = NSLayoutConstraint(item: self, attribute: .height, relatedBy: .equal, toItem: parentView, attribute: .height, multiplier: 1.0, constant: 0.0)
    
    parentView.addConstraints([left,top,width,height])
    
  }
}

