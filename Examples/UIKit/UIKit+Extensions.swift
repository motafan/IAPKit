import UIKit
import IAPFramework

// MARK: - UIViewController 扩展

extension UIViewController {
    
    /// 显示内购界面
    /// - Parameters:
    ///   - productIDs: 商品ID集合
    ///   - animated: 是否动画
    ///   - completion: 完成回调
    public func presentIAPViewController(
        with productIDs: Set<String>,
        animated: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        let iapViewController = IAPViewController.createWithNavigation(with: productIDs)
        present(iapViewController, animated: animated, completion: completion)
    }
    
    /// 推送内购界面到导航栈
    /// - Parameter productIDs: 商品ID集合
    public func pushIAPViewController(with productIDs: Set<String>) {
        let iapViewController = IAPViewController.create(with: productIDs)
        navigationController?.pushViewController(iapViewController, animated: true)
    }
    
    /// 显示简单的购买确认对话框
    /// - Parameters:
    ///   - product: 商品对象
    ///   - onConfirm: 确认购买回调
    ///   - onCancel: 取消购买回调
    public func showPurchaseConfirmation(
        for product: IAPProduct,
        onConfirm: @escaping () -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        let alert = UIAlertController(
            title: "确认购买",
            message: "确定要购买 \(product.displayName) (\(product.formattedPrice)) 吗？",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in
            onCancel?()
        })
        
        alert.addAction(UIAlertAction(title: "购买", style: .default) { _ in
            onConfirm()
        })
        
        present(alert, animated: true)
    }
    
    /// 显示购买成功提示
    /// - Parameters:
    ///   - transaction: 交易对象
    ///   - completion: 完成回调
    public func showPurchaseSuccessAlert(
        for transaction: IAPTransaction,
        completion: (() -> Void)? = nil
    ) {
        let alert = UIAlertController(
            title: "购买成功",
            message: "感谢您的购买！",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in
            completion?()
        })
        
        present(alert, animated: true)
    }
    
    /// 显示购买错误提示
    /// - Parameters:
    ///   - error: 错误对象
    ///   - completion: 完成回调
    public func showPurchaseErrorAlert(
        for error: IAPError,
        completion: (() -> Void)? = nil
    ) {
        let alert = UIAlertController(
            title: "购买失败",
            message: error.userFriendlyDescription,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in
            completion?()
        })
        
        present(alert, animated: true)
    }
}

// MARK: - UIButton 扩展

extension UIButton {
    
    /// 设置购买按钮样式
    /// - Parameters:
    ///   - product: 商品对象
    ///   - isPurchasing: 是否正在购买
    public func configurePurchaseButton(for product: IAPProduct, isPurchasing: Bool = false) {
        if isPurchasing {
            setTitle("购买中...", for: .normal)
            isEnabled = false
            alpha = 0.6
        } else {
            setTitle("购买 \(product.formattedPrice)", for: .normal)
            isEnabled = true
            alpha = 1.0
        }
        
        // 设置样式
        backgroundColor = UIColor.systemBlue
        setTitleColor(UIColor.white, for: .normal)
        setTitleColor(UIColor.lightGray, for: .disabled)
        layer.cornerRadius = 8
        titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
    }
    
    /// 设置恢复购买按钮样式
    public func configureRestoreButton() {
        setTitle("恢复购买", for: .normal)
        backgroundColor = UIColor.systemGray
        setTitleColor(UIColor.white, for: .normal)
        layer.cornerRadius = 8
        titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
    }
}

// MARK: - UILabel 扩展

extension UILabel {
    
    /// 设置商品价格标签样式
    /// - Parameter product: 商品对象
    public func configurePriceLabel(for product: IAPProduct) {
        text = product.formattedPrice
        font = UIFont.systemFont(ofSize: 18, weight: .bold)
        textColor = UIColor.systemBlue
        textAlignment = .right
    }
    
    /// 设置商品标题标签样式
    /// - Parameter product: 商品对象
    public func configureTitleLabel(for product: IAPProduct) {
        text = product.displayName
        font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        textColor = UIColor.label
        numberOfLines = 2
    }
    
    /// 设置商品描述标签样式
    /// - Parameter product: 商品对象
    public func configureDescriptionLabel(for product: IAPProduct) {
        text = product.description
        font = UIFont.systemFont(ofSize: 14, weight: .regular)
        textColor = UIColor.secondaryLabel
        numberOfLines = 0
    }
    
    /// 设置商品类型标签样式
    /// - Parameter product: 商品对象
    public func configureProductTypeLabel(for product: IAPProduct) {
        text = product.localizedProductType
        font = UIFont.systemFont(ofSize: 12, weight: .medium)
        textColor = UIColor.systemOrange
        textAlignment = .right
    }
}

// MARK: - UIImageView 扩展

extension UIImageView {
    
    /// 设置商品图片
    /// - Parameter product: 商品对象
    public func setProductImage(for product: IAPProduct) {
        let systemImageName: String
        
        switch product.productType {
        case .consumable:
            systemImageName = "bag.fill"
        case .nonConsumable:
            systemImageName = "gift.fill"
        case .autoRenewableSubscription:
            systemImageName = "arrow.clockwise.circle.fill"
        case .nonRenewingSubscription:
            systemImageName = "calendar.circle.fill"
        }
        
        image = UIImage(systemName: systemImageName)?.withTintColor(.systemBlue, renderingMode: .alwaysOriginal)
        contentMode = .scaleAspectFit
        backgroundColor = UIColor.systemGray6
        layer.cornerRadius = 8
        clipsToBounds = true
    }
}

// MARK: - UIView 扩展

extension UIView {
    
    /// 添加加载指示器
    /// - Returns: 加载指示器视图
    @discardableResult
    public func addLoadingIndicator() -> UIActivityIndicatorView {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.center = center
        indicator.startAnimating()
        
        addSubview(indicator)
        bringSubviewToFront(indicator)
        
        return indicator
    }
    
    /// 移除加载指示器
    public func removeLoadingIndicators() {
        subviews.compactMap { $0 as? UIActivityIndicatorView }.forEach { indicator in
            indicator.stopAnimating()
            indicator.removeFromSuperview()
        }
    }
    
    /// 添加简单的阴影效果
    public func addShadow() {
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 4
        layer.shadowOpacity = 0.1
    }
}

// MARK: - 便利工厂方法

public struct IAPUIFactory {
    
    /// 创建标准的购买按钮
    /// - Parameters:
    ///   - product: 商品对象
    ///   - target: 目标对象
    ///   - action: 点击事件
    /// - Returns: 配置好的按钮
    public static func createPurchaseButton(
        for product: IAPProduct,
        target: Any?,
        action: Selector
    ) -> UIButton {
        let button = UIButton(type: .system)
        button.configurePurchaseButton(for: product)
        button.addTarget(target, action: action, for: .touchUpInside)
        return button
    }
    
    /// 创建恢复购买按钮
    /// - Parameters:
    ///   - target: 目标对象
    ///   - action: 点击事件
    /// - Returns: 配置好的按钮
    public static func createRestoreButton(
        target: Any?,
        action: Selector
    ) -> UIButton {
        let button = UIButton(type: .system)
        button.configureRestoreButton()
        button.addTarget(target, action: action, for: .touchUpInside)
        return button
    }
    
    /// 创建商品信息视图
    /// - Parameter product: 商品对象
    /// - Returns: 配置好的视图
    public static func createProductInfoView(for product: IAPProduct) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = UIColor.systemBackground
        containerView.layer.cornerRadius = 12
        containerView.addShadow()
        
        let imageView = UIImageView()
        imageView.setProductImage(for: product)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.configureTitleLabel(for: product)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let descriptionLabel = UILabel()
        descriptionLabel.configureDescriptionLabel(for: product)
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let priceLabel = UILabel()
        priceLabel.configurePriceLabel(for: product)
        priceLabel.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(imageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(descriptionLabel)
        containerView.addSubview(priceLabel)
        
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            imageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            imageView.widthAnchor.constraint(equalToConstant: 60),
            imageView.heightAnchor.constraint(equalToConstant: 60),
            
            titleLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: priceLabel.leadingAnchor, constant: -8),
            
            descriptionLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            descriptionLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            descriptionLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            
            priceLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            priceLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            priceLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 80)
        ])
        
        return containerView
    }
}

// MARK: - 主题支持

public struct IAPTheme {
    
    public static let primaryColor = UIColor.systemBlue
    public static let secondaryColor = UIColor.systemGray
    public static let successColor = UIColor.systemGreen
    public static let errorColor = UIColor.systemRed
    public static let warningColor = UIColor.systemOrange
    
    public static let cornerRadius: CGFloat = 8
    public static let shadowRadius: CGFloat = 4
    public static let shadowOpacity: Float = 0.1
    
    /// 应用主题到购买按钮
    /// - Parameter button: 按钮对象
    public static func applyToPurchaseButton(_ button: UIButton) {
        button.backgroundColor = primaryColor
        button.setTitleColor(.white, for: .normal)
        button.setTitleColor(.lightGray, for: .disabled)
        button.layer.cornerRadius = cornerRadius
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
    }
    
    /// 应用主题到卡片视图
    /// - Parameter view: 视图对象
    public static func applyToCardView(_ view: UIView) {
        view.backgroundColor = UIColor.systemBackground
        view.layer.cornerRadius = cornerRadius
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = shadowRadius
        view.layer.shadowOpacity = shadowOpacity
    }
}import UIKit
import IAPFramework

// MARK: - UIViewController Extensions

extension UIViewController {
    
    /// 显示内购界面
    /// - Parameters:
    ///   - productIDs: 商品ID集合
    ///   - animated: 是否动画展示
    ///   - completion: 完成回调
    public func presentIAPViewController(
        productIDs: Set<String>,
        animated: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        let iapViewController = IAPViewController(productIDs: productIDs)
        let navigationController = UINavigationController(rootViewController: iapViewController)
        
        // 设置展示样式
        navigationController.modalPresentationStyle = .pageSheet
        
        if #available(iOS 15.0, *) {
            if let sheet = navigationController.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.prefersGrabberVisible = true
            }
        }
        
        present(navigationController, animated: animated, completion: completion)
    }
    
    /// 显示内购界面（数组版本）
    /// - Parameters:
    ///   - productIDs: 商品ID数组
    ///   - animated: 是否动画展示
    ///   - completion: 完成回调
    public func presentIAPViewController(
        productIDs: [String],
        animated: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        presentIAPViewController(
            productIDs: Set(productIDs),
            animated: animated,
            completion: completion
        )
    }
    
    /// 显示简单的购买对话框
    /// - Parameters:
    ///   - product: 商品信息
    ///   - purchaseHandler: 购买处理器
    public func showPurchaseDialog(
        for product: IAPProduct,
        purchaseHandler: @escaping (IAPProduct) -> Void
    ) {
        let alert = UIAlertController(
            title: "购买确认",
            message: "是否购买 \(product.displayName)？\n价格：\(product.formattedPrice)",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "购买", style: .default) { _ in
            purchaseHandler(product)
        })
        
        present(alert, animated: true)
    }
    
    /// 显示恢复购买确认对话框
    /// - Parameter restoreHandler: 恢复处理器
    public func showRestorePurchasesDialog(restoreHandler: @escaping () -> Void) {
        let alert = UIAlertController(
            title: "恢复购买",
            message: "这将恢复您之前购买的所有商品。是否继续？",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "恢复", style: .default) { _ in
            restoreHandler()
        })
        
        present(alert, animated: true)
    }
}

// MARK: - UIView Extensions

extension UIView {
    
    /// 添加购买成功的动画效果
    public func animatePurchaseSuccess() {
        // 缩放动画
        UIView.animate(
            withDuration: 0.2,
            delay: 0,
            usingSpringWithDamping: 0.6,
            initialSpringVelocity: 0.8,
            options: [.curveEaseInOut],
            animations: {
                self.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            }
        ) { _ in
            UIView.animate(withDuration: 0.2) {
                self.transform = .identity
            }
        }
        
        // 添加绿色边框闪烁效果
        let originalBorderColor = layer.borderColor
        let originalBorderWidth = layer.borderWidth
        
        layer.borderColor = UIColor.systemGreen.cgColor
        layer.borderWidth = 2.0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            UIView.animate(withDuration: 0.3) {
                self.layer.borderColor = originalBorderColor
                self.layer.borderWidth = originalBorderWidth
            }
        }
    }
    
    /// 添加购买失败的动画效果
    public func animatePurchaseFailure() {
        // 摇摆动画
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.duration = 0.6
        animation.values = [-20.0, 20.0, -20.0, 20.0, -10.0, 10.0, -5.0, 5.0, 0.0]
        layer.add(animation, forKey: "shake")
        
        // 添加红色边框闪烁效果
        let originalBorderColor = layer.borderColor
        let originalBorderWidth = layer.borderWidth
        
        layer.borderColor = UIColor.systemRed.cgColor
        layer.borderWidth = 2.0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            UIView.animate(withDuration: 0.3) {
                self.layer.borderColor = originalBorderColor
                self.layer.borderWidth = originalBorderWidth
            }
        }
    }
    
    /// 添加加载状态的脉冲动画
    public func startPulseAnimation() {
        let pulseAnimation = CABasicAnimation(keyPath: "opacity")
        pulseAnimation.duration = 1.0
        pulseAnimation.fromValue = 0.3
        pulseAnimation.toValue = 1.0
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .infinity
        
        layer.add(pulseAnimation, forKey: "pulse")
    }
    
    /// 停止脉冲动画
    public func stopPulseAnimation() {
        layer.removeAnimation(forKey: "pulse")
    }
}

// MARK: - UIButton Extensions

extension UIButton {
    
    /// 设置购买按钮样式
    /// - Parameters:
    ///   - product: 商品信息
    ///   - isPurchasing: 是否正在购买
    public func configurePurchaseButton(for product: IAPProduct, isPurchasing: Bool = false) {
        if isPurchasing {
            setTitle("购买中...", for: .normal)
            isEnabled = false
            backgroundColor = UIColor.systemGray
            startPulseAnimation()
        } else {
            setTitle("购买 \(product.formattedPrice)", for: .normal)
            isEnabled = true
            backgroundColor = UIColor.systemBlue
            stopPulseAnimation()
        }
        
        setTitleColor(.white, for: .normal)
        setTitleColor(.lightGray, for: .disabled)
        titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        layer.cornerRadius = 8
    }
    
    /// 设置恢复购买按钮样式
    /// - Parameter isRestoring: 是否正在恢复
    public func configureRestoreButton(isRestoring: Bool = false) {
        if isRestoring {
            setTitle("恢复中...", for: .normal)
            isEnabled = false
            startPulseAnimation()
        } else {
            setTitle("恢复购买", for: .normal)
            isEnabled = true
            stopPulseAnimation()
        }
        
        setTitleColor(.systemBlue, for: .normal)
        setTitleColor(.systemGray, for: .disabled)
        titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
    }
}

// MARK: - UILabel Extensions

extension UILabel {
    
    /// 设置商品价格标签样式
    /// - Parameter product: 商品信息
    public func configurePriceLabel(for product: IAPProduct) {
        text = product.formattedPrice
        font = UIFont.systemFont(ofSize: 18, weight: .bold)
        textColor = UIColor.systemBlue
        textAlignment = .right
    }
    
    /// 设置商品类型标签样式
    /// - Parameter product: 商品信息
    public func configureProductTypeLabel(for product: IAPProduct) {
        text = product.localizedProductType
        font = UIFont.systemFont(ofSize: 12, weight: .medium)
        textColor = UIColor.systemOrange
        textAlignment = .right
    }
    
    /// 设置商品标题标签样式
    /// - Parameter product: 商品信息
    public func configureTitleLabel(for product: IAPProduct) {
        text = product.displayName
        font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        textColor = UIColor.label
        numberOfLines = 2
    }
    
    /// 设置商品描述标签样式
    /// - Parameter product: 商品信息
    public func configureDescriptionLabel(for product: IAPProduct) {
        text = product.description
        font = UIFont.systemFont(ofSize: 14, weight: .regular)
        textColor = UIColor.secondaryLabel
        numberOfLines = 3
    }
}

// MARK: - UIImageView Extensions

extension UIImageView {
    
    /// 设置商品图标
    /// - Parameter productType: 商品类型
    public func setProductIcon(for productType: IAPProductType) {
        let systemImageName: String
        let tintColor: UIColor
        
        switch productType {
        case .consumable:
            systemImageName = "bag.fill"
            tintColor = .systemBlue
            
        case .nonConsumable:
            systemImageName = "gift.fill"
            tintColor = .systemPurple
            
        case .autoRenewableSubscription:
            systemImageName = "arrow.clockwise.circle.fill"
            tintColor = .systemGreen
            
        case .nonRenewingSubscription:
            systemImageName = "calendar.circle.fill"
            tintColor = .systemOrange
        }
        
        image = UIImage(systemName: systemImageName)?.withTintColor(tintColor, renderingMode: .alwaysOriginal)
        contentMode = .scaleAspectFit
    }
}

// MARK: - UIAlertController Extensions

extension UIAlertController {
    
    /// 创建购买错误提示
    /// - Parameters:
    ///   - error: 错误信息
    ///   - retryHandler: 重试处理器（可选）
    /// - Returns: 配置好的 UIAlertController
    public static func createPurchaseErrorAlert(
        error: IAPError,
        retryHandler: (() -> Void)? = nil
    ) -> UIAlertController {
        let alert = UIAlertController(
            title: "购买失败",
            message: error.userFriendlyDescription,
            preferredStyle: .alert
        )
        
        if let retryHandler = retryHandler {
            alert.addAction(UIAlertAction(title: "重试", style: .default) { _ in
                retryHandler()
            })
        }
        
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        
        return alert
    }
    
    /// 创建购买成功提示
    /// - Parameters:
    ///   - transaction: 交易信息
    ///   - productName: 商品名称（可选）
    /// - Returns: 配置好的 UIAlertController
    public static func createPurchaseSuccessAlert(
        transaction: IAPTransaction,
        productName: String? = nil
    ) -> UIAlertController {
        let name = productName ?? transaction.productID
        
        let alert = UIAlertController(
            title: "购买成功",
            message: "您已成功购买 \(name)！",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        
        return alert
    }
    
    /// 创建恢复购买结果提示
    /// - Parameter transactionCount: 恢复的交易数量
    /// - Returns: 配置好的 UIAlertController
    public static func createRestoreResultAlert(transactionCount: Int) -> UIAlertController {
        let title: String
        let message: String
        
        if transactionCount > 0 {
            title = "恢复成功"
            message = "已成功恢复 \(transactionCount) 个购买项目。"
        } else {
            title = "恢复完成"
            message = "没有找到可恢复的购买项目。"
        }
        
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        
        return alert
    }
}

// MARK: - UITableView Extensions

extension UITableView {
    
    /// 注册内购相关的单元格
    public func registerIAPCells() {
        register(ProductTableViewCell.self, forCellReuseIdentifier: ProductTableViewCell.reuseIdentifier)
    }
    
    /// 刷新购买状态
    /// - Parameter purchaseManager: 购买管理器
    public func refreshPurchaseStates(with purchaseManager: PurchaseManager) {
        for indexPath in indexPathsForVisibleRows ?? [] {
            if let cell = cellForRow(at: indexPath) as? ProductTableViewCell {
                // 这里需要从数据源获取商品信息
                // 实际使用时需要根据具体的数据源实现来调整
            }
        }
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    
    /// 购买成功通知
    public static let iapPurchaseSuccess = Notification.Name("IAPPurchaseSuccess")
    
    /// 购买失败通知
    public static let iapPurchaseFailure = Notification.Name("IAPPurchaseFailure")
    
    /// 商品加载完成通知
    public static let iapProductsLoaded = Notification.Name("IAPProductsLoaded")
    
    /// 恢复购买完成通知
    public static let iapRestoreCompleted = Notification.Name("IAPRestoreCompleted")
}

// MARK: - UserDefaults Extensions

extension UserDefaults {
    
    /// 保存购买状态
    /// - Parameters:
    ///   - productID: 商品ID
    ///   - isPurchased: 是否已购买
    public func setPurchased(_ isPurchased: Bool, for productID: String) {
        set(isPurchased, forKey: "purchased_\(productID)")
    }
    
    /// 获取购买状态
    /// - Parameter productID: 商品ID
    /// - Returns: 是否已购买
    public func isPurchased(_ productID: String) -> Bool {
        return bool(forKey: "purchased_\(productID)")
    }
    
    /// 清除所有购买状态
    public func clearAllPurchaseStates() {
        let keys = dictionaryRepresentation().keys.filter { $0.hasPrefix("purchased_") }
        for key in keys {
            removeObject(forKey: key)
        }
    }
}

// MARK: - Error Handling Utilities

public struct IAPUIHelper {
    
    /// 显示错误提示
    /// - Parameters:
    ///   - error: 错误信息
    ///   - viewController: 要显示提示的视图控制器
    ///   - retryHandler: 重试处理器（可选）
    public static func showError(
        _ error: IAPError,
        in viewController: UIViewController,
        retryHandler: (() -> Void)? = nil
    ) {
        let alert = UIAlertController.createPurchaseErrorAlert(error: error, retryHandler: retryHandler)
        viewController.present(alert, animated: true)
    }
    
    /// 显示成功提示
    /// - Parameters:
    ///   - transaction: 交易信息
    ///   - productName: 商品名称（可选）
    ///   - viewController: 要显示提示的视图控制器
    public static func showSuccess(
        transaction: IAPTransaction,
        productName: String? = nil,
        in viewController: UIViewController
    ) {
        let alert = UIAlertController.createPurchaseSuccessAlert(transaction: transaction, productName: productName)
        viewController.present(alert, animated: true)
    }
    
    /// 显示加载指示器
    /// - Parameters:
    ///   - message: 提示消息
    ///   - viewController: 要显示指示器的视图控制器
    /// - Returns: 指示器视图
    @discardableResult
    public static func showLoadingIndicator(
        message: String = "加载中...",
        in viewController: UIViewController
    ) -> UIView {
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
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        
        hudView.addSubview(indicator)
        hudView.addSubview(label)
        
        viewController.view.addSubview(hudView)
        
        NSLayoutConstraint.activate([
            hudView.centerXAnchor.constraint(equalTo: viewController.view.centerXAnchor),
            hudView.centerYAnchor.constraint(equalTo: viewController.view.centerYAnchor),
            hudView.widthAnchor.constraint(greaterThanOrEqualToConstant: 160),
            hudView.heightAnchor.constraint(greaterThanOrEqualToConstant: 120),
            
            indicator.centerXAnchor.constraint(equalTo: hudView.centerXAnchor),
            indicator.topAnchor.constraint(equalTo: hudView.topAnchor, constant: 20),
            
            label.topAnchor.constraint(equalTo: indicator.bottomAnchor, constant: 16),
            label.leadingAnchor.constraint(equalTo: hudView.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: hudView.trailingAnchor, constant: -10),
            label.bottomAnchor.constraint(equalTo: hudView.bottomAnchor, constant: -20)
        ])
        
        return hudView
    }
    
    /// 隐藏加载指示器
    /// - Parameter indicator: 要隐藏的指示器
    public static func hideLoadingIndicator(_ indicator: UIView) {
        UIView.animate(withDuration: 0.3, animations: {
            indicator.alpha = 0
        }) { _ in
            indicator.removeFromSuperview()
        }
    }
}