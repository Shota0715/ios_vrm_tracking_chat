//
//  ChatDetailsTableView.swift
//  PoseFinder
//
//  Created by 三浦将太 on 2020/11/04.
//  Copyright © 2020 Apple. All rights reserved.
//

import UIKit

class ChatDetailsTableView: UITableView, UITableViewDelegate, UITableViewDataSource {
    
    private var messageViewModel: MessageViewModel = MessageViewModel()
    var nickName: String?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        configuartionTableView()
        configureViewModel()
    }
    
    private func configuartionTableView() {
        
        self.register(UINib(nibName: "MessageSendTableViewCell", bundle: nil), forCellReuseIdentifier: "MessageSendTableViewCell")
        self.register(UINib(nibName: "MessageTableViewCell", bundle: nil), forCellReuseIdentifier: "MessageTableViewCell")
        
        self.dataSource = self
        self.delegate = self
    }

    private func configureViewModel() {
        
        messageViewModel.arrMessage.subscribe { [weak self] (result: [Message]) in
            
            guard let self = self else {
                return
            }
            
            self.reloadData()
            self.scrollToBottom(animated: false)
        }
        
        messageViewModel.getMessagesFromServer()
    }
}

// MARK: - Table view data source
extension ChatDetailsTableView {
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let message: Message = messageViewModel.arrMessage.value[indexPath.row]
        
        //入ってきたメッセージが自分のだったら
        if message.nickname == nickName {
            
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "MessageSendTableViewCell") as? MessageSendTableViewCell else {
                return UITableView.emptyCell()
            }
            
            cell.configureCell(message)
            return cell
            
        }
        //それ以外のメッセージは
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "MessageTableViewCell") as? MessageTableViewCell else {
            return UITableView.emptyCell()
        }
        
        cell.configureCell(message)
        return cell
   }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messageViewModel.arrMessage.value.count
    }
}
