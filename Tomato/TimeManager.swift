//
//  TimeManager.swift
//  Tomato
//

import UIKit
import SwiftUI
import Foundation
import Combine
import UserNotifications
import BackgroundTasks
import AVFoundation  // 新增音频支持

enum TimerState {
    case stopped
    case running
    case paused
}

class TimerManager: NSObject, ObservableObject {  // 改为继承NSObject
    @Published var currentSessionType: SessionType = .work
    // MARK: - 状态属性
    @Published var selectedTime: Int = 25 {
        didSet {
            if canChangeTime {
                resetTimer()
            }
        }
    }
    @Published var selectedTimeForWheel: Int = 25
    @Published var remainingTime: Int = 25 * 60
    @Published var timerState: TimerState = .stopped {
        didSet { canChangeTime = (timerState == .stopped) }
    }
    @Published var totalTimeToday: Double = 0.0
    @Published var totalSessions: Int32 = 0
    @Published var canChangeTime: Bool = true
    // 在 TimerManager 中添加
    @Published var enableNotifications = true
    @Published var autoStartNext = false
    @Published var dailyGoal = 8
    private var currentSessionId: UUID?

    
    // MARK: - 后台管理属性
    private var audioPlayer: AVAudioPlayer?  // 新增音频播放器
    private var timer: Timer?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var lastTickTime: Date?
    private var startTime: Date? {
        didSet { saveState() }
    }
    
    var progress: Double {
        Double(remainingTime) / Double(selectedTime * 60) // 修正 DoublTe 拼写
    }
    
    var remainingTimeString: String {
        let minutes = remainingTime / 60
        let seconds = remainingTime % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // 添加计算属性（在progress属性之后）
    var buttonLabel: String {
        switch timerState {
        case .running: return "Running"
        case .paused: return "Resume"
        case .stopped: return "Start"
        }
    }

    var buttonColor: Color {
        switch timerState {
        case .running: return .green
        case .paused: return .blue
        case .stopped: return .green
        }
    }

    // MARK: - 生命周期
    override init() {
        super.init()
        setupAudioSession()  // 初始化音频会话
        setupBackgroundHandling()
        loadPersistedState()
        registerBackgroundTasks()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    
    // 添加切换定时器方法
    func toggleTimer() {
        switch timerState {
        case .stopped:
            startTimer()
        case .running:
            pauseTimer()
        case .paused:
            resumeTimer()
        }
    }
    
    func pauseTimer() {
        timerState = .paused
    }

    func resumeTimer() {
        timerState = .running
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
        timerState = .stopped
        
        if let startTime = startTime {
            let duration = Date().timeIntervalSince(startTime)
            if duration >= 5 * 60 {
                addTime(duration: duration / 60)
            }
        }
        remainingTime = selectedTime * 60
    }

    // MARK: - 音频会话配置（关键新增）
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers, .duckOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
            
            // 初始化静音音频（需要项目添加silent.mp3文件）
            if let url = Bundle.main.url(forResource: "silent", withExtension: "mp3") {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.numberOfLoops = -1
                audioPlayer?.volume = 0
            }
        } catch {
            print("音频会话设置失败: \(error)")
        }
    }

    // MARK: - 后台任务处理（优化版）
    private func setupBackgroundHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appMovedToBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.tomato.timer.refresh",
            using: nil
        ) { task in
            self.handleBackgroundRefresh(task: task as! BGProcessingTask)
        }
    }

    // MARK: - startTimer
    func startTimer() {
        guard timerState != .running else { return }
        
        // 生成唯一会话ID
        currentSessionId = UUID()
        startTime = Date()
        
        // 创建初始会话并保存
        saveCurrentSession()
        
        timerState = .running
        startBackgroundTask()
        scheduleBackgroundProcessingTask()
        startSilentAudioPlayback()
        
        // 更精确的定时器
        timer = Timer.scheduledTimer(
            timeInterval: 1.0,
            target: self,
            selector: #selector(preciseTick),
            userInfo: nil,
            repeats: true
        )
        RunLoop.current.add(timer!, forMode: .common)
    }
    
    // 新增方法：保存当前会话状态
    private func saveCurrentSession() {
        guard let sessionId = currentSessionId, let startTime = startTime else { return }
        
        let duration = Date().timeIntervalSince(startTime)
        let session = TimeSession(
            id: sessionId,
            startDate: startTime,
            duration: duration,
            sessionType: currentSessionType,
            deviceIdentifier: UIDevice.current.identifierForVendor?.uuidString ?? "",
            totalsessions: totalSessions
        )
        
        CoreDataManager.shared.saveSession(session: session)
    }

    @objc private func preciseTick() {
        guard timerState == .running, let startTime = startTime else { return }
        
        saveCurrentSession()
        
        let elapsed = Int(Date().timeIntervalSince(startTime))
        remainingTime = max(selectedTime * 60 - elapsed, 0)
        
        if remainingTime <= 0 {
            handleTimerCompletion()
        }
        saveState()
    }

    // MARK: - 改进的后台任务处理
    private func handleBackgroundRefresh(task: BGProcessingTask) {
        // 在 handleTimerCompletion 中添加自动开始逻辑
        if autoStartNext {
            startTimer()
        }
        
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
            self.scheduleBackgroundProcessingTask()
        }
        
        let elapsed = Int(Date().timeIntervalSince(startTime ?? Date()))
        if elapsed >= selectedTime * 60 {
            handleTimerCompletion()
            task.setTaskCompleted(success: true)
        } else {
            remainingTime = selectedTime * 60 - elapsed
            scheduleLocalNotification()
            scheduleBackgroundProcessingTask()
            task.setTaskCompleted(success: true)
        }
        saveState()
    }

    private func scheduleBackgroundProcessingTask() {
        let request = BGProcessingTaskRequest(identifier: "com.tomato.timer.refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: TimeInterval(remainingTime))
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = true
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("后台任务提交失败: \(error.localizedDescription)")
        }
    }

    // MARK: - 静音播放控制
    private func startSilentAudioPlayback() {
        guard UIApplication.shared.applicationState == .background else { return }
        audioPlayer?.play()
    }

    private func stopSilentAudioPlayback() {
        audioPlayer?.stop()
    }

    // MARK: - 优化的后台任务管理
    private func startBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }

    // MARK: - 增强的状态管理
    private func saveState() {
        let state: [String: Any] = [
            "remainingTime": remainingTime,
            "timerState": timerStateDescription,
            "startTime": startTime ?? Date(),
            "selectedTime": selectedTime
        ]
        UserDefaults.standard.set(state, forKey: "timerState")
    }

    private var timerStateDescription: String {
        switch timerState {
        case .running: return "running"
        case .paused: return "paused"
        default: return "stopped"
        }
    }

    private func loadPersistedState() {
        guard let state = UserDefaults.standard.dictionary(forKey: "timerState") else { return }
        
        remainingTime = state["remainingTime"] as? Int ?? 25 * 60
        selectedTime = state["selectedTime"] as? Int ?? 25
        startTime = state["startTime"] as? Date
        
        switch state["timerState"] as? String {
        case "running":
            if let startTime = startTime {
                let elapsed = Int(Date().timeIntervalSince(startTime))
                remainingTime = max(selectedTime * 60 - elapsed, 0)
                if remainingTime > 0 { timerState = .running }
            }
        case "paused": timerState = .paused
        default: timerState = .stopped
        }
    }

    // MARK: - 前后台切换处理（优化版）
    @objc private func appMovedToBackground() {
        guard timerState == .running else { return }
        // 立即写入闪存
        saveStateToPersistentStore()
        
        // 启动定时保存机制
        startAutoSaveTimer()
        
        startSilentAudioPlayback()
        saveState()
        startBackgroundTask()
        scheduleBackgroundProcessingTask()
        scheduleLocalNotification()
    }

    private func saveStateToPersistentStore() {
        let session = TimeSession(
            id: UUID(),
            startDate: startTime ?? Date(),
            duration: totalTimeToday,
            sessionType: currentSessionType,
            deviceIdentifier: UIDevice.current.identifierForVendor?.uuidString ?? "",
            totalsessions: totalSessions
        )
        
        // 双写策略
        CacheManager.shared.saveToCache(session: session)
        CoreDataManager.shared.batchInsert(sessions: [session])
    }

    // 定时保存保护
    private func startAutoSaveTimer() {
        let timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            self.saveStateToPersistentStore()
        }
        RunLoop.current.add(timer, forMode: .common)
    }

    @objc private func appWillEnterForeground() {
        endBackgroundTask()
        stopSilentAudioPlayback()
        
        if timerState == .running {
            let elapsed = Int(Date().timeIntervalSince(startTime ?? Date()))
            remainingTime = max(selectedTime * 60 - elapsed, 0)
            
            if remainingTime <= 0 {
                handleTimerCompletion()
            } else {
                startTimer()
            }
        }
    }

    // MARK: - handleTimerCompletion
    func handleTimerCompletion() {
        guard let currentSessionId = currentSessionId else { return }
        
        // 标记会话为已完成
        let session = TimeSession(
            id: currentSessionId,
            startDate: startTime!,
            duration: Date().timeIntervalSince(startTime!),
            sessionType: currentSessionType,
            deviceIdentifier: UIDevice.current.identifierForVendor?.uuidString ?? "",
            totalsessions: totalSessions
        )
        CoreDataManager.shared.markSessionAsCompleted(session)
        stopTimer()
        addTime(duration: Double(selectedTime))
        displayNotification()
        DispatchQueue.main.async { self.displayAlert() }
        saveState()
        remainingTime = selectedTime * 60
        self.currentSessionId = nil // 清除当前会话
    }

    private func scheduleLocalNotification() {
        let content = UNMutableNotificationContent()
        content.title = "🍅 Time's up!"
        content.body = "\(selectedTime)分钟专注时间已到"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(remainingTime),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "timerComplete",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func resetTimer() {
        remainingTime = selectedTime * 60
        timer?.invalidate()
        timer = nil
        timerState = .stopped
        startTime = nil
    }
    
    // MARK: - Time Management
    private func addTime(duration: TimeInterval = 0) {
        if duration > 0 {
            totalTimeToday += duration
        } else {
            totalTimeToday += Double(selectedTime)
        }
        totalSessions += 1  // 新增统计
        saveTotalTime()
    }
    
    // MARK: - Notifications and Storage
    private func displayNotification() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            
            let content = UNMutableNotificationContent()
            content.title = "🍅 Pomodoro Completed!"
            content.subtitle = "Great job on your \(self.selectedTime)-minute session!"
            content.sound = UNNotificationSound.defaultCritical

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
            )
            
            UNUserNotificationCenter.current().add(request)
        }
    }
    
    private func displayAlert() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }
        
        let alert = UIAlertController(
            title: "Pomodoro Timer Ended!",
            message: "Keep it up today! 😎",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        rootViewController.present(alert, animated: true)
    }
    
    // 防止每天创建新key
    func saveTotalTime() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let dateKey = formatter.string(from: Date())
        
        UserDefaults.standard.set(totalTimeToday, forKey: "totalTime_\(dateKey)")
        UserDefaults.standard.set(totalSessions, forKey: "totalSessions_\(dateKey)")  // 新增保存
    }
    
    // 在App启动时
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // 迁移缓存数据
        CacheManager.shared.migrateCacheToCoreData()
        
        // 检查未完成会话
        recoverInterruptedSessions()
        return true
    }

    // TimeManager.swift
    private func recoverInterruptedSessions() {
        let incompleteSessions = CoreDataManager.shared.loadIncompleteSessions()
        incompleteSessions.forEach { session in
            // 计算剩余时间（示例逻辑）
            let elapsed = Date().timeIntervalSince(session.startDate)
            let remaining = session.duration - elapsed
            
            guard remaining > 0 else {
                // 如果已超时，标记为完成
                completeSession(session)
                return
            }
            
            // 恢复计时器状态
            self.selectedTime = Int(session.duration / 60)
            self.remainingTime = Int(remaining)
            self.startTime = session.startDate
            self.timerState = .running
            self.currentSessionType = session.sessionType
            
            // 启动计时器
            startTimer()
        }
    }

    private func completeSession(_ session: TimeSession) {
        // 标记为已完成
        CoreDataManager.shared.markSessionAsCompleted(session)
    }
}
