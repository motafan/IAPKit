import UIKit
import IAPFramework

/// 主要的内购界面控制器
/// 展示商品列表并处理购买流程，确保所有 UI 更新在主线程执行
@MainActor
public final class IAPViewController: UIViewController {
    
    // MARK: - UI Components
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(ProductTableViewCell.self, forCellReuseIdentifier: ProductTableViewCell.reuseIdentifier)
        tableView.separatorStyle = .singleLine
        tableView.backgroundColor = UIColor.systemBackground
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()
    
    private lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshProducts), for: .valueChanged)
        return refreshControl
    }()
    
    private lazy var loadingView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.8)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private lazy var loadingLabel: UILabel = {
        let label = UILabel()
        label.text = "加载商品中..."
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = UIColor.secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var emptyStateView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemBackground
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var emptyStateLabel: UILabel = {
        let label = UILabel()
        label.text = "暂无可购买的商品"
        label.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        label.textColor = UIColor.secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var retryButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("重新加载", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        button.backgroundColor = UIColor.systemBlue
        button.setTitleColor(UIColor.white, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(retryLoadProducts), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Properties
    
    /// 购买管理器
    private let purchaseManager = PurchaseManager()
    
    /// 要加载的商品ID列表
    public var productIDs: Set<String> = []
    
    /// 商品列表
    private var products: [IAPProduct] = [] {
        didSet {
            updateUI()
        }
    }
    
    /// 是否正在加载
    private var isLoading = false {
        didSet {
            updateLoadingState()
        }
    }
    
    /// 购买成功回调
    public var onPurchaseSuccess: ((IAPTransaction) -> Void)?
    
    /// 购买失败回调
    public var onPurchaseFailure: ((IAPError) -> Void)?
    
    /// 商品加载完成回调
    public var onProductsLoaded: (([IAPProduct]) -> Void)?
    
    // MARK: - Lifecycle
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupPurchaseManager()
        
        // 如果有预设的商品ID，自动加载
        if !productIDs.isEmpty {
            loadProducts()
        }
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // 刷新购买状态
        refreshPurchaseStates()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        title = "内购商品"
        view.backgroundColor = UIColor.systemBackground
        
        // 设置导航栏
        setupNavigationBar()
        
        // 添加子视图
        view.addSubview(tableView)
        view.addSubview(loadingView)
        view.addSubview(emptyStateView)
        
        loadingView.addSubview(loadingIndicator)
        loadingView.addSubview(loadingLabel)
        
        emptyStateView.addSubview(emptyStateLabel)
        emptyStateView.addSubview(retryButton)
        
        // 设置约束
        setupConstraints()
        
        // 设置下拉刷新
        tableView.refreshControl = refreshControl
        
        // 初始状态
        loadingView.isHidden = true
        emptyStateView.isHidden = true
    }
    
    private func setupNavigationBar() {
        // 恢复购买按钮
        let restoreButton = UIBarButtonItem(
            title: "恢复购买",
            style: .plain,
            target: self,
            action: #selector(restorePurchases)
        )
        
        // 关闭按钮（如果是模态展示）
        let closeButton = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeViewController)
        )
        
        navigationItem.rightBarButtonItem = restoreButton
        
        // 如果是模态展示，添加关闭按钮
        if presentingViewController != nil {
            navigationItem.leftBarButtonItem = closeButton
        }
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // 表格视图
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // 加载视图
            loadingView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            loadingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // 加载指示器
            loadingIndicator.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: loadingView.centerYAnchor, constant: -20),
            
            // 加载标签
            loadingLabel.topAnchor.constraint(equalTo: loadingIndicator.bottomAnchor, constant: 16),
            loadingLabel.leadingAnchor.constraint(equalTo: loadingView.leadingAnchor, constant: 20),
            loadingLabel.trailingAnchor.constraint(equalTo: loadingView.trailingAnchor, constant: -20),
            
            // 空状态视图
            emptyStateView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // 空状态标签
            emptyStateLabel.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: emptyStateView.centerYAnchor, constant: -30),
            emptyStateLabel.leadingAnchor.constraint(equalTo: emptyStateView.leadingAnchor, constant: 40),
            emptyStateLabel.trailingAnchor.constraint(equalTo: emptyStateView.trailingAnchor, constant: -40),
            
            // 重试按钮
            retryButton.topAnchor.constraint(equalTo: emptyStateLabel.bottomAnchor, constant: 20),
            retryButton.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            retryButton.widthAnchor.constraint(equalToConstant: 120),
            retryButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    private func setupPurchaseManager() {
        // 设置回调
        purchaseManager.onPurchaseSuccess = { [weak self] transaction in
            self?.handlePurchaseSuccess(transaction)
        }
        
        purchaseManager.onPurchaseFailure = { [weak self] error in
            self?.handlePurchaseFailure(error)
        }
        
        purchaseManager.onProductsLoaded = { [weak self] products in
            self?.handleProductsLoaded(products)
        }
    }
    
    // MARK: - Public Methods
    
    /// 设置要加载的商品ID
    /// - Parameter productIDs: 商品ID集合
    public func setProductIDs(_ productIDs: Set<String>) {
        self.productIDs = productIDs
        
        if isViewLoaded {
            loadProducts()
        }
    }
    
    /// 加载商品
    public func loadProducts() {
        guard !productIDs.isEmpty else {
            showEmptyState(message: "请先设置商品ID")
            return
        }
        
        guard !isLoading else {
            return
        }
        
        isLoading = true
        purchaseManager.loadProducts(productIDs)
    }
    
    /// 刷新商品
    public func refreshProducts() {
        loadProducts()
    }
    
    // MARK: - Actions
    
    @objc private func refreshProducts() {
        refreshProducts()
    }
    
    @objc private func retryLoadProducts() {
        loadProducts()
    }
    
    @objc private func restorePurchases() {
        // 显示确认对话框
        let alert = UIAlertController(
            title: "恢复购买",
            message: "这将恢复您之前购买的所有商品。是否继续？",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "恢复", style: .default) { [weak self] _ in
            self?.performRestorePurchases()
        })
        
        present(alert, animated: true)
    }
    
    @objc private func closeViewController() {
        dismiss(animated: true)
    }
    
    private func performRestorePurchases() {
        // 禁用恢复按钮
        navigationItem.rightBarButtonItem?.isEnabled = false
        
        purchaseManager.restorePurchases()
        
        // 显示加载提示
        let hud = showProgressHUD(message: "恢复购买中...")
        
        // 设置超时处理
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            hud.removeFromSuperview()
            self?.navigationItem.rightBarButtonItem?.isEnabled = true
        }
    }
    
    // MARK: - Purchase Handling
    
    private func handlePurchaseSuccess(_ transaction: IAPTransaction) {
        // 刷新表格
        refreshPurchaseStates()
        
        // 显示成功提示
        showSuccessAlert(for: transaction)
        
        // 调用外部回调
        onPurchaseSuccess?(transaction)
    }
    
    private func handlePurchaseFailure(_ error: IAPError) {
        // 刷新表格
        refreshPurchaseStates()
        
        // 显示错误提示
        purchaseManager.showErrorAlert(error, in: self)
        
        // 调用外部回调
        onPurchaseFailure?(error)
    }
    
    private func handleProductsLoaded(_ products: [IAPProduct]) {
        self.products = products
        isLoading = false
        
        // 停止下拉刷新
        refreshControl.endRefreshing()
        
        // 调用外部回调
        onProductsLoaded?(products)
    }
    
    private func refreshPurchaseStates() {
        // 刷新所有可见的单元格
        for indexPath in tableView.indexPathsForVisibleRows ?? [] {
            if let cell = tableView.cellForRow(at: indexPath) as? ProductTableViewCell {
                let product = products[indexPath.row]
                let isPurchasing = purchaseManager.isPurchasing(productID: product.id)
                cell.setPurchasingState(isPurchasing)
            }
        }
    }
    
    // MARK: - UI Updates
    
    private func updateUI() {
        DispatchQueue.main.async { [weak self] in
            self?.tableView.reloadData()
            self?.updateViewState()
        }
    }
    
    private func updateLoadingState() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if self.isLoading {
                self.showLoadingState()
            } else {
                self.hideLoadingState()
            }
        }
    }
    
    private func updateViewState() {
        if products.isEmpty && !isLoading {
            showEmptyState()
        } else {
            hideEmptyState()
        }
    }
    
    private func showLoadingState() {
        loadingView.isHidden = false
        loadingIndicator.startAnimating()
        emptyStateView.isHidden = true
        tableView.isHidden = true
    }
    
    private func hideLoadingState() {
        loadingView.isHidden = true
        loadingIndicator.stopAnimating()
        tableView.isHidden = false
    }
    
    private func showEmptyState(message: String = "暂无可购买的商品") {
        emptyStateLabel.text = message
        emptyStateView.isHidden = false
        tableView.isHidden = true
    }
    
    private func hideEmptyState() {
        emptyStateView.isHidden = true
        tableView.isHidden = false
    }
    
    // MARK: - Helper Methods
    
    private func showSuccessAlert(for transaction: IAPTransaction) {
        let product = products.first { $0.id == transaction.productID }
        let productName = product?.displayName ?? transaction.productID
        
        let alert = UIAlertController(
            title: "购买成功",
            message: "您已成功购买 \(productName)！",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        
        present(alert, animated: true)
    }
    
    private func showProgressHUD(message: String) -> UIView {
        let hudView = UIView()
        hudView.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        hudView.layer.cornerRadius = 10
        hudView.translatesAutoresizingMaskIntoConstraints = false
        
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.startAnimating()
        indicator.translatesAutoresizingMaskIntoConstraints = false
        
        let label = UILabel()
        label.text = message
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        
        hudView.addSubview(indicator)
        hudView.addSubview(label)
        
        view.addSubview(hudView)
        
        NSLayoutConstraint.activate([
            hudView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hudView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            hudView.widthAnchor.constraint(equalToConstant: 160),
            hudView.heightAnchor.constraint(equalToConstant: 120),
            
            indicator.centerXAnchor.constraint(equalTo: hudView.centerXAnchor),
            indicator.topAnchor.constraint(equalTo: hudView.topAnchor, constant: 20),
            
            label.topAnchor.constraint(equalTo: indicator.bottomAnchor, constant: 16),
            label.leadingAnchor.constraint(equalTo: hudView.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: hudView.trailingAnchor, constant: -10)
        ])
        
        return hudView
    }
}

// MARK: - UITableViewDataSource

extension IAPViewController: UITableViewDataSource {
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return products.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: ProductTableViewCell.reuseIdentifier,
            for: indexPath
        ) as! ProductTableViewCell
        
        let product = products[indexPath.row]
        let isPurchasing = purchaseManager.isPurchasing(productID: product.id)
        
        cell.configure(with: product, isPurchasing: isPurchasing)
        
        // 设置购买回调
        cell.onPurchaseButtonTapped = { [weak self] product in
            self?.purchaseProduct(product)
        }
        
        return cell
    }
}

// MARK: - UITableViewDelegate

extension IAPViewController: UITableViewDelegate {
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    public func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let product = products[indexPath.row]
        showProductDetail(product)
    }
    
    private func purchaseProduct(_ product: IAPProduct) {
        // 检查是否可以购买
        let validationResult = IAPManager.shared.validateCanPurchase(product)
        
        switch validationResult {
        case .valid:
            purchaseManager.purchase(product)
            
        case .invalid(let reason):
            showValidationError(reason)
        }
    }
    
    private func showProductDetail(_ product: IAPProduct) {
        let alert = UIAlertController(
            title: product.displayName,
            message: product.description,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "购买", style: .default) { [weak self] _ in
            self?.purchaseProduct(product)
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func showValidationError(_ reason: String) {
        let alert = UIAlertController(
            title: "无法购买",
            message: reason,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        
        present(alert, animated: true)
    }
}

// MARK: - Convenience Initializers

extension IAPViewController {
    
    /// 便利初始化方法
    /// - Parameter productIDs: 商品ID集合
    public convenience init(productIDs: Set<String>) {
        self.init()
        self.productIDs = productIDs
    }
    
    /// 便利初始化方法
    /// - Parameter productIDs: 商品ID数组
    public convenience init(productIDs: [String]) {
        self.init(productIDs: Set(productIDs))
    }
}nstant: -20),
            
            // 加载标签
            loadingLabel.topAnchor.constraint(equalTo: loadingIndicator.bottomAnchor, constant: 16),
            loadingLabel.leadingAnchor.constraint(equalTo: loadingView.leadingAnchor, constant: 20),
            loadingLabel.trailingAnchor.constraint(equalTo: loadingView.trailingAnchor, constant: -20),
            
            // 空状态视图
            emptyStateView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // 空状态标签
            emptyStateLabel.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: emptyStateView.centerYAnchor),
            emptyStateLabel.leadingAnchor.constraint(equalTo: emptyStateView.leadingAnchor, constant: 20),
            emptyStateLabel.trailingAnchor.constraint(equalTo: emptyStateView.trailingAnchor, constant: -20)
        ])
    }
    
    private func setupPurchaseManager() {
        // 设置回调
        purchaseManager.onProductsLoaded = { [weak self] products in
            DispatchQueue.main.async {
                self?.handleProductsLoaded(products)
            }
        }
        
        purchaseManager.onPurchaseSuccess = { [weak self] transaction in
            DispatchQueue.main.async {
                self?.handlePurchaseSuccess(transaction)
            }
        }
        
        purchaseManager.onPurchaseFailure = { [weak self] error in
            DispatchQueue.main.async {
                self?.handlePurchaseFailure(error)
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// 设置要加载的商品ID
    /// - Parameter productIDs: 商品ID集合
    public func setProductIDs(_ productIDs: Set<String>) {
        self.productIDs = productIDs
        
        if isViewLoaded {
            loadProducts()
        }
    }
    
    /// 加载商品
    public func loadProducts() {
        guard !productIDs.isEmpty else {
            showEmptyState(true)
            return
        }
        
        showLoadingState(true)
        purchaseManager.loadProducts(productIDs)
    }
    
    // MARK: - Actions
    
    @objc private func refreshProducts() {
        loadProducts()
    }
    
    @objc private func restoreButtonTapped() {
        let alert = UIAlertController(
            title: "恢复购买",
            message: "确定要恢复之前的购买吗？",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "恢复", style: .default) { [weak self] _ in
            self?.purchaseManager.restorePurchases()
        })
        
        present(alert, animated: true)
    }
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
    
    // MARK: - State Management
    
    private func showLoadingState(_ show: Bool) {
        loadingView.isHidden = !show
        
        if show {
            loadingIndicator.startAnimating()
            showEmptyState(false)
        } else {
            loadingIndicator.stopAnimating()
            refreshControl.endRefreshing()
        }
    }
    
    private func showEmptyState(_ show: Bool) {
        emptyStateView.isHidden = !show
        
        if show {
            showLoadingState(false)
        }
    }
    
    // MARK: - Event Handlers
    
    private func handleProductsLoaded(_ products: [IAPProduct]) {
        showLoadingState(false)
        
        if products.isEmpty {
            showEmptyState(true)
        } else {
            showEmptyState(false)
            tableView.reloadData()
        }
    }
    
    private func handlePurchaseSuccess(_ transaction: IAPTransaction) {
        // 刷新表格以更新购买状态
        tableView.reloadData()
        
        // 显示成功提示
        purchaseManager.showSuccessAlert(transaction, in: self)
        
        // 调用外部回调
        onPurchaseSuccess?(transaction)
    }
    
    private func handlePurchaseFailure(_ error: IAPError) {
        // 刷新表格以更新购买状态
        tableView.reloadData()
        
        // 显示错误提示
        purchaseManager.showErrorAlert(error, in: self)
        
        // 调用外部回调
        onPurchaseFailure?(error)
    }
    
    private func handlePurchaseButtonTapped(for product: IAPProduct) {
        // 确认购买
        let alert = UIAlertController(
            title: "确认购买",
            message: "确定要购买 \(product.displayName) (\(product.formattedPrice)) 吗？",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "购买", style: .default) { [weak self] _ in
            self?.purchaseManager.purchase(product)
        })
        
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension IAPViewController: UITableViewDataSource {
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return purchaseManager.products.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ProductTableViewCell.reuseIdentifier, for: indexPath) as! ProductTableViewCell
        
        let product = purchaseManager.products[indexPath.row]
        let isPurchasing = purchaseManager.isPurchasing(productID: product.id)
        
        cell.configure(with: product, isPurchasing: isPurchasing)
        cell.onPurchaseButtonTapped = { [weak self] product in
            self?.handlePurchaseButtonTapped(for: product)
        }
        
        return cell
    }
}

// MARK: - UITableViewDelegate

extension IAPViewController: UITableViewDelegate {
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    public func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let product = purchaseManager.products[indexPath.row]
        showProductDetail(product)
    }
    
    private func showProductDetail(_ product: IAPProduct) {
        let alert = UIAlertController(
            title: product.displayName,
            message: """
            价格: \(product.formattedPrice)
            类型: \(product.localizedProductType)
            
            \(product.description)
            """,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "购买", style: .default) { [weak self] _ in
            self?.purchaseManager.purchase(product)
        })
        
        present(alert, animated: true)
    }
}

// MARK: - 便利初始化方法

extension IAPViewController {
    
    /// 便利初始化方法
    /// - Parameter productIDs: 要展示的商品ID列表
    /// - Returns: 配置好的视图控制器
    public static func create(with productIDs: Set<String>) -> IAPViewController {
        let viewController = IAPViewController()
        viewController.productIDs = productIDs
        return viewController
    }
    
    /// 创建导航控制器包装的内购界面
    /// - Parameter productIDs: 要展示的商品ID列表
    /// - Returns: 导航控制器
    public static func createWithNavigation(with productIDs: Set<String>) -> UINavigationController {
        let viewController = create(with: productIDs)
        let navigationController = UINavigationController(rootViewController: viewController)
        return navigationController
    }
}