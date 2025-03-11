//
//  ContentView.swift
//  Tomato
//
//  Created by 梁力航 on 2025/2/24.
//

import SwiftUI

// 主题枚举定义（放在文件顶部）
enum AppTheme: Int, CaseIterable {
    case deepBlue
    case vibrantOrange
    case forestGreen
    
    var colors: [Color] {
        switch self {
        case .deepBlue:
            return [.indigo, .blue]
        case .vibrantOrange:
            return [Color(red: 1, green: 0.5, blue: 0), .orange]
        case .forestGreen:
            return [.green, .mint]
        }
    }
    
    var name: String {
        switch self {
        case .deepBlue: return "深蓝主题"
        case .vibrantOrange: return "活力橙"
        case .forestGreen: return "森林绿"
        }
    }
}

struct ContentView: View {
    @StateObject private var timerManager = TimerManager()
    @State private var showingSettings = false // 新增状态控制
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.deepBlue.rawValue
    
    // 当前主题颜色集合
    private var themeColors: [Color] {
        AppTheme(rawValue: selectedTheme)?.colors ?? [.indigo, .blue]
    }
    
    private var totalTimeToday:Double {
        getTotalTimeToday()
    }
    
    private var totalSessionsToday:Int32 {
        getTotalSessionsToday()
    }
    
    var body: some View {
        NavigationStack { // 改为导航视图
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: themeColors),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 50) {
                        timeSelectionSection()
                            .padding(.top, 30)
                        
                        CircularProgressView(progress: timerManager.progress)
                            .frame(width: 300, height: 300)
                        
                        
                        controlButtonsSection()
                            .padding(.vertical)
                        statsSection()
                            .padding(.horizontal)
                            
                    }
                    .padding(.horizontal)
                }
            }
            .navigationBarHidden(true)
            .sheet (isPresented: $showingSettings ) {
                SettingsView()
                    .presentationDetents([.medium, .large])
            }
            .foregroundColor(.white)
            // iOS通知权限请求
            .onAppear {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
            }
        }
    }
 
    private func controlButtonsSection() -> some View {
        HStack(spacing: 30) {
            Button(timerManager.buttonLabel) {
                UIImpactFeedbackGenerator(style:.light).impactOccurred()
                withAnimation { timerManager.toggleTimer() }
            }
            .buttonStyle(ControlButtonStyle(color: timerManager.buttonColor))
                   
            Button("End") {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation { timerManager.stopTimer() }
            }
            .buttonStyle(ControlButtonStyle(color: .red))
            .disabled(timerManager.timerState == .stopped)
        }
    }

        
    private func statsSection() -> some View {
        HStack(spacing: 25){
            StatBadge(icon: "hourglass", value: "\(Int(totalTimeToday)/60) min")
            SettingsButton
                .padding(.horizontal,20)
        }
        
    }

    private func timeSelectionSection() -> some View {
        VStack(spacing: 1) {
            // 分段选择器
            Picker("Time", selection: $timerManager.selectedTime) {
                ForEach([15, 20, 25, 30], id: \.self) { time in
                    Text("\(time)m")
                        .foregroundColor(.white) // ✨ 直接设置文本颜色
                        .tag(time)
                        .font(.system(size:25,weight:.semibold))// 字号与字重
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .accentColor(.white) // 设置选中指示器颜色
            .disabled(!timerManager.canChangeTime)
            
            // 滚轮选择器
            Picker("Time", selection: $timerManager.selectedTime) {
                ForEach(1...99, id: \.self) { time in
                    Text("\(time)m")
                        .foregroundColor(.white) // ✨ 直接设置文本颜色
                        .tag(time)
                }
            }
            .pickerStyle(.wheel)
            .colorMultiply(.white) // ✨ 增强滚轮整体色调
            .disabled(!timerManager.canChangeTime)
        }
        .background(Color.black.opacity(0.1)) // 添加背景增强对比度
        .cornerRadius(10)
        .onChange(of: timerManager.selectedTime) {
            hapticFeedback(style: .medium) // 数值变化时触发震动
        }
    }
    
    private var SettingsButton: some View {
        Button(action: {
            showingSettings.toggle()
            hapticFeedback()
        }) {
            Image(systemName: "gearshape")
                .font(.system(size: 24, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(.white)
                .padding(15)
                .background(
                    Circle()
                        .fill(themeColors.first?.opacity(0.3) ?? Color.white.opacity(0.2))
                        .background(
                            Circle()
                                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
                )
        }
    }

}



#Preview {
    ContentView()
}
