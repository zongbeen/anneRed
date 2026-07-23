//
//  Haptics.swift
//  anneRed
//
//  Created by zongbeen on 4/20/26.
//

import UIKit

enum Haptics {
    private static let impactLight = UIImpactFeedbackGenerator(style: .light)
    private static let impactRigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let notification = UINotificationFeedbackGenerator()

    static func prepareImpact() { impactLight.prepare() }
    static func prepareNotification() { notification.prepare() }

    static func pinToggle() { impactLight.impactOccurred() }
    static func delete() { impactRigid.impactOccurred() }
    static func saveSuccess() { notification.notificationOccurred(.success) }
    static func limitWarning() { notification.notificationOccurred(.warning) }
}
