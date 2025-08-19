//
//  SwiftUIExampleStoreView.swift
//  Examples
//
//  SwiftUI 商店界面示例
//  展示如何在 SwiftUI 中创建完整的商店界面
//

import SwiftUI
import IAPKit

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
    
    /// 显示订单详情
    @State private var showingOrderDetails = false
    @State private var selectedOrder: IAPOrder?
    
    /// 显示用户信息输入
    @State private var showingUserInfoInput = false
    @State private var selectedProduct: IAPProduct?
    @State private var userID = ""
    @State private var campaignCode = ""
    
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
                ToolbarItem(placement: .navigationBarLeading) {
                    ordersButton
                }
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
            .sheet(isPresented: $showingOrderDetails) {
                if let order = selectedOrder {
                    OrderDetailsView(order: order, iapManager: iapManager)
                }
            }
            .sheet(isPresented: $showingUserInfoInput) {
                if let product = selectedProduct {
                    UserInfoInputView(
                        product: product,
                        userID: $userID,
                        campaignCode: $campaignCode,
                        onPurchase: { userInfo in
                            Task {
                                await purchaseProductWithUserInfo(product, userInfo: userInfo)
                            }
                        },
                        onCancel: {
                            selectedProduct = nil
                        }
                    )
                }
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
                        activeOrder: iapManager.getActiveOrder(for: product.id),
                        isCreatingOrder: iapManager.isCreatingOrder(product.id),
                        onPurchase: {
                            selectedProduct = product
                            showingUserInfoInput = true
                        },
                        onQuickPurchase: {
                            Task {
                                await purchaseProduct(product)
                            }
                        },
                        onOrderDetails: { order in
                            selectedOrder = order
                            showingOrderDetails = true
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
    
    /// 订单按钮
    private var ordersButton: some View {
        Button(action: {
            // 显示最近的订单
            if let recentOrder = iapManager.recentOrders.first {
                selectedOrder = recentOrder
                showingOrderDetails = true
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: "doc.text")
                if !iapManager.activeOrders.isEmpty {
                    Text("\(iapManager.activeOrders.count)")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
            }
        }
        .disabled(iapManager.recentOrders.isEmpty)
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
        } else if !iapManager.creatingOrders.isEmpty {
            return "创建订单"
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
    
    /// 购买商品（快速购买，不输入用户信息）
    private func purchaseProduct(_ product: IAPProduct) async {
        await purchaseProductWithUserInfo(product, userInfo: nil)
    }
    
    /// 购买商品（包含用户信息）
    private func purchaseProductWithUserInfo(_ product: IAPProduct, userInfo: [String: Any]?) async {
        do {
            let result = try await iapManager.purchase(product, userInfo: userInfo)
            
            switch result {
            case .success(let transaction, let order):
                successMessage = "成功购买 \(product.displayName)\n订单ID: \(order.id)"
                showingSuccessAlert = true
                
                // 自动完成交易（如果配置允许）
                try await iapManager.finishTransaction(transaction)
                
            case .pending(let transaction, let order):
                successMessage = "购买请求已提交，等待处理\n订单ID: \(order.id)"
                showingSuccessAlert = true
                
            case .cancelled(let order):
                if let order = order {
                    successMessage = "购买已取消\n订单ID: \(order.id)"
                    showingSuccessAlert = true
                }
                
            case .failed(let error, let order):
                if let order = order {
                    successMessage = "购买失败: \(error.localizedDescription)\n订单ID: \(order.id)"
                } else {
                    successMessage = "购买失败: \(error.localizedDescription)"
                }
                showingSuccessAlert = true
            }
        } catch {
            showingErrorAlert = true
        }
        
        // 清理选中的商品
        selectedProduct = nil
        userID = ""
        campaignCode = ""
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
    let activeOrder: IAPOrder?
    let isCreatingOrder: Bool
    let onPurchase: () -> Void
    let onQuickPurchase: () -> Void
    let onOrderDetails: (IAPOrder) -> Void
    
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
            
            // 订单信息（如果有活跃订单）
            if let order = activeOrder {
                orderInfoView(order)
            }
            
            // 底部操作区域
            HStack {
                // 购买状态指示器
                purchaseStatusView
                
                Spacer()
                
                // 购买按钮组
                purchaseButtonGroup
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
    
    /// 购买按钮组
    private var purchaseButtonGroup: some View {
        HStack(spacing: 8) {
            // 快速购买按钮
            Button(action: onQuickPurchase) {
                HStack(spacing: 6) {
                    if case .purchasing = purchaseState {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "cart")
                    }
                    Text("快速购买")
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
            .disabled(isPurchaseDisabled)
            .controlSize(.small)
            
            // 主购买按钮（带用户信息）
            Button(action: onPurchase) {
                HStack(spacing: 8) {
                    if isCreatingOrder {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: purchaseButtonIcon)
                    }
                    
                    Text(purchaseButtonText)
                        .fontWeight(.medium)
                }
                .frame(minWidth: 80)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isPurchaseDisabled || isCreatingOrder)
            .controlSize(.regular)
        }
    }
    
    /// 购买状态视图
    private var purchaseStatusView: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 购买状态
            switch purchaseState {
            case .idle:
                if isCreatingOrder {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("创建订单中...")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
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
    
    /// 订单信息视图
    private func orderInfoView(_ order: IAPOrder) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("订单信息")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        // 订单状态
                        HStack(spacing: 4) {
                            Circle()
                                .fill(orderStatusColor(order.status))
                                .frame(width: 8, height: 8)
                            Text(order.status.localizedDescription)
                                .font(.caption2)
                                .foregroundColor(orderStatusColor(order.status))
                        }
                        
                        // 订单ID（简短版本）
                        Text("ID: \(String(order.id.prefix(8)))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        // 创建时间
                        Text(orderTimeText(order.createdAt))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // 订单详情按钮
                Button("详情") {
                    onOrderDetails(order)
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
        }
    }
    
    /// 订单状态颜色
    private func orderStatusColor(_ status: IAPOrderStatus) -> Color {
        switch status {
        case .created:
            return .blue
        case .pending:
            return .orange
        case .completed:
            return .green
        case .cancelled:
            return .gray
        case .failed:
            return .red
        }
    }
    
    /// 订单时间文本
    private func orderTimeText(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
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
        case .failed(_):
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
        case .failed(_):
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

// MARK: - User Info Input View

/// 用户信息输入视图
private struct UserInfoInputView: View {
    let product: IAPProduct
    @Binding var userID: String
    @Binding var campaignCode: String
    let onPurchase: ([String: Any]) -> Void
    let onCancel: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Text(product.displayName)
                            .fontWeight(.medium)
                        Spacer()
                        Text(product.localizedPrice)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                    
                    Text(product.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("商品信息")
                }
                
                Section {
                    TextField("用户ID（可选）", text: $userID)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("活动代码（可选）", text: $campaignCode)
                        .textFieldStyle(.roundedBorder)
                } header: {
                    Text("用户信息")
                } footer: {
                    Text("这些信息将与您的订单关联，用于更好的服务和统计")
                }
                
                Section {
                    Button("确认购买") {
                        var userInfo: [String: Any] = [:]
                        if !userID.isEmpty {
                            userInfo["userID"] = userID
                        }
                        if !campaignCode.isEmpty {
                            userInfo["campaign"] = campaignCode
                        }
                        
                        onPurchase(userInfo)
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("购买确认")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        onCancel()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Order Details View

/// 订单详情视图
private struct OrderDetailsView: View {
    let order: IAPOrder
    let iapManager: SwiftUIIAPManager
    
    @Environment(\.dismiss) private var dismiss
    @State private var isRefreshing = false
    @State private var currentStatus: IAPOrderStatus
    
    init(order: IAPOrder, iapManager: SwiftUIIAPManager) {
        self.order = order
        self.iapManager = iapManager
        self._currentStatus = State(initialValue: order.status)
    }
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    DetailRow(title: "订单ID", value: order.id)
                    DetailRow(title: "商品ID", value: order.productID)
                    DetailRow(title: "服务器订单ID", value: order.serverOrderID ?? "无")
                } header: {
                    Text("基本信息")
                }
                
                Section {
                    HStack {
                        Text("状态")
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(statusColor(currentStatus))
                                .frame(width: 10, height: 10)
                            Text(currentStatus.localizedDescription)
                                .foregroundColor(statusColor(currentStatus))
                        }
                    }
                    
                    DetailRow(title: "创建时间", value: formatDate(order.createdAt))
                    
                    if let expiresAt = order.expiresAt {
                        DetailRow(title: "过期时间", value: formatDate(expiresAt))
                        
                        HStack {
                            Text("是否过期")
                            Spacer()
                            Text(order.isExpired ? "是" : "否")
                                .foregroundColor(order.isExpired ? .red : .green)
                        }
                    }
                } header: {
                    Text("状态信息")
                }
                
                if let userInfo = order.userInfo, !userInfo.isEmpty {
                    Section {
                        ForEach(Array(userInfo.keys.sorted()), id: \.self) { key in
                            DetailRow(title: key, value: userInfo[key] ?? "")
                        }
                    } header: {
                        Text("用户信息")
                    }
                }
                
                if let amount = order.amount, let currency = order.currency {
                    Section {
                        DetailRow(title: "金额", value: "\(amount) \(currency)")
                    } header: {
                        Text("支付信息")
                    }
                }
                
                Section {
                    Button("刷新状态") {
                        Task {
                            await refreshOrderStatus()
                        }
                    }
                    .disabled(isRefreshing)
                    
                    if isRefreshing {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("刷新中...")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("操作")
                }
            }
            .navigationTitle("订单详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func refreshOrderStatus() async {
        isRefreshing = true
        
        do {
            let newStatus = try await iapManager.queryOrderStatus(order.id)
            currentStatus = newStatus
        } catch {
            print("刷新订单状态失败: \(error)")
        }
        
        isRefreshing = false
    }
    
    private func statusColor(_ status: IAPOrderStatus) -> Color {
        switch status {
        case .created:
            return .blue
        case .pending:
            return .orange
        case .completed:
            return .green
        case .cancelled:
            return .gray
        case .failed:
            return .red
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// 详情行视图
private struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
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
