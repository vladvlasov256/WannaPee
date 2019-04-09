//
//  MenuCell.swift
//  WannaPee
//
//  Created by Vladimir Vlasov on 11.06.2018.
//  Copyright © 2018 Sofatech. All rights reserved.
//

import UIKit

class MenuCell: UITableViewCell {
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        let bgColorView = UIView()
        bgColorView.backgroundColor = UIColor.white.withAlphaComponent(0.5)
        selectedBackgroundView = bgColorView
    }
}
