//
//  SwiftUIExampleSettingsView.swift
//  Examples
//
//  SwiftUI 设置页面示例
//  展示如何在 SwiftUI 中管理 IAP 设置和调试信息
//

import SwiftUI
import IAPKit

/// SwiftUI 设置页面示例
@available(iOS 15.0, *)
struct SwiftUIExampleSettingsView: View {
    
    // MARK: - Properties
    
    /// 内购管理器
    @EnvironmentObject private var iapManager: SwiftUIIAPManager
    
    /// 显示调试信息
    @State private var showDebugInfo = false
    
    /// 显示清除缓存确认
    @State private var showClearCacheConfirmation = false
    
    /// 显示重置确认
    @State private var showResetConfirmation = false
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            List {
                // 购买管理区域
                purchaseManagementSection
                
                // 调试信息区域
                debugInfoSection
                
                // 系统信息区域
                systemInfoSection
                
                // 开发者选项区域
                developerOptionsSection
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.large)
            .confirmationDialog("清除缓存", isPresented: $showClearCacheConfirmation) {
                Button("清除缓存", role: .destructive) {
                    clearCache()
                }
                Button("取消", role: .cancel) { }
            } message: {
                Text("这将清除所有缓存的商品信息和状态")
            }
            .confirmationDialog("重置框架", isPresented: $showResetConfirmation) {
                Button("重置", role: .destructive) {
                    resetFramework()
                }
                Button("取消", role: .cancel) { }
            } message: {
                Text("这将重置框架到初始状态，清除所有数据")
            }
        }
    }
    
    // MARK: - View Sections
    
    /// 购买管理区域
    private var purchaseManagementSection: some View {
        Section("购买管理") {
            // 恢复购买
            Button(action: {
                Task {
                    try? await iapManager.restorePurchases()
                }
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.blue)
                    
                    Text("恢复购买")
                    
                    Spacer()
                    
                    if iapManager.isRestoringPurchases {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
            .disabled(iapManager.isRestoringPurchases)
            
            // 清除缓存
            Button(action: {
                showClearCacheConfirmation = true
            }) {
                HStack {
                    Image(systemName: "trash")
                        .foregroundColor(.orange)
                    
                    Text("清除缓存")
                }
            }
            
            // 重新加载商品
            Button(action: {
                Task {
                    let productIDs: Set<String> = [
                        "com.example.premium",
                        "com.example.coins_100",
                        "com.example.coins_500",
                        "com.example.monthly_subscription",
                        "com.example.yearly_subscription"
                    ]
                    try? await iapManager.loadProducts(productIDs: productIDs)
                }
            }) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(.green)
                    
                    Text("重新加载商品")
                    
                    Spacer()
                    
                    if iapManager.isLoadingProducts {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
            .disabled(iapManager.isLoadingProducts)
        }
    }
    
    /// 调试信息区域
    private var debugInfoSection: some View {
        Section("调试信息") {
            // 显示/隐藏调试信息
            Toggle("显示调试信息", isOn: $showDebugInfo)
            
            if showDebugInfo {
                // 框架状态
                InfoRowView(
                    label: "框架状态",
                    value: iapManager.isBusy ? "忙碌" : "空闲",
                    color: iapManager.isBusy ? .orange : .green
                )
                
                // 交易监听状态
                InfoRowView(
                    label: "交易监听",
                    value: iapManager.isTransactionObserverActive ? "已启用" : "未启用",
                    color: iapManager.isTransactionObserverActive ? .green : .red
                )
                
                // 已加载商品数量
                InfoRowView(
                    label: "已加载商品",
                    value: "\(iapManager.products.count)",
                    color: .primary
                )
                
                // 最近交易数量
                InfoRowView(
                    label: "最近交易",
                    value: "\(iapManager.recentTransactions.count)",
                    color: .primary
                )
                
                // 购买中的商品
                InfoRowView(
                    label: "购买中商品",
                    value: iapManager.purchasingProducts.isEmpty ? "无" : "\(iapManager.purchasingProducts.count)",
                    color: iapManager.purchasingProducts.isEmpty ? .secondary : .blue
                )
                
                // 恢复进度
                InfoRowView(
                    label: "恢复进度",
                    value: iapManager.isRecoveryInProgress ? "进行中" : "空闲",
                    color: iapManager.isRecoveryInProgress ? .blue : .secondary
                )
                
                // 最后错误
                if let error = iapManager.lastError {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("最后错误:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(error.localizedDescription)
                            .font(.caption)
                            .foregroundColor(.red)
                            .lineLimit(3)
                    }
                } else {
                    InfoRowView(
                        label: "最后错误",
                        value: "无",
                        color: .green
                    )
                }
            }
        }
    }
    
    /// 系统信息区域
    private var systemInfoSection: some View {
        Section("系统信息") {
            InfoRowView(
                label: "iOS 版本",
                value: UIDevice.current.systemVersion,
                color: .primary
            )
            
            InfoRowView(
                label: "设备型号",
                value: UIDevice.current.model,
                color: .primary
            )
            
            InfoRowView(
                label: "StoreKit 版本",
                value: isStoreKit2Available ? "StoreKit 2" : "StoreKit 1",
                color: isStoreKit2Available ? .green : .orange
            )
            
            InfoRowView(
                label: "应用版本",
                value: appVersion,
                color: .primary
            )
            
            InfoRowView(
                label: "构建版本",
                value: buildVersion,
                color: .secondary
            )
        }
    }
    
    /// 开发者选项区域
    private var developerOptionsSection: some View {
        Section("开发者选项") {
            // 模拟网络错误
            Button(action: {
                // 这里可以添加模拟网络错误的代码
                print("模拟网络错误")
            }) {
                HStack {
                    Image(systemName: "wifi.slash")
                        .foregroundColor(.red)
                    
                    Text("模拟网络错误")
                }
            }
            
            // 模拟购买成功
            Button(action: {
                // 这里可以添加模拟购买成功的代码
                print("模拟购买成功")
            }) {
                HStack {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.green)
                    
                    Text("模拟购买成功")
                }
            }
            
            // 重置框架
            Button(action: {
                showResetConfirmation = true
            }) {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundColor(.red)
                    
                    Text("重置框架")
                }
            }
            
            // 导出日志
            Button(action: {
                exportLogs()
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.blue)
                    
                    Text("导出日志")
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// 是否支持 StoreKit 2
    private var isStoreKit2Available: Bool {
        if #available(iOS 15.0, *) {
            return true
        }
        return false
    }
    
    /// 应用版本
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "未知"
    }
    
    /// 构建版本
    private var buildVersion: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "未知"
    }
    
    // MARK: - Methods
    
    /// 清除缓存
    private func clearCache() {
        // 这里可以添加清除缓存的实际代码
        print("清除缓存")
    }
    
    /// 重置框架
    private func resetFramework() {
        Task {
            // 这里可以添加重置框架的实际代码
            await iapManager.cleanup()
            await iapManager.initialize()
            print("框架已重置")
        }
    }
    
    /// 导出日志
    private func exportLogs() {
        // 这里可以添加导出日志的代码
        print("导出日志")
    }
}

// MARK: - Supporting Views

/// 信息行视图
private struct InfoRowView: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .foregroundColor(color)
                .fontWeight(.medium)
        }
    }
}

#if DEBUG
@available(iOS 15.0, *)
struct SwiftUIExampleSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SwiftUIExampleSettingsView()
            .environmentObject(SwiftUIIAPManager())
    }
}
#endif