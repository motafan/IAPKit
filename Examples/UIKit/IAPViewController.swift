import UIKit
import IAPFramework

/// 内购界面控制器
/// 展示商品列表并处理购买流程
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
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private lazy var loadingLabel: UILabel = {
        let label = UILabel()
        label.text = "加载商品中..."
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = UIColor.label
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
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Properties
    
    /// 购买管理器
    private let purchaseManager = PurchaseManager()
    
    /// 要加载的商品ID列表
    public var productIDs: Set<String> = []
    
    /// 购买成功回调
    public var onPurchaseSuccess: ((IAPTransaction) -> Void)?
    
    /// 购买失败回调
    public var onPurchaseFailure: ((IAPError) -> Void)?
    
    // MARK: - Lifecycle
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupPurchaseManager()
        
        // 如果有商品ID，自动加载
        if !productIDs.isEmpty {
            loadProducts()
        }
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // 刷新购买状态
        tableView.reloadData()
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
        
        // 设置约束
        setupConstraints()
        
        // 添加下拉刷新
        tableView.refreshControl = refreshControl
        
        // 初始状态
        showEmptyState(false)
        showLoadingState(false)
    }
    
    private func setupNavigationBar() {
        // 恢复购买按钮
        let restoreButton = UIBarButtonItem(
            title: "恢复购买",
            style: .plain,
            target: self,
            action: #selector(restoreButtonTapped)
        )
        navigationItem.rightBarButtonItem = restoreButton
        
        // 关闭按钮（如果是模态展示）
        if presentingViewController != nil {
            let closeButton = UIBarButtonItem(
                barButtonSystemItem: .close,
                target: self,
                action: #selector(closeButtonTapped)
            )
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
            loadingView.topAnchor.constraint(equalTo: view.topAnchor),
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