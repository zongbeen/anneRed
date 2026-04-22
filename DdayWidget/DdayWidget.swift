//
//  DdayWidget.swift
//  DdayWidget
//
//  Created by zongbeen on 4/20/26.
//

import WidgetKit
import SwiftUI

// MARK: - Shared Defaults

private let appGroupID = "group.com.zongbeen.anneRed"
private var sharedDefaults: UserDefaults { UserDefaults(suiteName: appGroupID) ?? .standard }

// MARK: - Entry

struct DdayEntry: TimelineEntry {
    let date: Date
    let title: String
    let selectedDate: String
    let dday: String
}

// MARK: - Provider

struct DdayProvider: TimelineProvider {

    func placeholder(in context: Context) -> DdayEntry {
        DdayEntry(date: .now, title: "Title", selectedDate: "2026-01-01", dday: "D-Day")
    }

    func getSnapshot(in context: Context, completion: @escaping (DdayEntry) -> Void) {
        completion(makeEntry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DdayEntry>) -> Void) {
        let calendar = Calendar.current
        // 오늘부터 7일치 자정 entry를 생성 → 매일 자정에 정확한 D-Day를 표시
        var entries: [DdayEntry] = []
        for dayOffset in 0..<7 {
            guard let entryDate = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: .now)) else { continue }
            entries.append(makeEntry(at: entryDate))
        }
        // 7일 후 다시 getTimeline 호출
        let refreshDate = calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: .now)) ?? Date().addingTimeInterval(7 * 86400)
        let timeline = Timeline(entries: entries, policy: .after(refreshDate))
        completion(timeline)
    }

    /// `referenceDate` 시점의 D-Day를 직접 계산해 Entry 생성
    private func makeEntry(at referenceDate: Date) -> DdayEntry {
        let dict = sharedDefaults.dictionary(forKey: "widgetData") as? [String: String]
        let title = dict?["title"] ?? "-"
        let dateString = dict?["date"] ?? "-"
        let dday = computeDday(from: dateString, referenceDate: referenceDate)
        return DdayEntry(date: referenceDate, title: title, selectedDate: dateString, dday: dday)
    }

    /// "yyyy-MM-dd" 문자열과 기준 날짜로 D-Day 문자열 계산
    private func computeDday(from dateString: String, referenceDate: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let targetDate = formatter.date(from: dateString) else { return "-" }
        let calendar = Calendar.current
        let refDay = calendar.startOfDay(for: referenceDate)
        let targetDay = calendar.startOfDay(for: targetDate)
        let diff = calendar.dateComponents([.day], from: refDay, to: targetDay).day ?? 0
        if diff == 0 { return "D-Day" }
        if diff > 0  { return "D-\(diff)" }
        return "D+\(-diff)"
    }
}

// MARK: - Widget View

struct DdayWidgetView: View {
    let entry: DdayEntry

    private var ddayRawNumber: Int {
        if entry.dday == "D-Day" { return 0 }
        return Int(String(entry.dday.dropFirst(2))) ?? 0
    }

    private var ddayDisplayText: String { "\(ddayRawNumber)" }

    private var ddayFontSize: CGFloat {
        switch ddayRawNumber {
        case 0..<100:   return 36
        case 100..<1000: return 30
        default:         return 26
        }
    }

    private var ddayLabel: String? {
        if entry.dday == "D-Day" { return nil }
        return entry.dday.hasPrefix("D-") ? "일 남음" : "일 지남"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // 상단: 타이틀 + 날짜
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text(entry.selectedDate)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            // 하단: 숫자 바로 옆에 남음/지남
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(ddayDisplayText)
                    .font(.system(size: ddayFontSize, weight: .bold))
                    .foregroundColor(.primary)

                if let label = ddayLabel {
                    Text(label)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(14)
        .containerBackground(.background, for: .widget)
    }
}

// MARK: - Widget

struct DdayWidget: Widget {
    let kind = "DdayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DdayProvider()) { entry in
            DdayWidgetView(entry: entry)
        }
        .configurationDisplayName("D-Day")
        .description("고정된 첫 번째 D-Day를 표시합니다.")
        .supportedFamilies([.systemSmall])
    }
}
