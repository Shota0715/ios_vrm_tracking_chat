//
//  ChatViewModel.swift
//  PoseFinder
//
//  Created by 三浦将太 on 2020/11/04.
//  Copyright © 2020 Apple. All rights reserved.
//

import Foundation

final class ChatViewModel {
    
    var arrUsers: KxSwift<[User]> = KxSwift<[User]>([])
    
    func fetchParticipantList(_ name: String) {
        
        SocketHelper.shared.participantList {[weak self] (result: [User]?) in
            
            guard let self = self,
                let users = result else{
                    return
            }
            
            var filterUsers: [User] = users
            //この時点で相手のデータがリストにない！
            // Removed login user from list
            if let index = filterUsers.firstIndex(where: {$0.nickname == name}) {
                filterUsers.remove(at: index)
            }
            self.arrUsers.value = filterUsers
        }
    }
}
