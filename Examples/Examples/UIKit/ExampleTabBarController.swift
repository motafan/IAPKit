//
//  ExampleTabBarController.swift
//  Examples
//
//  主标签栏控制器
//  展示 UIKit 和 SwiftUI 的集成示例
//

import UIKit
import SwiftUI
import IAPFramework

/// 主标签栏控制器
class ExampleTabBarController: UITabBarController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupTabBar()
        setupViewControllers()
    }
    
    private func setupTabBar() {
        tabBar.tintColor = .systemBlue
        tabBar.backgroundColor = .systemBackground
    }
    
    private func setupViewControllers() {
        var controllers: [UIViewController] = []
        
        // UIKit 示例
        let uikitStoreVC = UIKitExampleStoreViewController()
        uikitStoreVC.tabBarItem = UITabBarItem(
            title: "UIKit 商店",
            image: UIImage(systemName: "cart"),
            selectedImage: UIImage(systemName: "cart.fill")
        )
        let uikitNavController = UINavigationController(rootViewController: uikitStoreVC)
        controllers.append(uikitNavController)
        
        // SwiftUI 示例
        let swiftUIView = SwiftUIExampleContentView()
        let swiftUIHostingController = UIHostingController(rootView: swiftUIView)
        swiftUIHostingController.tabBarItem = UITabBarItem(
            title: "SwiftUI 商店",
            image: UIImage(systemName: "swift"),
            selectedImage: UIImage(systemName: "swift")
        )
        controllers.append(swiftUIHostingController)
        
        // 设置视图控制器
        viewControllers = controllers
    }
}


