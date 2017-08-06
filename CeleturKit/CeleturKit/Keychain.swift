import Foundation


// MARK: - KeychainItemAccessibility

protocol KeychainAttrRepresentable {
  var keychainAttrValue: CFString { get }
}

// MARK: - KeychainItemAccessibility
public enum KeychainItemAccessibility {
  /**
   The data in the keychain item cannot be accessed after a restart until the device has been unlocked once by the user.
   
   After the first unlock, the data remains accessible until the next restart. This is recommended for items that need to be accessed by background applications. Items with this attribute migrate to a new device when using encrypted backups.
   */
  @available(iOS 4, *)
  case afterFirstUnlock
  
  /**
   The data in the keychain item cannot be accessed after a restart until the device has been unlocked once by the user.
   
   After the first unlock, the data remains accessible until the next restart. This is recommended for items that need to be accessed by background applications. Items with this attribute do not migrate to a new device. Thus, after restoring from a backup of a different device, these items will not be present.
   */
  @available(iOS 4, *)
  case afterFirstUnlockThisDeviceOnly
  
  /**
   The data in the keychain item can always be accessed regardless of whether the device is locked.
   
   This is not recommended for application use. Items with this attribute migrate to a new device when using encrypted backups.
   */
  @available(iOS 4, *)
  case always
  
  /**
   The data in the keychain can only be accessed when the device is unlocked. Only available if a passcode is set on the device.
   
   This is recommended for items that only need to be accessible while the application is in the foreground. Items with this attribute never migrate to a new device. After a backup is restored to a new device, these items are missing. No items can be stored in this class on devices without a passcode. Disabling the device passcode causes all items in this class to be deleted.
   */
  @available(iOS 8, *)
  case whenPasscodeSetThisDeviceOnly
  
  /**
   The data in the keychain item can always be accessed regardless of whether the device is locked.
   
   This is not recommended for application use. Items with this attribute do not migrate to a new device. Thus, after restoring from a backup of a different device, these items will not be present.
   */
  @available(iOS 4, *)
  case alwaysThisDeviceOnly
  
  /**
   The data in the keychain item can be accessed only while the device is unlocked by the user.
   
   This is recommended for items that need to be accessible only while the application is in the foreground. Items with this attribute migrate to a new device when using encrypted backups.
   
   This is the default value for keychain items added without explicitly setting an accessibility constant.
   */
  @available(iOS 4, *)
  case whenUnlocked
  
  /**
   The data in the keychain item can be accessed only while the device is unlocked by the user.
   
   This is recommended for items that need to be accessible only while the application is in the foreground. Items with this attribute do not migrate to a new device. Thus, after restoring from a backup of a different device, these items will not be present.
   */
  @available(iOS 4, *)
  case whenUnlockedThisDeviceOnly
  
  static func accessibilityForAttributeValue(_ keychainAttrValue: CFString) -> KeychainItemAccessibility? {
    for (key, value) in keychainItemAccessibilityLookup {
      if value == keychainAttrValue {
        return key
      }
    }
    
    return nil
  }
}



private let keychainItemAccessibilityLookup: [KeychainItemAccessibility:CFString] = {
  var lookup: [KeychainItemAccessibility:CFString] = [
    .afterFirstUnlock: kSecAttrAccessibleAfterFirstUnlock,
    .afterFirstUnlockThisDeviceOnly: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    .always: kSecAttrAccessibleAlways,
    .whenPasscodeSetThisDeviceOnly: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
    .alwaysThisDeviceOnly : kSecAttrAccessibleAlwaysThisDeviceOnly,
    .whenUnlocked: kSecAttrAccessibleWhenUnlocked,
    .whenUnlockedThisDeviceOnly: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
  ]
  
  return lookup
}()


extension KeychainItemAccessibility : KeychainAttrRepresentable {
  internal var keychainAttrValue: CFString {
    return keychainItemAccessibilityLookup[self]!
  }
}

// MARK: - KeychainServiceType

public protocol KeychainServiceType {
  
  func insertItemWithAttributes(_ attributes: [String: Any]) throws
  func removeItemWithAttributes(_ attributes: [String: Any]) throws
  func fetchItemWithAttributes(_ attributes: [String: Any]) throws -> [String: Any]?
}

// MARK: - KeychainItemType

public protocol KeychainItemType {
  
  var accessPolicy: SecAccessControlCreateFlags? {get}
  var accessMode: KeychainItemAccessibility? {get}
  var accessGroup: String? {get}
  var attributes: [String: Any] {get}
  var data: [String: Any] {get set}
  var dataToStore: [String: Any] {get}
}

extension KeychainItemType {
  
  public var accessMode: KeychainItemAccessibility? {
    return .whenUnlockedThisDeviceOnly
  }
  
  public var accessPolicy: SecAccessControlCreateFlags? {
    return .userPresence
  }
  
  public var accessGroup: String? {
    return nil
  }
}

extension KeychainItemType {
  
  private func setInternalAttributes(itemAttributes: inout [String: Any], setAccessControl:Bool ) throws {
    if let group = accessGroup {
      itemAttributes[String(kSecAttrAccessGroup)] = group
    }
    
    itemAttributes.removeValue(forKey: String(kSecAttrAccessible))
    itemAttributes.removeValue(forKey: String(kSecAttrAccessControl))
    
    if setAccessControl {
      if let policy = accessPolicy, let access = accessMode {
        var error: Unmanaged<CFError>?
        
        guard let accessControl = SecAccessControlCreateWithFlags(kCFAllocatorDefault, access.keychainAttrValue, policy, &error)
          else {
            if let e = error?.takeRetainedValue() {
              throw CeleturKitError.keychainError1(keychainError: e)
            } else {
              throw CeleturKitError.keychainError(keychainError: -1)
            }
        }
        
        itemAttributes[String(kSecAttrAccessControl)] = accessControl
        itemAttributes[String(kSecUseOperationPrompt)] = "Ausweispapiere, aber plötzlich..."
      } else if let access = accessMode {
        itemAttributes[String(kSecAttrAccessible)] = access.keychainAttrValue
      }
    }
  }
  
  internal func attributesToSave() throws -> [String: Any] {
    var itemAttributes = attributes
    let archivedData = NSKeyedArchiver.archivedData(withRootObject: dataToStore)
    
    itemAttributes[String(kSecValueData)] = archivedData
    
    try self.setInternalAttributes(itemAttributes: &itemAttributes,setAccessControl: true)
    
    return itemAttributes
  }
  
  internal func dataFromAttributes(_ attributes: [String: Any]) -> [String: Any]? {
    guard let valueData = attributes[String(kSecValueData)] as? Data else { return nil }
    
    return NSKeyedUnarchiver.unarchiveObject(with: valueData) as? [String: Any] ?? nil
  }
  
  internal func attributesForFetch() throws -> [String: Any] {
    var itemAttributes = attributes
    
    itemAttributes[String(kSecReturnData)] = kCFBooleanTrue
    itemAttributes[String(kSecReturnAttributes)] = kCFBooleanTrue
    itemAttributes[String(kSecUseOperationPrompt)] = "Ausweispapiere, aber plötzlich..."
    
    try self.setInternalAttributes(itemAttributes: &itemAttributes,setAccessControl: false)
    
    return itemAttributes
  }
  
  
  internal func attributesForRemove() throws -> [String: Any] {
    var itemAttributes = attributes
    
    try self.setInternalAttributes(itemAttributes: &itemAttributes,setAccessControl: false)
    
    return itemAttributes
  }
}

// MARK: - KeychainGenericPasswordType

public protocol KeychainGenericPasswordType: KeychainItemType {
  
  var serviceName: String {get}
  var accountName: String {get}
}

extension KeychainGenericPasswordType {
  
  public var serviceName: String {
    return "celetur.service"
  }
  
  public var attributes: [String: Any] {
    var attributes = [String: Any]()
    
    attributes[String(kSecClass)] = kSecClassGenericPassword
    attributes[String(kSecAttrAccessible)] = accessMode
    attributes[String(kSecAttrService)] = serviceName
    attributes[String(kSecAttrAccount)] = accountName
    
    return attributes
  }
}

// MARK: - Keychain

public struct Keychain: KeychainServiceType {
  
  public init() {
  }
  
  public func insertItemWithAttributes(_ attributes: [String: Any]) throws {
    var statusCode = SecItemAdd(attributes as CFDictionary, nil)
    
    if statusCode == errSecDuplicateItem {
      SecItemDelete(attributes as CFDictionary)
      
      statusCode = SecItemAdd(attributes as CFDictionary, nil)
    }
    
    if statusCode != errSecSuccess {
      throw CeleturKitError.keychainError(keychainError: statusCode)
    }
  }
  
  public func removeItemWithAttributes(_ attributes: [String: Any]) throws {
    let statusCode = SecItemDelete(attributes as CFDictionary)
    
    if statusCode != errSecSuccess && statusCode != errSecItemNotFound {
      throw CeleturKitError.keychainError(keychainError: statusCode)
    }
  }
  
  public func fetchItemWithAttributes(_ attributes: [String: Any]) throws -> [String: Any]? {
    var result: AnyObject?
    
    let statusCode = SecItemCopyMatching(attributes as CFDictionary, &result)
    if statusCode != errSecSuccess {
      throw CeleturKitError.keychainError(keychainError: statusCode)
    }
    
    if let result = result as? [String: Any] {
      return result
    }
    
    return nil
  }
}

// MARK: - KeychainItemType + Keychain

extension KeychainItemType {
  
  public mutating func saveInKeychain(_ keychain: KeychainServiceType = Keychain()) throws {
    try keychain.insertItemWithAttributes(attributesToSave())
    
    self.data = self.dataToStore
  }
  
  public func removeFromKeychain(_ keychain: KeychainServiceType = Keychain()) throws {
    try keychain.removeItemWithAttributes(attributesForRemove())
  }
  
  public mutating func fetchFromKeychain(completion: @escaping (Self?,Error?) -> Void, _ keychain: KeychainServiceType = Keychain()) {
    var me = self
    
    DispatchQueue.global().async {
      do {
        if let result = try keychain.fetchItemWithAttributes(me.attributesForFetch()),
          let itemData = me.dataFromAttributes(result) {
          me.data = itemData
        }
        
        DispatchQueue.main.async {
          completion(me,nil)
        }
      } catch {
        DispatchQueue.main.async {
          completion(nil,error)
        }
      }
    }
  }
}

