import Foundation
import StoreKit

/**
 内购商品信息
 
 `IAPProduct` 表示 App Store 中的一个内购商品，包含了商品的所有基本信息和元数据。
 该结构体统一了 StoreKit 1 和 StoreKit 2 中的商品信息格式，提供了一致的访问接口。
 
 ## 商品类型支持
 
 - **消耗型商品**: 可以重复购买的商品（如游戏币、道具）
 - **非消耗型商品**: 一次购买永久有效的商品（如去广告、解锁功能）
 - **自动续费订阅**: 自动续费的订阅服务（如会员服务）
 - **非续费订阅**: 固定期限的订阅服务（如季票）
 
 ## 价格和本地化
 
 商品价格信息完全本地化，支持：
 - 用户当前地区的货币格式
 - 本地化的价格显示
 - 订阅商品的介绍性价格
 - 促销优惠价格
 
 ## 使用示例
 
 ```swift
 let product: IAPProduct = // 从 loadProducts 获取
 
 // 基本信息
 print("商品名称: \(product.displayName)")
 print("商品描述: \(product.description)")
 print("价格: \(product.localizedPrice)")
 
 // 类型检查
 if product.isSubscription {
     print("这是订阅商品")
     if let subscriptionInfo = product.subscriptionInfo {
         print("订阅周期: \(subscriptionInfo.subscriptionPeriod)")
     }
 }
 
 // 价格比较
 if product.hasIntroductoryPrice {
     print("介绍价: \(product.bestLocalizedPrice)")
 }
 ```
 
 - Note: 符合 `Sendable` 协议，可以安全地在并发环境中使用
 - Important: 商品信息可能会发生变化，建议定期刷新
 */
public struct IAPProduct: Sendable, Identifiable, Equatable {
    /// 商品唯一标识符
    public let id: String
    
    /// 商品显示名称
    public let displayName: String
    
    /// 商品描述
    public let description: String
    
    /// 商品价格
    public let price: Decimal
    
    /// 价格本地化信息
    public let priceLocale: Locale
    
    /// 格式化的价格字符串
    public let localizedPrice: String
    
    /// 商品类型
    public let productType: IAPProductType
    
    /// 订阅信息（仅订阅类商品有效）
    public let subscriptionInfo: IAPSubscriptionInfo?
    

    
    public init(
        id: String,
        displayName: String,
        description: String,
        price: Decimal,
        priceLocale: Locale,
        localizedPrice: String,
        productType: IAPProductType,
        subscriptionInfo: IAPSubscriptionInfo? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.price = price
        self.priceLocale = priceLocale
        self.localizedPrice = localizedPrice
        self.productType = productType
        self.subscriptionInfo = subscriptionInfo
    }
    
    public static func == (lhs: IAPProduct, rhs: IAPProduct) -> Bool {
        return lhs.id == rhs.id
    }
    
    // MARK: - 便利方法
    
    /// 是否为订阅类商品
    public var isSubscription: Bool {
        switch productType {
        case .autoRenewableSubscription, .nonRenewingSubscription:
            return true
        default:
            return false
        }
    }
    
    /// 是否为消耗型商品
    public var isConsumable: Bool {
        return productType == .consumable
    }
    
    /// 是否有介绍性价格
    public var hasIntroductoryPrice: Bool {
        return subscriptionInfo?.introductoryPrice != nil
    }
    
    /// 是否有促销优惠
    public var hasPromotionalOffers: Bool {
        return !(subscriptionInfo?.promotionalOffers.isEmpty ?? true)
    }
    
    /// 获取最优惠的价格（考虑介绍性价格）
    public var bestPrice: Decimal {
        if let introPrice = subscriptionInfo?.introductoryPrice {
            return min(price, introPrice.price)
        }
        return price
    }
    
    /// 获取最优惠的本地化价格字符串
    public var bestLocalizedPrice: String {
        if let introPrice = subscriptionInfo?.introductoryPrice,
           introPrice.price < price {
            return introPrice.localizedPrice
        }
        return localizedPrice
    }
    
    /// 格式化的价格字符串（便利属性）
    public var formattedPrice: String {
        return localizedPrice
    }
    
    /// 商品类型的本地化描述
    public var localizedProductType: String {
        switch productType {
        case .consumable:
            return "消耗型商品"
        case .nonConsumable:
            return "非消耗型商品"
        case .autoRenewableSubscription:
            return "自动续费订阅"
        case .nonRenewingSubscription:
            return "非续费订阅"
        }
    }
    
    /// 创建测试商品
    /// - Parameters:
    ///   - id: 商品ID
    ///   - displayName: 显示名称
    ///   - price: 价格
    ///   - productType: 商品类型
    /// - Returns: 测试商品对象
    public static func mock(
        id: String,
        displayName: String,
        price: Decimal = 0.99,
        productType: IAPProductType = .consumable
    ) -> IAPProduct {
        let locale = Locale.current
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        
        let localizedPrice = formatter.string(from: NSDecimalNumber(decimal: price)) ?? "$0.99"
        
        return IAPProduct(
            id: id,
            displayName: displayName,
            description: "Test product description",
            price: price,
            priceLocale: locale,
            localizedPrice: localizedPrice,
            productType: productType
        )
    }
}

/// 商品类型枚举
public enum IAPProductType: Sendable, CaseIterable {
    /// 消耗型商品
    case consumable
    /// 非消耗型商品
    case nonConsumable
    /// 自动续费订阅
    case autoRenewableSubscription
    /// 非续费订阅
    case nonRenewingSubscription
}

/// 订阅信息
public struct IAPSubscriptionInfo: Sendable, Equatable {
    /// 订阅组标识符
    public let subscriptionGroupID: String
    
    /// 订阅期间
    public let subscriptionPeriod: IAPSubscriptionPeriod
    
    /// 介绍性价格信息
    public let introductoryPrice: IAPSubscriptionOffer?
    
    /// 促销优惠
    public let promotionalOffers: [IAPSubscriptionOffer]
    
    public init(
        subscriptionGroupID: String,
        subscriptionPeriod: IAPSubscriptionPeriod,
        introductoryPrice: IAPSubscriptionOffer? = nil,
        promotionalOffers: [IAPSubscriptionOffer] = []
    ) {
        self.subscriptionGroupID = subscriptionGroupID
        self.subscriptionPeriod = subscriptionPeriod
        self.introductoryPrice = introductoryPrice
        self.promotionalOffers = promotionalOffers
    }
}

/// 订阅期间
public struct IAPSubscriptionPeriod: Sendable, Equatable {
    /// 期间单位
    public let unit: Unit
    
    /// 期间数值
    public let value: Int
    
    public init(unit: Unit, value: Int) {
        self.unit = unit
        self.value = value
    }
    
    public enum Unit: Sendable, CaseIterable {
        case day
        case week
        case month
        case year
    }
}

/// 订阅优惠
public struct IAPSubscriptionOffer: Sendable, Equatable {
    /// 优惠标识符
    public let identifier: String?
    
    /// 优惠类型
    public let type: OfferType
    
    /// 优惠价格
    public let price: Decimal
    
    /// 价格本地化信息
    public let priceLocale: Locale
    
    /// 格式化的价格字符串
    public let localizedPrice: String
    
    /// 优惠期间
    public let period: IAPSubscriptionPeriod
    
    /// 优惠期间数量
    public let periodCount: Int
    
    public init(
        identifier: String?,
        type: OfferType,
        price: Decimal,
        priceLocale: Locale,
        localizedPrice: String,
        period: IAPSubscriptionPeriod,
        periodCount: Int
    ) {
        self.identifier = identifier
        self.type = type
        self.price = price
        self.priceLocale = priceLocale
        self.localizedPrice = localizedPrice
        self.period = period
        self.periodCount = periodCount
    }
    
    public enum OfferType: Sendable, CaseIterable {
        case introductory
        case promotional
    }
}