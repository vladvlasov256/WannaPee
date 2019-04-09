//
//  UILabelWithInsets.swift
//  WannaPee
//
//  Created by Vladimir Vlasov on 14.06.2018.
//  Copyright © 2018 Sofatech. All rights reserved.
//

import UIKit

class UILabelWithInsets: UILabel {
    private let inset = CGFloat(4)
    private lazy var insets = UIEdgeInsetsMake(0, inset, 0, inset)
    
    override func drawText(in rect: CGRect) {
        super.drawText(in: UIEdgeInsetsInsetRect(rect, insets))
    }
    
//    override func sizeToFit() {
//        let size = sizeThatFits(CGSize(width: CGFloat.Magnitude, height: CGFloat.Magnitude))
//
//    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let rect = ((text ?? "") as NSString).boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: size.height), options: .usesLineFragmentOrigin, attributes: [.font: font], context: nil)
        return CGSize(width: rect.size.width + inset * 2 + 5, height: rect.size.height)
    }
}
