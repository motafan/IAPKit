import UIKit
import IAPFramework

/// 完整的 UIKit 内购使用示例
/// 展示如何在实际应用中集成和使用 IAPFramework
@MainActor
public final class IAPUsageExample: UIViewController {
    
    // MARK: - Properties
    
    /// 购买管理器
    private let purchaseManager = PurchaseManager()
    
    /// 示例商品ID
    private let sampleProductIDs: Set<String> = [
        "com.example.premium_features",
        "com.example.remove_ads",
        "com.example.monthly_subscription",
        "com.example.yearly_subscription",
        "com.example.consumable_coins"
    ]
    
    // MARK: - UI Components
    
    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()
    
    private lazy var contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "IAPFramework UIKit 示例"
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var descriptionLabel: UILabel = {
        let label = UILabel()
        label.text = "这个示例展示了如何在 UIKit 应用中使用 IAPFramework 进行内购开发"
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.textColor = UIColor.secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    // MARK: - Lifecycle
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupPurchaseManager()
        initializeIAPFramework()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        title = "IAP 示例"
        view.backgroundColor = UIColor.systemBackground
        
        // 添加子视图
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(descriptionLabel)
        contentView.addSubview(stackView)
        
        // 设置约束
        setupConstraints()
        
        // 创建示例按钮
        createExampleButtons()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // 滚动视图
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // 内容视图
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // 标题
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // 描述
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            descriptionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            descriptionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // 按钮堆栈
            stackView.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 32),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    private func createExampleButtons() {
        // 1. 显示内购界面
        let showIAPButton = createButton(
            title: "显示内购界面",
            subtitle: "展示完整的商品列表和购买界面",
            action: #selector(showIAPViewController)
        )
        
        // 2. 加载商品信息
        let loadProductsButton = createButton(
            title: "加载商品信息",
            subtitle: "演示如何加载和显示商品信息",
            action: #selector(loadProducts)
        )
        
        // 3. 单个商品购买
        let singlePurchaseButton = createButton(
            title: "单个商品购买",
            subtitle: "演示如何购买单个商品",
            action: #selector(purchaseSingleProduct)
        )
        
        // 4. 恢复购买
        let restoreButton = createButton(
            title: "恢复购买",
            subtitle: "恢复用户之前的购买记录",
            action: #selector(restorePurchases)
        )
        
        // 5. 检查购买状态
        let checkStatusButton = createButton(
            title: "检查购买状态",
            subtitle: "检查特定商品的购买状态",
            action: #selector(checkPurchaseStatus)
        )
        
        // 6. 显示调试信息
        let debugInfoButton = createButton(
            title: "显示调试信息",
            subtitle: "查看框架的内部状态和统计信息",
            action: #selector(showDebugInfo)
        )
        
        // 添加到堆栈视图
        [showIAPButton, loadProductsButton, singlePurchaseButton, 
         restoreButton, checkStatusButton, debugInfoButton].forEach {
            stackView.addArrangedSubview($0)
        }
    }
    
    private func createButton(title: String, subtitle: String, action: Selector) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = UIColor.secondarySystemBackground
        containerView.layer.cornerRadius = 12
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        let button = UIButton(type: .system)
        button.addTarget(self, action: action, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = UIColor.label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = UIColor.secondaryLabel
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let chevronImageView = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevronImageView.tintColor = UIColor.tertiaryLabel
        chevronImageView.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(button)
        containerView.addSubview(titleLabel)
        containerView.addSubview(subtitleLabel)
        containerView.addSubview(chevronImageView)
        
        NSLayoutConstraint.activate([
            containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 80),
            
            button.topAnchor.constraint(equalTo: containerView.topAnchor),
            button.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            button.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: chevronImageView.leadingAnchor, constant: -16),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -16),
            
            chevronImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            chevronImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            chevronImageView.widthAnchor.constraint(equalToConstant: 12),
            chevronImageView.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        return containerView
    }
    
    private func setupPurchaseManager() {
        // 设置购买成功回调
        purchaseManager.onPurchaseSuccess = { [weak self] transaction in
            self?.handlePurchaseSuccess(transaction)
        }
        
        // 设置购买失败回调
        purchaseManager.onPurchaseFailure = { [weak self] error in
            self?.handlePurchaseFailure(error)
        }
        
        // 设置商品加载完成回调
        purchaseManager.onProductsLoaded = { [weak self] products in
            self?.handleProductsLoaded(products)
        }
    }
    
    private func initializeIAPFramework() {
        Task {
            do {
                // 初始化 IAPManager
                await IAPManager.shared.initialize()
                print("✅ IAPFramework 初始化成功")
            } catch {
                print("❌ IAPFramework 初始化失败: \(error)")
                showError("框架初始化失败: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Actions
    
    @objc private func showIAPViewController() {
        presentIAPViewController(productIDs: sampleProductIDs)
    }
    
    @objc private func loadProducts() {
        let loadingIndicator = IAPUIHelper.showLoadingIndicator(message: "加载商品中...", in: self)
        
        purchaseManager.loadProducts(sampleProductIDs)
        
        // 设置超时处理
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            IAPUIHelper.hideLoadingIndicator(loadingIndicator)
        }
    }
    
    @objc private func purchaseSingleProduct() {
        // 显示商品选择对话框
        let alert = UIAlertController(title: "选择商品", message: "请选择要购买的商品", preferredStyle: .actionSheet)
        
        let productOptions = [
            ("高级功能", "com.example.premium_features"),
            ("移除广告", "com.example.remove_ads"),
            ("月度订阅", "com.example.monthly_subscription"),
            ("年度订阅", "com.example.yearly_subscription"),
            ("金币包", "com.example.consumable_coins")
        ]
        
        for (name, productID) in productOptions {
            alert.addAction(UIAlertAction(title: name, style: .default) { [weak self] _ in
                self?.purchaseProduct(productID: productID)
            })
        }
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        // iPad 支持
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }
        
        present(alert, animated: true)
    }
    
    @objc private func restorePurchases() {
        showRestorePurchasesDialog { [weak self] in
            self?.performRestorePurchases()
        }
    }
    
    @objc private func checkPurchaseStatus() {
        Task {
            let stats = IAPManager.shared.getPurchaseStats()
            let message = """
            购买统计信息：
            • 总购买次数: \(stats.totalPurchases)
            • 成功购买: \(stats.successfulPurchases)
            • 失败购买: \(stats.failedPurchases)
            • 取消购买: \(stats.cancelledPurchases)
            """
            
            showInfo("购买状态", message: message)
        }
    }
    
    @objc private func showDebugInfo() {
        let debugInfo = IAPManager.shared.getDebugInfo()
        
        var message = "框架调试信息：\n\n"
        
        for (key, value) in debugInfo {
            if let dict = value as? [String: Any] {
                message += "\(key):\n"
                for (subKey, subValue) in dict {
                    message += "  • \(subKey): \(subValue)\n"
                }
            } else {
                message += "• \(key): \(value)\n"
            }
        }
        
        showInfo("调试信息", message: message)
    }
    
    // MARK: - Purchase Handling
    
    private func purchaseProduct(productID: String) {
        Task {
            do {
                // 先加载商品信息
                let products = try await IAPManager.shared.loadProducts(productIDs: [productID])
                
                guard let product = products.first else {
                    showError("商品不存在")
                    return
                }
                
                // 显示购买确认对话框
                showPurchaseDialog(for: product) { [weak self] product in
                    self?.purchaseManager.purchase(product)
                }
                
            } catch {
                showError("加载商品失败: \(error.localizedDescription)")
            }
        }
    }
    
    private func performRestorePurchases() {
        let loadingIndicator = IAPUIHelper.showLoadingIndicator(message: "恢复购买中...", in: self)
        
        purchaseManager.restorePurchases()
        
        // 设置超时处理
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            IAPUIHelper.hideLoadingIndicator(loadingIndicator)
        }
    }
    
    private func handlePurchaseSuccess(_ transaction: IAPTransaction) {
        // 显示成功动画
        view.animatePurchaseSuccess()
        
        // 显示成功提示
        IAPUIHelper.showSuccess(transaction: transaction, in: self)
        
        // 发送通知
        NotificationCenter.default.post(
            name: .iapPurchaseSuccess,
            object: transaction
        )
        
        print("✅ 购买成功: \(transaction.productID)")
    }
    
    private func handlePurchaseFailure(_ error: IAPError) {
        // 显示失败动画
        view.animatePurchaseFailure()
        
        // 显示错误提示
        IAPUIHelper.showError(error, in: self) { [weak self] in
            // 重试逻辑
            self?.showError("购买失败，是否重试？")
        }
        
        // 发送通知
        NotificationCenter.default.post(
            name: .iapPurchaseFailure,
            object: error
        )
        
        print("❌ 购买失败: \(error.localizedDescription)")
    }
    
    private func handleProductsLoaded(_ products: [IAPProduct]) {
        let message = """
        成功加载 \(products.count) 个商品：
        
        \(products.map { "• \($0.displayName) - \($0.formattedPrice)" }.joined(separator: "\n"))
        """
        
        showInfo("商品加载完成", message: message)
        
        // 发送通知
        NotificationCenter.default.post(
            name: .iapProductsLoaded,
            object: products
        )
        
        print("✅ 商品加载完成: \(products.count) 个商品")
    }
    
    // MARK: - Helper Methods
    
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "错误", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    private func showInfo(_ title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - App Integration Example

/// 应用集成示例
/// 展示如何在 AppDelegate 或 SceneDelegate 中集成 IAPFramework
public class IAPAppIntegrationExample {
    
    /// 在应用启动时初始化 IAP
    public static func initializeIAP() {
        Task { @MainActor in
            do {
                await IAPManager.shared.initialize()
                print("✅ IAPFramework 初始化成功")
                
                // 可选：预加载常用商品
                let commonProductIDs: Set<String> = [
                    "com.example.premium_features",
                    "com.example.remove_ads"
                ]
                
                _ = try await IAPManager.shared.loadProducts(productIDs: commonProductIDs)
                print("✅ 常用商品预加载完成")
                
            } catch {
                print("❌ IAPFramework 初始化失败: \(error)")
            }
        }
    }
    
    /// 在应用即将终止时清理资源
    public static func cleanupIAP() {
        IAPManager.shared.cleanup()
        print("✅ IAPFramework 清理完成")
    }
    
    /// 处理应用从后台恢复时的逻辑
    public static func handleAppDidBecomeActive() {
        Task { @MainActor in
            // 检查是否有未完成的交易
            await IAPManager.shared.recoverTransactions { result in
                switch result {
                case .success(let count):
                    if count > 0 {
                        print("✅ 恢复了 \(count) 个未完成的交易")
                    }
                case .failure(let error):
                    print("❌ 交易恢复失败: \(error)")
                case .alreadyInProgress:
                    print("ℹ️ 交易恢复已在进行中")
                }
            }
        }
    }
}

// MARK: - Custom Purchase Flow Example

/// 自定义购买流程示例
/// 展示如何创建自定义的购买流程
@MainActor
public class CustomPurchaseFlowExample: UIViewController {
    
    private let purchaseManager = PurchaseManager()
    
    /// 创建自定义的购买流程
    /// - Parameter productID: 商品ID
    public func startCustomPurchaseFlow(for productID: String) {
        Task {
            do {
                // 1. 加载商品信息
                let products = try await IAPManager.shared.loadProducts(productIDs: [productID])
                guard let product = products.first else {
                    throw IAPError.productNotFound
                }
                
                // 2. 验证是否可以购买
                let validationResult = IAPManager.shared.validateCanPurchase(product)
                guard case .valid = validationResult else {
                    if case .invalid(let reason) = validationResult {
                        showError(reason)
                    }
                    return
                }
                
                // 3. 显示购买前的确认界面
                await showPurchaseConfirmation(for: product)
                
            } catch {
                showError("购买流程启动失败: \(error.localizedDescription)")
            }
        }
    }
    
    private func showPurchaseConfirmation(for product: IAPProduct) async {
        return await withCheckedContinuation { continuation in
            let alert = UIAlertController(
                title: "确认购买",
                message: "您即将购买 \(product.displayName)\n价格：\(product.formattedPrice)\n\n\(product.description)",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in
                continuation.resume()
            })
            
            alert.addAction(UIAlertAction(title: "购买", style: .default) { [weak self] _ in
                self?.executePurchase(product)
                continuation.resume()
            })
            
            present(alert, animated: true)
        }
    }
    
    private func executePurchase(_ product: IAPProduct) {
        // 显示购买进度
        let progressHUD = IAPUIHelper.showLoadingIndicator(message: "购买中...", in: self)
        
        // 执行购买
        purchaseManager.purchase(product)
        
        // 设置购买回调
        purchaseManager.onPurchaseSuccess = { [weak self] transaction in
            IAPUIHelper.hideLoadingIndicator(progressHUD)
            self?.handlePurchaseSuccess(transaction, product: product)
        }
        
        purchaseManager.onPurchaseFailure = { [weak self] error in
            IAPUIHelper.hideLoadingIndicator(progressHUD)
            self?.handlePurchaseFailure(error, product: product)
        }
    }
    
    private func handlePurchaseSuccess(_ transaction: IAPTransaction, product: IAPProduct) {
        // 保存购买状态到本地
        UserDefaults.standard.setPurchased(true, for: product.id)
        
        // 显示成功界面
        showPurchaseSuccessScreen(transaction: transaction, product: product)
    }
    
    private func handlePurchaseFailure(_ error: IAPError, product: IAPProduct) {
        // 显示失败界面
        showPurchaseFailureScreen(error: error, product: product)
    }
    
    private func showPurchaseSuccessScreen(transaction: IAPTransaction, product: IAPProduct) {
        let alert = UIAlertController(
            title: "🎉 购买成功！",
            message: "感谢您购买 \(product.displayName)！\n\n您现在可以享受所有高级功能了。",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "开始使用", style: .default) { [weak self] _ in
            self?.navigateToFeatures()
        })
        
        present(alert, animated: true)
    }
    
    private func showPurchaseFailureScreen(error: IAPError, product: IAPProduct) {
        let alert = UIAlertController(
            title: "购买失败",
            message: error.userFriendlyDescription,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "重试", style: .default) { [weak self] _ in
            self?.executePurchase(product)
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func navigateToFeatures() {
        // 导航到功能界面的逻辑
        print("导航到高级功能界面")
    }
    
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "错误", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}