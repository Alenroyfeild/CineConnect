//
//  BaseAPIService.swift
//  Assignment
//
//  Created by Balaji Royal on 10/01/26.
//

import Foundation

class BaseAPIService {
    let remoteService: RemoteService
    
    init(remoteService: RemoteService = .shared) {
        self.remoteService = remoteService
    }
}
