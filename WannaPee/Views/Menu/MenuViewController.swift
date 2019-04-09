//
//  MenuViewController.swift
//  WannaPee
//
//  Created by Vladimir Vlasov on 20.05.2018.
//  Copyright © 2018 Sofatech. All rights reserved.
//

import UIKit
import SideMenu
import AVKit
import AVFoundation
import LNRSimpleNotifications

class MenuViewController: UITableViewController {
    var model: MainModel!
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case "presentOfflineMaps":            
            let navigationController = segue.destination as? UINavigationController
            let offlineMapsViewController = navigationController?.viewControllers.first as? OfflineMapsViewController
            offlineMapsViewController?.model = model
        default:
            break
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch indexPath.row {
        case 1:
            SideMenuManager.default.menuLeftNavigationController?.dismiss(animated: true, completion: {
                self.addGeoObject()
            })
        default:
            break
        }
    }
    
    private func addGeoObject() {
        let model = self.model!
        AVCaptureDevice.requestAccess(for: .video) { hasAccess in
            DispatchQueue.main.async {
                if hasAccess {
                    imagePicker.takePhoto() { picker, image in
                        guard let image = image else {
                            picker.dismiss(animated: true)
                            return
                        }
                        picker.setLocation(with: image, model: model)
                    }
                } else {
                    notificationManager.showNotification(notification: self.cameraAccessDeniedNotification)
                }
            }
        }
    }
    
    private lazy var cameraAccessDeniedNotification: LNRNotification = {
        let title = NSLocalizedString("Camera access has been denied", comment: "")
        let text = NSLocalizedString("Please, go to settings, choose \"WannaPee\" and enable the camera option.", comment: "")
        let notificaton = LNRNotification(title: title, body: text)
        notificaton.duration = LNRNotificationDuration.endless.rawValue
        return notificaton
    }()
}

var rootViewController: UIViewController? {
    return UIApplication.shared.windows.first?.rootViewController
}
