//
//  DataModel.swift
//  Tomato
//
//  Created by 梁力航 on 2025/3/3.
// DataModel.swift
import Foundation

enum SessionType: String, Codable {
    case work
    case `break`
}

struct TimeSession: Codable, Identifiable {
    let id: UUID
    var startDate: Date
    var duration: Double
    var sessionType: SessionType
    let deviceIdentifier: String
    
    // 添加字典转换方法
    var dictionaryRepresentation: [String: Any] {
        return [
            "id": id.uuidString,
            "startDate": startDate,
            "duration": duration,
            "sessionType": sessionType.rawValue,
            "deviceIdentifier": deviceIdentifier
        ]
    }
}
