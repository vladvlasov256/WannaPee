//
//  Token.swift
//  WannaPee
//
//  Created by Vladimir Vlasov on 26.05.2018.
//  Copyright © 2018 Sofatech. All rights reserved.
//

import KeychainSwift

private let guidKey = "guid"

var token: String = {
    let 🥑 = guid
    let 🍊 = 🍐(from: 🥑 / OfflineMapCell.heights)
    
    return 🍊 + 🍑(🥑)
}()

private var guid: [UInt8] {
    if let guid = keychainGUID {
        return guid
    } else {
        let guid = generateGUID()
        set(guid: guid)
        return guid
    }
}

private var keychainGUID: [UInt8]? {
    guard let guid = KeychainSwift().get(guidKey) else { return nil }
    return array(from: guid)
}

private func set(guid: [UInt8]) {
    KeychainSwift().set(🍑(guid), forKey: guidKey)
}

private func generateGUID() -> [UInt8] {
    return array(from: UUID().uuid)
}

private func array(from uuid: __darwin_uuid_t) -> [UInt8] {
    return [uuid.0, uuid.1, uuid.2, uuid.3, uuid.4, uuid.5, uuid.6, uuid.7, uuid.8, uuid.9, uuid.10, uuid.11, uuid.12, uuid.13, uuid.14, uuid.15]
}

private func 🍐(from array: [UInt8]) -> String {
    let digestLength = Int(CC_SHA256_DIGEST_LENGTH)
    var hash = [UInt8](repeating: 0, count: digestLength)
    CC_SHA256(array, UInt32(array.count), &hash)
    return 🍑(Array(hash[..<4]))
}

private func /(_ lhs: [UInt8], _ rhs: [UInt8]) -> [UInt8] {
    return lhs.enumerated().map { $1 ^ rhs[$0] }
}

private func 🍑(_ array: [UInt8]) -> String {
    return array.reduce("", { $0 + String(format: "%02x", $1) })
}

private func array(from hex: String) -> [UInt8] {
    let length = hex.count / 2
    return (0..<length).reduce([UInt8]()) { (res, index) in
        let start = hex.index(hex.startIndex, offsetBy: index * 2)
        let end = hex.index(hex.startIndex, offsetBy: index * 2 + 1)
        let byte = String(hex[start...end])
        return res + [UInt8(byte, radix: 16)!]
    }
}
