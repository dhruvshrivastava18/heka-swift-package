//
//  KeychainHelper.swift
//
//
//  Created by Gaurav Tiwari on 16/02/23.
//

import Security
import UIKit

final class HekaKeychainHelper {

  private var keychainFirstUploadKey: String {
    if let bundleIdentifier = Bundle.main.bundleIdentifier {
      return bundleIdentifier + ".firstUploadSuccessfull"
    } else {
      return "firstUploadSuccessfull"
    }
  }

  func markFirstUpload() {
    _ = save(key: keychainFirstUploadKey, data: Data(from: Date().timeIntervalSince1970))
  }

  var lastSyncDate: Date? {
    guard let keychainData = load(key: keychainFirstUploadKey) else {
      return nil
    }
    let timeInterval = keychainData.to(type: TimeInterval.self)
    return Date(timeIntervalSince1970: timeInterval)
  }

  private func save(key: String, data: Data) -> OSStatus {
    let query =
      [
        kSecClass as String: kSecClassGenericPassword as String,
        kSecAttrAccount as String: key,
        kSecValueData as String: data,
      ] as [String: Any]

    SecItemDelete(query as CFDictionary)

    return SecItemAdd(query as CFDictionary, nil)
  }

  private func load(key: String) -> Data? {
    let query =
      [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: key,
        kSecReturnData as String: kCFBooleanTrue!,
        kSecMatchLimit as String: kSecMatchLimitOne,
      ] as [String: Any]

    var dataTypeRef: AnyObject? = nil

    let status: OSStatus = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

    if status == noErr {
      return dataTypeRef as! Data?
    } else {
      return nil
    }
  }
}

extension Data {
  init<T>(from value: T) {
    let pointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
    pointer.initialize(to: value)
    defer {
      pointer.deinitialize(count: 1)
      pointer.deallocate()
    }

    let bufferPointer = UnsafeBufferPointer(start: pointer, count: 1)
    self.init(buffer: bufferPointer)
  }

  func to<T>(type: T.Type) -> T {
    return self.withUnsafeBytes { $0.load(as: T.self) }
  }
}
