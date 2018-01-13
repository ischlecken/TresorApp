//
//  Copyright © 2017-2018 prisnoc. All rights reserved.
//

//
// MARK:- Json Serializer
//
import CeleturKit

public class IconCatalogSerializer {
  
  public class func jsonData(model:JSONSerializable) -> Data? {
    var result : Data?
    do {
      result = try JSONSerialization.data(withJSONObject: model.toJSOnSerializableObject(), options: [])
    } catch {
      celeturLogger.error("Error while serializing to json", error: error)
    }
    
    return result
  }
  
  public class func payload(jsonData:Data) -> Payload? {
    var result : Payload?
    
    do {
      if let parsedJSON = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String:Any] {
        
        //celeturKit.debug("parsedJSON:\(parsedJSON)")
        
        result = Payload(json:parsedJSON)
      }
    } catch {
      celeturLogger.error("Error while deserializing json to payload",error:error)
    }
    
    return result
  }
  
  public class func iconCatalog(jsonData:Data) -> IconCatalog? {
    var result : IconCatalog?
    
    do {
      if let parsedJSON = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String:Any] {
        
        //celeturKit.debug("parsedJSON:\(parsedJSON)")
        
        result = IconCatalog(json:parsedJSON)
      }
    } catch {
      celeturLogger.error("Error while deserializing json to payloadmetainfo",error:error)
    }
    
    return result
  }
  
  public class func iconCatalog(jsonUrl:URL) -> IconCatalog? {
    var result : IconCatalog?
    
    do {
      let data = try Data(contentsOf: jsonUrl)
      
      result = IconCatalogSerializer.iconCatalog(jsonData:data)
    } catch {
      celeturLogger.error("Error while reading json data",error:error)
    }
    
    return result
  }
}


//
// MARK:- Payload Elements
//

public struct IconCatalogItem : JSONSerializable {
  public var name        : String
  public var description : String
  
  public init(name:String, description:String) {
    self.name = name
    self.description = description
  }
  
  public init?(json: [String : Any]) {
    guard let name = json["name"] as? String, let description = json["description"]  as? String else { return nil }
    
    self.name = name
    self.description = description
  }
  
  
  public func toJSOnSerializableObject() -> Any {
    var result = Dictionary<String, Any>()
    
    result["name"] = self.name
    result["description"] = self.description
    
    return result
  }
}

public struct IconCatalogSection : JSONSerializable {
  
  public var name : String
  public var icons: [IconCatalogItem]
  
  public init?(json: [String : Any]) {
    guard let name = json["name"] as? String, let items = json["icons"] as? [Any] else { return nil }
    
    self.name = name
    
    self.icons = [IconCatalogItem]()
    for case let i as [String:Any] in items {
      if let p = IconCatalogItem(json:i) {
        self.icons.append(p)
      }
    }
  }
  
  public init(name: String, icons: [IconCatalogItem]) {
    self.name = name
    self.icons = icons
  }
  
  public func toJSOnSerializableObject() -> Any {
    var result = Dictionary<String, Any>()
    
    result["name"] = self.name
    
    var icons = Array<Any>()
    for it in self.icons {
      icons.append(it.toJSOnSerializableObject())
    }
    result["icons"] = icons
    
    return result
  }
}

public struct IconCatalog : JSONSerializable {
  
  public var name     : String
  public var sections : [IconCatalogSection]
  public var sectionNames : [String]
  
  public func toJSOnSerializableObject() -> Any {
    var result = Dictionary<String, Any>()
    
    result["name"] = self.name
    
    var sections = Array<Any>()
    for li in self.sections {
      sections.append(li.toJSOnSerializableObject())
    }
    result["sections"] = sections
    
    return result
  }
  
  public init?(json: [String : Any]) {
    guard let name = json["name"] as? String, let sections = json["sections"] as? [Any] else { return nil }
    
    self.name = name
    
    self.sections = [IconCatalogSection]()
    self.sectionNames = []
    for case let li as [String:Any] in sections {
      if let l = IconCatalogSection(json:li) {
        self.sectionNames.append(l.name)
        self.sections.append(l)
      }
    }
  }
  
  public init(name:String, sections: [IconCatalogSection]) {
    self.name = name
    self.sections = sections
    
    self.sectionNames = []
    
    for s in self.sections {
      self.sectionNames.append(s.name)
    }
  }
}

