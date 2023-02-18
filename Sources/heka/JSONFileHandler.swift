//
//  JSONFileHandler.swift
//  
//
//  Created by Gaurav Tiwari on 18/02/23.
//

import Foundation

final class JSONFileHandler {
  
  private let fileName = "userData.json"
  private var filePath: URL? {
    guard let documentDirectory = FileManager.default
      .urls(for: .documentDirectory, in: .userDomainMask).first else {
      print("Cannot loacate the document directory")
      return nil
    }
    return documentDirectory.appendingPathComponent(fileName)
  }
  
  func createJSONFile(with samples: [String: Any], and completion: (URL) -> Void) {
    guard let jsonData = try? JSONSerialization.data(withJSONObject: samples, options: .prettyPrinted),
          let jsonString = String(data: jsonData, encoding: .ascii) else {
      print("Cannot convert data to json")
      return
    }
    
    guard let filePath = filePath else {
      print("Cannot loacate the document directory")
      return
    }
    
    do {
      try jsonString.write(to: filePath, atomically: true, encoding: .utf8)
      completion(filePath)
    } catch(let error) {
      print("Cannot write data to file with error: ", error)
    }
  }
}
