//
//  MotionPreference.swift
//  anneRed
//
//  Created by zongbeen on 4/20/26.
//

import UIKit

enum Motion {
    static let standardDuration: TimeInterval = 0.4
    static let pressDuration: TimeInterval = 0.25
    static let editDuration: TimeInterval = 0.3
    static let reduceCrossfade: TimeInterval = 0.2

    static var reduce: Bool { UIAccessibility.isReduceMotionEnabled }

    /// bounce 0 = critically damped. bounce>0 = 약간의 오버슈트.
    static func spring(bounce: CGFloat, duration: TimeInterval) -> UIViewPropertyAnimator {
        // dampingRatio = 1 - bounce (근사). bounce 0 → 1.0, bounce 0.2 → 0.8
        let damping = max(0.1, 1.0 - bounce)
        let params = UISpringTimingParameters(dampingRatio: damping)
        return UIViewPropertyAnimator(duration: duration, timingParameters: params)
    }
}
