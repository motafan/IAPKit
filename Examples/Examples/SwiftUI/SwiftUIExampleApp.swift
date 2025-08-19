//
//  SwiftUIExampleApp.swift
//  Examples
//
//  SwiftUI 示例应用
//  展示如何在 SwiftUI 应用中集成和使用 IAPKit
//

import SwiftUI
import IAPKit

/// SwiftUI 示例应用主入口
@available(iOS 14.0, *)
@main
struct SwiftUIExampleApp: App {
    
    /// 内购管理器（应用级别）
    @StateObject private var iapManager = SwiftUIIAPManager()
    
    var body: some Scene {
        WindowGroup {
            if #available(iOS 15.0, *) {
                SwiftUIExampleContentView()
                    .environmentObject(iapManager)
                    .task {
                        // 应用启动时初始化内购框架
                        await iapManager.initialize()
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                        // 应用即将终止时清理资源
                        iapManager.cleanup()
                    }
            } else {
                // Fallback on earlier versions
            }
        }
    }
}

/// 主内容视图
struct SwiftUIExampleContentView: View {
    
    /// 从环境中获取内购管理器
    @EnvironmentObject private var iapManager: SwiftUIIAPManager
    
    var body: some View {
        TabView {
            // 商店页面
            SwiftUIExampleStoreView()
                .tabItem {
                    Image(systemName: "cart")
                    Text("商店")
                }
            
            // 使用示例页面
            if #available(iOS 15.0, *) {
                SwiftUIExampleUsageView()
                    .tabItem {
                        Image(systemName: "doc.text")
                        Text("示例")
                    }
            } else {
                Text("使用示例页面需要 iOS 15.0 或更高版本")
                    .tabItem {
                        Image(systemName: "doc.text")
                        Text("示例")
                    }
            }
            
            // 设置页面
            if #available(iOS 15.0, *) {
                SwiftUIExampleSettingsView()
                    .tabItem {
                        Image(systemName: "gear")
                        Text("设置")
                    }
            } else {
                Text("设置页面需要 iOS 15.0 或更高版本")
                    .tabItem {
                        Image(systemName: "gear")
                        Text("设置")
                    }
            }
        }
    }
}

#if DEBUG
struct SwiftUIExampleApp_Previews: PreviewProvider {
    static var previews: some View {
        SwiftUIExampleContentView()
            .environmentObject(SwiftUIIAPManager())
    }
}
#endif
