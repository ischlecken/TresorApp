//
//  Created by Feldmaus on 15.11.17.
//  Copyright © 2017-2018 ischlecken. All rights reserved.
//

import UIKit
import SVGKit

class GradientView : UIView
{
  var dimmedColors           : [Any]!
  var normalColors           : [Any]!
  let dimGradientAnimation   = CABasicAnimation(keyPath: "colors")
  let resetGradientAnimation = CABasicAnimation(keyPath: "colors")
  
  let dimShapeAnimation   = CABasicAnimation(keyPath: "fillColor")
  let resetShapeAnimation = CABasicAnimation(keyPath: "fillColor")

  let setStrokeShapeAnimation   = CABasicAnimation(keyPath: "strokeEnd")
  let resetStrokeShapeAnimation = CABasicAnimation(keyPath: "strokeEnd")

  
  var runningAnimation       : String?
  
  var shieldPath: UIBezierPath?
  
  var shapeLayer : CAShapeLayer?
  
  override init(frame: CGRect)
  { super.init(frame: frame)
    
    self.commonInit()
  }
  
  override var frame: CGRect {
    didSet {
      celeturLogger.debug("GradientView.frame didSet:\(self.frame)")
      
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
    
    self.gradientLayer.colors     = [UIColor.celeturPrimary.cgColor, UIColor.celeturPrimary1.cgColor]
    
    self.dimmedColors = [UIColor.celeturGradient0.cgColor, UIColor.celeturGradient1.cgColor]
    self.normalColors = self.gradientLayer.colors
    
    self.dimGradientAnimation.duration    = 4
    self.dimGradientAnimation.fromValue   = self.normalColors
    self.dimGradientAnimation.toValue     = self.dimmedColors
    self.dimGradientAnimation.delegate    = self
    
    self.resetGradientAnimation.duration  = 2
    self.resetGradientAnimation.fromValue = self.dimmedColors
    self.resetGradientAnimation.toValue   = self.normalColors
    self.resetGradientAnimation.delegate  = self
    
    self.dimShapeAnimation.duration    = 4
    self.dimShapeAnimation.fromValue   = UIColor.celeturSecondary.cgColor
    self.dimShapeAnimation.toValue     = UIColor.celeturPrimary.cgColor
    
    self.resetShapeAnimation.duration  = 2
    self.resetShapeAnimation.fromValue = UIColor.celeturPrimary.cgColor
    self.resetShapeAnimation.toValue   = UIColor.celeturSecondary.cgColor
    
    self.setStrokeShapeAnimation.duration    = 4
    self.setStrokeShapeAnimation.fromValue   = 0.0
    self.setStrokeShapeAnimation.toValue     = 1.0
    
    self.resetStrokeShapeAnimation.duration  = 2
    self.resetStrokeShapeAnimation.fromValue = 1.0
    self.resetStrokeShapeAnimation.toValue   = 0.0
    
    let shapeLayer = CAShapeLayer()
    shapeLayer.fillColor        = UIColor.celeturSecondary.cgColor
    shapeLayer.strokeColor      = UIColor.celeturPrimary.cgColor
    shapeLayer.strokeStart      = 0.0
    shapeLayer.strokeEnd        = 0.0
    shapeLayer.lineCap          = kCALineCapRound
    shapeLayer.lineWidth        = CGFloat(40.0)
    shapeLayer.frame            = self.frame
    shapeLayer.path             = self.updatePath(rect: shapeLayer.frame)
    
    self.shapeLayer = shapeLayer
    self.layer.addSublayer(shapeLayer)
  }
  
  func dimGradient () {
    self.runningAnimation = "dimGradient"
    
    self.gradientLayer.removeAllAnimations()
    self.gradientLayer.add(self.dimGradientAnimation, forKey: self.runningAnimation)
    self.gradientLayer.colors = self.dimmedColors
    
    self.shapeLayer?.removeAllAnimations()
    self.shapeLayer?.add(self.dimShapeAnimation, forKey: self.runningAnimation)
    self.shapeLayer?.add(self.resetStrokeShapeAnimation, forKey: self.runningAnimation)
    self.shapeLayer?.fillColor = UIColor.celeturPrimary.cgColor
    self.shapeLayer?.strokeEnd = 0.0
  }
  
  func resetGradient() {
    self.runningAnimation = "resetGradient"
    self.gradientLayer.removeAllAnimations()
    self.gradientLayer.add(self.resetGradientAnimation, forKey: self.runningAnimation)
    self.gradientLayer.colors = self.normalColors
    
    self.shapeLayer?.removeAllAnimations()
    self.shapeLayer?.add(self.resetShapeAnimation, forKey: self.runningAnimation)
    self.shapeLayer?.add(self.setStrokeShapeAnimation, forKey: self.runningAnimation)
    self.shapeLayer?.fillColor = UIColor.celeturSecondary.cgColor
    self.shapeLayer?.strokeEnd = 1.0
  }
  
  
  func updateArcPath(rect:CGRect) -> CGPath {
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
    
    path.addArc(center: CGPoint(x: circleX, y: circleY), radius: CGFloat(circleRadius-30.0),
                startAngle: CGFloat(stopAngle-Double.pi*0.5), endAngle: CGFloat(startAngle-Double.pi*0.5),
                clockwise: true)
    
    return path
  }
  
  func updatePath(rect:CGRect) -> CGPath {
    let pathBoundingBox = self.getShieldPath().boundingBox
    //celeturLogger.debug("shieldPathBoundingBox:\(String(describing: pathBoundingBox))")
    
    let xOffset = rect.size.width * 0.5 - (pathBoundingBox.origin.x + pathBoundingBox.size.width * 0.5)
    let yOffset = rect.size.height * 0.5 - (pathBoundingBox.origin.y + pathBoundingBox.size.height * 0.5)
    //celeturLogger.debug("translate(\(xOffset),\(yOffset))")
    
    var translation = CGAffineTransform(translationX: xOffset, y: yOffset)
    return self.getShieldPath().copy(using: &translation)!
  }
  
  func createContraints(parentView:UIView) {
    self.translatesAutoresizingMaskIntoConstraints = false
    
    let left = NSLayoutConstraint(item: self, attribute: .left, relatedBy: .equal, toItem: parentView, attribute: .left, multiplier: 1.0, constant: 0.0)
    let top = NSLayoutConstraint(item: self, attribute: .top, relatedBy: .equal, toItem: parentView, attribute: .top, multiplier: 1.0, constant: 0.0)
    let width = NSLayoutConstraint(item: self, attribute: .width, relatedBy: .equal, toItem: parentView, attribute: .width, multiplier: 1.0, constant: 0.0)
    let height = NSLayoutConstraint(item: self, attribute: .height, relatedBy: .equal, toItem: parentView, attribute: .height, multiplier: 1.0, constant: 0.0)
    
    parentView.addConstraints([left,top,width,height])
    
  }
  
  
  func getShieldPath() -> CGPath {
    if self.shieldPath == nil {
      let shieldPath = UIBezierPath(pathString:"M256,102.433c46.974,34.162,100.779,47.517,143.455,52.245C388.319,257.588,332.197,353.065,256,412.763c-76.084-59.608-132.305-155.036-143.455-258.085C155.221,149.95,209.026,136.594,256,102.433 M256,50c-51.418,51.417-125.167,67-185.5,67c0,147.334,83.666,278,185.5,345c101.834-67,185.5-197.666,185.5-345C381.167,117,307.417,101.417,256,50z M365.302,179.834c-34.612-6.643-73.071-18.999-109.302-41.314c-36.23,22.315-74.689,34.671-109.302,41.314C161.676,255.86,202.592,324.588,256,373.434C309.412,324.585,350.324,255.856,365.302,179.834z")
      
      //celeturLogger.debug("shieldPath.0:\(String(describing: shieldPath))")
      
      shieldPath.apply(CGAffineTransform(scaleX: 0.8, y: 0.8))
      let shieldBB = shieldPath.cgPath.boundingBox
      shieldPath.apply(CGAffineTransform(translationX: -shieldBB.origin.x, y: -shieldBB.origin.y))
      self.shieldPath = shieldPath
      
      //celeturLogger.debug("shieldPath.1:\(String(describing: shieldPath))")
    }
    
    return self.shieldPath!.cgPath
  }
}

extension GradientView: CAAnimationDelegate {
  func animationDidStart(_ anim: CAAnimation) {
    celeturLogger.debug("animation did start")
  }
  
  func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
    celeturLogger.debug("animation did finish")
    self.runningAnimation = nil
  }
}
