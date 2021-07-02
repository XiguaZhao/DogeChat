//
//  Common.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/25.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import Foundation

var myName: String {
    (UserDefaults.standard.value(forKey: "lastUsername") as? String) ?? ""
}

var myPassWord: String {
    (UserDefaults.standard.value(forKey: "lastPassword") as? String) ?? ""
}

var maxID: Int {
    (UserDefaults.standard.value(forKey: "maxID") as? Int) ?? 0
}

public func fileURLAt(dirName: String, fileName: String) -> URL? {
    let url = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        .appendingPathComponent(dirName)
        .appendingPathComponent(fileName)
    let path = (url.absoluteString as NSString).substring(from: 7)
    if FileManager.default.fileExists(atPath: path) {
        return url
    } else {
        return nil
    }
}

public func saveFileToDisk(dirName: String, fileName: String, data: Data) {
    let folderName = dirName
    let fileManager = FileManager.default
    let documentsFolder = try! fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
    let folderURL = documentsFolder.appendingPathComponent(folderName)
    let folderExists = (try? folderURL.checkResourceIsReachable()) ?? false
    do {
        if !folderExists {
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: false)
        }
        let fileURL = folderURL.appendingPathComponent(fileName)
        try data.write(to: fileURL)
        
    } catch {
        print(error)
    }
}

public func deleteFile(dirName: String, fileName: String) {
    let folderName = dirName
    let fileManager = FileManager.default
    let documentsFolder = try! fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
    let folderURL = documentsFolder.appendingPathComponent(folderName)
    let fileURL = folderURL.appendingPathComponent(fileName)
    try? fileManager.removeItem(at: fileURL)
}
