//
//  ChatListViewController.swift
//  PoseFinder
//
//  Created by 三浦将太 on 2020/11/04.
//  Copyright © 2020 Apple. All rights reserved.
//

import UIKit

class ChatListViewController: UIViewController {
    
    @IBOutlet private weak var tblChatList: ChatListTableView? {
        didSet {
            
            guard let tblChatList = tblChatList else {
                return
            }
            
            tblChatList.nickName = nickName
        }
    }
    
    var nickName: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configuration()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.isHidden = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
}

// MARK:- Private Methods -
extension ChatListViewController {
    
    private func configuration() {
        
        guard let name = nickName else {
            return
        }
        
        title = "Welcome \(name)"

        configureTableView()
    }
    
    @IBAction func navigationRightBarButton() {
        
        exitButtonCLK()
        
        //self.navigationItem.rightBarButtonItem = UIBarButtonItem(
        //    title: "ログアウト",
        //    style: .done,
        //    target: self,
        //    action: #selector(exitButtonCLK)
        //)
    }
    
    private func configureTableView() {
        
        guard let tblChatList = tblChatList else {
            return
        }
        
        tblChatList.onDidSelect = { [weak self] (user: User) in
            
            guard let self = self,
            let name = self.nickName else {
                return
            }
            
            let storyboard = UIStoryboard(name: "chat", bundle: nil)
            
            guard let chatDetailViewController = storyboard.instantiateViewController(withIdentifier: "ChatDetailViewController") as? ChatDetailViewController else{
                return
            }
            chatDetailViewController.user = user
            chatDetailViewController.nickName = name
            self.present(chatDetailViewController, animated: true, completion: nil)
        }
    }
}

// MARK:- Action Events -
extension ChatListViewController {
    
    @objc func exitButtonCLK() {
        
        guard let name = nickName else {
            return
        }
        
        SocketHelper.shared.leaveChatRoom(nickname: name) { [weak self] in
            guard let self = self else {
                return
            }
            
            //self.navigationController?.popViewController(animated: true)
            //self.dismiss(animated: true, completion: nil)
            let storyboard = UIStoryboard(name: "chat", bundle: nil)
            
            guard let JoinChatViewController = storyboard.instantiateViewController(withIdentifier: "JoinChatViewController") as? JoinChatViewController else{
                return
            }
            
            self.present(JoinChatViewController, animated: true, completion: nil)
        }
        
    }
}

