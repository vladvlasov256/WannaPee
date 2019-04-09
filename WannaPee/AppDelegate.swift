//
//  AppDelegate.swift
//  WannaPee
//
//  Created by Vladimir Vlasov on 21.04.2018.
//  Copyright © 2018 Sofatech. All rights reserved.
//

import UIKit
import GLMap
import Fabric
import Crashlytics
import LNRSimpleNotifications
import Reachability

let notificationManager = LNRNotificationManager()

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    private(set) var model: MainModel!
    private var hasSetReachabilityChangeObserver = false

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        Fabric.with([Crashlytics.self])
        
        model = MainModel() {
            NotificationCenter.default.addObserver(self, selector: #selector(self.reachabilityChanged), name: .reachabilityChanged, object: nil)
            self.hasSetReachabilityChangeObserver = true
        }
        mainViewController?.model = model
        
        setupToastNotificationsAppearance()
        
        return true
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        guard let model = self.model else { return }
        DispatchQueue.global().async {
            if model.reachability.connection != .none {
                model.fetchIfNecessary()
            }
        }
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        if hasSetReachabilityChangeObserver {
            NotificationCenter.default.removeObserver(self)
        }
    }
    
    private var mainViewController: MainViewController? {
        return rootViewController as? MainViewController
    }
    
    private func setupToastNotificationsAppearance() {
        notificationManager.notificationsPosition = .top
        notificationManager.notificationsBackgroundColor = UIColor(red: 255 / 255.0, green: 233 / 255.0, blue: 129 / 255.0, alpha: 1.0)
        notificationManager.notificationsTitleTextColor = .black
        notificationManager.notificationsBodyTextColor = .gray
        notificationManager.notificationsSeperatorColor = .lightGray
        notificationManager.notificationsIcon = #imageLiteral(resourceName: "info")
    }
    
    @objc private func reachabilityChanged() {
        let connection = model?.reachability.connection ?? Reachability.Connection.none
        guard connection != .none else { return }
        DispatchQueue.global().async {
            self.model.fetchIfNecessary()
        }
    }
}

