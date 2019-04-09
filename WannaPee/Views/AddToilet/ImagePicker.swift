//
//  ImagePicker.swift
//  WannaPee
//
//  Created by Vladimir Vlasov on 12.06.2018.
//  Copyright © 2018 Sofatech. All rights reserved.
//

import UIKit

let imagePicker = ImagePicker()

class ImagePicker: NSObject {
    private var completion: ((UIImagePickerController, UIImage?) -> ())?
    
    func takePhoto(_ animated: Bool = true, completion: @escaping (UIImagePickerController, UIImage?) -> ()) {
        logContentView(name: "Photo", type: "Screen")
        self.completion = completion
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.allowsEditing = true
        picker.sourceType = imagePickerControllerSourceType
        rootViewController?.present(picker, animated: animated)
    }
    
    private var imagePickerControllerSourceType: UIImagePickerControllerSourceType {
        #if targetEnvironment(simulator)
        return .photoLibrary
        #else
        return .camera
        #endif
    }
}

extension ImagePicker: UIImagePickerControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        completion?(picker, info.image)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.completion?(picker, nil)
    }
}

extension ImagePicker: UINavigationControllerDelegate {}

extension Dictionary where Key == String, Value == Any {
    var image: UIImage? {
        return self[UIImagePickerControllerEditedImage] as? UIImage
    }
}
