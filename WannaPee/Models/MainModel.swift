//
//  MainModel.swift
//  WannaPee
//
//  Created by Vladimir Vlasov on 05.05.2018.
//  Copyright © 2018 Sofatech. All rights reserved.
//

import GLMap
import GLMapSwift
import MagicalRecord
import Reachability

private let glMapApiKey = "YOUR_API_KEY"

let didUpdateGeoObjects = Notification.Name("didUpdateGeoObjects")
let didReceiveServerError = Notification.Name("didReceiveServerError")
let didReceiveMapServerError = Notification.Name("didReceiveMapServerError")

let refreshInterval = TimeInterval(60)

private let geoObjectsDrawOrder = 2

protocol MainModelDelegate: class {
    func didUpdate(locations: [CLLocation], manager: CLLocationManager)
    func didChange(city: City?, withLocation location: CLLocation)
    func didChange(city: City?, withBBox bbox: GLMapBBox)
}

class MainModel: NSObject {
    let locationManager = CLLocationManager()
    var cities: [City]?
    private(set) var geoObjectClustering: GeoObjectClustering?
    
    var offlineMaps: [OfflineMap]?
    fileprivate(set) var currentVisibleCity: City?
    fileprivate(set) var currentCity: City?
    let networkModel = NetworkModel()
    fileprivate var lastFetch: Date?
    
    weak var delegate: MainModelDelegate?
    
    private let geoObjectsQueue = DispatchQueue(label: "geo objects queue")
    
    let feedbackModel = FeedbackModel()
    
    let reachability = Reachability()!
    
    init(completion: @escaping () -> ()) {
        MagicalRecord.enableShorthandMethods()
        
        if hasModelData {
            setModels()
        } else {
            prepopulateDataModel()
        }
        
        super.init()
        setUpGLMap()
        
        NotificationCenter.default.addObserver(self, selector: #selector(downloadProgress(notifaction:)), name: GLMapInfo.downloadProgress, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reachabilityChanged), name: .reachabilityChanged, object: nil)

        geoObjectsQueue.async {
            self.cities = loadCities()
            self.offlineMaps = self.loadOfflineMaps(withCities: self.cities)
            self.geoObjectClustering = loadGeoObjects(self.geoObjectsContext)
            
            NotificationCenter.default.post(name: didUpdateGeoObjects, object: nil)
            
            if self.reachability.connection != .none {
                self.fetch(completion: completion)
            } else {
                completion()
            }
        }
        
        do{
            try reachability.startNotifier()
        }catch{
            NSLog("Could not start reachability notifier")
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private lazy var geoObjectsContext: NSManagedObjectContext = {
        let coordinator = NSPersistentStoreCoordinator.mr_default()
        return NSManagedObjectContext.mr_context(with: coordinator!)
    }()
    
    @objc private func downloadProgress(notifaction: NSNotification) {
        offlineMaps?.forEach { $0.updateProgress() }
    }
    
    private func setUpGLMap() {
        GLMapManager.shared.apiKey = glMapApiKey
        GLMapManager.shared.tileDownloadingAllowed = true
    }
    
    func setUpLocationManager() {
        if CLLocationManager.authorizationStatus() == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        
        locationManager.delegate = self
        locationManager.startUpdatingLocation()
    }
    
    func updateMapsIfNecessary(completion: @escaping (Error?) -> ()) {
        guard needUpdateMaps else {
            updateOfflineMaps()
            completion(nil)
            return
        }
        
        GLMapManager.shared.updateMapList { (fetchedMaps: [GLMapInfo]?, _, error: Error?) in
            DispatchQueue.global().async {
                if error != nil {
                    NSLog("Map downloading error \(error!.localizedDescription)")
                }
                
                if let fetchedMaps = fetchedMaps {
                    self.updateOfflineMaps(withMaps: fetchedMaps)
                } else {
                    NotificationCenter.default.post(name: didReceiveMapServerError, object: nil)
                }
                
                completion((fetchedMaps == nil) ? error : nil)
            }
        }
    }
    
    func didChangeBBox(_ bbox: GLMapBBox) {
        let city = cities?.first(where: { $0.contains(bbox) })
        if city != currentVisibleCity {
            currentVisibleCity = city
            delegate?.didChange(city: city, withBBox: bbox)
        }
    }
    
    @objc private func reachabilityChanged() {
        guard reachability.connection != .none else { return }
        updateMapsIfNecessary { _ in }
    }
}

// MARK: - Offline Maps

extension MainModel {
    private var needUpdateMaps: Bool {
        return GLMapManager.shared.cachedMapList()?.count ?? 0 == 0
    }
    
    private func updateOfflineMaps(withMaps maps: [GLMapInfo]? = nil) {
        var maps = maps
        if maps == nil {
            guard let cachedMaps = GLMapManager.shared.cachedMapList() else { return }
            maps = cachedMaps
        }
        
        maps!.forEach { map in
            guard map.subMaps.count == 0 else {
                updateOfflineMaps(withMaps: map.subMaps)
                return
            }
            
            offlineMaps?.forEach { offlineMap in
                if offlineMap.isInside(map: map) {
                    offlineMap.map = map
                }
            }
        }
        
        NotificationCenter.default.post(name: didUpdateOfflineMaps, object: self)
    }
    
    func mapToDownload(atPoint point: GLMapPoint) -> GLMapInfo? {
        return GLMapManager.shared.map(at: point)
    }
    
    func needToDownload(_ city: City, _ mapInfo: GLMapInfo) -> Bool {
        switch mapInfo.state {
        case .notDownloaded, .needResume:
            return !isRejected(city)
        default:
            return false
        }
    }
    
    func isRejected(_ city: City) -> Bool {
        let context = NSManagedObjectContext.mr_default()
        if let _ = RejectedCity.mr_findFirst(byAttribute: "name", withValue: city.name, in: context) {
            return true
        }
        
        return false
    }
    
    func reject(_ city: City) {
        let context = NSManagedObjectContext.mr_default()
        let rejectedCity = RejectedCity.mr_createEntity(in: context)
        rejectedCity?.name = city.name
        context.mr_saveToPersistentStoreAndWait()
    }
    
    func download(_ mapInfo: GLMapInfo) {
        let offlineMap = offlineMaps?.first(where: { $0.map == mapInfo })
        offlineMap?.download()
    }
    
    private func loadOfflineMaps(withCities cities: [City]?) -> [OfflineMap]? {
        guard let cities = cities else { return nil }
        
        var citiesByMapIds = [Int: [City]]()
        
        cities.forEach { city in
            let mapCities = citiesByMapIds[city.mapId]
            citiesByMapIds[city.mapId] = (mapCities ?? []) + [city]
        }
        
        return citiesByMapIds
            .map { OfflineMap(id: $0, cities: $1, model: self) }
            .sorted(by: { $0.id < $1.id })
    }
}

// MARK: - Location

extension MainModel: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        delegate?.didUpdate(locations: locations, manager: manager)
        
        guard let location = locations.last else { return }
        
        let city = cities?.first(where: { $0.contains(location.coordinate.geoPoint) })
        if city != currentCity {
            currentCity = city
            delegate?.didChange(city: city, withLocation: location)
            updateIsHere(with: city)
        }
    }
    
    private func updateIsHere(with city: City?) {
        guard let city = city else { return }
        offlineMaps?.forEach { $0.updateIsHere(with: city) }
    }
}

private func loadCities() -> [City] {
    guard let citiesURL = Bundle.main.url(forResource: "Cities", withExtension: "json") else {
        fatalError("Could not locate the \"Cities.json\"")
    }
    do {
        let data = try Data(contentsOf: citiesURL)
        return try JSONDecoder().decode([City].self, from: data)
    } catch {
        fatalError("Could not load content of \"Cities.json\"")
    }
}

private func loadGeoObjects(_ context: NSManagedObjectContext) -> GeoObjectClustering {
    guard let geoObjects = GeoObject.mr_findAll(in: context) as? [GeoObject] else {
        return GeoObjectClustering([], drawOrder: geoObjectsDrawOrder)
    }
    
    let existingObjects = geoObjects.filter { !$0.missed }
    return GeoObjectClustering(existingObjects, drawOrder: geoObjectsDrawOrder)
}

private var hasModelData: Bool {
    let fileManager = FileManager.default
    guard let appSupportPath = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.path else { return false }
    
    let modelPath = "\(appSupportPath)/WannaPee/Model"
    return fileManager.fileExists(atPath: modelPath)
}

private func prepopulateDataModel() {
    let fileManager = FileManager.default
    guard let appSupportPath = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.path else { return }
    
    let modelDir = "\(appSupportPath)/WannaPee"
    let filenames = ["Model", "Model-shm", "Model-wal"]
    
    do {
        try fileManager.createDirectory(atPath: modelDir, withIntermediateDirectories: true, attributes: nil)
        
        try filenames.forEach { filename in
            guard let originalUrl = Bundle.main.url(forResource: filename, withExtension: "") else { return }
            let destinationUrl = URL(fileURLWithPath: "\(modelDir)/\(filename)")
            try fileManager.copyItem(at: originalUrl, to: destinationUrl)
        }
    } catch {
        NSLog("Prepolation data error: \(error.localizedDescription)")
        return
    }
    
    setModels()
}

private func setModels() {
    MagicalRecord.setupCoreDataStack(withAutoMigratingSqliteStoreNamed: "Model")
    MagicalRecord.setDefaultModelFrom(GeoObject.self)
    MagicalRecord.setDefaultModelFrom(History.self)
    MagicalRecord.setDefaultModelFrom(RejectedCity.self)
}

// MARK: - Fetching

extension MainModel {
    func fetch(completion: @escaping () -> () = {}) {
        lastFetch = Date()
        
        if let historyId = lastHistoryId {
            fetchHistory(historyId) { error in
                if let _ = error {
                    NotificationCenter.default.post(name: didReceiveServerError, object: nil)
                    completion()
                } else {
                    self.fetchActionsIfNecessary(completion: completion)
                }
            }
        } else {
            networkModel.objects { objectsList, error in
                if let error = error {
                    NSLog("Objects, server error: \(error)")
                    NotificationCenter.default.post(name: didReceiveServerError, object: nil)
                    completion()
                } else if let objectsList = objectsList {
                    self.geoObjectsQueue.async {
                        self.populateDataModel(objectsList)
                        self.fetchHistory(objectsList.historyId) { error in
                            if let _ = error {
                                NotificationCenter.default.post(name: didReceiveServerError, object: nil)
                                completion()
                            } else {
                                self.fetchActionsIfNecessary(completion: completion)
                            }
                        }
                    }
                }
            }
        }
    }
    
    func fetchIfNecessary() {
        let lastFetch = self.lastFetch ?? Date(timeIntervalSince1970: 0)
        guard Date().timeIntervalSince(lastFetch) > refreshInterval else { return }
        fetch()
    }
    
    func set(_ likes: Int, for geoObject: GeoObject) {
        geoObjectsQueue.async {
            geoObject.likes = Int32(likes)
            self.geoObjectsContext.mr_saveToPersistentStoreAndWait()
        }
    }
    
    private var lastHistoryId: Int? {
        guard let history = History.mr_findFirst() else {
            return nil
        }
        
        return Int(history.id)
    }
    
    private func fetchHistory(_ id: Int, completion: @escaping (Error?) -> ()) {
        networkModel.history(id) { history, error in
            if let error = error {
                NSLog("History, server error: \(error)")
                completion(error)
            } else if let history = history {
                self.geoObjectsQueue.async {
                    self.apply(history)
                }
                
                completion(nil)
            }
        }
    }
    
    private func fetchActionsIfNecessary(completion: @escaping () -> ()) {
        feedbackModel.hasFeedback { hasFeedback in
            guard !hasFeedback else {
                completion()
                return
            }
            
            self.networkModel.actions { actions, error in
                if let error = error {
                    NSLog("Actions, server error: \(error)")
                    NotificationCenter.default.post(name: didReceiveServerError, object: nil)
                } else if let actions = actions, actions.count > 0 {
                    self.feedbackModel.apply(actions)
                }
                completion()
            }
        }
    }
    
    private func populateDataModel(_ objectsList: ServerObjectList) {
        objectsList.objects.enumerated().forEach { index, object in
            createGeoObject(object, context: geoObjectsContext)
        }
        update(historyId: objectsList.historyId, context: geoObjectsContext)
        geoObjectsContext.mr_saveToPersistentStoreAndWait()
        
        NotificationCenter.default.post(name: didUpdateGeoObjects, object: nil)
    }
    
    private func createGeoObject(_ object: ServerGeoObject, context: NSManagedObjectContext) {
        let geoObject = GeoObject.mr_createEntity(in: context)
        geoObject?.id = Int32(object.id)
        geoObject?.latitude = object.location.latitude
        geoObject?.longitude = object.location.longitude
        geoObject?.likes = Int32(object.likes)
        geoObject?.name = object.name
        geoObject?.closed = object.closed ?? false
        geoObject?.chargeable = object.fee ?? false
        geoObject?.dirty = object.dirty ?? false
        geoObject?.disabledFriendly = object.wheelchair ?? false
        geoObject?.missed = object.missed ?? false
        
        if geoObject?.missed != true {
            geoObjectClustering?.add(geoObject)
        }
    }
    
    private func apply(_ history: ServerHistory) {
        history.operations.forEach { apply($0, context: geoObjectsContext) }
        update(historyId: history.historyId, context: geoObjectsContext)
        geoObjectsContext.mr_saveToPersistentStoreAndWait()
        NotificationCenter.default.post(name: didUpdateGeoObjects, object: nil)
    }
    
    private func apply(_ operation: ServerOperation, context: NSManagedObjectContext) {
        switch operation.operation_type {
        case .new:
            addGeoObject(operation, context: context)
        case .update:
            updateGeoObject(operation, context: context)
        case .delete:
            deleteGeoObject(withId: operation.object_id, context: context)
        }
    }
    
    private func updateGeoObject(_ operation: ServerOperation, context: NSManagedObjectContext) {
        let geoObject = GeoObject.mr_findFirst(byAttribute: "id", withValue: operation.object_id, in: context)
        
        if let location = operation.location {
            geoObject?.latitude = location.latitude
            geoObject?.longitude = location.longitude
        }
        
        if let name = operation.name {
            geoObject?.name = name
        }
        
        if let likes = operation.likes {
            geoObject?.likes = Int32(likes)
        }
        
        if let dirty = operation.dirty {
            geoObject?.dirty = dirty
        }
        
        if let closed = operation.closed {
            geoObject?.closed = closed
        }
        
        if let fee = operation.fee {
            geoObject?.chargeable = fee
        }
        
        if let wheelchair = operation.wheelchair {
            geoObject?.disabledFriendly = wheelchair
        }
        
        if let missed = operation.missed {
            geoObject?.missed = missed
        }
        
        if geoObject?.missed != true {
            geoObjectClustering?.update(geoObject)
        } else {
            geoObjectClustering?.delete(geoObject)
        }
    }
    
    private func deleteGeoObject(withId id: Int, context: NSManagedObjectContext) {
        guard let geoObject = GeoObject.mr_findFirst(byAttribute: "id", withValue: id, in: context) else { return }
        geoObject.mr_deleteEntity(in: context)
        geoObjectClustering?.delete(geoObject)
    }
    
    private func addGeoObject(_ operation: ServerOperation, context: NSManagedObjectContext) {
        let geoObject = GeoObject.mr_createEntity(in: context)
        geoObject?.id = Int32(operation.object_id)
        geoObject?.latitude = operation.location?.latitude ?? 0
        geoObject?.longitude = operation.location?.longitude ?? 0
        geoObject?.name = operation.name ?? ""
        geoObject?.likes = Int32(operation.likes ?? 0)
        geoObject?.closed = operation.closed ?? false
        geoObject?.dirty = operation.dirty ?? false
        geoObject?.chargeable = operation.fee ?? false
        geoObject?.disabledFriendly = operation.wheelchair ?? false
        geoObject?.missed = operation.missed ?? false
        
        if geoObject?.missed != true {
            geoObjectClustering?.add(geoObject)
        }
    }
    
    private func update(historyId id: Int, context: NSManagedObjectContext) {
        let historyId = Int32(id)
        if let history = History.mr_findFirst(in: context) {
            history.id = historyId
        } else {
            let newHistory = History.mr_createEntity(in: context)
            newHistory?.id = historyId
        }
    }
}
