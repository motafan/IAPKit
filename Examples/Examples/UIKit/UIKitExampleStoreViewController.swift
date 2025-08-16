//
//  UIKitExampleStoreViewController.swift
//  Examples
//
//  UIKit 商店视图控制器示例
//  展示如何在 UIKit 中创建完整的商店界面
//

import UIKit
import IAPFramework

/// UIKit 商店视图控制器示例
class UIKitExampleStoreViewController: UIViewController {
    
    // MARK: - UI Components
    
    /// 表格视图
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(ProductTableViewCell.self, forCellReuseIdentifier: ProductTableViewCell.identifier)
        tableView.register(StatusTableViewCell.self, forCellReuseIdentifier: StatusTableViewCell.identifier)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "BasicCell")
        return tableView
    }()
    
    /// 加载指示器
    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    /// 状态标签
    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()
    
    /// 刷新控件
    private lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        return refreshControl
    }()
    
    // MARK: - Properties
    
    /// IAP 管理器
    private let iapManager = UIKitIAPManager()
    
    /// 商品ID列表（示例）
    private let productIDs: Set<String> = [
        "com.example.premium",
        "com.example.coins_100",
        "com.example.coins_500",
        "com.example.monthly_subscription",
        "com.example.yearly_subscription"
    ]
    
    /// 商品列表
    private var products: [IAPProduct] = [] {
        didSet {
            DispatchQueue.main.async {
                self.tableView.reloadData()
                self.updateUI()
            }
        }
    }
    
    /// 购买状态映射
    private var purchaseStates: [String: PurchaseState] = [:] {
        didSet {
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
    
    /// 订单状态映射
    private var orderStates: [String: IAPOrder] = [:] {
        didSet {
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
    
    /// 是否正在加载
    private var isLoading = false {
        didSet {
            DispatchQueue.main.async {
                self.updateLoadingState()
            }
        }
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupIAPManager()
        initializeStore()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // 如果是被销毁，清理资源
        if isBeingDismissed || isMovingFromParent {
            iapManager.cleanup()
        }
    }
    
    // MARK: - Setup
    
    /// 设置UI
    private func setupUI() {
        title = "UIKit 商店示例"
        view.backgroundColor = .systemBackground
        
        // 添加导航栏按钮
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "doc.text"),
            style: .plain,
            target: self,
            action: #selector(ordersButtonTapped)
        )
        
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(
                title: "恢复",
                style: .plain,
                target: self,
                action: #selector(restoreButtonTapped)
            ),
            UIBarButtonItem(
                image: UIImage(systemName: "gear"),
                style: .plain,
                target: self,
                action: #selector(settingsButtonTapped)
            )
        ]
        
        // 添加子视图
        view.addSubview(tableView)
        view.addSubview(loadingIndicator)
        view.addSubview(statusLabel)
        
        // 添加刷新控件
        tableView.refreshControl = refreshControl
        
        // 设置约束
        NSLayoutConstraint.activate([
            // 表格视图
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // 加载指示器
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            // 状态标签
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 50),
            statusLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
        ])
    }
    
    /// 设置内购管理器
    private func setupIAPManager() {
        iapManager.delegate = self
    }
    
    /// 初始化商店
    private func initializeStore() {
        isLoading = true
        statusLabel.text = "正在初始化..."
        
        iapManager.initialize { [weak self] in
            self?.loadProducts()
        }
    }
    
    /// 加载商品
    private func loadProducts() {
        isLoading = true
        statusLabel.text = "正在加载商品..."
        
        iapManager.loadProducts(productIDs: productIDs) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                self?.refreshControl.endRefreshing()
                
                switch result {
                case .success(let products):
                    self?.products = products
                    self?.updatePurchaseStates()
                    
                case .failure(let error):
                    self?.showError(error)
                }
            }
        }
    }
    
    /// 更新购买状态
    private func updatePurchaseStates() {
        var newStates: [String: PurchaseState] = [:]
        var newOrderStates: [String: IAPOrder] = [:]
        
        for product in products {
            let productID = product.id
            
            // 更新订单状态
            if let activeOrder = iapManager.getActiveOrder(for: productID) {
                newOrderStates[productID] = activeOrder
            } else if let recentOrder = iapManager.getRecentOrder(for: productID) {
                newOrderStates[productID] = recentOrder
            }
            
            // 更新购买状态
            if iapManager.isPurchasing(productID) {
                newStates[productID] = .purchasing
            } else if iapManager.isCreatingOrder(productID) {
                newStates[productID] = .creatingOrder
            } else if let transaction = iapManager.getRecentTransaction(for: productID) {
                switch transaction.transactionState {
                case .purchased, .restored:
                    newStates[productID] = .purchased
                case .failed:
                    newStates[productID] = .failed
                case .deferred:
                    newStates[productID] = .deferred
                case .purchasing:
                    newStates[productID] = .purchasing
                }
            } else {
                newStates[productID] = .idle
            }
        }
        
        purchaseStates = newStates
        orderStates = newOrderStates
    }
    
    /// 更新加载状态
    private func updateLoadingState() {
        if isLoading {
            loadingIndicator.startAnimating()
            statusLabel.isHidden = false
            tableView.isHidden = true
        } else {
            loadingIndicator.stopAnimating()
            updateUI()
        }
    }
    
    /// 更新UI
    private func updateUI() {
        if products.isEmpty {
            statusLabel.text = "暂无可购买商品\n下拉刷新或点击恢复按钮重新加载"
            statusLabel.isHidden = false
            tableView.isHidden = true
        } else {
            statusLabel.isHidden = true
            tableView.isHidden = false
        }
        
        // 更新导航栏按钮状态
        navigationItem.rightBarButtonItems?.first?.isEnabled = !iapManager.isRestoringPurchases
    }
    
    // MARK: - Actions
    
    /// 刷新数据
    @objc private func refreshData() {
        loadProducts()
    }
    
    /// 恢复按钮点击
    @objc private func restoreButtonTapped() {
        let alert = UIAlertController(
            title: "恢复购买",
            message: "这将恢复您之前购买的所有项目",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "恢复", style: .default) { [weak self] _ in
            self?.restorePurchases()
        })
        
        present(alert, animated: true)
    }
    
    /// 订单按钮点击
    @objc private func ordersButtonTapped() {
        let ordersVC = OrderListViewController(iapManager: iapManager)
        let navController = UINavigationController(rootViewController: ordersVC)
        present(navController, animated: true)
    }
    
    /// 设置按钮点击
    @objc private func settingsButtonTapped() {
        let settingsVC = UIKitExampleSettingsViewController()
        let navController = UINavigationController(rootViewController: settingsVC)
        present(navController, animated: true)
    }
    
    /// 恢复购买
    private func restorePurchases() {
        navigationItem.rightBarButtonItems?.first?.isEnabled = false
        
        iapManager.restorePurchases { [weak self] result in
            DispatchQueue.main.async {
                self?.navigationItem.rightBarButtonItems?.first?.isEnabled = true
                
                switch result {
                case .success(let transactions):
                    let message = transactions.isEmpty ? "没有找到可恢复的购买" : "成功恢复 \(transactions.count) 个购买项目"
                    self?.showSuccess(message)
                    self?.updatePurchaseStates()
                    
                case .failure(let error):
                    self?.showError(error)
                }
            }
        }
    }
    
    /// 购买商品（显示用户信息输入）
    private func purchaseProduct(_ product: IAPProduct) {
        let alert = UIAlertController(
            title: "购买 \(product.displayName)",
            message: "请选择购买方式",
            preferredStyle: .actionSheet
        )
        
        alert.addAction(UIAlertAction(title: "快速购买", style: .default) { [weak self] _ in
            self?.purchaseProductDirectly(product, userInfo: nil)
        })
        
        alert.addAction(UIAlertAction(title: "输入用户信息购买", style: .default) { [weak self] _ in
            self?.showUserInfoInput(for: product)
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        // 为iPad设置popover
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(alert, animated: true)
    }
    
    /// 显示用户信息输入
    private func showUserInfoInput(for product: IAPProduct) {
        let alert = UIAlertController(
            title: "用户信息",
            message: "请输入用户信息（可选）",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "用户ID"
            textField.keyboardType = .default
        }
        
        alert.addTextField { textField in
            textField.placeholder = "活动代码"
            textField.keyboardType = .default
        }
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "购买", style: .default) { [weak self] _ in
            var userInfo: [String: Any] = [:]
            
            if let userID = alert.textFields?[0].text, !userID.isEmpty {
                userInfo["userID"] = userID
            }
            
            if let campaign = alert.textFields?[1].text, !campaign.isEmpty {
                userInfo["campaign"] = campaign
            }
            
            self?.purchaseProductDirectly(product, userInfo: userInfo.isEmpty ? nil : userInfo)
        })
        
        present(alert, animated: true)
    }
    
    /// 直接购买商品
    private func purchaseProductDirectly(_ product: IAPProduct, userInfo: [String: Any]?) {
        iapManager.purchase(product, userInfo: userInfo) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let purchaseResult):
                    self?.handlePurchaseResult(purchaseResult, for: product)
                    
                case .failure(let error):
                    self?.showError(error)
                }
                
                self?.updatePurchaseStates()
            }
        }
    }
    
    /// 处理购买结果
    private func handlePurchaseResult(_ result: IAPPurchaseResult, for product: IAPProduct) {
        switch result {
        case .success(let transaction, let order):
            showSuccess("成功购买 \(product.displayName)\n订单ID: \(order.id)")
            
            // 自动完成交易
            iapManager.finishTransaction(transaction) { _ in }
            
        case .pending(let transaction, let order):
            showSuccess("购买请求已提交，等待处理\n订单ID: \(order.id)")
            
        case .cancelled(let order):
            if let order = order {
                showSuccess("购买已取消\n订单ID: \(order.id)")
            }
            
        case .failed(let error, let order):
            var message = "购买失败: \(error.localizedDescription)"
            if let order = order {
                message += "\n订单ID: \(order.id)"
            }
            showError(IAPError.unknownError(message))
        }
    }
    
    // MARK: - Helper Methods
    
    /// 显示错误
    private func showError(_ error: IAPError) {
        let alert = UIAlertController(
            title: "错误",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    /// 显示成功消息
    private func showSuccess(_ message: String) {
        let alert = UIAlertController(
            title: "成功",
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension UIKitExampleStoreViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2 // 商品列表 + 状态信息
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: // 商品列表
            return products.count
        case 1: // 状态信息
            return 1
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0: // 商品列表
            let cell = tableView.dequeueReusableCell(withIdentifier: ProductTableViewCell.identifier, for: indexPath) as! ProductTableViewCell
            let product = products[indexPath.row]
            let state = purchaseStates[product.id] ?? .idle
            let order = orderStates[product.id]
            
            cell.configure(
                with: product,
                state: state,
                order: order,
                purchaseAction: { [weak self] in
                    self?.purchaseProduct(product)
                },
                orderDetailsAction: { [weak self] order in
                    self?.showOrderDetails(order)
                }
            )
            
            return cell
            
        case 1: // 状态信息
            let cell = tableView.dequeueReusableCell(withIdentifier: StatusTableViewCell.identifier, for: indexPath) as! StatusTableViewCell
            cell.configure(with: iapManager)
            return cell
            
        default:
            return UITableViewCell()
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "可购买商品"
        case 1:
            return "系统状态"
        default:
            return nil
        }
    }
}

// MARK: - UITableViewDelegate

extension UIKitExampleStoreViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 0: // 商品列表
            return 100
        case 1: // 状态信息
            return 120
        default:
            return 44
        }
    }
}

// MARK: - UIKitIAPManager.Delegate

@MainActor
extension UIKitExampleStoreViewController: UIKitIAPManager.Delegate {
    
    func iapManager(_ manager: UIKitIAPManager, didLoadProducts products: [IAPProduct]) {
        // 通过属性设置器自动处理UI更新
        self.products = products
    }
    
    func iapManager(_ manager: UIKitIAPManager, didFailToLoadProducts error: IAPError) {
        DispatchQueue.main.async {
            self.isLoading = false
            self.showError(error)
        }
    }
    
    func iapManager(_ manager: UIKitIAPManager, didCompletePurchase result: IAPPurchaseResult) {
        // 通过购买方法的回调处理
    }
    
    func iapManager(_ manager: UIKitIAPManager, didFailPurchase error: IAPError) {
        // 通过购买方法的回调处理
    }
    
    func iapManager(_ manager: UIKitIAPManager, didRestorePurchases transactions: [IAPTransaction]) {
        // 通过恢复方法的回调处理
    }
    
    func iapManager(_ manager: UIKitIAPManager, didFailToRestorePurchases error: IAPError) {
        // 通过恢复方法的回调处理
    }
    
    func iapManager(_ manager: UIKitIAPManager, didUpdateTransaction transaction: IAPTransaction) {
        DispatchQueue.main.async {
            self.updatePurchaseStates()
        }
    }
    
    func iapManager(_ manager: UIKitIAPManager, didUpdateLoadingState isLoading: Bool) {
        DispatchQueue.main.async {
            self.isLoading = isLoading
        }
    }
    
    func iapManager(_ manager: UIKitIAPManager, didUpdatePurchasingProducts productIDs: Set<String>) {
        DispatchQueue.main.async {
            self.updatePurchaseStates()
        }
    }
    
    func iapManager(_ manager: UIKitIAPManager, didUpdateCreatingOrders productIDs: Set<String>) {
        DispatchQueue.main.async {
            self.updatePurchaseStates()
        }
    }
    
    func iapManager(_ manager: UIKitIAPManager, didCreateOrder order: IAPOrder) {
        DispatchQueue.main.async {
            self.updatePurchaseStates()
        }
    }
    
    func iapManager(_ manager: UIKitIAPManager, didFailToCreateOrder error: IAPError, for productID: String) {
        DispatchQueue.main.async {
            self.showError(error)
            self.updatePurchaseStates()
        }
    }
    
    func iapManager(_ manager: UIKitIAPManager, didUpdateOrder order: IAPOrder) {
        DispatchQueue.main.async {
            self.updatePurchaseStates()
        }
    }
}

// MARK: - Purchase State

/// 购买状态枚举
private enum PurchaseState {
    case idle
    case creatingOrder
    case purchasing
    case purchased
    case failed
    case deferred
}

// MARK: - Helper Methods Extension

extension UIKitExampleStoreViewController {
    
    /// 显示订单详情
    private func showOrderDetails(_ order: IAPOrder) {
        let orderDetailsVC = OrderDetailsViewController(order: order, iapManager: iapManager)
        let navController = UINavigationController(rootViewController: orderDetailsVC)
        present(navController, animated: true)
    }
}

// MARK: - Custom Table View Cells

/// 商品表格视图单元格
private class ProductTableViewCell: UITableViewCell {
    
    static let identifier = "ProductTableViewCell"
    
    // MARK: - UI Components
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let priceLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let typeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        label.textAlignment = .center
        label.layer.cornerRadius = 8
        label.layer.masksToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let purchaseButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        button.layer.cornerRadius = 8
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let statusIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    /// 订单信息容器
    private let orderInfoContainer: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemGray6
        view.layer.cornerRadius = 8
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    /// 订单状态标签
    private let orderStatusLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    /// 订单ID标签
    private let orderIDLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 10)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    /// 订单详情按钮
    private let orderDetailsButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("详情", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        button.layer.cornerRadius = 6
        button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        button.contentEdgeInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - Properties
    
    private var purchaseAction: (() -> Void)?
    private var orderDetailsAction: ((IAPOrder) -> Void)?
    private var currentOrder: IAPOrder?
    
    // MARK: - Initialization
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear
        
        // 添加子视图
        contentView.addSubview(containerView)
        containerView.addSubview(nameLabel)
        containerView.addSubview(descriptionLabel)
        containerView.addSubview(priceLabel)
        containerView.addSubview(typeLabel)
        containerView.addSubview(purchaseButton)
        containerView.addSubview(statusIndicator)
        containerView.addSubview(orderInfoContainer)
        orderInfoContainer.addSubview(orderStatusLabel)
        orderInfoContainer.addSubview(orderIDLabel)
        orderInfoContainer.addSubview(orderDetailsButton)
        
        // 设置约束
        NSLayoutConstraint.activate([
            // 容器视图
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            // 商品名称
            nameLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(equalTo: priceLabel.leadingAnchor, constant: -8),
            
            // 商品描述
            descriptionLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            descriptionLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            
            // 类型标签
            typeLabel.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 8),
            typeLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            typeLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -12),
            typeLabel.widthAnchor.constraint(equalToConstant: 60),
            typeLabel.heightAnchor.constraint(equalToConstant: 20),
            
            // 价格标签
            priceLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            priceLabel.trailingAnchor.constraint(equalTo: purchaseButton.leadingAnchor, constant: -12),
            priceLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
            
            // 购买按钮
            purchaseButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            purchaseButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            purchaseButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
            
            // 状态指示器
            statusIndicator.centerXAnchor.constraint(equalTo: purchaseButton.centerXAnchor),
            statusIndicator.centerYAnchor.constraint(equalTo: purchaseButton.centerYAnchor),
            
            // 订单信息容器
            orderInfoContainer.topAnchor.constraint(equalTo: typeLabel.bottomAnchor, constant: 8),
            orderInfoContainer.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            orderInfoContainer.trailingAnchor.constraint(equalTo: purchaseButton.leadingAnchor, constant: -12),
            orderInfoContainer.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -12),
            orderInfoContainer.heightAnchor.constraint(equalToConstant: 40),
            
            // 订单状态标签
            orderStatusLabel.topAnchor.constraint(equalTo: orderInfoContainer.topAnchor, constant: 6),
            orderStatusLabel.leadingAnchor.constraint(equalTo: orderInfoContainer.leadingAnchor, constant: 8),
            
            // 订单ID标签
            orderIDLabel.topAnchor.constraint(equalTo: orderStatusLabel.bottomAnchor, constant: 2),
            orderIDLabel.leadingAnchor.constraint(equalTo: orderInfoContainer.leadingAnchor, constant: 8),
            orderIDLabel.bottomAnchor.constraint(equalTo: orderInfoContainer.bottomAnchor, constant: -6),
            
            // 订单详情按钮
            orderDetailsButton.centerYAnchor.constraint(equalTo: orderInfoContainer.centerYAnchor),
            orderDetailsButton.trailingAnchor.constraint(equalTo: orderInfoContainer.trailingAnchor, constant: -8),
            orderDetailsButton.leadingAnchor.constraint(greaterThanOrEqualTo: orderStatusLabel.trailingAnchor, constant: 8)
        ])
        
        // 添加按钮动作
        purchaseButton.addTarget(self, action: #selector(purchaseButtonTapped), for: .touchUpInside)
        orderDetailsButton.addTarget(self, action: #selector(orderDetailsButtonTapped), for: .touchUpInside)
    }
    
    // MARK: - Configuration
    
    func configure(
        with product: IAPProduct,
        state: PurchaseState,
        order: IAPOrder?,
        purchaseAction: @escaping () -> Void,
        orderDetailsAction: @escaping (IAPOrder) -> Void
    ) {
        self.purchaseAction = purchaseAction
        self.orderDetailsAction = orderDetailsAction
        self.currentOrder = order
        
        nameLabel.text = product.displayName
        descriptionLabel.text = product.description
        priceLabel.text = product.localizedPrice
        
        // 配置类型标签
        typeLabel.text = productTypeText(product.productType)
        typeLabel.backgroundColor = productTypeColor(product.productType)
        typeLabel.textColor = .white
        
        updateButtonState(state)
        updateOrderInfo(order)
    }
    
    private func updateButtonState(_ state: PurchaseState) {
        switch state {
        case .idle:
            purchaseButton.setTitle("购买", for: .normal)
            purchaseButton.backgroundColor = .systemBlue
            purchaseButton.setTitleColor(.white, for: .normal)
            purchaseButton.isEnabled = true
            statusIndicator.stopAnimating()
            
        case .creatingOrder:
            purchaseButton.setTitle("创建订单中", for: .normal)
            purchaseButton.backgroundColor = .systemGray4
            purchaseButton.setTitleColor(.label, for: .normal)
            purchaseButton.isEnabled = false
            statusIndicator.startAnimating()
            
        case .purchasing:
            purchaseButton.setTitle("", for: .normal)
            purchaseButton.backgroundColor = .systemGray4
            purchaseButton.isEnabled = false
            statusIndicator.startAnimating()
            
        case .purchased:
            purchaseButton.setTitle("已拥有", for: .normal)
            purchaseButton.backgroundColor = .systemGreen
            purchaseButton.setTitleColor(.white, for: .normal)
            purchaseButton.isEnabled = false
            statusIndicator.stopAnimating()
            
        case .failed:
            purchaseButton.setTitle("重试", for: .normal)
            purchaseButton.backgroundColor = .systemRed
            purchaseButton.setTitleColor(.white, for: .normal)
            purchaseButton.isEnabled = true
            statusIndicator.stopAnimating()
            
        case .deferred:
            purchaseButton.setTitle("等待批准", for: .normal)
            purchaseButton.backgroundColor = .systemOrange
            purchaseButton.setTitleColor(.white, for: .normal)
            purchaseButton.isEnabled = false
            statusIndicator.stopAnimating()
        }
    }
    
    private func updateOrderInfo(_ order: IAPOrder?) {
        if let order = order {
            orderInfoContainer.isHidden = false
            orderStatusLabel.text = order.status.localizedDescription
            orderStatusLabel.textColor = orderStatusColor(order.status)
            orderIDLabel.text = "ID: \(String(order.id.prefix(8)))"
            
            // 更新类型标签的底部约束，为订单信息让出空间
            typeLabel.bottomAnchor.constraint(lessThanOrEqualTo: orderInfoContainer.topAnchor, constant: -8).isActive = true
        } else {
            orderInfoContainer.isHidden = true
            
            // 恢复类型标签的原始底部约束
            typeLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -12).isActive = true
        }
    }
    
    private func orderStatusColor(_ status: IAPOrderStatus) -> UIColor {
        switch status {
        case .created:
            return .systemBlue
        case .pending:
            return .systemOrange
        case .completed:
            return .systemGreen
        case .cancelled:
            return .systemGray
        case .failed:
            return .systemRed
        }
    }
    
    private func productTypeText(_ type: IAPProductType) -> String {
        switch type {
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
    
    private func productTypeColor(_ type: IAPProductType) -> UIColor {
        switch type {
        case .consumable:
            return .systemBlue
        case .nonConsumable:
            return .systemGreen
        case .autoRenewableSubscription:
            return .systemPurple
        case .nonRenewingSubscription:
            return .systemOrange
        }
    }
    
    // MARK: - Actions
    
    @objc private func purchaseButtonTapped() {
        purchaseAction?()
    }
    
    @objc private func orderDetailsButtonTapped() {
        if let order = currentOrder {
            orderDetailsAction?(order)
        }
    }
}

/// 状态表格视图单元格
private class StatusTableViewCell: UITableViewCell {
    
    static let identifier = "StatusTableViewCell"
    
    // MARK: - UI Components
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    // MARK: - Initialization
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear
        
        contentView.addSubview(containerView)
        containerView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16)
        ])
    }
    
    // MARK: - Configuration
    
    func configure(with manager: UIKitIAPManager) {
        // 清除之前的视图
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // 添加状态信息
        addStatusRow(label: "交易监听", value: manager.isTransactionObserverActive ? "已启用" : "未启用", color: manager.isTransactionObserverActive ? .systemGreen : .systemRed)
        
        addStatusRow(label: "商品数量", value: "\(manager.products.count)", color: .label)
        
        addStatusRow(label: "最近交易", value: "\(manager.recentTransactions.count)", color: .label)
        
        addStatusRow(label: "框架状态", value: manager.isBusy ? "忙碌" : "空闲", color: manager.isBusy ? .systemOrange : .systemGreen)
    }
    
    private func addStatusRow(label: String, value: String, color: UIColor) {
        let rowView = UIView()
        
        let labelLabel = UILabel()
        labelLabel.text = label + ":"
        labelLabel.font = UIFont.systemFont(ofSize: 14)
        labelLabel.textColor = .secondaryLabel
        labelLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        valueLabel.textColor = color
        valueLabel.textAlignment = .right
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        
        rowView.addSubview(labelLabel)
        rowView.addSubview(valueLabel)
        
        NSLayoutConstraint.activate([
            labelLabel.leadingAnchor.constraint(equalTo: rowView.leadingAnchor),
            labelLabel.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
            
            valueLabel.trailingAnchor.constraint(equalTo: rowView.trailingAnchor),
            valueLabel.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: labelLabel.trailingAnchor, constant: 8),
            
            rowView.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        stackView.addArrangedSubview(rowView)
    }
}

// MARK: - Order List View Controller

/// 订单列表视图控制器
class OrderListViewController: UIViewController {
    
    // MARK: - UI Components
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(OrderTableViewCell.self, forCellReuseIdentifier: OrderTableViewCell.identifier)
        return tableView
    }()
    
    private lazy var emptyStateLabel: UILabel = {
        let label = UILabel()
        label.text = "暂无订单"
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Properties
    
    private let iapManager: UIKitIAPManager
    private var orders: [IAPOrder] = []
    
    // MARK: - Initialization
    
    init(iapManager: UIKitIAPManager) {
        self.iapManager = iapManager
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadOrders()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        title = "订单列表"
        view.backgroundColor = .systemBackground
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "完成",
            style: .done,
            target: self,
            action: #selector(doneButtonTapped)
        )
        
        view.addSubview(tableView)
        view.addSubview(emptyStateLabel)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func loadOrders() {
        orders = iapManager.recentOrders
        updateUI()
    }
    
    private func updateUI() {
        if orders.isEmpty {
            emptyStateLabel.isHidden = false
            tableView.isHidden = true
        } else {
            emptyStateLabel.isHidden = true
            tableView.isHidden = false
            tableView.reloadData()
        }
    }
    
    // MARK: - Actions
    
    @objc private func doneButtonTapped() {
        dismiss(animated: true)
    }
}

// MARK: - OrderListViewController Extensions

extension OrderListViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return orders.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: OrderTableViewCell.identifier, for: indexPath) as! OrderTableViewCell
        let order = orders[indexPath.row]
        cell.configure(with: order)
        return cell
    }
}

extension OrderListViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let order = orders[indexPath.row]
        let orderDetailsVC = OrderDetailsViewController(order: order, iapManager: iapManager)
        navigationController?.pushViewController(orderDetailsVC, animated: true)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
}

// MARK: - Order Details View Controller

/// 订单详情视图控制器
class OrderDetailsViewController: UIViewController {
    
    // MARK: - UI Components
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "DetailCell")
        return tableView
    }()
    
    // MARK: - Properties
    
    private let order: IAPOrder
    private let iapManager: UIKitIAPManager
    private var currentStatus: IAPOrderStatus
    private var isRefreshing = false
    
    // MARK: - Initialization
    
    init(order: IAPOrder, iapManager: UIKitIAPManager) {
        self.order = order
        self.iapManager = iapManager
        self.currentStatus = order.status
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        title = "订单详情"
        view.backgroundColor = .systemBackground
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "刷新",
            style: .plain,
            target: self,
            action: #selector(refreshButtonTapped)
        )
        
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func refreshButtonTapped() {
        guard !isRefreshing else { return }
        
        isRefreshing = true
        navigationItem.rightBarButtonItem?.isEnabled = false
        
        iapManager.queryOrderStatus(order.id) { [weak self] result in
            DispatchQueue.main.async {
                self?.isRefreshing = false
                self?.navigationItem.rightBarButtonItem?.isEnabled = true
                
                switch result {
                case .success(let status):
                    self?.currentStatus = status
                    self?.tableView.reloadData()
                    
                case .failure(let error):
                    let alert = UIAlertController(
                        title: "刷新失败",
                        message: error.localizedDescription,
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "确定", style: .default))
                    self?.present(alert, animated: true)
                }
            }
        }
    }
}

// MARK: - OrderDetailsViewController Extensions

extension OrderDetailsViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return order.userInfo?.isEmpty == false ? 4 : 3
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 3 // 基本信息
        case 1: return order.expiresAt != nil ? 4 : 2 // 状态信息
        case 2: return order.userInfo?.count ?? 0 // 用户信息
        case 3: return order.amount != nil ? 1 : 0 // 支付信息
        default: return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DetailCell", for: indexPath)
        cell.selectionStyle = .none
        
        switch indexPath.section {
        case 0: // 基本信息
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "订单ID"
                cell.detailTextLabel?.text = order.id
            case 1:
                cell.textLabel?.text = "商品ID"
                cell.detailTextLabel?.text = order.productID
            case 2:
                cell.textLabel?.text = "服务器订单ID"
                cell.detailTextLabel?.text = order.serverOrderID ?? "无"
            default:
                break
            }
            
        case 1: // 状态信息
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "状态"
                cell.detailTextLabel?.text = currentStatus.localizedDescription
                cell.detailTextLabel?.textColor = orderStatusColor(currentStatus)
            case 1:
                cell.textLabel?.text = "创建时间"
                cell.detailTextLabel?.text = formatDate(order.createdAt)
            case 2:
                if let expiresAt = order.expiresAt {
                    cell.textLabel?.text = "过期时间"
                    cell.detailTextLabel?.text = formatDate(expiresAt)
                }
            case 3:
                cell.textLabel?.text = "是否过期"
                cell.detailTextLabel?.text = order.isExpired ? "是" : "否"
                cell.detailTextLabel?.textColor = order.isExpired ? .systemRed : .systemGreen
            default:
                break
            }
            
        case 2: // 用户信息
            if let userInfo = order.userInfo {
                let keys = Array(userInfo.keys.sorted())
                let key = keys[indexPath.row]
                cell.textLabel?.text = key
                cell.detailTextLabel?.text = userInfo[key]
            }
            
        case 3: // 支付信息
            if let amount = order.amount, let currency = order.currency {
                cell.textLabel?.text = "金额"
                cell.detailTextLabel?.text = "\(amount) \(currency)"
            }
            
        default:
            break
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "基本信息"
        case 1: return "状态信息"
        case 2: return order.userInfo?.isEmpty == false ? "用户信息" : nil
        case 3: return order.amount != nil ? "支付信息" : nil
        default: return nil
        }
    }
    
    private func orderStatusColor(_ status: IAPOrderStatus) -> UIColor {
        switch status {
        case .created: return .systemBlue
        case .pending: return .systemOrange
        case .completed: return .systemGreen
        case .cancelled: return .systemGray
        case .failed: return .systemRed
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

extension OrderDetailsViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44
    }
}

// MARK: - Order Table View Cell

/// 订单表格视图单元格
class OrderTableViewCell: UITableViewCell {
    
    static let identifier = "OrderTableViewCell"
    
    // MARK: - UI Components
    
    private let statusIndicator: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 6
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let orderIDLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let productIDLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let timeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Initialization
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        accessoryType = .disclosureIndicator
        
        contentView.addSubview(statusIndicator)
        contentView.addSubview(orderIDLabel)
        contentView.addSubview(productIDLabel)
        contentView.addSubview(statusLabel)
        contentView.addSubview(timeLabel)
        
        NSLayoutConstraint.activate([
            statusIndicator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            statusIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            statusIndicator.widthAnchor.constraint(equalToConstant: 12),
            statusIndicator.heightAnchor.constraint(equalToConstant: 12),
            
            orderIDLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            orderIDLabel.leadingAnchor.constraint(equalTo: statusIndicator.trailingAnchor, constant: 12),
            orderIDLabel.trailingAnchor.constraint(equalTo: timeLabel.leadingAnchor, constant: -8),
            
            productIDLabel.topAnchor.constraint(equalTo: orderIDLabel.bottomAnchor, constant: 4),
            productIDLabel.leadingAnchor.constraint(equalTo: orderIDLabel.leadingAnchor),
            productIDLabel.trailingAnchor.constraint(equalTo: statusLabel.leadingAnchor, constant: -8),
            
            statusLabel.centerYAnchor.constraint(equalTo: productIDLabel.centerYAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: timeLabel.leadingAnchor, constant: -8),
            
            timeLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            timeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),
            timeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 80)
        ])
    }
    
    // MARK: - Configuration
    
    func configure(with order: IAPOrder) {
        orderIDLabel.text = "订单: \(String(order.id.prefix(8)))"
        productIDLabel.text = order.productID
        statusLabel.text = order.status.localizedDescription
        statusLabel.textColor = orderStatusColor(order.status)
        statusIndicator.backgroundColor = orderStatusColor(order.status)
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        timeLabel.text = formatter.localizedString(for: order.createdAt, relativeTo: Date())
    }
    
    private func orderStatusColor(_ status: IAPOrderStatus) -> UIColor {
        switch status {
        case .created: return .systemBlue
        case .pending: return .systemOrange
        case .completed: return .systemGreen
        case .cancelled: return .systemGray
        case .failed: return .systemRed
        }
    }
}