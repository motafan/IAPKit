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
        
        for product in products {
            let productID = product.id
            
            if iapManager.isPurchasing(productID) {
                newStates[productID] = .purchasing
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
    
    /// 购买商品
    private func purchaseProduct(_ product: IAPProduct) {
        iapManager.purchase(product) { [weak self] result in
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
        case .success(let transaction):
            showSuccess("成功购买 \(product.displayName)")
            
            // 自动完成交易
            iapManager.finishTransaction(transaction) { _ in }
            
        case .pending:
            showSuccess("购买请求已提交，等待处理")
            
        case .cancelled, .userCancelled:
            // 用户取消，不显示消息
            break
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
            
            cell.configure(with: product, state: state) { [weak self] in
                self?.purchaseProduct(product)
            }
            
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
}

// MARK: - Purchase State

/// 购买状态枚举
private enum PurchaseState {
    case idle
    case purchasing
    case purchased
    case failed
    case deferred
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
    
    // MARK: - Properties
    
    private var purchaseAction: (() -> Void)?
    
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
            statusIndicator.centerYAnchor.constraint(equalTo: purchaseButton.centerYAnchor)
        ])
        
        // 添加按钮动作
        purchaseButton.addTarget(self, action: #selector(purchaseButtonTapped), for: .touchUpInside)
    }
    
    // MARK: - Configuration
    
    func configure(with product: IAPProduct, state: PurchaseState, purchaseAction: @escaping () -> Void) {
        self.purchaseAction = purchaseAction
        
        nameLabel.text = product.displayName
        descriptionLabel.text = product.description
        priceLabel.text = product.localizedPrice
        
        // 配置类型标签
        typeLabel.text = productTypeText(product.productType)
        typeLabel.backgroundColor = productTypeColor(product.productType)
        typeLabel.textColor = .white
        
        updateButtonState(state)
    }
    
    private func updateButtonState(_ state: PurchaseState) {
        switch state {
        case .idle:
            purchaseButton.setTitle("购买", for: .normal)
            purchaseButton.backgroundColor = .systemBlue
            purchaseButton.setTitleColor(.white, for: .normal)
            purchaseButton.isEnabled = true
            statusIndicator.stopAnimating()
            
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