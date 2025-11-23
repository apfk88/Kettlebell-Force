//
//  UserProfile.swift
//  Kettlebell Force
//
//  Created by Alexander Kvamme on 11/23/25.
//

import Foundation

struct UserProfile: Codable {
    var bodyMassKg: Double
    
    static let `default` = UserProfile(bodyMassKg: 70.0)
}

