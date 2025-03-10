//
//  CacheManager.swift
//  Tomato
//
//  Created by 梁力航 on 2025/3/3.
//
import Foundation

class CacheManager {
    static let shared = CacheManager()
    
    private let cacheFileURL: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("timecache.plist")
    }()
    
    // 加载所有缓存数据
    func loadAllCache() -> [TimeSession] {
        guard FileManager.default.fileExists(atPath: cacheFileURL.path) else {
            return [] // 如果文件不存在，返回空数组
        }
        
        do {
            let data = try Data(contentsOf: cacheFileURL)
            let sessions = try PropertyListDecoder().decode([TimeSession].self, from: data)
            return sessions
        } catch {
            print("缓存读取失败: \(error)")
            return []
        }
    }
    
    // 保存数据到缓存
    func saveToCache(session: TimeSession) {
        var existing = loadAllCache()
        existing.append(session)
        
        do {
            let data = try PropertyListEncoder().encode(existing)
            try data.write(to: cacheFileURL, options: .atomic)
        } catch {
            print("缓存写入失败: \(error)")
        }
    }
    
    // 迁移缓存数据到CoreData
    func migrateCacheToCoreData() {
        let cached = loadAllCache()
        CoreDataManager.shared.batchInsert(sessions: cached)
        try? FileManager.default.removeItem(at: cacheFileURL)
    }
}
