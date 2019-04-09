//
//  OfflineMapCell.swift
//  WannaPee
//
//  Created by Vladimir Vlasov on 20.05.2018.
//  Copyright © 2018 Sofatech. All rights reserved.
//

import UIKit
import MRProgress
import Reachability

class OfflineMapCell: UITableViewCell {
    static let heights: [UInt8] = [100, 87, 247, 81, 198, 114, 66, 17, 175, 33, 28, 191, 32, 51, 146, 222]
    
    @IBOutlet var name: UILabel!
    @IBOutlet var size: UILabel!
    @IBOutlet var youAreHere: UILabel!
    @IBOutlet var progress: MRCircularProgressView!
    @IBOutlet var button: UIButton!
    @IBOutlet var icon: UIImageView!
    @IBOutlet private var youAreHereTopConstraint: NSLayoutConstraint!
    @IBOutlet private var youAreHereBottomConstraint: NSLayoutConstraint!
    @IBOutlet private var sizeBottomConstraint: NSLayoutConstraint!
    
    @objc var offlineMap: OfflineMap! {
        didSet {
            guard oldValue !== offlineMap else {
                setup()
                return
            }
            removeObservers(from: oldValue)
            setup()
            addObservers(to: offlineMap)
        }
    }
    
    var reachability: Reachability!
    
    deinit {
        removeObservers(from: offlineMap)
        NotificationCenter.default.removeObserver(self)
    }
    
    private func addObservers(to offlineMap: OfflineMap?) {
        offlineMap?.addObserver(self, forKeyPath: #keyPath(OfflineMap.progress), options: .new, context: nil)
        offlineMap?.addObserver(self, forKeyPath: #keyPath(OfflineMap.status), options: .new, context: nil)
    }
    
    private func removeObservers(from offlineMap: OfflineMap?) {
        offlineMap?.removeObserver(self, forKeyPath: #keyPath(OfflineMap.progress))
        offlineMap?.removeObserver(self, forKeyPath: #keyPath(OfflineMap.status))
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        progress.mayStop = true
        progress.stopButton.addTarget(self, action: #selector(stop), for: .touchUpInside)
        progress.borderWidth = 2
        progress.lineWidth = 3.5
        
        youAreHere.layer.masksToBounds = true
        youAreHere.layer.cornerRadius = 4
        
        NotificationCenter.default.addObserver(self, selector: #selector(reachabilityChanged), name: .reachabilityChanged, object: nil)
    }
    
    @IBAction func download(_ sender: Any) {
        logOfflineMapAction(map: offlineMap.name, action: "download")
        offlineMap.download()
    }
    
    @objc func stop(_ sender: Any) {
        logOfflineMapAction(map: offlineMap.name, action: "stop")
        offlineMap.cancelDownloading()
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        let oldOfflineMap = offlineMap
        if keyPath == #keyPath(OfflineMap.progress) {
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self, let offlineMap = oldOfflineMap, offlineMap.id == strongSelf.offlineMap.id else { return }
                strongSelf.progress?.progress = strongSelf.clamp(offlineMap.progress)
            }
        } else if keyPath == #keyPath(OfflineMap.status) {
            DispatchQueue.main.async { [weak self] in
                guard let offlineMap = oldOfflineMap, offlineMap.id == self?.offlineMap.id else { return }
                self?.setup(status: offlineMap.status)
            }
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    private func setup() {
        name.attributedText = nameAttributedText
        name.sizeToFit()
        
        if let mapSize = offlineMap.size {
            size.text = "\(mapSize) \(NSLocalizedString("MB", comment: ""))"
        } else {
            size.text = nil
        }
        size.sizeToFit()
        
        progress.progress = clamp(offlineMap.progress)
        setup(status: offlineMap.status)
        
        if offlineMap.isHere {
            youAreHere.attributedText = locationText
            youAreHere.sizeToFit()
        }
        
        youAreHere.isHidden = !offlineMap.isHere

        if offlineMap.isHere {
            [sizeBottomConstraint].forEach { $0!.priority = .defaultLow }
            [youAreHereBottomConstraint, youAreHereTopConstraint].forEach { $0!.priority = .defaultHigh }
        } else {
            [sizeBottomConstraint].forEach { $0!.priority = .defaultHigh }
            [youAreHereBottomConstraint, youAreHereTopConstraint].forEach { $0!.priority = .defaultLow }
        }
        
        setNeedsDisplay()
        setNeedsUpdateConstraints()
        setNeedsLayout()
    }
    
    override func updateConstraints() {
        super.updateConstraints()
    }
    
    private lazy var locationText: NSAttributedString? = {
        let text = NSMutableAttributedString(attributedString: youAreHere.attributedText ?? NSAttributedString(string: ""))
        text.mutableString.setString(NSLocalizedString("You are here", comment: ""))
        return text.copy() as? NSAttributedString
    }()
    
    private var nameAttributedText: NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 0
        paragraphStyle.lineHeightMultiple = 1.25
        
        let attributes = [NSAttributedStringKey.paragraphStyle: paragraphStyle]
        
        return NSAttributedString(string: offlineMap.localizedName, attributes: attributes)
    }
    
    private func setup(status: OfflineMapStatus) {
        progress.isHidden = offlineMap.status != .inProgress
        
        let connection = reachability?.connection ?? .none
        button.isEnabled = connection != .none
        button.isHidden = offlineMap.status != .notDownloaded
        
        icon.isHidden = offlineMap.status != .downloaded
    }
    
    private func clamp(_ progress: NSNumber?) -> Float {
        guard let progress = progress else { return 0 }
        return min(max(progress.floatValue, 0), 1)
    }
    
    @objc private func reachabilityChanged() {
        let connection = reachability?.connection ?? .none
        button.isEnabled = connection != .none
    }
}
