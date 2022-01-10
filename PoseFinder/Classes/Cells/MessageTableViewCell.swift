//
//  MessageTableViewCell.swift
//  PoseFinder
//
//  Created by 三浦将太 on 2020/11/05.
//  Copyright © 2020 Apple. All rights reserved.
//

import UIKit

class MessageTableViewCell: UITableViewCell {
    
    @IBOutlet weak var lblMessage: UILabel!
    @IBOutlet weak var lblDate: UILabel!
    
    @IBOutlet weak var viewContainer: UIView!{
        didSet {
            viewContainer.layer.cornerRadius = 8.0
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    func configureCell(_ message: Message) {
        
        self.lblMessage.text = message.message ?? ""
        self.lblDate.text = message.date ?? ""
    }
    
}
