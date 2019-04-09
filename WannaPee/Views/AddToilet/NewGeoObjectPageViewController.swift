//
//  AddToiletPageViewController.swift
//  WannaPee
//
//  Created by Vladimir Vlasov on 12.06.2018.
//  Copyright © 2018 Sofatech. All rights reserved.
//

import UIKit
import GLMap
import GLMapSwift

class NewGeoObjectPageViewController: UIPageViewController {
    var photo: UIImage?
    var location: GLMapGeoPoint?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource = self
        
        setViewControllers([pageContentViewControllers.first!], direction: .forward, animated: false)
        
        photoViewController.imageView.image = photo
        
        if let location = self.location {
            locationViewController.map?.mapGeoCenter = location
        }
        
        setupPageIndicator()
    }
    
    private func setupPageIndicator() {
        let pageControl = UIPageControl.appearance()
        pageControl.backgroundColor = .clear
        pageControl.currentPageIndicatorTintColor = UIColor(red: 117.0 / 255, green: 194.0 / 255, blue: 246.0 / 255, alpha: 1.0)
        pageControl.pageIndicatorTintColor = .lightGray
    }

    lazy var pageContentViewControllers: [UIViewController] = [self.photoViewController, self.locationViewController]
    
    lazy var photoViewController: GeoObjectPhotoViewController = {
        return (storyboard?.instantiateViewController(withIdentifier: String(describing: GeoObjectPhotoViewController.self))) as! GeoObjectPhotoViewController
    }()
    
    lazy var locationViewController: GeoObjectLocationViewController = {
        return (storyboard?.instantiateViewController(withIdentifier: String(describing: GeoObjectLocationViewController.self))) as! GeoObjectLocationViewController
    }()
}

extension NewGeoObjectPageViewController: UIPageViewControllerDataSource {
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        switch viewController {
        case is GeoObjectLocationViewController:
            return photoViewController
        default:
            return nil
        }
    }
     
    public func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        switch viewController {
        case is GeoObjectPhotoViewController:
            return locationViewController
        default:
            return nil
        }
    }
    
    public func presentationCount(for pageViewController: UIPageViewController) -> Int {
        return pageContentViewControllers.count
    }
    
    func presentationIndex(for pageViewController: UIPageViewController) -> Int  {
        return pageContentViewControllers.index(where: { $0 === pageViewController }) ?? 0
    }
}
