//
//  NetworkModel.swift
//  WannaPee
//
//  Created by Vladimir Vlasov on 24.05.2018.
//  Copyright © 2018 Sofatech. All rights reserved.
//

import GLMap
import GLMapSwift

struct GeoObjectPoint: Codable {
    let longitude: Double
    let latitude: Double
    
    init(_ point: GLMapGeoPoint) {
        longitude = point.lon
        latitude = point.lat
    }
}

struct ServerGeoObject: Codable {
    let id: Int
    let name: String
    let location: GeoObjectPoint
    let likes: Int
    let dirty: Bool?
    let closed: Bool?
    let wheelchair: Bool?
    let fee: Bool?
    let missed: Bool?
}

struct ServerObjectList: Codable {
    let objects: [ServerGeoObject]
    let historyId: Int
}

enum ServerOperationType: String, Codable {
    case new = "new"
    case delete = "delete"
    case update = "update"
}

struct ServerOperation: Codable {
    let id: Int
    let object_id: Int
    let operation_type: ServerOperationType
    let name: String?
    let location: GeoObjectPoint?
    let likes: Int?
    let dirty: Bool?
    let closed: Bool?
    let wheelchair: Bool?
    let fee: Bool?
    let missed: Bool?
}

struct ServerHistory: Codable {
    let operations: [ServerOperation]
    let historyId: Int
}

private struct LikeOperation: Codable {
    let likes: Int
}

struct UserAction: Codable {
    let object_id: Int
    let type: String
    
    var feedback: FeedbackType? {
        return FeedbackType(type)
    }
}

private struct Toilet: Codable {
    let name: String
    let location: GeoObjectPoint
    let fee: Bool
    let wheelchair: Bool
    let photo: String
    
    init(location: GLMapGeoPoint, fee: Bool, wheelchair: Bool, photo: UIImage?) {
        name = "WC"
        self.location = GeoObjectPoint(location)
        self.fee = fee
        self.wheelchair = wheelchair
        self.photo = photo?.base64 ?? ""
    }
    
    var body: Data? {
        do {
            let encoder = JSONEncoder()
            return try encoder.encode(self)
        } catch {
            return nil
        }
    }
}

private let baseUrl = "https://wannapee.ru/v1/"
private let objectsListQuery = "objects/list"
private let objectsHistoryQuery = "objects/history/"
private let likeCommand = "objects/like/"
private let dislikeCommand = "objects/dislike/"
private let dirtyCommand = "objects/dirty/"
private let closedCommand = "objects/closed/"
private let missedCommand = "objects/missed/"
private let actionsQuery = "objects/actions/"
private let newCommand = "objects/new"

enum NetworkError: Error, CustomStringConvertible {
    case network(Error)
    case noResponse
    case code(Int)
    case parsing(Error)
    
    var description: String {
        switch self {
        case .network(let error):
            return error.localizedDescription
        case .noResponse:
            return "no response"
        case .code(let code):
            return "error code \(code)"
        case .parsing(let error):
            return error.localizedDescription
        }
    }
}

class NetworkModel {
    func objects(completion: @escaping (ServerObjectList?, NetworkError?) -> ()) {
        let url = URL(string: "\(baseUrl)\(objectsListQuery)?token=\(token)")!
        request(url) { data, error in
            if let error = error {
                completion(nil, error)                
            } else if let data = data {
                do {
                    try completion(self.parse(objectsData: data), nil)
                } catch {
                    completion(nil, .parsing(error))
                }
            }
        }
    }
    
    func history(_ id: Int, completion: @escaping (ServerHistory?, NetworkError?) -> ()) {
        let url = URL(string: "\(baseUrl)\(objectsHistoryQuery)\(id)?token=\(token)")!
        request(url) { data, error in
            if let error = error {
                completion(nil, error)
            } else if let data = data {
                do {
                    try completion(self.parse(historyData: data), nil)
                } catch {
                    completion(nil, .parsing(error))
                }
            }
        }
    }
    
    func actions(completion: @escaping ([UserAction]?, NetworkError?) -> ()) {
        let url = URL(string: "\(baseUrl)\(actionsQuery)\(token)")!
        request(url) { data, error in
            if let error = error {
                completion(nil, error)
            } else if let data = data {
                do {
                    try completion(self.parse(userActions: data), nil)
                } catch {
                    completion(nil, .parsing(error))
                }
            }
        }
    }
    
    private func request(_ url: URL, completion: @escaping (Data?, NetworkError?) -> ()) {
        let defaultSession = URLSession(configuration: .default)
        let dataTask = defaultSession.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(nil, .network(error))
            } else if let data = data,
                let response = response as? HTTPURLResponse {
                if response.statusCode == 200 {
                    completion(data, nil)
                } else {
                    completion(nil, .code(response.statusCode))
                }
            } else {
                completion(nil, .noResponse)
            }
        }
        
        dataTask.resume()
    }
    
    func like(_ id: Int32, completion: @escaping (Int?, NetworkError?) -> ()) {
        let url = URL(string: "\(baseUrl)\(likeCommand)\(id)?token=\(token)")!
        postLike(url, completion: completion)
    }
    
    func dislike(_ id: Int32, completion: @escaping (Int?, NetworkError?) -> ()) {
        let url = URL(string: "\(baseUrl)\(dislikeCommand)\(id)?token=\(token)")!
        postLike(url, completion: completion)
    }
    
    private func postLike(_ url: URL, completion: @escaping (Int?, NetworkError?) -> ()) {
        post(url) { data, error in
            if let error = error {
                completion(nil, error)
            } else if let data = data {
                do {
                    try completion(self.parse(likesData: data), nil)
                } catch {
                    completion(nil, .parsing(error))
                }
            }
        }
    }
    
    func dirty(_ id: Int32, cancel: Bool = false, completion: @escaping (NetworkError?) -> ()) {
        let url = URL(string: "\(baseUrl)\(dirtyCommand)\(id)?token=\(token)")!
        postFeedback(url, cancel: cancel, completion: completion)
    }
    
    func closed(_ id: Int32, cancel: Bool = false, completion: @escaping (NetworkError?) -> ()) {
        let url = URL(string: "\(baseUrl)\(closedCommand)\(id)?token=\(token)")!
        postFeedback(url, cancel: cancel, completion: completion)
    }
    
    func missed(_ id: Int32, cancel: Bool = false, completion: @escaping (NetworkError?) -> ()) {
        let url = URL(string: "\(baseUrl)\(missedCommand)\(id)?token=\(token)")!
        postFeedback(url, cancel: cancel, completion: completion)
    }
    
    private func postFeedback(_ url: URL, cancel: Bool = false, completion: @escaping (NetworkError?) -> ()) {
        let body = cancel ? cancelFeedbackBody : emptyBody
        post(url, body: body) { _, error in
            completion(error)
        }
    }
    
    private var cancelFeedbackBody: Data? {
        do {
            let encoder = JSONEncoder()
            return try encoder.encode(["cancel": true])
        } catch {
            return nil
        }
    }
    
    func postToilet(with location: GLMapGeoPoint, fee: Bool, wheelchair: Bool, photo: UIImage?, completion: @escaping (NetworkError?) -> ()) {
        let toilet = Toilet(location: location, fee: fee, wheelchair: wheelchair, photo: photo)
        post(toilet, completion: completion)
    }
    
    private func post(_ toilet: Toilet, completion: @escaping (NetworkError?) -> ()) {
        let url = URL(string: "\(baseUrl)\(newCommand)?token=\(token)")!
        post(url, body: toilet.body) { _, error in
            completion(error)
        }
    }
    
    private func post(_ url: URL, body: Data? = emptyBody, completion: @escaping (Data?, NetworkError?) -> ()) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(nil, .network(error))
            } else if let data = data,
                let response = response as? HTTPURLResponse {
                if response.statusCode == 200 {
                    completion(data, nil)
                } else {
                    completion(nil, .code(response.statusCode))
                }
            } else {
                completion(nil, .noResponse)
            }
        }
        task.resume()
    }
    
    private func parse(objectsData data: Data) throws -> ServerObjectList {
        return try JSONDecoder().decode(ServerObjectList.self, from: data)
    }
    
    private func parse(historyData data: Data) throws -> ServerHistory {
        return try JSONDecoder().decode(ServerHistory.self, from: data)
    }
    
    private func parse(likesData data: Data) throws -> Int {
        return try JSONDecoder().decode(LikeOperation.self, from: data).likes
    }
    
    private func parse(userActions data: Data) throws -> [UserAction] {
        return try JSONDecoder().decode([UserAction].self, from: data)
    }
}

private var emptyBody: Data? = {
    do {
        return try JSONSerialization.data(withJSONObject: [String: Any](), options: [])
    } catch {
        return nil
    }
}()
