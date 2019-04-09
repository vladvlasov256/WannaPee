//
//  GeoObjectLocationViewController.swift
//  WannaPee
//
//  Created by Vladimir Vlasov on 12.06.2018.
//  Copyright © 2018 Sofatech. All rights reserved.
//

import UIKit
import GLMap
import GLMapSwift

class GeoObjectLocationViewController: UIViewController {
    @IBOutlet private var marker: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.bringSubview(toFront: marker)
    }
    
    var map: GLMapView? {
        return (view as? MapViewContainer)?.map
    }
}
