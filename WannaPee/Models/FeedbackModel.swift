//
//  FeedbackModel.swift
//  WannaPee
//
//  Created by Vladimir Vlasov on 29.05.2018.
//  Copyright © 2018 Sofatech. All rights reserved.
//

import MagicalRecord

enum FeedbackType: Int16, CustomStringConvertible {
    case like, dislike, dirty, closed, missed
    
    var description: String {
        switch self {
        case .like:
            return "like"
        case .dislike:
            return "dislike"
        case .dirty:
            return "dirty"
        case .closed:
            return "closed"
        case .missed:
            return "missed"
        }
    }
    
    init?(_ name: String) {
        guard let type = FeedbackType.all.first(where: { $0.description.caseInsensitiveCompare(name) == .orderedSame }) else { return nil }
        self.init(rawValue: type.rawValue)
    }
    
    static var all: [FeedbackType] {
        return [like, dislike, dirty, closed, missed]
    }
}

class FeedbackModel {
    private let geoObjectsQueue = DispatchQueue(label: "feedback queue")
    
    init() {
        MagicalRecord.setDefaultModelFrom(Feedback.self)
    }
    
    private lazy var context: NSManagedObjectContext = {
        let coordinator = NSPersistentStoreCoordinator.mr_default()
        return NSManagedObjectContext.mr_context(with: coordinator!)
    }()
    
    func feedback(for id: Int32, completion: @escaping ([FeedbackType]) -> ()) {
        geoObjectsQueue.async {
            let predicate = NSPredicate(format: "id == %d", id)
            let events = Feedback.mr_findAll(with: predicate, in: self.context) as? [Feedback]
            let types = events?.compactMap { FeedbackType(rawValue: $0.type) }
            completion(types ?? [])
        }
    }
    
    func set(_ type: FeedbackType, for id: Int32) {
        geoObjectsQueue.async {
            let feedback = Feedback.mr_createEntity(in: self.context)
            feedback?.id = id
            feedback?.type = type.rawValue
            self.context.mr_saveToPersistentStoreAndWait()
        }
    }
    
    func set(_ type: FeedbackType, remove removed: FeedbackType?, for id: Int32) {
        geoObjectsQueue.async {
            let feedback = Feedback.mr_createEntity(in: self.context)
            feedback?.id = id
            feedback?.type = type.rawValue
            
            if let removed = removed {
                let predicate = NSPredicate(format: "(id == %d) AND (type == %d)", id, removed.rawValue)
                let removedEvents = Feedback.mr_findAll(with: predicate, in: self.context) as? [Feedback]
                removedEvents?.forEach { $0.mr_deleteEntity(in: self.context) }
            }
            
            self.context.mr_saveToPersistentStoreAndWait()
        }
    }
    
    func remove(_ type: FeedbackType, for id: Int32) {
        geoObjectsQueue.async {
            let predicate = NSPredicate(format: "(id == %d) AND (type == %d)", id, type.rawValue)
            let removedEvents = Feedback.mr_findAll(with: predicate, in: self.context) as? [Feedback]
            removedEvents?.forEach { $0.mr_deleteEntity(in: self.context) }
            
            self.context.mr_saveToPersistentStoreAndWait()
        }
    }
    
    func apply(_ userActions: [UserAction]) {
        geoObjectsQueue.async {
            userActions.forEach { action in
                guard let feedbackType = action.feedback else { return }
                let feedback = Feedback.mr_createEntity(in: self.context)
                feedback?.id = Int32(action.object_id)
                feedback?.type = feedbackType.rawValue
            }
            
            self.context.mr_saveToPersistentStoreAndWait()
        }
    }
    
    func hasFeedback(completion: @escaping (Bool) -> ()) {
        geoObjectsQueue.async {
            let events = Feedback.mr_findAll(in: self.context) as? [Feedback]
            completion((events?.count ?? 0) > 0)
        }
    }
}
