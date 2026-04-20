//
//  DdayData+CoreDataProperties.swift
//  Clock
//
//  Created by zongbeen on 2024/04/04.
//
//

import Foundation
import CoreData


extension DdayData {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DdayData> {
        return NSFetchRequest<DdayData>(entityName: "DdayData")
    }

    @NSManaged public var title: String?
    @NSManaged public var dday: String?
    @NSManaged public var selectedDate: Date?
}

extension DdayData : Identifiable {

}
