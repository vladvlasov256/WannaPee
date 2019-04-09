//
//  NewGeoObjectViewController.swift
//  WannaPee
//
//  Created by Vladimir Vlasov on 13.05.2018.
//  Copyright © 2018 Sofatech. All rights reserved.
//

import UIKit
import GLMap
import GLMapSwift
import MRProgress
import Reachability
import LNRSimpleNotifications

class NewGeoObjectViewController: UIViewController {
    @IBOutlet private var fee: UISwitch!
    @IBOutlet private var wheelchair: UISwitch!
    @IBOutlet private var done: UIBarButtonItem!
    
    var photo: UIImage?
    var location: GLMapGeoPoint?
    var model: MainModel!

    override func viewDidLoad() {
        super.viewDidLoad()
        logContentView(name: "NewGeoObject", type: "Screen")
        
        NotificationCenter.default.addObserver(self, selector: #selector(reachabilityChanged), name: .reachabilityChanged, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @IBAction func back(_ sender: AnyObject) {
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction func done(_ sender: AnyObject) {
        let title = NSLocalizedString("Sending...", comment: "")
        let overlay = MRProgressOverlayView.showOverlayAdded(to: view, title: title, mode: .indeterminate, animated: true)
        
        let fee = self.fee.isOn
        let wheelchair = self.wheelchair.isOn
        
        DispatchQueue.global().async {
            self.send(fee: fee, wheelchair: wheelchair, completion: { error in
                DispatchQueue.main.async {
                    overlay?.dismiss(true)
                    if let _ = error {
                        self.presentError()
                    } else {
                        rootViewController?.presentedViewController?.dismiss(animated: true, completion: {
                            presentSuccessInfo()
                        })
                    }
                }
            })
        }
        
        logAddToilet()
    }
    
    private func send(fee: Bool, wheelchair: Bool, completion: @escaping (NetworkError?) -> ()) {
        let photo = self.photo?.resize()
        let location = self.location ?? GLMapGeoPoint(lat: 0, lon: 0)
        model.networkModel.postToilet(with: location, fee: fee, wheelchair: wheelchair, photo: photo, completion: completion)
    }
    
    private func presentError() {
        let title = NSLocalizedString("Something went wrong", comment: "")
        let text = NSLocalizedString("Please, try to submit a toilet later.", comment: "")
        let notification = LNRNotification(title: title, body: text)
        notification.duration = LNRNotificationDuration.endless.rawValue
        notificationManager.showNotification(notification: notification)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.destination {
        case let destination as NewGeoObjectPageViewController:
            destination.photo = photo?.squaredImage
            destination.location = location
        default:
            break
        }
    }
    
    @objc private func reachabilityChanged() {
        let connection = model?.reachability.connection ?? .none
        done?.isEnabled = connection != .none
    }
}

private func presentSuccessInfo() {
    let title = NSLocalizedString("A toilet has been submitted for review", comment: "")
    let text = NSLocalizedString("It will be added into the database as soon as possible. Thank you very much for making WannaPee better!", comment: "")
    let notification = LNRNotification(title: title, body: text)
    notification.duration = 10
    notificationManager.showNotification(notification: notification)
}
