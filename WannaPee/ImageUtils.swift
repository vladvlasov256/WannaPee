//
//  ImageUtils.swift
//  WannaPee
//
//  Created by Vladimir Vlasov on 12.06.2018.
//  Copyright © 2018 Sofatech. All rights reserved.
//

import UIKit

extension UIImage {
    var cgImageWidth: Int { return cgImage?.width ?? 0 }
    var cgImageheight: Int { return cgImage?.height ?? 0 }
    var blance: CGFloat { return min(size.width, size.height)}
    var blanceSize: CGSize { return CGSize(width: blance, height: blance) }
    var blanceRect: CGRect { return CGRect(origin: .zero, size: blanceSize) }
    
    var squaredImage: UIImage? {
        UIGraphicsBeginImageContextWithOptions(blanceSize, false, scale)
        defer { UIGraphicsEndImageContext() }
        guard let cgImage = cgImage?.cropping(to: CGRect(origin: CGPoint(x: max(0, CGFloat(cgImageWidth) - blance)/2.0, y: max(0, CGFloat(cgImageheight) - blance)/2.0), size: blanceSize)) else { return nil }
        
        UIImage(cgImage: cgImage, scale: 1.0, orientation: self.imageOrientation).draw(in: blanceRect)
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    func resize(to dimension: CGFloat = 1024) -> UIImage? {
        let aspectWidth = dimension / size.width;
        let aspectHeight = dimension / size.height;
        
        let aspectRatio = min(aspectWidth, aspectHeight)
        
        return resizeImage(withSize: CGSize(width: size.width * aspectRatio, height: size.height * aspectRatio))
    }
    
    private func resizeImage(withSize size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 1)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    var base64: String? {
        guard let data = UIImageJPEGRepresentation(self, 1.0) else {
            return nil
        }
        
        return data.base64EncodedString()
    }
}

var emptyImage: UIImage? = {
    let size = CGSize(width: 2, height: 2)
    
    UIGraphicsBeginImageContextWithOptions(size, true, 0)
    defer { UIGraphicsEndImageContext() }
    
    UIColor.white.withAlphaComponent(0).setFill()
    UIRectFill(CGRect(origin: CGPoint.zero, size: size))
    
    return UIGraphicsGetImageFromCurrentImageContext()
}()
