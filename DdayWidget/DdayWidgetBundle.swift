//
//  DdayWidgetBundle.swift
//  DdayWidget
//
//  Created by zongbeen on 4/20/26.
//

import WidgetKit
import SwiftUI

@main
struct DdayWidgetBundle: WidgetBundle {
    var body: some Widget {
        DdayWidget()
        DdayWidgetControl()
    }
}
