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
    let lines = pem
        .components(separatedBy: .newlines)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty && !$0.hasPrefix("-----") }
    let base64Body = lines.joined()
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
    -----BEGIN PUBLIC KEY-----
    MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAvyJ32TltswWY4jBKc2z9
    /8slizBfnGLqmaGTs0CKmlJPHvjSIzk6Vj10nSEE4lvnyhIHDvnnLjkNxkZ4L9J8
    tTyUMM8EbepIOht8KRTQl4CQwIUNqM12NG7ji1+q0qENAdoahPjx1iYlsamVvLWs
    LOsaNjhE3OZrNYAvZUHsyQDOJN0Tx+QT6aFabUOfUA8n62xKExAVITYi9Fk0f4UB
    k88Qj1eJF8Z5YF/9lEqlD88RHPABLBgSwOLaQTpj+qHTtGOtPYNCMjd9+jk1qyFR
    IXzdj8k4hlIrAM4kxFMQEfAmwbl2W8AK2S2UjYsyFCpshdiLzDFmW2UEtwKG34rF
    8wIDAQAB
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
        // 教务系统也走 PKCS1
        let encrypted = try rsaPKCS1EncryptToBase64(password, publicKeyPEM: publicKeyString)
        return encrypted + "_RSA"
    } catch {
        print("encrypt failed: \(error)")
        return nil
    }
}
