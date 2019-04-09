//
//  GeoObjectClustering.swift
//  WannaPee
//
//  Created by Vladimir Vlasov on 08.06.2018.
//  Copyright © 2018 Sofatech. All rights reserved.
//

import GLMap
import GLMapSwift

private let geoObjectSize = CGSize(width: 32, height: 60)
private let selectionYOffset: CGFloat = 20
private let scaleFactor = UIScreen.main.scale

class GeoObjectClustering {
    private let unionStyleCount = 7
    
    private(set) var objects: [GeoObject]
    private(set) var markerLayer: GLMapMarkerLayer?
    
    private let lock = NSRecursiveLock()
    private var internalSelectedId: Int32?
    
    private var vectorObjects = [Int32: GLMapVectorObject]()
    
    init(_ objects: [GeoObject], drawOrder: Int, selectedId: Int32? = nil) {
        self.objects = objects
        let vectorObjects = objects.vectorObjects
        self.vectorObjects = vectorObjects.dictionary        
        markerLayer = GLMapMarkerLayer(vectorObjects: vectorObjects, andStyles: styles, clusteringRadius: clusteringRadius, drawOrder: Int32(drawOrder))
    }
    
    private lazy var textStyle: GLMapVectorStyle = {
        return GLMapVectorStyle.createStyle("{text-color:white;font-size:12;}")!
    }()
    
    private lazy var styles: GLMapMarkerStyleCollection = {
        let styleCollection = GLMapMarkerStyleCollection()
        
        let markerStyle = styleCollection.addStyle(with: #imageLiteral(resourceName: "toilet"))
        styleCollection.setStyleName("marker", forStyleIndex: markerStyle)
        
        let selectedImage = emptyImage ?? #imageLiteral(resourceName: "selected_toilet")
        let selectedMarkerStyle = styleCollection.addStyle(with: selectedImage)
        styleCollection.setStyleName("selectedMarker", forStyleIndex: selectedMarkerStyle)
        
        let imagePrefix = "oval-"
        
        for i in 1...unionStyleCount {
            guard let image = UIImage(named: "\(imagePrefix)\(i)") else { continue }
            let styleIndex = styleCollection.addStyle(with: image)
        }
        
        styleCollection.setMarkerDataFill { (marker, data) in
            if let obj = marker as? GLMapVectorObject {
                guard let idStr = obj.value(forKey: "id"), let id = Int32(idStr) else { return }
                let style = (id == self.internalSelectedId) ? 1 : 0
                data.setStyle(UInt(style))
            }
        }
        
        styleCollection.setMarkerUnionFill({ (markerCount, data) in
            var markerStyle = Int( log2( Double(markerCount) ) )
            if markerStyle >= self.unionStyleCount {
                markerStyle = self.unionStyleCount - 1
            }
            data.setStyle(UInt(markerStyle + 1))
            data.setText("\(markerCount)", offset: CGPoint.zero, style: self.textStyle)
        })
        
        return styleCollection
    }()
    
    private lazy var clusteringRadius: Double = {
        return Double(#imageLiteral(resourceName: "oval-7").size.width * UIScreen.main.scale) / 2
    }()
    
    var selectedId: Int32? {
        lock.lock()
        defer { lock.unlock() }
        return internalSelectedId
    }
    
    func setSelectedId(_ id: Int32?, completion: @escaping () -> ()) {
        lock.lock()
        defer { lock.unlock() }
        let oldId = internalSelectedId
        internalSelectedId = id
        
        let reload = [oldId, internalSelectedId].compactMap { marker(with: $0) }
        guard reload.count > 0 else { return }
        markerLayer?.add(nil, remove: nil, reload: reload, animated: false, completion: completion)
    }
    
    private func marker(with id: Int32?) -> GLMapVectorObject? {
        guard let id = id else { return nil }
        return vectorObjects[id]
    }
    
    func object(at point: CGPoint, map: GLMapView) -> GeoObject? {
        lock.lock()
        defer { lock.unlock() }
        
        let rect = objectSelectionRect.offsetBy(dx: point.x, dy: point.y)
        let candidate = objects.reversed()
            .first(where: { rect.contains(map.makeDisplayPoint(from: $0.mapPoint)) })
        
        guard let object = candidate else { return nil }
        let objectsAround = markerLayer?.objects(at: map, nearPoint: object.mapPoint, distance: clusteringRadius)

        guard objectsAround?.count == 1 else { return nil }
        
        return object
    }
    
    private lazy var objectSelectionRect: CGRect = {
        return CGRect(x: -geoObjectSize.width / 2, y: -selectionYOffset, width: geoObjectSize.width, height: geoObjectSize.height + selectionYOffset)
    }()
    
    func add(_ geoObject: GeoObject?) {
        guard let geoObject = geoObject else { return }
        
        lock.lock()
        defer { lock.unlock() }
        
        guard !vectorObjects.keys.contains(geoObject.id) else { return }
        
        objects.append(geoObject)
        
        let vectorObject = geoObject.vectorObject
        vectorObjects[geoObject.id] = vectorObject
        markerLayer?.add([vectorObject], remove: nil, reload: nil, animated: true, completion: nil)
    }
    
    func delete(_ geoObject: GeoObject?) {
        guard let geoObject = geoObject else { return }
        
        lock.lock()
        defer { lock.unlock() }
        
        if let index = objects.index(where: { $0.id == geoObject.id }) {
            objects.remove(at: index)
        }
        
        if let vectorObject = vectorObjects[geoObject.id] {
            vectorObjects.removeValue(forKey: geoObject.id)
            markerLayer?.add(nil, remove: [vectorObject], reload: nil, animated: true, completion: nil)
        }
    }
    
    func update(_ geoObject: GeoObject?) {
        guard let geoObject = geoObject else { return }
        
        lock.lock()
        defer { lock.unlock() }
        
        if let index = objects.index(where: { $0.id == geoObject.id }) {
            objects[index] = geoObject
        }
        
        let oldVectorObject = vectorObjects[geoObject.id]
        let removed = [oldVectorObject].compactMap { $0 }
        
        let vectorObject = geoObject.vectorObject
        vectorObjects[geoObject.id] = vectorObject
        
        guard (oldVectorObject == nil) || (oldVectorObject?.point.x != vectorObject.point.x) || (oldVectorObject?.point.y != vectorObject.point.y) else { return }
        
        markerLayer?.add([vectorObject], remove: removed, reload: nil, animated: true, completion: nil)
    }
    
    func nearestObject(to location: CLLocation) -> (GeoObject, Double)? {
        lock.lock()
        defer { lock.unlock() }
        
        var nearestObject: GeoObject?
        var minDistance: Double = Double.greatestFiniteMagnitude
        
        objects.forEach { object in
            let distance = location.distance(from: CLLocation(latitude: object.latitude, longitude: object.longitude))
            if distance < minDistance {
                minDistance = distance
                nearestObject = object
            }
        }
        
        guard let resultObject = nearestObject else { return nil }
        return (resultObject, minDistance)
    }
}

private let featureTemplatePrefix = """
{
    "type": "Feature",
    "properties": {

"""

private let featureTemplateInfix = """
    },
    "geometry": {
        "type": "Point",
        "coordinates":
"""

private let featureTemplateSuffix = """

    }
}
"""

extension Array where Element == GeoObject {
    var vectorObjects: GLMapVectorObjectArray {
        let result = GLMapVectorObjectArray(capacity: UInt(count))
        forEach { result.add($0.vectorObject) }
        return result
    }
}

extension GeoObject {    
    var mapPoint: GLMapPoint {
        return GLMapPointMakeFromGeoCoordinates(latitude, longitude)
    }
}

extension GeoObject {
    var vectorObject: GLMapVectorObject {
        let vectorObject = GLMapVectorObject()
        vectorObject.loadPoint(mapPoint)
        vectorObject.setValue("\(id)", forKey: "id")
        return vectorObject
    }
}

private extension GLMapVectorObjectArray {
    var dictionary: [Int32: GLMapVectorObject] {
        var result = [Int32: GLMapVectorObject]()
        for index in 0..<count {
            let obj = object(at: index)
            guard let str = obj.value(forKey: "id"), let id = Int32(str) else { continue }
            result[id] = obj
        }
        
        return result
    }
}
