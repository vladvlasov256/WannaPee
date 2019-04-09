//
//  MapViewController.swift
//  WannaPee
//
//  Created by Vladimir Vlasov on 20.05.2018.
//  Copyright © 2018 Sofatech. All rights reserved.
//

import UIKit
import GLMap
import GLMapSwift
import Reachability
import Pulley

private let defaultZoomLevel: Double = 14
let focusZoomLevel: Double = 17
private let trackDrawOrder: UInt32 = 5
private let trackBBoxScaleFactorForZoom: Double = 2

private let trackColor = GLMapColorMake(117, 194, 246, 255)

private let selectedMarkerDrawOrder: Int32 = 1

protocol MapViewControllerDelegate {
    func didTapOn(geoObject: GeoObject?, withDistance distance: Double?)
    func didChangeDistance(_ distance: Double, to geoObject: GeoObject?)
}

class MapViewController: UIViewController {
    var delegate: MapViewControllerDelegate?
    
    @IBOutlet private var navigationButtonOffset: NSLayoutConstraint!
    @IBOutlet private var navigationButton: UIButton!
    
    private var markerLayer: GLMapMarkerLayer?
    
    private var selectedVectorObject: GLMapVectorObject?
    private let selectionLock = NSRecursiveLock()
    
    private var lastSelectedObject: GeoObject?
    private var distanceToLastObject: Double?
    
    private var lastTrack: GLMapTrack?
    private var lastTrackDestination: GeoObject?
    
    private var needFlyToGeoPosition = true
    private var needConstructRoute = true
    
    var model: MainModel! {
        didSet {
            model.delegate = self
            model.setUpLocationManager()
            map.bboxChangedBlock = model.didChangeBBox
        }
    }
    
    lazy var map: GLMapView = {
        return GLMapView()
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpMapView()
        view.bringSubview(toFront: navigationButton)
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateGeoObjects(notification:)), name: didUpdateGeoObjects, object: nil)
        
        updateGeoObjects()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setUpMapView() {
        map.frame = view.bounds
        map.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        map.showUserLocation = true
        map.mapZoomLevel = defaultZoomLevel
        map.setUserLocationImage(#imageLiteral(resourceName: "location"), movementImage: #imageLiteral(resourceName: "location"))
        view.addSubview(map)
        
        map.tapGestureBlock = didTapOnMap
        
        map.add(selectedMarkerLayer)
    }
    
    private func testAddObject(_ point: CGPoint) {
        let geoPoint = map.makeGeoPoint(fromDisplay: point)
        let geoObject = GeoObject.mr_createEntity()
        geoObject?.id = Int32(10000)
        geoObject?.latitude = geoPoint.lat
        geoObject?.longitude = geoPoint.lon
        
        model?.geoObjectClustering?.add(geoObject)
    }
    
    private func testRemoveObject(_ object: GeoObject) {
        model?.geoObjectClustering?.delete(object)
    }
    
    private func testUpdateObject(_ object: GeoObject) {
        object.longitude += 0.0001
        model?.geoObjectClustering?.update(object)
    }
    
    private func didTapOnMap(_ point: CGPoint) {
        let object = model.geoObjectClustering?.object(at: point, map: map)
        didTapOn(geoObject: object)
    }
    
    private func didTapOn(geoObject object: GeoObject?) {
        if object?.id != lastSelectedObject?.id  {
            let previousVectorObject = selectedVectorObject
            lastSelectedObject = object
            model.geoObjectClustering?.setSelectedId(object?.id, completion: {
                DispatchQueue.main.async {
                    self.removeSelected(object: previousVectorObject)
                }
            })
            
            addSelectedObject(object: object?.vectorObject)
            
            if lastSelectedObject != nil {
                logPickToilet(in: model.currentVisibleCity?.name)
            }
        }
        
        if let selectedObject = lastSelectedObject {
            map.animate { animation in
                animation.fly(to: selectedObject.mapPoint)
            }
            map.mapZoomLevel = focusZoomLevel
        }
        
        distanceToLastObject = distance(to: lastSelectedObject)
        
        delegate?.didTapOn(geoObject: lastSelectedObject, withDistance: distanceToLastObject)
    }
    
    private func removeSelected(object: GLMapVectorObject?) {
        guard let object = object else { return }
        selectionLock.lock()
        defer { selectionLock.unlock() }
        
        selectedMarkerLayer.add(nil, remove: [object], reload: nil, animated: false, completion: nil)
        
        if selectedVectorObject == object {
            selectedVectorObject = nil
        }
    }
    
    private func addSelectedObject(object: GLMapVectorObject?) {
        guard let object = object else { return }
        selectionLock.lock()
        defer { selectionLock.unlock() }
        
        selectedVectorObject = object
        
        selectedMarkerLayer.add([object], remove: nil, reload: nil, animated: false, completion: nil)
    }
    
    private lazy var selectedMarkerLayer: GLMapMarkerLayer = {
        return GLMapMarkerLayer(markers: [], andStyles: selectedMarkerStyles, clusteringRadius:0, drawOrder: selectedMarkerDrawOrder);
    }()
    
    private lazy var selectedMarkerStyles: GLMapMarkerStyleCollection = {
        let styles = GLMapMarkerStyleCollection()
        styles.addStyle(with: #imageLiteral(resourceName: "selected_toilet"))
        
        styles.setMarkerLocationBlock { (marker) -> GLMapPoint in
            if let obj = marker as? GLMapVectorObject {
                return obj.point;
            }
            return GLMapPoint();
        }
        
        styles.setMarkerDataFill { (_, data) in
            data.setStyle(0)
        }
        
        return styles
    }()
    
    private func distance(to object: GeoObject?) -> Double? {
        guard let object = object, let lastLocation = map.lastLocation else { return nil }
        let objectLocation = CLLocation(latitude: object.latitude, longitude: object.longitude)
        return lastLocation.distance(from: objectLocation)
    }
    
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    @IBAction func flyToLocation(_ sender: Any) {
        guard let lastLocation = map.lastLocation?.coordinate else { return }
        
        map.animate { animation in
            animation.fly(to: lastLocation.geoPoint)
        }
    }
}

extension MapViewController: MainModelDelegate {
    func didUpdate(locations: [CLLocation], manager: CLLocationManager) {
        map.locationManager(manager, didUpdateLocations: locations)
        
        if let object = lastSelectedObject, let oldDistance = distanceToLastObject, let newDistance = distance(to: object) {
            if abs(newDistance - oldDistance) > 5 {
                delegate?.didChangeDistance(newDistance, to: object)
            }
        }
    }
    
    func didChange(city: City?, withLocation location: CLLocation) {
        if needFlyToGeoPosition {
            map.mapGeoCenter = location.coordinate.geoPoint
            needFlyToGeoPosition = false
        }
        
        constructRouteToNearestToiletIfNecessary()
        
        log(city: city?.name)
    }
    
    private func constructRouteToNearestToiletIfNecessary() {
        guard let clustering = model.geoObjectClustering, let location = map.lastLocation, needConstructRoute else { return }
        
        needConstructRoute = false
        
        DispatchQueue.global().async {
            guard let nearestObject = clustering.nearestObject(to: location),
                nearestObject.1 < 1000,
                self.model.reachability.connection != .none else {
                    return
            }
            
            self.showRoute(to: nearestObject.0) { success in
                if success {
                    self.didTapOn(geoObject: nearestObject.0)
                }
            }
        }
    }
    
    func didChange(city: City?, withBBox bbox: GLMapBBox) {
        guard let city = city, model.reachability.connection != .none else { return }
        
        model.updateMapsIfNecessary { error in
            guard error == nil, let info = self.model.mapToDownload(atPoint: bbox.center), self.model.needToDownload(city, info) else { return }
            
            DispatchQueue.main.async {
                guard self.model.reachability.connection != .none else { return }
                self.proposeDownload(city: city, info: info)
            }
        }
    }
    
    private func proposeDownload(city: City, info: GLMapInfo) {
        let alertController = UIAlertController(title: nil, message: NSLocalizedString("Do you want to download an offline map of the city?", comment: ""), preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Yes", comment: ""), style: .default, handler: { _ in
            self.model.download(info)
            logOfflineMapDownload(action: "yes")
        }))
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Remind me later", comment: ""), style: .default) { _ in
            logOfflineMapDownload(action: "later")
        })
        alertController.addAction(UIAlertAction(title: NSLocalizedString("No, thanks", comment: ""), style: .destructive, handler: { _ in
            self.model.reject(city)
            
            logOfflineMapDownload(action: "no")
        }))
        self.present(alertController, animated: true) {
            logContentView(name: "Offline Map Download", type: "Alert")
        }
    }
    
    @objc private func updateGeoObjects(notification: NSNotification) {
        updateGeoObjects()
        constructRouteToNearestToiletIfNecessary()
    }
    
    private func updateGeoObjects() {
        DispatchQueue.global().async {
            guard let clustering = self.model?.geoObjectClustering, self.markerLayer == nil, let markerLayer = clustering.markerLayer else { return }
        
            self.markerLayer = markerLayer
            self.map.add(markerLayer)
        }
    }
}

extension MapViewController: GeoObjectDetailsViewControllerDelegate {
    var routeDestination: GeoObject? {
        return lastTrackDestination
    }
    
    var hasConstructedRoute: Bool {
        return lastTrack != nil
    }
    
    func showRoute(to geoObject: GeoObject, completion: @escaping (Bool) -> ()) {
        guard let lastLocation = map.lastLocation else {
            completion(false)
            return
        }
        
        removeLastTrackIfNecessary()
        lastTrackDestination = geoObject
        
        let start = GLRoutePoint(pt: lastLocation.coordinate.geoPoint, heading: Double.nan, isStop: true)
        let stop = GLRoutePoint(pt: GLMapGeoPointFromMapPoint(geoObject.mapPoint), heading: Double.nan, isStop: true)
        let points = [start, stop]
        
        GLMapRouteData.requestRoute(withPoints: points, count: points.count, mode: .walk, locale: "en", units: .international) { (result, error) in
            guard self.lastTrackDestination?.id == geoObject.id else {
                completion(false)
                return
            }
            
            if let error = error as NSError? {
                self.lastTrackDestination = nil
                self.handleRoute(error: error)
                completion(false)
                return
            }
            
            guard let routeData = result, let trackData = routeData.trackData(withColor: trackColor) else {
                self.lastTrackDestination = nil
                completion(false)
                return
            }
            
            let track = GLMapTrack(drawOrder: trackDrawOrder, andTrackData: trackData)
            self.map.add(track)
            let bbox = trackData.bbox().scaled(by: trackBBoxScaleFactorForZoom)
            self.map.mapCenter = bbox.center
            self.map.mapZoom = self.map.mapZoom(for: bbox)
            self.lastTrack = track
            completion(true)
        }
    }
    
    private func handleRoute(error: NSError) {
        DispatchQueue.main.async {
            switch error.code {
            case 442:
                self.presentError(with: NSLocalizedString("Unfortunately, a path wasn't found.", comment: ""))
                return
            default:
                self.presentError(with: NSLocalizedString("Could not fetch data from the map server.", comment: ""))
                return
            }
        }
    }
    
    func hideRoute(to geoObject: GeoObject) {
        removeLastTrackIfNecessary()
    }
    
    private func removeLastTrackIfNecessary() {
        guard let track = lastTrack else { return }
        map.remove(track)
        lastTrack = nil
        lastTrackDestination = nil
    }
}

private let defaultOffset: CGFloat = 8

var minNavigationButtonOffset: CGFloat {
    if #available(iOS 11.0, *) {
        let window = UIApplication.shared.keyWindow
        let bottom = window?.safeAreaInsets.bottom ?? 0
        return defaultOffset + bottom
    } else {
        return defaultOffset
    }
}

extension MapViewController: PulleyDelegate {
    func drawerChangedDistanceFromBottom(drawer: PulleyViewController, distance: CGFloat) {
        let maxOffset = CGFloat(216) + defaultOffset
        let offset = distance + defaultOffset
        navigationButtonOffset.constant = max(min(offset, maxOffset), minNavigationButtonOffset)
        view.setNeedsLayout()
    }
}
