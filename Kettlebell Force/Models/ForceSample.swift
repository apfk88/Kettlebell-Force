//
//  ForceSample.swift
//  Kettlebell Force
//
//  Created by Alexander Kvamme on 11/23/25.
//

import Foundation
import simd

struct ForceSample: Codable {
    let timestamp: TimeInterval   // seconds since session start
    let accelG: SIMD3<Double>     // acceleration in g in board frame or world frame
    let forceN: Double            // magnitude in newtons (bell force)
}

