//
//  UIKitExampleSettingsViewController.swift
//  Examples
//
//  UIKit 设置页面示例
//  展示如何在 UIKit 中管理 IAP 设置和调试信息
//

import UIKit
import IAPFramework

/// UIKit 设置页面示例
class UIKitExampleSettingsViewController: UIViewController {
    
    // MARK: - UI Components
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.register(SwitchTableViewCell.self, forCellReuseIdentifier: SwitchTableViewCell.identifier)
        tableView.register(DetailTableViewCell.self, forCellReuseIdentifier: DetailTableViewCell.identifier)
        return tableView
    }()
    
    // MARK: - Properties
    
    /// IAP 管理器
    private let iapManager = UIKitIAPManager()
    
    /// 显示调试信息
    private var showDebugInfo = false {
        didSet {
            tableView.reloadData()
        }
    }
    
    /// 设置项目
    private lazy var settingSections: [SettingSection] = [
        SettingSection(title: "购买管理", items: [
            .action("恢复购买", "arrow.clockwise", .systemBlue),
            .action("清除缓存", "trash", .systemOrange),
            .action("重新加载商品", "arrow.triangle.2.circlepath", .systemGreen)
        ]),
        SettingSection(title: "调试选项", items: [
            .toggle("显示调试信息"),
            .action("导出日志", "square.and.arrow.up", .systemBlue),
            .action("重置框架", "arrow.counterclockwise", .systemRed)
        ]),
        SettingSection(title: "系统信息", items: [
            .info("iOS 版本", UIDevice.current.systemVersion),
            .info("设备型号", UIDevice.current.model),
            .info("StoreKit 版本", isStoreKit2Available ? "StoreKit 2" : "StoreKit 1"),
            .info("应用版本", appVersion),
            .info("构建版本", buildVersion)
        ])
    ]
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupIAPManager()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        title = "设置"
        view.backgroundColor = .systemBackground
        
        // 添加导航栏按钮
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(doneButtonTapped)
        )
        
        // 添加子视图
        view.addSubview(tableView)
        
        // 设置约束
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupIAPManager() {
        iapManager.delegate = self
        
        // 初始化管理器
        iapManager.initialize { [weak self] in
            DispatchQueue.main.async {
                self?.tableView.reloadData()
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
    
    // MARK: - Actions
    
    @objc private func doneButtonTapped() {
        dismiss(animated: true)
    }
    
    private func handleSettingAction(_ item: SettingItem) {
        switch item {
        case .action(let title, _, _):
            switch title {
            case "恢复购买":
                restorePurchases()
            case "清除缓存":
                clearCache()
            case "重新加载商品":
                reloadProducts()
            case "导出日志":
                exportLogs()
            case "重置框架":
                resetFramework()
            default:
                break
            }
        case .toggle(let title):
            if title == "显示调试信息" {
                showDebugInfo.toggle()
            }
        default:
            break
        }
    }
    
    // MARK: - IAP Actions
    
    private func restorePurchases() {
        let alert = UIAlertController(
            title: "恢复购买",
            message: "这将恢复您之前购买的所有项目",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "恢复", style: .default) { [weak self] _ in
            self?.performRestorePurchases()
        })
        
        present(alert, animated: true)
    }
    
    private func performRestorePurchases() {
        iapManager.restorePurchases { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let transactions):
                    let message = transactions.isEmpty ? "没有找到可恢复的购买" : "成功恢复 \(transactions.count) 个购买项目"
                    self?.showAlert(title: "恢复完成", message: message)
                    
                case .failure(let error):
                    self?.showAlert(title: "恢复失败", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func clearCache() {
        let alert = UIAlertController(
            title: "清除缓存",
            message: "这将清除所有缓存的商品信息和状态",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "清除", style: .destructive) { [weak self] _ in
            // 这里可以添加清除缓存的实际代码
            self?.showAlert(title: "完成", message: "缓存已清除")
        })
        
        present(alert, animated: true)
    }
    
    private func reloadProducts() {
        let productIDs: Set<String> = [
            "com.example.premium",
            "com.example.coins_100",
            "com.example.coins_500",
            "com.example.monthly_subscription",
            "com.example.yearly_subscription"
        ]
        
        iapManager.loadProducts(productIDs: productIDs) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let products):
                    self?.showAlert(title: "加载完成", message: "成功加载 \(products.count) 个商品")
                    
                case .failure(let error):
                    self?.showAlert(title: "加载失败", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func exportLogs() {
        // 这里可以添加导出日志的实际代码
        showAlert(title: "导出日志", message: "日志导出功能尚未实现")
    }
    
    private func resetFramework() {
        let alert = UIAlertController(
            title: "重置框架",
            message: "这将重置框架到初始状态，清除所有数据",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "重置", style: .destructive) { [weak self] _ in
            // 这里可以添加重置框架的实际代码
            self?.iapManager.cleanup()
            self?.iapManager.initialize { }
            self?.showAlert(title: "完成", message: "框架已重置")
        })
        
        present(alert, animated: true)
    }
    
    // MARK: - Helper Methods
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension UIKitExampleSettingsViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        var sections = settingSections.count
        
        // 如果显示调试信息，添加调试信息区域
        if showDebugInfo {
            sections += 1
        }
        
        return sections
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if showDebugInfo && section == settingSections.count {
            // 调试信息区域
            return 6 // 框架状态、交易监听、商品数量、交易数量、购买中商品、最后错误
        }
        
        return settingSections[section].items.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if showDebugInfo && indexPath.section == settingSections.count {
            // 调试信息区域
            let cell = tableView.dequeueReusableCell(withIdentifier: DetailTableViewCell.identifier, for: indexPath) as! DetailTableViewCell
            
            switch indexPath.row {
            case 0:
                cell.configure(title: "框架状态", detail: iapManager.isBusy ? "忙碌" : "空闲", color: iapManager.isBusy ? .systemOrange : .systemGreen)
            case 1:
                cell.configure(title: "交易监听", detail: iapManager.isTransactionObserverActive ? "已启用" : "未启用", color: iapManager.isTransactionObserverActive ? .systemGreen : .systemRed)
            case 2:
                cell.configure(title: "已加载商品", detail: "\(iapManager.products.count)", color: .label)
            case 3:
                cell.configure(title: "最近交易", detail: "\(iapManager.recentTransactions.count)", color: .label)
            case 4:
                cell.configure(title: "购买中商品", detail: iapManager.purchasingProducts.isEmpty ? "无" : "\(iapManager.purchasingProducts.count)", color: iapManager.purchasingProducts.isEmpty ? .secondaryLabel : .systemBlue)
            case 5:
                if let error = iapManager.lastError {
                    cell.configure(title: "最后错误", detail: error.localizedDescription, color: .systemRed)
                } else {
                    cell.configure(title: "最后错误", detail: "无", color: .systemGreen)
                }
            default:
                break
            }
            
            return cell
        }
        
        let item = settingSections[indexPath.section].items[indexPath.row]
        
        switch item {
        case .action(let title, let icon, let color):
            let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
            cell.textLabel?.text = title
            cell.imageView?.image = UIImage(systemName: icon)
            cell.imageView?.tintColor = color
            cell.accessoryType = .disclosureIndicator
            return cell
            
        case .toggle(let title):
            let cell = tableView.dequeueReusableCell(withIdentifier: SwitchTableViewCell.identifier, for: indexPath) as! SwitchTableViewCell
            cell.configure(title: title, isOn: showDebugInfo) { [weak self] isOn in
                self?.showDebugInfo = isOn
            }
            return cell
            
        case .info(let title, let value):
            let cell = tableView.dequeueReusableCell(withIdentifier: DetailTableViewCell.identifier, for: indexPath) as! DetailTableViewCell
            cell.configure(title: title, detail: value, color: .label)
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if showDebugInfo && section == settingSections.count {
            return "调试信息"
        }
        
        return settingSections[section].title
    }
}

// MARK: - UITableViewDelegate

extension UIKitExampleSettingsViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if showDebugInfo && indexPath.section == settingSections.count {
            // 调试信息区域，不处理点击
            return
        }
        
        let item = settingSections[indexPath.section].items[indexPath.row]
        handleSettingAction(item)
    }
}

// MARK: - UIKitIAPManager.Delegate

@MainActor
extension UIKitExampleSettingsViewController: UIKitIAPManager.Delegate {
    
    func iapManager(_ manager: UIKitIAPManager, didLoadProducts products: [IAPProduct]) {
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    func iapManager(_ manager: UIKitIAPManager, didFailToLoadProducts error: IAPError) {
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    func iapManager(_ manager: UIKitIAPManager, didCompletePurchase result: IAPPurchaseResult) {
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    func iapManager(_ manager: UIKitIAPManager, didFailPurchase error: IAPError) {
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    func iapManager(_ manager: UIKitIAPManager, didRestorePurchases transactions: [IAPTransaction]) {
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    func iapManager(_ manager: UIKitIAPManager, didFailToRestorePurchases error: IAPError) {
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    func iapManager(_ manager: UIKitIAPManager, didUpdateTransaction transaction: IAPTransaction) {
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    func iapManager(_ manager: UIKitIAPManager, didUpdateLoadingState isLoading: Bool) {
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    func iapManager(_ manager: UIKitIAPManager, didUpdatePurchasingProducts productIDs: Set<String>) {
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
}

// MARK: - Supporting Types

/// 设置区域
private struct SettingSection {
    let title: String
    let items: [SettingItem]
}

/// 设置项目
private enum SettingItem {
    case action(String, String, UIColor) // title, icon, color
    case toggle(String) // title
    case info(String, String) // title, value
}

// MARK: - Custom Table View Cells

/// 开关表格视图单元格
private class SwitchTableViewCell: UITableViewCell {
    
    static let identifier = "SwitchTableViewCell"
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let switchControl: UISwitch = {
        let switchControl = UISwitch()
        switchControl.translatesAutoresizingMaskIntoConstraints = false
        return switchControl
    }()
    
    private var switchAction: ((Bool) -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        selectionStyle = .none
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(switchControl)
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            switchControl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            switchControl.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            switchControl.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 8)
        ])
        
        switchControl.addTarget(self, action: #selector(switchValueChanged), for: .valueChanged)
    }
    
    func configure(title: String, isOn: Bool, action: @escaping (Bool) -> Void) {
        titleLabel.text = title
        switchControl.isOn = isOn
        switchAction = action
    }
    
    @objc private func switchValueChanged() {
        switchAction?(switchControl.isOn)
    }
}

/// 详情表格视图单元格
private class DetailTableViewCell: UITableViewCell {
    
    static let identifier = "DetailTableViewCell"
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let detailLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        selectionStyle = .none
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(detailLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            detailLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            detailLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            detailLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 8)
        ])
    }
    
    func configure(title: String, detail: String, color: UIColor) {
        titleLabel.text = title
        detailLabel.text = detail
        detailLabel.textColor = color
    }
}
