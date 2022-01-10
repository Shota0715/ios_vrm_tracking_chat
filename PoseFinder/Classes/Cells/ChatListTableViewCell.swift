//
//  ChatListTableViewCell.swift
//  PoseFinder
//
//  Created by 三浦将太 on 2020/11/05.
//  Copyright © 2020 Apple. All rights reserved.
//

import UIKit

class ChatListTableViewCell: UITableViewCell {

    @IBOutlet weak var lblName: UILabel!
    @IBOutlet weak var viewOnlineStatus: UIView! {
        didSet {
            viewOnlineStatus.layer.cornerRadius = viewOnlineStatus.frame.width/2
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    func configureCell(_ user: User) {
        lblName.text = user.nickname ?? ""
        viewOnlineStatus.isHidden = !(user.isConnected ?? false)
    }
    
}
