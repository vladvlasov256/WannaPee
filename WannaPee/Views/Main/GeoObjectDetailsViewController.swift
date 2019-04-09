//
//  GeoObjectDetailsViewController.swift
//  WannaPee
//
//  Created by Vladimir Vlasov on 20.05.2018.
//  Copyright © 2018 Sofatech. All rights reserved.
//

import UIKit
import Pulley
import Reachability
import LNRSimpleNotifications

private let greenColor = UIColor(red: 0, green: 204.0 / 255, blue: 0, alpha: 1)
private let redColor = UIColor(red: 1, green: 64.0 / 255, blue: 64.0 / 255, alpha: 1)
private let blackColor = UIColor.darkText

protocol GeoObjectDetailsViewControllerDelegate: class {
    var routeDestination: GeoObject? { get }
    var hasConstructedRoute: Bool { get }
    
    func showRoute(to geoObject: GeoObject, completion: @escaping (Bool) -> ())
    func hideRoute(to geoObject: GeoObject)
}

class GeoObjectDetailsViewController: UIViewController {
    weak var delegate: GeoObjectDetailsViewControllerDelegate?
    weak var container: PulleyViewController?
    
    var model: MainModel!
    
    private let routeButtonCornerRadius = CGFloat(20)
    
    private let colorChangeAnimationDuration = TimeInterval(0.5)
    
    @IBOutlet var distanceLabel: UILabel!
    
    @IBOutlet var icon0: UIImageView!
    @IBOutlet var icon1: UIImageView!
    @IBOutlet var icon2: UIImageView!
    @IBOutlet var icon3: UIImageView!
    @IBOutlet var icon4: UIImageView!
    
    @IBOutlet var routeButton: UIButton!

    @IBOutlet var likeButton: UIButton!
    @IBOutlet var dislikeButton: UIButton!
    
    @IBOutlet var dirtyButton: UIButton!
    @IBOutlet var closedButton: UIButton!
    @IBOutlet var missedButton: UIButton!
    
    @IBOutlet var report: UILabel!
    
    private lazy var icons: [UIImageView] = [icon0, icon1, icon2, icon3, icon4]
    
    private lazy var feedbackButtons: [UIButton] = [likeButton, dislikeButton, dirtyButton, closedButton, missedButton]
    
    private var isConstructingRoute = false
    
    var feedback: [FeedbackType]?
    private var processingFeedback = [FeedbackType]()
    
    var geoObject: GeoObject? {
        didSet {
            setup()
        }
    }
    
    var distance: Double? {
        didSet {
            setupDistance()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(reachabilityChanged), name: .reachabilityChanged, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        routeButton.layer.cornerRadius = routeButtonCornerRadius
        routeButton.layer.masksToBounds = true
    }
    
    @IBAction func makeRoute(_ sender: Any) {
        guard let geoObject = geoObject, let delegate = delegate else { return }
        
        if needShowRoute {
            routeButton.isEnabled = false
            isConstructingRoute = true
            
            delegate.showRoute(to: geoObject) { _ in
                self.isConstructingRoute = false
                
                DispatchQueue.main.async {
                    self.setupRouteButton()
                }
            }
            
            logShowRoute(in: model.currentVisibleCity?.name)
        } else {
            delegate.hideRoute(to: geoObject)
            setupRouteButton()
            
            logHideRoute(in: model.currentVisibleCity?.name)
        }
    }
    
    @IBAction func like(_ sender: Any) {
        guard !(feedback?.contains(.like) ?? true) else { return }
        send(like: .like, button: likeButton, oppositeButton: dislikeButton, color: greenColor)
    }
    
    @IBAction func dislike(_ sender: Any) {
        container?.setDrawerPosition(position: .open)
        
        guard !(feedback?.contains(.dislike) ?? true) else { return }
        send(like: .dislike, button: dislikeButton, oppositeButton: likeButton, color: redColor)
    }
    
    @IBAction func markDirty(_ sender: Any) {
        guard !processingFeedback.contains(.dirty) else { return }
        let cancel = feedback?.contains(.dirty) ?? false
        send(feedback: .dirty, cancel: cancel, button: dirtyButton)
    }
    
    @IBAction func markClosed(_ sender: Any) {
        guard !processingFeedback.contains(.closed) else { return }
        let cancel = feedback?.contains(.closed) ?? false
        send(feedback: .closed, cancel: cancel, button: closedButton)
    }
    
    @IBAction func markMissed(_ sender: Any) {
        guard !processingFeedback.contains(.missed) else { return }
        let cancel = feedback?.contains(.missed) ?? false
        send(feedback: .missed, cancel: cancel, button: missedButton)
    }
    
    private func send(like: FeedbackType, button: UIButton, oppositeButton: UIButton, color: UIColor) {
        guard let geoObject = self.geoObject else { return }
        
        self.feedback?.append(like)
        
        let hadOpposite = self.feedback?.contains(like.opposite!) ?? false
        if hadOpposite {
            self.feedback?.removeOpposite(to: like)
        }
        
        UIView.animate(withDuration: colorChangeAnimationDuration) {
            button.tintColor = color
            
            if hadOpposite {
                oppositeButton.tintColor = blackColor
            }
        }
        
        let completion = { (likes: Int?, error: NetworkError?) in
            if error == nil {
                self.model.feedbackModel.set(like, remove: like.opposite, for: geoObject.id)
            }
            
            if let likes = likes {
                self.model.set(likes, for: geoObject)
            }
            
            DispatchQueue.main.async {
                guard geoObject.id == self.geoObject?.id else { return }
                if let _ = error {
                    self.remove(like)
                    
                    if hadOpposite {
                        self.feedback?.append(like.opposite!)
                        oppositeButton.tintColor = color
                    }
                    
                    button.tintColor = blackColor
                    
                    self.presentError()
                } else if let likes = likes {
                    self.setupIcons(with: likes)
                }
            }
        }
        
        switch like {
        case .like:
            model.networkModel.like(geoObject.id, completion: completion)
        case .dislike:
            model.networkModel.dislike(geoObject.id, completion: completion)
        default:
            break
        }
        
        log(feedback: like, cancel: false, in: model.currentVisibleCity?.name)
    }
    
    private var hasLikeOrDislike: Bool {
        guard let feedback = self.feedback else { return true }
        return feedback.contains(.like) || feedback.contains(.dislike)
    }
    
    private func remove(_ feedback: FeedbackType) {
        if let index = self.feedback?.index(of: feedback) {
            self.feedback?.remove(at: index)
        }
    }
    
    private func send(feedback: FeedbackType, cancel: Bool, button: UIButton) {
        guard let geoObject = self.geoObject else { return }
        
        processingFeedback.append(feedback)
        
        if cancel {
            self.remove(feedback)
        } else {
            self.feedback?.append(feedback)
        }
        
        let color = cancel ? blackColor : redColor
        let fallbackColor = cancel ? redColor : blackColor
        
        UIView.transition(with: button, duration: colorChangeAnimationDuration, options: .transitionCrossDissolve, animations: {
            button.tintColor = color
            button.setTitleColor(color, for: .normal)
        }, completion: nil)
        
        let completion = { (error: NetworkError?) in
            if let _ = error {
                DispatchQueue.main.async {
                    guard geoObject.id == self.geoObject?.id else { return }
                    
                    if cancel {
                        self.feedback?.append(feedback)
                    } else {
                        self.remove(feedback)
                    }
                    
                    button.tintColor = fallbackColor
                    button.setTitleColor(fallbackColor, for: .normal)
                    
                    self.presentError()
                }
            } else {
                if cancel {
                    self.model.feedbackModel.remove(feedback, for: geoObject.id)
                } else {
                    self.model.feedbackModel.set(feedback, for: geoObject.id)
                }
            }
            
            DispatchQueue.main.async {
                if let index = self.processingFeedback.index(of: feedback) {
                    self.processingFeedback.remove(at: index)
                }
            }
        }
        
        switch feedback {
        case .dirty:
            model.networkModel.dirty(geoObject.id, cancel: cancel, completion: completion)
        case .closed:
            model.networkModel.closed(geoObject.id, cancel: cancel, completion: completion)
        case .missed:
            model.networkModel.missed(geoObject.id, cancel: cancel, completion: completion)
        default:
            break
        }
        
        log(feedback: feedback, cancel: cancel, in: model.currentVisibleCity?.name)
    }
    
    private func setup() {
        isConstructingRoute = false
        processingFeedback = [FeedbackType]()
        
        setupIcons()
        setupDistance()
        setupRouteButton()
        setupFeedbackButtons()
    }
    
    private func setupIcons(with likes: Int? = nil) {
        let states = geoObject?.states(with: likes) ?? []
        zip(states.reversed(), icons.reversed()).forEach { element in
            element.1.image = icon(for: element.0)
        }
        
        if states.count < icons.count {
            (0..<icons.count - states.count).forEach { index in
                icons[index].image = nil
            }
        }
    }
    
    private func setupDistance() {
        distanceLabel.text = text(from: distance)
    }
    
    private var needShowRoute: Bool {
        guard let delegate = delegate, let geoObject = geoObject else { return true }
        return delegate.routeDestination?.id != geoObject.id
    }
    
    private var isRouteButtonEnabled: Bool {
        if needShowRoute {
            let connection = model?.reachability.connection ?? .none
            return !isConstructingRoute && (connection != .none)
        } else {
            return delegate?.hasConstructedRoute ?? false
        }
    }
    
    private func setupRouteButton() {
        routeButton.isEnabled = isRouteButtonEnabled
        let title = NSLocalizedString(needShowRoute ? "Route" : "Hide Route", comment: "")
        routeButton.setTitle(title, for: .normal)
    }
    
    private func setupFeedbackButtons() {
        guard let geoObject = geoObject else { return }
        
        feedback = nil
        
        feedbackButtons.forEach { $0.isEnabled = false }
        report.isEnabled = model.reachability.connection != .none
        
        model.feedbackModel.feedback(for: geoObject.id) { feedback in
            DispatchQueue.main.async {
                guard geoObject.id == self.geoObject?.id else { return }
                self.feedback = feedback
                self.setupFeedbackButtons(with: feedback)
                let isOnline = self.model.reachability.connection != .none
                self.feedbackButtons.forEach { $0.isEnabled = isOnline }
            }
        }
    }
    
    private func setupFeedbackButtons(with feedback: [FeedbackType]) {
        likeButton.tintColor = feedback.contains(.like) ? greenColor : blackColor
        dislikeButton.tintColor = feedback.contains(.dislike) ? redColor : blackColor
        
        let dirtyButtonColor = feedback.contains(.dirty) ? redColor : blackColor
        dirtyButton.tintColor = dirtyButtonColor
        dirtyButton.setTitleColor(dirtyButtonColor, for: .normal)
        
        let closedButtonColor = feedback.contains(.closed) ? redColor : blackColor
        closedButton.tintColor = closedButtonColor
        closedButton.setTitleColor(closedButtonColor, for: .normal)
        
        let missedButtonColor = feedback.contains(.missed) ? redColor : blackColor
        missedButton.tintColor = missedButtonColor
        missedButton.setTitleColor(missedButtonColor, for: .normal)
    }
    
    private func text(from distance: Double?) -> String? {
        guard let distance = distance else { return nil }
        
        if #available(iOS 10.0, *) {
            let measurementFormatter = MeasurementFormatter()
            measurementFormatter.unitOptions = .naturalScale
            let numberFormatter = NumberFormatter()
            numberFormatter.minimumIntegerDigits = 1
            numberFormatter.maximumFractionDigits = (distance > 1000) ? 1 : 0
            measurementFormatter.numberFormatter = numberFormatter
            measurementFormatter.locale = Locale.current
            let measurement = Measurement(value: distance, unit: UnitLength.meters)
            return measurementFormatter.string(from: measurement)
        } else {
            if distance > 1000 {
                let kilometer = NSLocalizedString("km", comment: "")
                return String(format: "%.1f \(kilometer)", distance / 1000)
            } else {
                let meter = NSLocalizedString("m", comment: "")
                return String(format: "%d \(meter)", (Int(distance) / 10) * 10)
            }
        }
    }
    
    private func icon(for state: GeoObjectState) -> UIImage {
        switch state {
        case .liked:
            return #imageLiteral(resourceName: "liked")
        case .disliked:
            return #imageLiteral(resourceName: "disliked")
        case .closed:
            return #imageLiteral(resourceName: "closed")
        case .dirty:
            return #imageLiteral(resourceName: "dirty")
        case .chargeable:
            return #imageLiteral(resourceName: "chargeable")
        case .disabledFriendly:
            return #imageLiteral(resourceName: "disabled")
        }
    }
    
    @objc private func reachabilityChanged() {
        routeButton.isEnabled = isRouteButtonEnabled
        
        guard let connection = model?.reachability.connection else { return }
        let isOnline = connection != .none
        feedbackButtons.forEach { button in
            button.isEnabled = isOnline
            button.titleLabel?.isEnabled = isOnline
        }
        report.isEnabled = isOnline
    }
    
    private func presentError() {
        let title = NSLocalizedString("Something went wrong", comment: "")
        let text = NSLocalizedString("Please, try to submit feedback later.", comment: "")
        let notification = LNRNotification(title: title, body: text)
        notification.duration = 5
        notificationManager.showNotification(notification: notification)
    }
}

// MARK: - Drawer

private let defaultDetailsHeight = CGFloat(326)

var detailsHeight: CGFloat {
    if #available(iOS 11.0, *) {
        let window = UIApplication.shared.keyWindow
        let bottom = window?.safeAreaInsets.bottom ?? 0
        return defaultDetailsHeight + bottom
    } else {
        return defaultDetailsHeight
    }

}

extension GeoObjectDetailsViewController: PulleyDrawerViewControllerDelegate {
    func collapsedDrawerHeight() -> CGFloat {
        return 80
    }
    
    func partialRevealDrawerHeight() -> CGFloat {
        return 216
    }
    
    func supportedDrawerPositions() -> [PulleyPosition] {
        return [.open, .collapsed, .partiallyRevealed, .closed]
    }
}

private enum GeoObjectState {
    case liked, disliked, closed, dirty, chargeable, disabledFriendly
}

private extension GeoObject {
    func states(with likes: Int? = nil) -> [GeoObjectState] {
        var result = [GeoObjectState]()
        
        let likes = likes ?? Int(self.likes)
        if likes > 0 {
            result.append(.liked)
        } else if likes < 0 {
            result.append(.disliked)
        }
        
        if closed {
            result.append(.closed)
        }
        
        if dirty {
            result.append(.dirty)
        }
        
        if chargeable {
            result.append(.chargeable)
        }
        
        if disabledFriendly {
            result.append(.disabledFriendly)
        }
        
        return result
    }
}

extension Array where Element == FeedbackType {
    mutating func removeOpposite(to feedback: FeedbackType) {
        guard let oppositeFeedback = feedback.opposite else { return }
        if let index = index(where: { $0 == oppositeFeedback }) {
            remove(at: index)
        }
    }
}

extension FeedbackType {
    var opposite: FeedbackType? {
        switch self {
        case .like:
            return .dislike
        case .dislike:
            return .like
        default:
            return nil
        }
    }
}
