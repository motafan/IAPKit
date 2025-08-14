//
//  SwiftUIExampleStoreView.swift
//  Examples
//
//  SwiftUI 商店界面示例
//  展示如何在 SwiftUI 中创建完整的商店界面
//

import SwiftUI
import IAPFramework

/// SwiftUI 商店界面示例
struct SwiftUIExampleStoreView: View {
    
    // MARK: - Properties
    
    /// 内购管理器
    @EnvironmentObject private var iapManager: SwiftUIIAPManager
    
    /// 商品ID列表（示例）
    private let productIDs: Set<String> = [
        "com.example.premium",
        "com.example.coins_100",
        "com.example.coins_500",
        "com.example.monthly_subscription",
        "com.example.yearly_subscription"
    ]
    
    /// 显示错误警告
    @State private var showingErrorAlert = false
    
    /// 显示成功消息
    @State private var showingSuccessAlert = false
    @State private var successMessage = ""
    
    /// 显示恢复确认
    @State private var showingRestoreConfirmation = false
    
    /// 搜索文本
    @State private var searchText = ""
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 状态栏
                statusBar
                
                // 主内容
                mainContent
            }
            .navigationTitle("应用内购买")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "搜索商品")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    restoreButton
                }
            }
            .task {
                await initializeStore()
            }
            .alert("错误", isPresented: $showingErrorAlert) {
                Button("确定") {
                    iapManager.clearError()
                }
            } message: {
                Text(iapManager.localizedErrorMessage)
            }
            .alert("购买成功", isPresented: $showingSuccessAlert) {
                Button("确定") { }
            } message: {
                Text(successMessage)
            }
            .confirmationDialog("恢复购买", isPresented: $showingRestoreConfirmation) {
                Button("恢复购买") {
                    Task {
                        await restorePurchases()
                    }
                }
                Button("取消", role: .cancel) { }
            } message: {
                Text("这将恢复您之前购买的所有项目")
            }
        }
    }
    
    // MARK: - View Components
    
    /// 状态栏
    private var statusBar: some View {
        HStack {
            // 连接状态
            HStack(spacing: 4) {
                Circle()
                    .fill(iapManager.isTransactionObserverActive ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                
                Text(iapManager.isTransactionObserverActive ? "已连接" : "未连接")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 忙碌状态
            if iapManager.isBusy {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.6)
                    
                    Text(busyStatusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
    
    /// 主内容
    private var mainContent: some View {
        Group {
            if iapManager.isLoadingProducts {
                loadingView
            } else if filteredProducts.isEmpty {
                emptyStateView
            } else {
                productListView
            }
        }
    }
    
    /// 加载视图
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("正在加载商品...")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("首次加载可能需要几秒钟")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: searchText.isEmpty ? "cart.badge.questionmark" : "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(searchText.isEmpty ? "暂无可购买商品" : "未找到匹配的商品")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if searchText.isEmpty {
                Button("重新加载") {
                    Task {
                        await loadProducts()
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /// 商品列表视图
    private var productListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(filteredProducts) { product in
                    ProductCardView(
                        product: product,
                        purchaseState: iapManager.purchaseState(for: product.id),
                        onPurchase: {
                            Task {
                                await purchaseProduct(product)
                            }
                        }
                    )
                }
            }
            .padding()
        }
    }
    
    /// 恢复按钮
    private var restoreButton: some View {
        Button(action: {
            showingRestoreConfirmation = true
        }) {
            Image(systemName: "arrow.clockwise")
        }
        .disabled(iapManager.isRestoringPurchases)
    }
    
    // MARK: - Computed Properties
    
    /// 过滤后的商品列表
    private var filteredProducts: [IAPProduct] {
        if searchText.isEmpty {
            return iapManager.products
        } else {
            return iapManager.products.filter { product in
                product.displayName.localizedCaseInsensitiveContains(searchText) ||
                product.description.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    /// 忙碌状态文本
    private var busyStatusText: String {
        if iapManager.isLoadingProducts {
            return "加载中"
        } else if iapManager.isRestoringPurchases {
            return "恢复中"
        } else if iapManager.isRecoveryInProgress {
            return "恢复交易"
        } else if !iapManager.purchasingProducts.isEmpty {
            return "购买中"
        }
        return ""
    }
    
    // MARK: - Methods
    
    /// 初始化商店
    private func initializeStore() async {
        do {
            // 初始化框架
            await iapManager.initialize()
            
            // 加载商品
            await loadProducts()
        } catch {
            print("初始化商店失败: \(error)")
        }
    }
    
    /// 加载商品
    private func loadProducts() async {
        do {
            _ = try await iapManager.loadProducts(productIDs: productIDs)
        } catch {
            showingErrorAlert = true
        }
    }
    
    /// 购买商品
    private func purchaseProduct(_ product: IAPProduct) async {
        do {
            let result = try await iapManager.purchase(product)
            
            switch result {
            case .success(let transaction):
                successMessage = "成功购买 \(product.displayName)"
                showingSuccessAlert = true
                
                // 自动完成交易（如果配置允许）
                try await iapManager.finishTransaction(transaction)
                
            case .pending:
                successMessage = "购买请求已提交，等待处理"
                showingSuccessAlert = true
                
            case .cancelled, .userCancelled:
                // 用户取消，不显示消息
                break
            }
        } catch {
            showingErrorAlert = true
        }
    }
    
    /// 恢复购买
    private func restorePurchases() async {
        do {
            let transactions = try await iapManager.restorePurchases()
            
            if transactions.isEmpty {
                successMessage = "没有找到可恢复的购买"
            } else {
                successMessage = "成功恢复 \(transactions.count) 个购买项目"
            }
            showingSuccessAlert = true
        } catch {
            showingErrorAlert = true
        }
    }
}

// MARK: - Product Card View

/// 商品卡片视图
private struct ProductCardView: View {
    let product: IAPProduct
    let purchaseState: IAPPurchaseState
    let onPurchase: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 商品信息头部
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    // 商品名称
                    Text(product.displayName)
                        .font(.headline)
                        .lineLimit(2)
                    
                    // 商品类型标签
                    productTypeBadge
                }
                
                Spacer()
                
                // 价格信息
                VStack(alignment: .trailing, spacing: 4) {
                    Text(product.localizedPrice)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    if let subscriptionInfo = product.subscriptionInfo {
                        Text("每\(subscriptionPeriodText(subscriptionInfo.subscriptionPeriod))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // 商品描述
            Text(product.description)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(3)
            
            // 底部操作区域
            HStack {
                // 购买状态指示器
                purchaseStatusView
                
                Spacer()
                
                // 购买按钮
                purchaseButton
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
    
    /// 商品类型徽章
    private var productTypeBadge: some View {
        Text(productTypeText)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(productTypeColor.opacity(0.2))
            .foregroundColor(productTypeColor)
            .cornerRadius(8)
    }
    
    /// 购买按钮
    private var purchaseButton: some View {
        Button(action: onPurchase) {
            HStack(spacing: 8) {
                if case .purchasing = purchaseState {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: purchaseButtonIcon)
                }
                
                Text(purchaseButtonText)
                    .fontWeight(.medium)
            }
            .frame(minWidth: 100)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isPurchaseDisabled)
        .controlSize(.regular)
    }
    
    /// 购买状态视图
    private var purchaseStatusView: some View {
        Group {
            switch purchaseState {
            case .idle:
                EmptyView()
                
            case .purchasing:
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("购买中...")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
            case .purchased:
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("已购买")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                
            case .failed(let error):
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                    Text("购买失败")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
            case .cancelled:
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.orange)
                    Text("已取消")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
            case .deferred:
                HStack(spacing: 6) {
                    Image(systemName: "clock.circle.fill")
                        .foregroundColor(.blue)
                    Text("等待批准")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// 商品类型文本
    private var productTypeText: String {
        switch product.productType {
        case .consumable:
            return "消耗型"
        case .nonConsumable:
            return "非消耗型"
        case .autoRenewableSubscription:
            return "订阅"
        case .nonRenewingSubscription:
            return "限时订阅"
        }
    }
    
    /// 商品类型颜色
    private var productTypeColor: Color {
        switch product.productType {
        case .consumable:
            return .blue
        case .nonConsumable:
            return .green
        case .autoRenewableSubscription:
            return .purple
        case .nonRenewingSubscription:
            return .orange
        }
    }
    
    /// 购买按钮文本
    private var purchaseButtonText: String {
        switch purchaseState {
        case .purchasing:
            return "购买中..."
        case .purchased:
            return "已拥有"
        case .failed:
            return "重试"
        default:
            return "购买"
        }
    }
    
    /// 购买按钮图标
    private var purchaseButtonIcon: String {
        switch purchaseState {
        case .purchased:
            return "checkmark"
        case .failed:
            return "arrow.clockwise"
        default:
            return "cart"
        }
    }
    
    /// 是否禁用购买按钮
    private var isPurchaseDisabled: Bool {
        switch purchaseState {
        case .purchasing, .purchased, .deferred:
            return true
        default:
            return false
        }
    }
    
    /// 订阅周期文本
    private func subscriptionPeriodText(_ period: IAPSubscriptionPeriod) -> String {
        switch period.unit {
        case .day:
            return  "天"
        case .week:
            return "周"
        case .month:
            return "月"
        case .year:
            return "年"
        @unknown default:
            return "周期"
        }
    }
}

#if DEBUG
struct SwiftUIExampleStoreView_Previews: PreviewProvider {
    static var previews: some View {
        SwiftUIExampleStoreView()
            .environmentObject(SwiftUIIAPManager())
    }
}
#endif
