//
//  Item.swift
//  豆包爱学
//
//  Created by Roger Lin on 6/15/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
