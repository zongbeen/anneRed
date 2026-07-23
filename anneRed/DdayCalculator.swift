//
//  DdayCalculator.swift
//  anneRed
//
//  Created by zongbeen on 4/20/26.
//

import Foundation

enum DdayCalculator {
    /// 시각을 무시하고 달력상의 날짜 차이(일)를 반환한다.
    static func days(from now: Date, to target: Date) -> Int {
        let cal = Calendar.current
        let a = cal.dateComponents([.year, .month, .day], from: now)
        let b = cal.dateComponents([.year, .month, .day], from: target)
        return cal.dateComponents([.day], from: a, to: b).day ?? 0
    }

    static func text(daysLeft: Int) -> String {
        if daysLeft > 0 { return "D-\(daysLeft)" }
        if daysLeft == 0 { return "D-Day" }
        return "D+\(abs(daysLeft))"
    }

    static func text(from now: Date, to target: Date) -> String {
        text(daysLeft: days(from: now, to: target))
    }
}
