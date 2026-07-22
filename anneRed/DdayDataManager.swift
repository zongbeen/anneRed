//
//  DdayDataManager.swift
//  anneRed
//
//  Created by zongbeen on 4/20/26.
//


import UIKit
import CoreData

public class DdayDataManager {
    public static let shared = DdayDataManager()
    private init(){}
    private(set) var context: NSManagedObjectContext?
    
    func setup(context: NSManagedObjectContext) {
        self.context = context
    }
    
    func saveData(title: String, dday: String?, selectedDate: Date?, completion: @escaping () -> Void) {
        guard let context = context else {
            return
        }
        guard let entity = NSEntityDescription.entity(forEntityName: "DdayData", in: context) else {
            return
        }
        guard let data = NSManagedObject(entity: entity, insertInto: context) as? DdayData else {
            return
        }
        data.id = UUID()
        data.dday = dday
        data.title = title
        data.selectedDate = selectedDate

        do {
            try context.save()
            completion()
        } catch {
            completion()
        }
    }
    
    func getSavedData() -> [DdayData] {
        var data: [DdayData] = []
        guard let context = context else {
            return []
        }
        let request = NSFetchRequest<NSManagedObject>(entityName: "DdayData")
        let descriptor = NSSortDescriptor(key: "selectedDate", ascending: true)
        request.sortDescriptors = [descriptor]
        
        do {
            guard let fetchedData = try context.fetch(request) as? [DdayData] else {
                return data
            }
            data = fetchedData
        } catch {
            print("error")
        }
        return data
    }
    
    func removeData(id: UUID, completion: @escaping () -> Void) {
        guard let context = context else { completion(); return }
        let request = NSFetchRequest<NSManagedObject>(entityName: "DdayData")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        do {
            let fetched = try context.fetch(request) as? [DdayData] ?? []
            guard let data = fetched.first else { completion(); return }
            context.delete(data)
            try context.save()
            completion()
        } catch {
            completion()
        }
    }
    
    func updateData(targetId: Date, newData: DdayData, completion: @escaping () -> Void) {
        guard let context = context else {
            completion()
            return
        }
        // newData는 이미 context 내 managed object이므로 fetch 없이 바로 저장
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("error saving updated data: \(error)")
            }
        }
        completion()
    }
}
