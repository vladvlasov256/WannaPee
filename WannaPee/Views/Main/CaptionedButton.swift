//
//  ButtonUtils.swift
//  WannaPee
//
//  Created by Vladimir Vlasov on 27.05.2018.
//  Copyright © 2018 Sofatech. All rights reserved.
//

import UIKit

class CaptionedButton: UIButton {
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initInternal()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        initInternal()
    }
    
    private func initInternal() {
        titleLabel?.textAlignment = .center
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        guard let imageView = self.imageView, let titleLabel = self.titleLabel else {
            return
        }
        
        imageView.frame = CGRect(x: CGFloat(truncf(Float(bounds.size.width - imageView.frame.size.width) / 2)), y: 0.0, width: imageView.frame.size.width, height: imageView.frame.size.height)
        
        let textRect = titleLabel.textRect(forBounds: bounds, limitedToNumberOfLines: 1)        
        titleLabel.frame = CGRect(x: CGFloat(truncf(Float(bounds.size.width - textRect.size.width) / 2)), y: bounds.size.height - textRect.size.height, width: textRect.size.width, height: textRect.size.height)
    }
}
