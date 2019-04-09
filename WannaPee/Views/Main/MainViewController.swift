//
//  ViewController.swift
//  WannaPee
//
//  Created by Vladimir Vlasov on 21.04.2018.
//  Copyright © 2018 Sofatech. All rights reserved.
//

import UIKit
import Crashlytics
import SideMenu
import Pulley
import GLMap
import GLMapSwift
import LNRSimpleNotifications

class MainViewController: PulleyViewController {
    @IBOutlet private var menuButton: UIButton!
    @IBOutlet private var geoObjectDetailsContainer: UIView!
    
    private var mapViewController: MapViewController!
    private var detailsViewController: GeoObjectDetailsViewController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupSideMenu()
        view.bringSubview(toFront: menuButton)
        view.bringSubview(toFront: geoObjectDetailsContainer)
        
        logContentView(name: "Main", type: "Screen")
        
        NotificationCenter.default.addObserver(self, selector: #selector(receivedMapDownloadingError(notification:)), name: offlineMapDownloadingError, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(receivedServerError(notification:)), name: didReceiveServerError, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(receivedMapServerError(notification:)), name: didReceiveMapServerError, object: nil)
    }
    
    var model: MainModel! {
        didSet {
            mapViewController?.model = model
            
            let sideMenuNavigationController = storyboard?.instantiateViewController(withIdentifier: "SideMenuNavigationController") as? UISideMenuNavigationController
            let sideMenuController = sideMenuNavigationController?.viewControllers.first as? MenuViewController
            sideMenuController?.model = model
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupSideMenu() {
        let sideMenuNavigationController = storyboard?.instantiateViewController(withIdentifier: "SideMenuNavigationController") as? UISideMenuNavigationController
        SideMenuManager.default.menuLeftNavigationController = sideMenuNavigationController
        SideMenuManager.default.menuAddScreenEdgePanGesturesToPresent(toView: view)
        SideMenuManager.default.menuFadeStatusBar = false
        SideMenuManager.default.menuAnimationFadeStrength = 0.5
        SideMenuManager.default.menuPresentMode = .menuSlideIn
        
        let sideMenuController = sideMenuNavigationController?.viewControllers.first as? MenuViewController
        sideMenuController?.model = model
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if detailsViewController?.geoObject == nil {
            setDrawerPosition(position: .closed)
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        topInset = view.bounds.height - detailsHeight
    }
    
    @IBAction func presentMenu(_ sender: AnyObject) {
        present(SideMenuManager.default.menuLeftNavigationController!, animated: true)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case "embedMapViewController":
            mapViewController = segue.destination as? MapViewController
            mapViewController.model = model
            mapViewController.delegate = self
            detailsViewController?.delegate = mapViewController
            delegate = mapViewController
        case "embedDetailsViewController":
            detailsViewController = segue.destination as? GeoObjectDetailsViewController
            detailsViewController.delegate = mapViewController
            detailsViewController.container = self
            detailsViewController.model = model
        default:
            break
        }
    }
    
    @objc private func receivedMapDownloadingError(notification: NSNotification) {
        DispatchQueue.main.async {
            self.presentError(with: NSLocalizedString("Could not fetch an offline map.", comment: ""))
        }
    }
    
    @objc private func receivedServerError(notification: NSNotification) {
        DispatchQueue.main.async {
            self.presentError(with: NSLocalizedString("Could not fetch data from the server.", comment: ""))
        }
    }
    
    @objc private func receivedMapServerError(notification: NSNotification) {
        DispatchQueue.main.async {
            self.presentError(with: NSLocalizedString("Could not fetch data from the map server.", comment: ""))
        }
    }
}

extension UIViewController {
    func presentError(with text: String) {
        let title = NSLocalizedString("Something went wrong", comment: "")
        let notification = LNRNotification(title: title, body: text)
        notification.duration = 10
        notificationManager.showNotification(notification: notification)
    }
}

extension MainViewController: MapViewControllerDelegate {
    func didTapOn(geoObject: GeoObject?, withDistance distance: Double?) {
        if let geoObject = geoObject {
            detailsViewController.geoObject = geoObject
            detailsViewController.distance = distance
            setDrawerPosition(position: .partiallyRevealed)
        } else {
            setDrawerPosition(position: .closed)
            detailsViewController.geoObject = nil
        }
    }
    
    func didChangeDistance(_ distance: Double, to geoObject: GeoObject?) {
        detailsViewController.distance = distance
    }
}
