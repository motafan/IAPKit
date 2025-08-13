import UIKit
import IAPFramework

/// 商品展示单元格
public final class ProductTableViewCell: UITableViewCell {
    
    // MARK: - UI Components
    
    private let productImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = UIColor.systemGray6
        imageView.layer.cornerRadius = 8
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        label.textColor = UIColor.label
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = UIColor.secondaryLabel
        label.numberOfLines = 3
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let priceLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        label.textColor = UIColor.systemBlue
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let productTypeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = UIColor.systemOrange
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let purchaseButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("购买", for: .normal)
        button.setTitle("购买中...", for: .disabled)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        button.backgroundColor = UIColor.systemBlue
        button.setTitleColor(UIColor.white, for: .normal)
        button.setTitleColor(UIColor.lightGray, for: .disabled)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    // MARK: - Properties
    
    /// 当前商品
    private var product: IAPProduct?
    
    /// 购买按钮点击回调
    public var onPurchaseButtonTapped: ((IAPProduct) -> Void)?
    
    /// 重用标识符
    public static let reuseIdentifier = "ProductTableViewCell"
    
    // MARK: - Initialization
    
    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
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
        
        // 添加子视图
        contentView.addSubview(productImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(descriptionLabel)
        contentView.addSubview(priceLabel)
        contentView.addSubview(productTypeLabel)
        contentView.addSubview(purchaseButton)
        contentView.addSubview(loadingIndicator)
        
        // 设置约束
        setupConstraints()
        
        // 添加按钮事件
        purchaseButton.addTarget(self, action: #selector(purchaseButtonTapped), for: .touchUpInside)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // 商品图片
            productImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            productImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            productImageView.widthAnchor.constraint(equalToConstant: 60),
            productImageView.heightAnchor.constraint(equalToConstant: 60),
            
            // 标题
            titleLabel.leadingAnchor.constraint(equalTo: productImageView.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: priceLabel.leadingAnchor, constant: -8),
            
            // 描述
            descriptionLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            descriptionLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            
            // 价格
            priceLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            priceLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            priceLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
            
            // 商品类型
            productTypeLabel.trailingAnchor.constraint(equalTo: priceLabel.trailingAnchor),
            productTypeLabel.topAnchor.constraint(equalTo: priceLabel.bottomAnchor, constant: 4),
            productTypeLabel.widthAnchor.constraint(equalTo: priceLabel.widthAnchor),
            
            // 购买按钮
            purchaseButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            purchaseButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            purchaseButton.widthAnchor.constraint(equalToConstant: 80),
            purchaseButton.heightAnchor.constraint(equalToConstant: 32),
            
            // 加载指示器
            loadingIndicator.centerXAnchor.constraint(equalTo: purchaseButton.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: purchaseButton.centerYAnchor),
            
            // 内容视图高度
            contentView.bottomAnchor.constraint(greaterThanOrEqualTo: productImageView.bottomAnchor, constant: 12),
            contentView.bottomAnchor.constraint(greaterThanOrEqualTo: descriptionLabel.bottomAnchor, constant: 12)
        ])
    }
    
    // MARK: - Configuration
    
    /// 配置单元格
    /// - Parameters:
    ///   - product: 商品对象
    ///   - isPurchasing: 是否正在购买
    public func configure(with product: IAPProduct, isPurchasing: Bool = false) {
        self.product = product
        
        // 设置基本信息
        titleLabel.text = product.displayName
        descriptionLabel.text = product.description
        priceLabel.text = product.formattedPrice
        productTypeLabel.text = product.localizedProductType
        
        // 设置商品图片（这里使用默认图片，实际项目中可以根据商品类型设置不同图片）
        productImageView.image = getProductImage(for: product.productType)
        
        // 设置购买状态
        setPurchasingState(isPurchasing)
    }
    
    /// 设置购买状态
    /// - Parameter isPurchasing: 是否正在购买
    public func setPurchasingState(_ isPurchasing: Bool) {
        purchaseButton.isEnabled = !isPurchasing
        
        if isPurchasing {
            loadingIndicator.startAnimating()
            purchaseButton.alpha = 0.6
        } else {
            loadingIndicator.stopAnimating()
            purchaseButton.alpha = 1.0
        }
    }
    
    // MARK: - Actions
    
    @objc private func purchaseButtonTapped() {
        guard let product = product else { return }
        onPurchaseButtonTapped?(product)
    }
    
    // MARK: - Helper Methods
    
    private func getProductImage(for productType: IAPProductType) -> UIImage? {
        let systemImageName: String
        
        switch productType {
        case .consumable:
            systemImageName = "bag.fill"
        case .nonConsumable:
            systemImageName = "gift.fill"
        case .autoRenewableSubscription:
            systemImageName = "arrow.clockwise.circle.fill"
        case .nonRenewingSubscription:
            systemImageName = "calendar.circle.fill"
        }
        
        return UIImage(systemName: systemImageName)?.withTintColor(.systemBlue, renderingMode: .alwaysOriginal)
    }
}

// MARK: - 预览支持（仅用于开发）

#if DEBUG
extension ProductTableViewCell {
    
    /// 创建示例商品用于预览
    public static func createSampleProduct() -> IAPProduct {
        return IAPProduct.mock(
            id: "com.example.premium",
            displayName: "高级功能包",
            description: "解锁所有高级功能，包括无限制使用、高级主题和专属客服支持。",
            price: 9.99,
            productType: .nonConsumable
        )
    }
}
#endif