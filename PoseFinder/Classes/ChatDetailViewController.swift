//
//  ChatDetailViewController.swift
//  PoseFinder
//
//  Created by 三浦将太 on 2020/11/04.
//  Copyright © 2020 Apple. All rights reserved.
//

import UIKit

class ChatDetailViewController: UIViewController {

    @IBOutlet weak var tblChat: ChatDetailsTableView! {
        didSet {
            
            guard let tblChat = tblChat else {
                return
            }
            
            tblChat.nickName = nickName
        }
    }
    
    var user: User?
    var nickName: String?
    
    @IBOutlet weak var txtMessage: UITextView! {
        didSet {
            txtMessage.layer.cornerRadius = txtMessage.frame.height/2
            txtMessage.layer.borderWidth = 1.0
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureNavigation()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.isHidden = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    private func configureNavigation() {
        
        guard let user = user else {
            return
        }
        
        title = user.nickname
    }
    
    @IBAction private func moveToChatList(_ sender: UIButton) {
    
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction private func moveToPosenet(_ sender: UIButton) {
        
        guard let user = user else {
            return
        }
        guard let nickname = nickName else {
            return
        }
        
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        
        guard let ViewController = storyboard.instantiateViewController(withIdentifier: "ViewController") as? ViewController else{
            return
        }
        ViewController.user = user
        ViewController.nickName = nickname
        //self.navigationController?.pushViewController(chatDetailViewController, animated: true)
        self.present(ViewController, animated: true, completion: nil)
    }

}

// MARK:- Action Evetns -
extension ChatDetailViewController {
    
    @IBAction func btnSendCLK(_ sender: UIButton) {
        
        guard txtMessage.text.count > 0,
            let message = txtMessage.text,
            let name = nickName else {
            print("Please type your message.")
            return
        }
        
        txtMessage.resignFirstResponder()
        SocketHelper.shared.sendMessage(message: message, withNickname: name)
        txtMessage.text = nil
    }
}
