//
//  Created by Feldmaus on 31.10.17.
//  Copyright © 2017-2018 prisnoc. All rights reserved.
//

//
// MARK:- Json Serializer
//

fileprivate let jsonDateFormatter = ISO8601DateFormatter()

public protocol JSONSerializable {
  func toJSOnSerializableObject() -> Any
  
  init?(json:[String:Any])
}

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
  
  public class func payloadMetainfo(jsonData:Data) -> PayloadMetainfo? {
    var result : PayloadMetainfo?
    
    do {
      if let parsedJSON = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String:Any] {
        
        //celeturKitLogger.debug("parsedJSON:\(parsedJSON)")
        
        result = PayloadMetainfo(json:parsedJSON)
      }
    } catch {
      celeturKitLogger.error("Error while deserializing json to payloadmetainfo",error:error)
    }
    
    return result
  }
  
  public class func payloadMetainfo(jsonUrl:URL) -> PayloadMetainfo? {
    var result : PayloadMetainfo?
    
    do {
      let data = try Data(contentsOf: jsonUrl)
      
      result = PayloadSerializer.payloadMetainfo(jsonData:data)
    } catch {
      celeturKitLogger.error("Error while reading json data",error:error)
    }
    
    return result
  }
}


//
// MARK:- Payload Elements
//

public struct PayloadItem : JSONSerializable {
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
  
  public var name        : String
  public var value       : ValueType
  
  public init(name:String, value:ValueType) {
    self.name = name
    self.value = value
  }
  
  public init?(json: [String : Any]) {
    guard let name = json["name"] as? String,
      json["value"] != nil
      else {
        return nil
    }
    
    self.name = name
    
    let value = json["value"]
    if let v = ValueType.toValueType(any: value as Any) {
      self.value = v
    } else {
      return nil
    }
  }
  
  
  public func toJSOnSerializableObject() -> Any {
    var result = Dictionary<String, Any>()
    
    result["name"] = self.name
    result["value"] = self.value.toAny()
    
    return result
  }
}


public func ==(lhs: PayloadItem.ValueType, rhs: PayloadItem.ValueType)->Bool {
  return lhs.isEqual(st: rhs)
}

public struct PayloadSection : JSONSerializable {
  
  public var name : String
  public var items: [PayloadItem]
  
  public init?(json: [String : Any]) {
    guard let name = json["name"] as? String, let items = json["items"] as? [Any] else { return nil }
    
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
}

public struct PayloadSections : JSONSerializable {
  
  public var created : Date
  public var sections: [PayloadSection]
  
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
  
  
}

public struct Payload : JSONSerializable {
  
  public var metainfo : String
  
  //
  // fuer die Historisierung der Aenderungen gibt es hier eine Liste von Sections mit Zeitstempel
  //
  public var list     : [PayloadSections]
  
  public func toJSOnSerializableObject() -> Any {
    var result = Dictionary<String, Any>()
    
    result["metainfo"] = self.metainfo
    
    var list = Array<Any>()
    for li in self.list {
      list.append(li.toJSOnSerializableObject())
    }
    result["list"] = list
    
    return result
  }
  
  public init?(json: [String : Any]) {
    guard let metainfo = json["metainfo"] as? String, let list = json["list"] as? [Any] else { return nil }
    
    self.metainfo = metainfo
    
    self.list = [PayloadSections]()
    for case let li as [String:Any] in list {
      if let l = PayloadSections(json:li) {
        self.list.append(l)
      }
    }
  }
  
  public init(metainfo:String, list: [PayloadSections]) {
    self.metainfo = metainfo
    self.list = list
  }
  
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
  
  public mutating func removeItemFromActualSection(forPath indexPath: IndexPath) -> PayloadItem {
    return self.list[0].sections[indexPath.section].items.remove(at: indexPath.row)
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



//
// MARK: - Meta Info
//

public struct PayloadMetainfo : JSONSerializable {
  
  public var name       : String
  public var iconname   : String
  public var description: String?
  public var sections   : [PayloadMetainfoSection]
  
  public func toJSOnSerializableObject() -> Any {
    var result = Dictionary<String, Any>()
    
    result["name"] = self.name
    result["iconname"] = self.iconname
    
    if let d = self.description {
      result["description"] = d
    }
    
    var list = Array<Any>()
    for li in self.sections {
      list.append(li.toJSOnSerializableObject())
    }
    result["sections"] = list
    
    return result
  }
  
  public init?(json: [String : Any]) {
    guard let name = json["name"] as? String,let iconname = json["iconname"] as? String, let list = json["sections"] as? [Any] else { return nil }
    
    self.name = name
    self.iconname = iconname
    self.description = json["description"] as? String
    
    self.sections = [PayloadMetainfoSection]()
    
    for case let li as [String:Any] in list {
      if let l = PayloadMetainfoSection(json:li) {
        self.sections.append(l)
      }
    }
  }
  
  public init(name:String, iconname:String, description: String?, sections: [PayloadMetainfoSection]) {
    self.name = name
    self.iconname = iconname
    self.description = description
    self.sections = sections
  }
  
  public func toModel() -> Payload {
    var payloadSections : [PayloadSection] = []
    
    for s in self.sections {
      var psitems : [PayloadItem] = []
      
      for i in s.items {
        psitems.append(PayloadItem(name: i.name, value: .s("")))
      }
      
      payloadSections.append(PayloadSection(name: s.name, items: psitems))
    }
    
    return Payload(metainfo: self.name, list: [PayloadSections(sections: payloadSections)])
  }
  
  public func toTresorDocumentMetaInfo() -> TresorDocumentMetaInfo {
    var result : TresorDocumentMetaInfo = [:]
    
    result[TresorDocumentMetaInfoKey.title.rawValue] = self.name
    result[TresorDocumentMetaInfoKey.iconname.rawValue] = self.iconname
    
    if let d = self.description {
      result[TresorDocumentMetaInfoKey.description.rawValue] = d
    }
    
    return result
  }
}

public struct PayloadMetainfoSection : JSONSerializable {
  public var name : String
  public var items: [PayloadMetainfoItem]
  
  public init?(json: [String : Any]) {
    guard let name = json["name"] as? String,
      let items = json["items"] as? [Any]
      else {
        return nil
    }
    
    self.name = name
    
    self.items = [PayloadMetainfoItem]()
    for case let i as [String:Any] in items {
      if let p = PayloadMetainfoItem(json:i) {
        self.items.append(p)
      }
    }
  }
  
  public init(name: String, items: [PayloadMetainfoItem]) {
    self.name = name
    self.items = items
  }
  
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
}

public struct PayloadMetainfoItem : JSONSerializable {
  public enum AttributeName {
    case minlength
    case maxlength
    case revealable
  }
  
  public var name        : String
  public var placeholder : String?
  public var attributes  : [AttributeName:PayloadItem.ValueType]
  
  
  public init(name:String, placeholder:String?, attributes:[AttributeName:PayloadItem.ValueType]) {
    self.name = name
    self.placeholder = placeholder
    self.attributes = attributes
  }
  
  public init?(json: [String : Any]) {
    guard let name = json["name"] as? String else { return nil }
    
    self.name = name
    self.placeholder = json["placeholder"] as? String
    
    self.attributes = [AttributeName:PayloadItem.ValueType]()
    if let attributes = json["attributes"] as? [String:Any] {
      for (an,av) in attributes {
        switch an {
        case "minlength":
          self.attributes[.minlength] = PayloadItem.ValueType.toValueType(any: av)
        case "maxlength":
          self.attributes[.maxlength] = PayloadItem.ValueType.toValueType(any: av)
        case "revealable":
          self.attributes[.revealable] = PayloadItem.ValueType.toValueType(any: av)
        default:
          break
        }
      }
    }
  }
  
  
  public func toJSOnSerializableObject() -> Any {
    var result = Dictionary<String, Any>()
    
    result["name"] = self.name
    
    if let p = self.placeholder {
      result["placeholder"] = p
    }
    
    var attributes = Dictionary<String,Any>()
    for (an,av) in self.attributes {
      switch an {
      case .minlength:
        attributes["minlength"] = av.toAny()
      case .maxlength:
        attributes["maxlength"] = av.toAny()
      case .revealable:
        attributes["revealable"] = av.toAny()
      }
    }
    
    if attributes.count>0 {
      result["attributes"] = attributes
    }
    
    return result
  }
  
  public func isRevealable() -> Bool {
    guard let a = self.attributes[.revealable] else { return false }
    
    return a == .i(1)
  }
}
