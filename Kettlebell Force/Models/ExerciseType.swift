//
//  ExerciseType.swift
//  Kettlebell Force
//
//  Created by Alexander Kvamme on 11/23/25.
//

import Foundation

enum ExerciseType: String, Codable, CaseIterable, Identifiable {
    case snatch = "snatch"
    case swing = "swing"
    case other = "other"
    
    var id: String { rawValue }
    
    var displayName: String {
        rawValue.capitalized
    }
}

