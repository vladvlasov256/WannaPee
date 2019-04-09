//
//  MapViewContainer.swift
//  WannaPee
//
//  Created by Vladimir Vlasov on 12.06.2018.
//  Copyright © 2018 Sofatech. All rights reserved.
//

import UIKit
import GLMap
import GLMapSwift

class MapViewContainer: UIView {
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initInternal()
    }

    private func initInternal() {
        map.frame = bounds
        map.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        map.showUserLocation = false
        map.mapZoomLevel = focusZoomLevel
        addSubview(map)
    }
    
    lazy var map: GLMapView = GLMapView()
}
