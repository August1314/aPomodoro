//
//  CoreDataManager.swift
//  Tomato
//
//  Created by 梁力航 on 2025/3/3.
//
import Foundation
import CoreData

class CoreDataManager {
    static let shared = CoreDataManager()
    private lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "TimeDataModel")
        container.loadPersistentStores { description, error in
            if let error = error as NSError? {
                fatalError("CoreData加载失败: \(error), \(error.userInfo)")
            }
        }
        return container
    }()
    
    // 新增：保存或更新单个会话
    func saveSession(session: TimeSession) {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<TimeSessionEntity>(entityName: "TimeSessionEntity")
        request.predicate = NSPredicate(format: "id == %@", session.id as CVarArg)
        
        do {
            let results = try context.fetch(request)
            let entity = results.first ?? TimeSessionEntity(context: context)
            
            // 更新实体属性
            entity.id = session.id
            entity.startDate = session.startDate
            entity.duration = session.duration
            entity.sessionType = session.sessionType.rawValue
            entity.deviceIdentifier = session.deviceIdentifier
            entity.totalsessions = session.totalsessions
            
            try context.save()
        } catch {
            print("保存会话失败: \(error)")
        }
    }
    
    // MARK: - 保存上下文（关键修复）
    func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
                print("✅ 数据保存成功")
            } catch {
                let nserror = error as NSError
                fatalError("❌ 保存失败: \(nserror), \(nserror.userInfo)")
            }
        }
    }

    func batchInsert(sessions: [TimeSession]) {
        persistentContainer.performBackgroundTask { context in
            sessions.forEach { session in
                let entity = TimeSessionEntity(context: context)
                entity.id = session.id
                entity.startDate = session.startDate
                entity.duration = session.duration
                entity.sessionType = session.sessionType.rawValue
                entity.deviceIdentifier = session.deviceIdentifier
                entity.totalsessions = session.totalsessions
            }
            
            do {
                try context.save()
            } catch {
                print("保存失败: \(error.localizedDescription)")
            }
        }
    }
    
    func fetchSessions() -> [TimeSession] {
        // 正确初始化方法
        let request = NSFetchRequest<TimeSessionEntity>(entityName: "TimeSessionEntity")
        
        do {
            let results = try persistentContainer.viewContext.fetch(request)
            return results.compactMap { entity in
                guard let id = entity.id,
                      let startDate = entity.startDate,
                      let sessionTypeRaw = entity.sessionType,
                      let sessionType = SessionType(rawValue: sessionTypeRaw),
                      let deviceIdentifier = entity.deviceIdentifier else {
                    return nil
                }
                
                return TimeSession(
                    id: id,
                    startDate: startDate,
                    duration: entity.duration,
                    sessionType: sessionType,
                    deviceIdentifier: deviceIdentifier,
                    totalsessions: entity.totalsessions
                )
            }
        } catch {
            print("查询失败: \(error)")
            return []
        }
    }
        
    // CoreDataManager.swift
    func loadIncompleteSessions() -> [TimeSession] {
        let request = NSFetchRequest<TimeSessionEntity>(entityName: "TimeSessionEntity")
        request.predicate = NSPredicate(format: "completeDate == nil") // 更准确的条件
        request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
        // 定义过滤条件：假设未完成会话的 duration 未达到设定值
        let isIncompletePredicate = NSPredicate(format: "duration < %lf", 1500.0) // 1500秒=25分钟
        request.predicate = isIncompletePredicate
        
        // 排序规则：按开始时间倒序
        request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
        
        do {
            let results = try persistentContainer.viewContext.fetch(request)
            return results.compactMap { entity in
                guard let id = entity.id,
                      let startDate = entity.startDate,
                      let sessionTypeRaw = entity.sessionType,
                      let sessionType = SessionType(rawValue: sessionTypeRaw),
                      let deviceIdentifier = entity.deviceIdentifier else {
                    return nil
                }
                
                return TimeSession(
                    id: id,
                    startDate: startDate,
                    duration: entity.duration,
                    sessionType: sessionType,
                    deviceIdentifier: deviceIdentifier,
                    totalsessions: entity.totalsessions
                )
            }
        } catch {
            print("加载未完成会话失败: \(error)")
            return []
        }
    }
    
    // CoreDataManager.swift
    // 修改：完善完成标记逻辑
    func markSessionAsCompleted(_ session: TimeSession) {
        let request = NSFetchRequest<TimeSessionEntity>(entityName: "TimeSessionEntity")
        request.predicate = NSPredicate(format: "id == %@", session.id as CVarArg)
        
        do {
            let results = try persistentContainer.viewContext.fetch(request)
            if let entity = results.first {
                entity.completeDate = Date() // 添加完成时间
                entity.duration = session.duration // 更新实际持续时间
                entity.totalsessions = session.totalsessions
                saveContext()
            }
        } catch {
            print("标记完成失败: \(error)")
        }
    }
}
