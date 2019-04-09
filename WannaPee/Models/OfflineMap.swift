//
//  OfflineMap.swift
//  WannaPee
//
//  Created by Vladimir Vlasov on 20.05.2018.
//  Copyright © 2018 Sofatech. All rights reserved.
//

import GLMap
import GLMapSwift

private let megabyte = Int64(1024 * 1024)

let didUpdateOfflineMaps = Notification.Name("didUpdateOfflineMaps")
let offlineMapDownloadingError = Notification.Name("offlineMapDownloadingError")

@objc enum OfflineMapStatus: Int {
    case notDownloaded
    case inProgress
    case downloaded
}

class OfflineMap: NSObject {
    let id: Int
    let cities: [City]
    private(set) var isHere: Bool = false
    
    private(set) var size: Int? = nil
    @objc dynamic private(set) var status: OfflineMapStatus = .notDownloaded
    @objc dynamic private(set) var progress: NSNumber? = nil
    
    private(set) var downloadTask: GLMapDownloadTask?
    
    private unowned let model: MainModel
    
    init(id: Int, cities: [City], model: MainModel) {
        self.id = id
        self.cities = cities
        self.model = model
        super.init()
    }
    
    var map: GLMapInfo? {
        didSet {
            setup()
        }
    }
    
    var name: String {
        return cities[1...].reduce(cities.first?.name ?? "", { $0 + ", \($1.name)"})
    }
    
    var localizedName: String {
        return cities[1...].reduce(cities.first?.localizedName ?? "", { $0 + "\n\($1.localizedName)"})
    }
    
    func download() {
        guard status == .notDownloaded else { return }
        
        progress = 0
        status = .inProgress
        
        downloadInternal()
    }
    
    private func downloadInternal() {
        guard let map = map else {
            model.updateMapsIfNecessary { _ in
                DispatchQueue.global().async {
                    self.downloadInternal()
                }
            }
            return
        }
        
        GLMapManager.shared.downloadMap(map) { downloadTask in
            if let error = downloadTask.error {
                if (error as NSError).code != 2 {
                    NotificationCenter.default.post(name: offlineMapDownloadingError, object: error)
                    NSLog("Map downloading error: \(error)")
                }
                self.status = .notDownloaded
                
                self.deleteData()
            } else if downloadTask.isCancelled {
                self.status = .notDownloaded
            } else {
                self.status = .downloaded
                NotificationCenter.default.post(name: didUpdateOfflineMaps, object: self)
            }
            
            self.downloadTask = nil
        }
        
        downloadTask = GLMapManager.shared.downloadTask(forMap: map)
    }
    
    func updateProgress() {
        guard let map = map else { return }
        self.progress = NSNumber(floatLiteral: Double(map.downloadProgress))
    }
    
    func cancelDownloading() {
        downloadTask?.cancel()
    }
    
    func delete() {
        guard status == .downloaded else { return }
        
        self.status = .notDownloaded
        NotificationCenter.default.post(name: didUpdateOfflineMaps, object: self)
        
        deleteData()
    }
    
    private func deleteData() {
        guard let map = map else { return }
        DispatchQueue.global().async {
            GLMapManager.shared.deleteMap(map)
        }
    }
    
    func isInside(map: GLMapInfo) -> Bool {
        for city in cities {
            let center = city.center
            let geoPoint = GLMapGeoPointMake(center.latitude, center.longitude)
            let mapPoint = GLMapPointFromMapGeoPoint(geoPoint)
            if map.distance(fromBorder: mapPoint) == 0 {
                return true
            }
        }
        
        return false
    }
    
    private func setup() {
        if status != .inProgress {
            status = map?.status ?? .notDownloaded
        }
        
        if let downloadProgress = map?.downloadProgress {
            progress = NSNumber(floatLiteral: Double(downloadProgress))
        } else {
            progress = nil
        }
    
        if let map = map {
            size = Int(map.size / megabyte)
        } else {
            size = nil
        }
    }
    
    func updateIsHere(with city: City) {
        isHere = cities.contains(where: { $0.name == city.name })
    }
}

private extension GLMapInfo {
    var size: Int64 {
        switch state {
        case .downloaded:
            return sizeOnDisk
        default:
            return sizeOnServer
        }
    }
    
    var status: OfflineMapStatus {
        switch state {
        case .downloaded:
            return .downloaded
        case .inProgress:
            return .inProgress
        default:
            return .notDownloaded
        }
    }
}
