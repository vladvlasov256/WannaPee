//
//  OfflineMapsViewController.swift
//  WannaPee
//
//  Created by Vladimir Vlasov on 20.05.2018.
//  Copyright © 2018 Sofatech. All rights reserved.
//

import UIKit

class OfflineMapsViewController: UITableViewController {
    var model: MainModel! {
        didSet {
            tableView?.reloadData()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(updateOfflineMaps(notification:)), name: didUpdateOfflineMaps, object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        logContentView(name: "OfflineMaps", type: "Screen")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @IBAction func back(_ sender: Any) {
        dismiss(animated: true)
    }
    
    @objc private func updateOfflineMaps(notification: NSNotification) {
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return model?.offlineMaps?.count ?? 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "regionCell", for: indexPath) as! OfflineMapCell
        cell.reachability = model.reachability
        cell.offlineMap = model.offlineMaps?[indexPath.row]
        cell.updateConstraintsIfNeeded()
        cell.layoutIfNeeded()        
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return model.offlineMaps?[indexPath.row].status == .downloaded
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            guard let offlineMap = model.offlineMaps?[indexPath.row] else { return }
            offlineMap.delete()
            logOfflineMapAction(map: offlineMap.name, action: "delete")
        }
    }
}
