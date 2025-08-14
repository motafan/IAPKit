//
//  SwiftUIExampleUsageView.swift
//  Examples
//
//  SwiftUI 使用示例视图
//  展示如何在 SwiftUI 中使用 IAPFramework 的各种功能
//

import SwiftUI
import IAPFramework

/// SwiftUI 使用示例视图
@available(iOS 15.0, *)
struct SwiftUIExampleUsageView: View {
    
    // MARK: - Properties
    
    /// 内购管理器
    @EnvironmentObject private var iapManager: SwiftUIIAPManager
    
    /// 示例商品ID
    private let premiumProductID = "com.example.premium"
    
    /// 选中的示例类型
    @State private var selectedExample: ExampleType = .basicUsage
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 示例选择器
                examplePicker
                
                // 示例内容
                ScrollView {
                    VStack(spacing: 20) {
                        switch selectedExample {
                        case .basicUsage:
                            basicUsageSection
                        case .stateObservation:
                            stateObservationSection
                        case .errorHandling:
                            errorHandlingSection
                        case .advancedFeatures:
                            advancedFeaturesSection
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("使用示例")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    // MARK: - View Components
    
    /// 示例选择器
    private var examplePicker: some View {
        Picker("示例类型", selection: $selectedExample) {
            ForEach(ExampleType.allCases, id: \.self) { type in
                Text(type.title).tag(type)
            }
        }
        .pickerStyle(.segmented)
        .padding()
        .background(Color(.systemGray6))
    }
    
    /// 基本使用示例
    private var basicUsageSection: some View {
        VStack(spacing: 20) {
            ExampleSectionView(title: "1. 加载商品", icon: "tray.and.arrow.down") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("使用 loadProducts 方法加载商品信息：")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    CodeBlockView(code: """
                    let products = try await iapManager.loadProducts(
                        productIDs: ["com.example.premium"]
                    )
                    """)
                    
                    Button("加载商品") {
                        Task {
                            do {
                                let products = try await iapManager.loadProducts(productIDs: [premiumProductID])
                                print("加载了 \(products.count) 个商品")
                            } catch {
                                print("加载商品失败: \(error)")
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(iapManager.isLoadingProducts)
                }
            }
            
            ExampleSectionView(title: "2. 购买商品", icon: "cart") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("使用 purchase 方法购买商品：")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    CodeBlockView(code: """
                    let result = try await iapManager.purchase(product)
                    switch result {
                    case .success(let transaction):
                        // 购买成功
                    case .pending:
                        // 等待处理
                    case .cancelled:
                        // 用户取消
                    }
                    """)
                    
                    if let product = iapManager.products.first(where: { $0.id == premiumProductID }) {
                        Button("购买 \(product.displayName) - \(product.localizedPrice)") {
                            Task {
                                do {
                                    let result = try await iapManager.purchase(product)
                                    handlePurchaseResult(result)
                                } catch {
                                    print("购买失败: \(error)")
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(iapManager.isPurchasing(premiumProductID))
                    } else {
                        Text("请先加载商品")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            ExampleSectionView(title: "3. 恢复购买", icon: "arrow.clockwise") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("使用 restorePurchases 方法恢复历史购买：")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    CodeBlockView(code: """
                    let transactions = try await iapManager.restorePurchases()
                    print("恢复了 \\(transactions.count) 个购买")
                    """)
                    
                    Button("恢复购买") {
                        Task {
                            do {
                                let transactions = try await iapManager.restorePurchases()
                                print("恢复了 \(transactions.count) 个购买")
                            } catch {
                                print("恢复购买失败: \(error)")
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(iapManager.isRestoringPurchases)
                }
            }
        }
    }
    
    /// 状态监听示例
    private var stateObservationSection: some View {
        VStack(spacing: 20) {
            ExampleSectionView(title: "响应式状态管理", icon: "eye") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("SwiftUI 中的状态自动更新：")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    CodeBlockView(code: """
                    @EnvironmentObject private var iapManager: SwiftUIIAPManager
                    
                    var body: some View {
                        VStack {
                            if iapManager.isLoadingProducts {
                                ProgressView("加载中...")
                            }
                            
                            ForEach(iapManager.products) { product in
                                ProductView(product: product)
                            }
                        }
                    }
                    """)
                    
                    // 实时状态显示
                    VStack(spacing: 8) {
                        StatusRowView(label: "加载状态", value: iapManager.isLoadingProducts ? "加载中" : "空闲", color: iapManager.isLoadingProducts ? .blue : .secondary)
                        
                        StatusRowView(label: "购买状态", value: iapManager.purchasingProducts.isEmpty ? "无购买" : "购买中", color: iapManager.purchasingProducts.isEmpty ? .secondary : .blue)
                        
                        StatusRowView(label: "恢复状态", value: iapManager.isRestoringPurchases ? "恢复中" : "空闲", color: iapManager.isRestoringPurchases ? .blue : .secondary)
                        
                        StatusRowView(label: "已加载商品", value: "\(iapManager.products.count)", color: .primary)
                        
                        StatusRowView(label: "最近交易", value: "\(iapManager.recentTransactions.count)", color: .primary)
                        
                        StatusRowView(label: "交易监听", value: iapManager.isTransactionObserverActive ? "已启用" : "未启用", color: iapManager.isTransactionObserverActive ? .green : .red)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    /// 错误处理示例
    private var errorHandlingSection: some View {
        VStack(spacing: 20) {
            ExampleSectionView(title: "错误处理", icon: "exclamationmark.triangle") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("处理各种错误情况：")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    CodeBlockView(code: """
                    do {
                        let result = try await iapManager.purchase(product)
                        // 处理成功结果
                    } catch let error as IAPError {
                        switch error {
                        case .productNotFound:
                            // 商品未找到
                        case .purchaseCancelled:
                            // 购买被取消
                        case .networkError:
                            // 网络错误
                        default:
                            // 其他错误
                        }
                    }
                    """)
                    
                    // 错误状态显示
                    if let error = iapManager.lastError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            
                            VStack(alignment: .leading) {
                                Text("错误信息:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(error.localizedDescription)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            
                            Spacer()
                            
                            Button("清除") {
                                iapManager.clearError()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    } else {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            
                            Text("无错误")
                                .foregroundColor(.secondary)
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
        }
    }
    
    /// 高级功能示例
    private var advancedFeaturesSection: some View {
        VStack(spacing: 20) {
            ExampleSectionView(title: "防丢单机制", icon: "shield.checkered") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("自动处理未完成的交易：")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    CodeBlockView(code: """
                    // 框架会自动监听和恢复未完成的交易
                    // 应用启动时自动检查
                    await iapManager.initialize()
                    
                    // 实时监听交易状态变化
                    iapManager.isRecoveryInProgress // 是否正在恢复
                    """)
                    
                    HStack {
                        Text("恢复状态:")
                        Spacer()
                        Text(iapManager.isRecoveryInProgress ? "恢复中" : "空闲")
                            .foregroundColor(iapManager.isRecoveryInProgress ? .blue : .secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
            
            ExampleSectionView(title: "收据验证", icon: "checkmark.seal") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("验证购买收据：")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    CodeBlockView(code: """
                    // 本地验证
                    let result = try await iapManager.validateReceipt(receiptData)
                    
                    // 远程验证（需要配置服务器）
                    let result = try await iapManager.validateReceiptRemotely(receiptData)
                    """)
                    
                    Button("测试收据验证") {
                        // 这里可以添加收据验证的测试代码
                        print("收据验证功能需要实际的收据数据")
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            ExampleSectionView(title: "自定义配置", icon: "gear") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("配置框架行为：")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    CodeBlockView(code: """
                    let configuration = IAPConfiguration(
                        autoFinishTransactions: false,
                        maxRetryAttempts: 3
                    )
                    
                    await iapManager.configure(with: configuration)
                    """)
                    
                    Button("应用自定义配置") {
                        Task {
                            let configuration = IAPConfiguration(
                                autoFinishTransactions: false,
                                maxRetryAttempts: 3
                            )
                            await iapManager.configure(with: configuration)
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// 处理购买结果
    private func handlePurchaseResult(_ result: IAPPurchaseResult) {
        switch result {
        case .success(let transaction):
            print("购买成功: \(transaction.productID)")
            
            // 完成交易
            Task {
                try? await iapManager.finishTransaction(transaction)
            }
            
        case .pending(let transaction):
            print("购买待处理: \(transaction.productID)")
            
        case .cancelled:
            print("购买被取消")
            
        case .userCancelled:
            print("用户取消购买")
        }
    }
}

// MARK: - Supporting Views

/// 示例类型枚举
private enum ExampleType: CaseIterable {
    case basicUsage
    case stateObservation
    case errorHandling
    case advancedFeatures
    
    var title: String {
        switch self {
        case .basicUsage:
            return "基本使用"
        case .stateObservation:
            return "状态监听"
        case .errorHandling:
            return "错误处理"
        case .advancedFeatures:
            return "高级功能"
        }
    }
}

/// 示例区域视图
private struct ExampleSectionView<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.headline)
                
                Spacer()
            }
            
            content
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

/// 代码块视图
private struct CodeBlockView: View {
    let code: String
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(code)
                .font(.system(.caption, design: .monospaced))
                .padding()
        }
        .background(Color(.systemGray5))
        .cornerRadius(8)
    }
}

/// 状态行视图
private struct StatusRowView: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(label + ":")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }
}

#if DEBUG
@available(iOS 15.0, *)
struct SwiftUIExampleUsageView_Previews: PreviewProvider {
    static var previews: some View {
        SwiftUIExampleUsageView()
            .environmentObject(SwiftUIIAPManager())
    }
}
#endif