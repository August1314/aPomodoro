//
//  View.swift
//  Tomato
//
//  Created by 梁力航 on 2025/3/3.
//

import SwiftUI

// 新增设置视图
struct SettingsView: View {
    @AppStorage("enableNotifications") var enableNotifications = true
    @AppStorage("autoStartNext") var autoStartNext = false
    @AppStorage("dailyGoal") var dailyGoal = 5
    @AppStorage("selectedTheme") var selectedTheme = AppTheme.deepBlue.rawValue
    @AppStorage("enableHaptics") var enableHaptics = true
    
    
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

    var body: some View {
        NavigationStack {
            Form {
                // 通用设置
                Section{
                    Toggle("启用通知", isOn: $enableNotifications)
                        .toggleStyle(SwitchToggleStyle(tint:.blue))
                    Picker("主题颜色", selection: $selectedTheme) {
                        ForEach(AppTheme.allCases, id: \.rawValue) { theme in
                            HStack {
                                themePreview(theme: theme)
                                Text(theme.name)
                            }
                            .tag(theme.rawValue)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }header: {
                    Text("通用设置")
                        .foregroundColor(.primary)
                }
                .listRowBackground(Color(.systemBackground))
                .foregroundColor(.primary)
                
                // 计时设置
                Section{
                    Toggle("自动开始", isOn: $autoStartNext)
                        .toggleStyle(SwitchToggleStyle(tint:.blue))
                    Stepper("每日目标: \(dailyGoal) 个番茄",
                           value: $dailyGoal, in: 1...10)
                    .onChange(of: dailyGoal, {hapticFeedback(style :.light)})
                }header: {
                    Text("专注设置")
                        .foregroundColor(.primary)
                }
                .listRowBackground(Color(.systemBackground))
                .foregroundColor(.primary)
                
                // 高级设置
                Section {
                    NavigationLink("数据统计") {
                        DataView()
                    }
                }header:{
                    Text("高级设置")
                        .foregroundColor(.primary)
                }
                .foregroundColor(.primary)
                
                // 关于信息
                Section {
                    HStack {
                        Text("版本").foregroundColor(.black) // ✨ 直接设置文本颜色
                        Spacer()
                        Text("0.0.0")
                            .foregroundColor(.secondary)
                    }
                    Link("用户协议", destination: URL(string: "https://example.com/tos")!)
                        .foregroundColor(.blue)
                    Link("隐私政策", destination: URL(string: "https://example.com/privacy")!)
                        .foregroundColor(.blue)
                }
                .listRowBackground(Color(.systemBackground))
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear{
            UITableViewCell.appearance().backgroundColor = .clear
            UITableView.appearance().backgroundColor = .clear
            UITableView.appearance().separatorColor = .clear
        }
    }
    
    
    private func themePreview(theme: AppTheme) -> some View {
        HStack(spacing: 4) {
            ForEach(theme.colors, id: \.self) { color in
                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: 24, height: 24)
            }
        }
        .padding(6)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 2)
    }
}
struct DataView: View {
    // 改为计算属性
    private var sessions: [TimeSession] {
        CoreDataManager.shared.fetchSessions()
    }
    
    private var today: Date {
        Calendar.current.startOfDay(for: Date())
    }
    
    // 计算属性替代变量赋值
    private var totalTimeToday: Double {
        sessions
            .filter { $0.startDate >= today }
            .reduce(0) { $0 + $1.duration }
    }
    
    private var totalSessions: Int {
        sessions.count
    }
    
    var body: some View {
        List {
            Section {
                StatRow(icon: "clock", title: "总专注次数", value: "\(totalSessions)")
                StatRow(icon: "hourglass", title: "总专注时间",
                       value: "\(String(format: "%.1f", totalTimeToday)) 小时")
            } header: {
                Text("历史统计").foregroundColor(.black)
            }
            
            Section {
                ProgressView(value: Double(totalSessions)/100) {
                    Text("百次专注").foregroundColor(.black)
                }
                ProgressView(value: Double(totalTimeToday)/60) {
                    Text("百小时成就").foregroundColor(.black)
                }
            } header: {
                Text("成就系统").foregroundColor(.black)
            }
        }
        .background(Color(.systemGroupedBackground))
        .scrollContentBackground(.hidden)
        .navigationTitle("数据统计")
    }
}
// 新增统计行组件
struct StatRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}
