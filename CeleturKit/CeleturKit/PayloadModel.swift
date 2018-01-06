//
//  PayloadSerializer.swift
//  CeleturKit
//
//  Created by Feldmaus on 31.10.17.
//  Copyright © 2017 prisnoc. All rights reserved.
//

fileprivate let jsonDateFormatter = ISO8601DateFormatter()

public class PayloadSerializer {

  public class func jsonData(model:JSONSerializable) -> Data? {
    var result : Data?
    do {
      result = try JSONSerialization.data(withJSONObject: model.toJSOnSerializableObject(), options: [])
    } catch {
      celeturKitLogger.error("Error while serializing to json", error: error)
    }
    
    return result
  }
  
  public class func payloadItem(jsonData:Data) -> PayloadItem? {
    var result : PayloadItem?
    
    do {
      if let parsedJSON = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String:Any] {
        
        //celeturKitLogger.debug("parsedJSON:\(parsedJSON)")

        result = PayloadItem(json:parsedJSON)
      }
    } catch {
      celeturKitLogger.error("Error while deserializing json to payloaditem",error:error)
    }
    
    return result
  }
  
  public class func payloadSection(jsonData:Data) -> PayloadSection? {
    var result : PayloadSection?
    
    do {
      if let parsedJSON = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String:Any] {
        
        //celeturKitLogger.debug("parsedJSON:\(parsedJSON)")
        
        result = PayloadSection(json:parsedJSON)
      }
    } catch {
      celeturKitLogger.error("Error while deserializing json to payloadsection",error:error)
    }
    
    return result
  }
  
  public class func tpayloadSection(jsonData:Data) -> PayloadSections? {
    var result : PayloadSections?
    
    do {
      if let parsedJSON = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String:Any] {
        
        //celeturKitLogger.debug("parsedJSON:\(parsedJSON)")
        
        result = PayloadSections(json:parsedJSON)
      }
    } catch {
      celeturKitLogger.error("Error while deserializing json to payloadsections",error:error)
    }
    
    return result
  }
  
  public class func payload(jsonData:Data) -> Payload? {
    var result : Payload?
    
    do {
      if let parsedJSON = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String:Any] {
        
        //celeturKitLogger.debug("parsedJSON:\(parsedJSON)")
        
        result = Payload(json:parsedJSON)
      }
    } catch {
      celeturKitLogger.error("Error while deserializing json to payload",error:error)
    }
    
    return result
  }
  
  public class func payload(jsonUrl:URL) -> Payload? {
    var result : Payload?
    
    do {
      let data = try Data(contentsOf: jsonUrl)
      
      result = PayloadSerializer.payload(jsonData:data)
    } catch {
      celeturKitLogger.error("Error while reading json data",error:error)
    }
    
    return result
  }
}

public protocol JSONSerializable {
  func toJSOnSerializableObject() -> Any
  
  init?(json:[String:Any])
}

public struct PayloadItem : JSONSerializable {
  
  public init(name:String, value:ValueType, attributes:[AttributeName:ValueType]) {
    self.name = name
    self.value = value
    self.attributes = attributes
  }
  
  public init?(json: [String : Any]) {
    guard let name = json["name"] as? String,
      json["value"] != nil
      else {
        return nil
    }
    
    let value = json["value"]
    
    self.name = name
    if let v = ValueType.toValueType(any: value as Any) {
      self.value = v
    } else {
      return nil
    }
    
    self.attributes = [AttributeName:ValueType]()
    
    if let attributes = json["attributes"] as? [String:Any] {
      for (an,av) in attributes {
        switch an {
        case "minlength":
          self.attributes[.minlength] = ValueType.toValueType(any: av)
        case "maxlength":
          self.attributes[.maxlength] = ValueType.toValueType(any: av)
        case "revealable":
          self.attributes[.revealable] = ValueType.toValueType(any: av)
        case "revealed":
          self.attributes[.revealed] = ValueType.toValueType(any: av)
        default:
          break
        }
      }
    }
  }
  
  
  public func toJSOnSerializableObject() -> Any {
    var result = Dictionary<String, Any>()
    
    result["name"] = self.name
    result["value"] = self.value.toAny()
    
    var attributes = Dictionary<String,Any>()
    for (an,av) in self.attributes {
      switch an {
      case .minlength:
        attributes["minlength"] = av.toAny()
      case .maxlength:
        attributes["maxlength"] = av.toAny()
      case .revealable:
        attributes["revealable"] = av.toAny()
      case .revealed:
        attributes["revealed"] = av.toAny()
      }
    }
    
    if attributes.count>0 {
      result["attributes"] = attributes
    }
    
    return result
  }
  
  public enum ValueType {
    case s(String)
    case i(Int)
    case f(Float)
    case d(Date)
    
    func toAny() -> Any {
      switch self {
      case .s(let v):
        return v
      case .i(let v):
        return v
      case .f(let v):
        return v
      case .d(let v):
        return v
      }
    }
    
    public func toString() -> String {
      switch self {
      case .s(let v):
        return v
      case .i(let v):
        return String(v)
      case .f(let v):
        return String(v)
      case .d(let v):
        return jsonDateFormatter.string(from: v)
      }
    }
    
    func isEqual(st: ValueType)->Bool {
      switch self {
      case .s(let v1):
        if case .s(let v2) = st, v1 == v2 { return true }
      
      case .i(let i1):
        if case .i(let i2) = st, i1 == i2 { return true }
      
      case .f(let v1):
        if case .f(let v2) = st, v1 == v2 { return true }
        
      case .d(let v1):
        if case .d(let v2) = st, v1 == v2 { return true }
        
      }
      
      return false
    }
    
    static func toValueType(any:Any) -> ValueType? {
      switch any {
      case let v as String:
        return .s(v)
      case let v as Int:
        return .i(v)
      case let v as Float:
        return .f(v)
      case let v as Date:
        return .d(v)
      default:
        return nil
      }
    }
  }
  
  public enum AttributeName {
    case minlength
    case maxlength
    case revealable
    case revealed
  }
  
  public var name      : String
  public var value     : ValueType
  public var attributes: [AttributeName:ValueType]
  
  public func isRevealable() -> Bool {
    guard let a = self.attributes[.revealable] else { return false }
    
    return a == .i(1)
  }
  
  public func isRevealed() -> Bool {
    guard let a = self.attributes[.revealed] else { return false }
    
    return a == .i(1)
  }
  
  public mutating func reveal() {
    self.attributes[.revealed] = .i(1)
  }
  
  public mutating func unreveal() {
    self.attributes[.revealed] = .i(0)
  }
}

public struct PayloadSection : JSONSerializable {
  
  public func toJSOnSerializableObject() -> Any {
    var result = Dictionary<String, Any>()
    
    result["name"] = self.name
    
    var items = Array<Any>()
    for it in self.items {
      items.append(it.toJSOnSerializableObject())
    }
    result["items"] = items
    
    return result
  }
  
  public init?(json: [String : Any]) {
    guard let name = json["name"] as? String,
      let items = json["items"] as? [Any]
      else {
        return nil
    }
    
    self.name = name
    
    self.items = [PayloadItem]()
    for case let i as [String:Any] in items {
      if let p = PayloadItem(json:i) {
        self.items.append(p)
      }
    }
  }
  
  public init(name: String, items: [PayloadItem]) {
    self.name = name
    self.items = items
  }
  
  public var name : String
  public var items: [PayloadItem]
}

public struct PayloadSections : JSONSerializable {
  
  public func toJSOnSerializableObject() -> Any {
    var result = Dictionary<String, Any>()
    
    result["created"] = jsonDateFormatter.string(from: self.created)
    
    var sections = Array<Any>()
    for se in self.sections {
      sections.append(se.toJSOnSerializableObject())
    }
    result["sections"] = sections
    
    return result
  }
  
  public init?(json: [String : Any]) {
    guard let created = json["created"] as? String,
      let sections = json["sections"] as? [Any]
      else {
        return nil
    }
    
    self.created = jsonDateFormatter.date(from: created)!
    self.sections = [PayloadSection]()
    
    for case let se as [String:Any] in sections {
      if let s = PayloadSection(json:se) {
        self.sections.append(s)
      }
    }
  }
  
  public init(sections: [PayloadSection]) {
    self.created = Date()
    self.sections = sections
  }
  
  public var created : Date
  public var sections: [PayloadSection]
}

public struct Payload : JSONSerializable {
  public func toJSOnSerializableObject() -> Any {
    var result = Dictionary<String, Any>()
    
    result["title"] = self.title
    result["iconname"] = self.iconname
    if let d = self.description {
      result["description"] = d
    }
    
    var list = Array<Any>()
    for li in self.list {
      list.append(li.toJSOnSerializableObject())
    }
    result["list"] = list
    
    return result
  }
  
  public init?(json: [String : Any]) {
    guard let title = json["title"] as? String,
      let iconname = json["iconname"] as? String,
      let list = json["list"] as? [Any]
      else {
        return nil
    }
    
    self.title = title
    self.iconname = iconname
    self.description = json["description"] as? String
    
    self.list = [PayloadSections]()
    
    for case let li as [String:Any] in list {
      if let l = PayloadSections(json:li) {
        self.list.append(l)
      }
    }
  }
  
  public init(title:String, iconname:String, description: String?, list: [PayloadSections]) {
    self.title = title
    self.iconname = iconname
    self.description = description
    self.list = list
  }
  
  public var title      : String
  public var iconname   : String
  public var description: String?
  
  public var list       : [PayloadSections]
  
  public func getActualPayloadSections() -> [PayloadSection] {
    return self.list[0].sections
  }
  
  public func getActualSectionCount() -> Int {
    return self.getActualPayloadSections().count
  }
  
  public func getActualSectionItems(forSection section:Int) -> [PayloadItem] {
    return self.getActualPayloadSections()[section].items
  }
  
  public mutating func appendToActualSection(forSection section:Int, payloadItem: PayloadItem){
    return self.list[0].sections[section].items.append(payloadItem)
  }
  
  public mutating func removeAllItemsFromActualSection(forSection section:Int){
    return self.list[0].sections[section].items.removeAll()
  }
  
  public mutating func setActualItem(forPath indexPath:IndexPath, payloadItem:PayloadItem) {
    return self.list[0].sections[indexPath.section].items[indexPath.row] = payloadItem
  }
  
  public func getActualItem(forPath indexPath:IndexPath) -> PayloadItem {
    return self.getActualPayloadSections()[indexPath.section].items[indexPath.row]
  }
  
  public func getActualRowCount(forSection section:Int) -> Int {
    return self.getActualSectionItems(forSection: section).count
  }
}


public func ==(lhs: PayloadItem.ValueType, rhs: PayloadItem.ValueType)->Bool {
  return lhs.isEqual(st: rhs)
}
