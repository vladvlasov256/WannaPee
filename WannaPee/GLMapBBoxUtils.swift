//
//  GLMapBBoxUtils.swift
//  WannaPee
//
//  Created by Vladimir Vlasov on 06.05.2018.
//  Copyright © 2018 Sofatech. All rights reserved.
//

import GLMap
import GLMapSwift

extension GLMapBBox {
    @discardableResult
    func scaled(by factor: Double) -> GLMapBBox  {
        assert(factor >= 0)
        let origin = GLMapPoint(x: self.origin.x - size.x * (factor - 1) / 2, y: self.origin.y - size.y * (factor - 1) / 2)
        return GLMapBBox(origin: origin, width: size.x * factor, height: size.y * factor)
    }
}
