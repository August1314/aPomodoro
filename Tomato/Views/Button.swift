//
//  Button.swift
//  Tomato
//
//  Created by 梁力航 on 2025/2/24.
//

import SwiftUI
import Combine
// 控制按钮统一样式
struct ControlButtonStyle: ButtonStyle {
    var color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.vertical, 10)
            .padding(.horizontal, 24)
            .background(Capsule().fill(color))
            .foregroundColor(.white)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct ControlButton: View {
    let label: String
    let color: Color
    var action: () -> Void  // 添加点击事件回调
    
    var body: some View {
        HStack(spacing: 20) {
            Button(label) {
                withAnimation { action() }
            }
            .buttonStyle(ControlButtonStyle(color: color))
        }
    }
}


// 统计徽章组件
struct StatBadge: View {
    let icon: String
    let value: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(value)
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
}

// 圆形进度视图组件
struct CircularProgressView: View {
    var progress: Double
    
    var body: some View {
        ZStack {
            // 背景圆环
            Circle()
                .stroke(lineWidth: 12)
                .opacity(0.3)
                .foregroundColor(.white)
            
            // 进度圆环（三种动画优化方案任选其一）
            progressCircleWithAnimation()
        }
    }
    
    // MARK: - 动画优化方案
    // 方案一：增强时间曲线 + 弹性效果
    private func progressCircleWithSpring() -> some View {
        Circle()
            .trim(from: 0, to: progress)
            .stroke(style: StrokeStyle(lineWidth: 12, lineCap: .round))
            .foregroundColor(.white)
            .rotationEffect(Angle(degrees: -90))
            .animation(
                .spring(
                    duration: 1.5,  // 延长动画时间
                    bounce: 0.25    // 添加弹性效果
                ),
                value: progress
            )
    }
    
    // 方案二：自定义时序曲线动画
    private func progressCircleWithCustomEasing() -> some View {
        Circle()
            .trim(from: 0, to: progress)
            .stroke(style: StrokeStyle(lineWidth: 12, lineCap: .round))
            .foregroundColor(.white)
            .rotationEffect(Angle(degrees: -90))
            .animation(
                .timingCurve(0.68, -0.55, 0.27, 1.55, duration: 1.2), // 自定义贝塞尔曲线
                value: progress
            )
    }
    
    // 方案三：组合动画 + 旋转同步
    private func progressCircleWithAnimation() -> some View {
        Circle()
            .trim(from: 0, to: progress)
            .stroke(style: StrokeStyle(lineWidth: 12, lineCap: .round))
            .foregroundColor(.white)
            .rotationEffect(Angle(degrees: -90))
            .animation(
                .easeInOut(duration: 1.2)  // 基础动画
                .delay(0.1)              // 开始前微延迟
                .speed(1.1),                // 加速动画
                value: progress
            )
            .transaction { transaction in  // 强制启用动画
                transaction.animation = transaction.animation?.speed(1.5)
            }
    }
}

public func hapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
    let generator = UIImpactFeedbackGenerator(style: style)
    generator.prepare() // 预载振动组件
    generator.impactOccurred()
}
