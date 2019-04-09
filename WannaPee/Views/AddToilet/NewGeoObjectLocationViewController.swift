//
//  NewGeoObjectLocationViewController.swift
//  WannaPee
//
//  Created by Vladimir Vlasov on 11.06.2018.
//  Copyright © 2018 Sofatech. All rights reserved.
//

import UIKit
import GLMap
import GLMapSwift

class NewGeoObjectLocationViewController: UIViewController {
    @IBOutlet private var marker: UIImageView!
    
    var photo: UIImage?
    var model: MainModel!
    
    private var needSetGeoPosition = true

    override func viewDidLoad() {
        super.viewDidLoad()
        logContentView(name: "NewGeoObjectLocation", type: "Screen")
        view.bringSubview(toFront: marker)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.setNavigationBarHidden(false, animated: true)
        
        guard let map = (view as? MapViewContainer)?.map, let geoPoint = model?.locationManager.location?.coordinate.geoPoint else { return }
        if needSetGeoPosition {
            map.mapGeoCenter = geoPoint
            needSetGeoPosition = false
        }
        map.mapZoomLevel = focusZoomLevel
    }
    
    @IBAction func back(_ sender: AnyObject) {
        let model = self.model!
        rootViewController?.presentedViewController?.dismiss(animated: true, completion: {
            imagePicker.takePhoto(completion: { picker, image in
                guard let image = image else {
                    rootViewController?.presentedViewController?.dismiss(animated: true)
                    return
                }
                picker.setLocation(with: image, model: model)
            })
        })
    }
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case "PresentAddToilet":
            let viewController = segue.destination as? NewGeoObjectViewController
            viewController?.photo = photo
            viewController?.location = location
            viewController?.model = model
        default:
            break
        }
    }
    
    private var location: GLMapGeoPoint {
        return (view as! MapViewContainer).map.mapGeoCenter
    }
}

extension UINavigationController {
    func setLocation(with photo: UIImage, model: MainModel) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let newGeoObjectViewController = storyboard.instantiateViewController(withIdentifier: String(describing: NewGeoObjectLocationViewController.self)) as? NewGeoObjectLocationViewController else { return }
        newGeoObjectViewController.photo = photo
        newGeoObjectViewController.model = model        
        pushViewController(newGeoObjectViewController, animated: true)
    }
}
