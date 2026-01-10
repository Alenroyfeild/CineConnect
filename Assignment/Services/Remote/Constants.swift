//
//  Constants.swift
//  Assignment
//
//  Created by Balaji Royal on 10/01/26.
//

import Foundation

extension Remote {
    struct Constants {
       static var defaultHeaders: [String: String] {
            [
                "Accept": "application/json",
                "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
                "x-hs-platform": "web",
                "x-hs-usertoken": "***REDACTED-CREDENTIAL***"
            ]
        }
    }
}
