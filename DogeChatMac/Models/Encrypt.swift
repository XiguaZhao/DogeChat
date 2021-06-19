//
//  Encrypt.swift
//  DogeChatMac
//
//  Created by 赵锡光 on 2021/6/14.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import Security
import RSAEncodingKey
import DogeChatUniversal

class Encrypt: RSAEncryptProtocol {
    
    
    public var publicKey: SecKey?
    public var privateKey: SecKey?
    public var myPublicKey = ""
    public var serverPublicKey: SecKey?
    
    var key: String = ""
    
    public func isGenerateKeyPairSuccess() -> Bool {
        let paras = [kSecAttrKeyType: kSecAttrKeyTypeRSA, kSecAttrKeySizeInBits: 1024] as CFDictionary
        let result = SecKeyGeneratePair(paras, &publicKey, &privateKey)
        return result == errSecSuccess
    }
    
    func getPublicKey() -> String {
        if !myPublicKey.isEmpty {
            return myPublicKey
        }
        guard isGenerateKeyPairSuccess() else { return "" }
        var error:Unmanaged<CFError>?
        if let cfdata = SecKeyCopyExternalRepresentation(publicKey!, &error) {
            let data:Data = cfdata as Data
            let paddingData = CryptoExportImportManager().exportRSAPublicKeyToDER(data, keyType: kSecAttrKeyTypeRSA as String, keySize: 1024)
            let b64Key = paddingData.base64EncodedString()
            myPublicKey = b64Key
            return b64Key
        }
        return ""
    }
    
    func encryptMessage(_ content: String) -> String {
        if serverPublicKey == nil {
            let pubKey = "-----BEGIN PUBLIC KEY-----\(key)-----END PUBLIC KEY-----"
            let pubKeyData = pubKey.data(using: .ascii)
            var error: Unmanaged<CFError>?
            serverPublicKey = SecKeyCreateFromData(NSDictionary(), pubKeyData! as CFData, &error)
        }
        if let secKey = serverPublicKey, let messageData = content.data(using: .utf8) {
            if let encryptedData = SecKeyCreateEncryptedData(secKey, .rsaEncryptionPKCS1, messageData as CFData, nil) {
                return String(data: encryptedData as Data, encoding: .utf8) ?? ""
            }
        }
        return ""
    }
    
    func decryptMessage(_ content: String) -> String {
        if let secKey = privateKey, let messageData = Data(base64Encoded: content) {
            var error: Unmanaged<CFError>?
            if let decryptedData = SecKeyCreateDecryptedData(secKey, .rsaEncryptionPKCS1, messageData as CFData, &error) {
                let decrypted = String(data: decryptedData as Data, encoding: .utf8) ?? ""
                return decrypted.removingPercentEncoding ?? ""
            } else {
                print(error)
            }
        }
        return ""
    }
}
