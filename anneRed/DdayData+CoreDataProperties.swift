//
//  DdayData+CoreDataProperties.swift
//  anneRed
//
//  Created by zongbeen on 4/20/26.
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
