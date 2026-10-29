//
//  RSA.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/2/8.
//

import Foundation
import Security

private enum RSAEncryptError: Error {
    case invalidPEM
    case keyCreateFailed
    case encryptFailed
}

private func makePublicKey(from pem: String) throws -> SecKey {
    let base64Body = pem
        .replacingOccurrences(of: "-----BEGIN PUBLIC KEY-----", with: "")
        .replacingOccurrences(of: "-----END PUBLIC KEY-----", with: "")
        .components(separatedBy: .whitespacesAndNewlines)
        .filter { !$0.isEmpty }
        .joined()
    guard let keyData = Data(base64Encoded: base64Body) else {
        throw RSAEncryptError.invalidPEM
    }

    let attributes: [String: Any] = [
        kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
        kSecAttrKeyClass as String: kSecAttrKeyClassPublic
    ]
    var error: Unmanaged<CFError>?
    guard let key = SecKeyCreateWithData(keyData as CFData, attributes as CFDictionary, &error) else {
        throw error?.takeRetainedValue() ?? RSAEncryptError.keyCreateFailed
    }
    return key
}

private func rsaPKCS1EncryptToBase64(_ plainText: String, publicKeyPEM: String) throws -> String {
    let key = try makePublicKey(from: publicKeyPEM)
    let data = Data(plainText.utf8)
    guard SecKeyIsAlgorithmSupported(key, .encrypt, .rsaEncryptionPKCS1) else {
        throw RSAEncryptError.encryptFailed
    }
    var error: Unmanaged<CFError>?
    guard let encrypted = SecKeyCreateEncryptedData(
        key,
        .rsaEncryptionPKCS1,
        data as CFData,
        &error
    ) else {
        throw error?.takeRetainedValue() ?? RSAEncryptError.encryptFailed
    }
    return (encrypted as Data).base64EncodedString()
}

func encryptSchoolPassword(password: String) -> String? {
    let publicKeyString = """
    -----BEGIN PUBLIC KEY----- MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAnzp4yI0i0PYBYJ/v/0U9iTve0YrY+kAPaAtVRN0Ueo3M0flwev5B3BHaDd+Nmh+g7X/O4fkSQRWNiAy7PSFYKIzQPHgdqh4dHYeclBPf7bIWQMM0PLY6noETpPqDzczemKsFEjZ8hQy61tXF9E9KfjbNdGCbJshUsXq1c2rZNoFEN4vtV2A/WGXJX3OH7byh6hD0DODMw34ouSnnuk8b5P+Sho+nraZP2K4rJgMkkKmVQGyIfzlJ+ve+HoZXEs3rHxN2tWe1UCDeaa2UbgODqXIwqkRqh0nWz1QiTW7yNuP6hBacGaupOUu0fYutPiiqHqm2AUuI5Qp7XbWyobLIPwIDAQAB 
    -----END PUBLIC KEY-----
    """

    do {
        // 华农 CAS 默认使用 PKCS1 填充
        let encrypted = try rsaPKCS1EncryptToBase64(password, publicKeyPEM: publicKeyString)
        return "__RSA__" + encrypted
    } catch {
        print("encrypt failed: \(error)")
        return nil
    }
}
func encryptShishanyouniPassword(password: String) -> String? {
    let publicKeyString = """
    -----BEGIN PUBLIC KEY-----
    MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQC4juOc5iyP+n1xZCtEtT4lZNeZ
    9UsFMla+t/+wIEx62Kwej7fiMZq04XfeS9yJQ1yTIT+08xezGGOo06H9OeKXy4et
    WZ/tRqrSp8Qv/IOJO+RxgcarrZqdSKZaoygscePqWaZzWv0z26vkY43z5tdm7MSC
    CAwbgL5zteyGGD5gmQIDAQAB
    -----END PUBLIC KEY-----
    """

    do {
        // 狮山有你也走 PKCS1
        let encrypted = try rsaPKCS1EncryptToBase64(password, publicKeyPEM: publicKeyString)
        return encrypted + "_RSA"
    } catch {
        print("encrypt failed: \(error)")
        return nil
    }
}
