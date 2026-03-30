//
//  RSA.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/2/8.
//

import Foundation

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
        // 直接使用，无需 import
        let publicKey = try PublicKey(pemEncoded: publicKeyString)
        let clear = try ClearMessage(string: password, using: .utf8)
        
        // 华农 CAS 默认使用 PKCS1 填充
        let encrypted = try clear.encrypted(with: publicKey, padding: .PKCS1)
        
        return "__RSA__" + encrypted.base64String
    } catch {
        print("❌ 加密失败: \(error)")
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
        // 直接使用，无需 import
        let publicKey = try PublicKey(pemEncoded: publicKeyString)
        let clear = try ClearMessage(string: password, using: .utf8)
        
        // 华农 CAS 默认使用 PKCS1 填充
        let encrypted = try clear.encrypted(with: publicKey, padding: .PKCS1)
        
        return encrypted.base64String + "_RSA"
    } catch {
        print("❌ 加密失败: \(error)")
        return nil
    }
}
