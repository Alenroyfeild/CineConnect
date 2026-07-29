//
//  BaseAPIService.swift
//  Assignment
//
//  Created by Balaji Royal on 10/01/26.
//

import Foundation

class BaseAPIService {
    let remoteService: RemoteService

    /// No default parameter - `RemoteService` is built once by
    /// `AppDependencyContainer` and threaded through the coordinators, the
    /// same pattern Phase 1 established for `AuthManager`.
    init(remoteService: RemoteService) {
        self.remoteService = remoteService
    }
}
