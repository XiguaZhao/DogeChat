//
//  Encrypt.swift
//  DogeChat
//
//  Created by 赵锡光 on 2020/5/31.
//  Copyright © 2020 Luke Parham. All rights reserved.
//

import Foundation
import SwiftyRSA
import Security

class EncryptMessage {
    
    var key = ""
    var publicKey: SecKey?
    var privateKey: SecKey?
    var myPublicKey = ""
    
    func isGenerateKeyPairSuccess() -> Bool {
        let paras = [kSecAttrKeyType: kSecAttrKeyTypeRSA, kSecAttrKeySizeInBits: 1024] as CFDictionary
        let result = SecKeyGeneratePair(paras, &publicKey, &privateKey)
        return result == errSecSuccess
    }
    
    func getPublicKey() -> String {
        if !myPublicKey.isEmpty {
            return myPublicKey
        }
        if isGenerateKeyPairSuccess() {
            guard let _publicKey = publicKey, let publicKey = try? PublicKey(reference: _publicKey) else { return "" }
            let data = CryptoExportImportManager().exportRSAPublicKeyToDER(try! publicKey.data(), keyType: kSecAttrKeyTypeRSA as String, keySize: 1024)
            myPublicKey = data.base64EncodedString()
            return myPublicKey
        }
        return ""
    }
    
    func getPrivateKey() -> String {
        guard let _privateKey = privateKey, let privateKey = try? PrivateKey(reference: _privateKey) else { return "" }
        return (try? privateKey.base64String()) ?? "privateKey fail"
    }
    
    
    func encryptMessage(_ content: String) -> String {
        guard let publicKey = try? PublicKey(base64Encoded: key ) else { return "" }
        let clearMessage = try? ClearMessage(string: content, using: .utf8)
        let encrypted = try? clearMessage?.encrypted(with: publicKey, padding: .PKCS1)
        return encrypted?.base64String ?? ""
    }
    
    func decryptMessage(_ content: String) -> String {
        guard let _privateKey = privateKey, let privateKey = try? PrivateKey(reference: _privateKey) else {
            debug(tag: 1)
            return "" }
        let encryptedMessage = try? EncryptedMessage(base64Encoded: content)
        let clear = try? encryptedMessage?.decrypted(with: privateKey, padding: .PKCS1)
        let utf8String = try? clear?.string(encoding: .utf8)
        let result = (utf8String?.removingPercentEncoding) ?? ""
        if result == "" {
            debug(tag: 2)
        }
        return result
    }
    
    func debug(tag: Int) {
        switch tag {
        case 1:
            (UIApplication.shared.delegate as! AppDelegate).navigationController.topViewController?.navigationItem.title = "获取不到privateKey"
        case 2:
            (UIApplication.shared.delegate as! AppDelegate).navigationController.topViewController?.navigationItem.title = "解码失败"
        default:
            break
        }
    }
    
}

