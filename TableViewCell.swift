//
//  TableViewCell.swift
//  Day
//
//  Created by zongbeen on 2024/04/02.
//

import UIKit

class TableViewCell: UITableViewCell {
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var ddayLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    
    let manager = DdayDataManager.shared
    var models = [[Model]]()
    var data: DdayData? {
        didSet {
            setupCell()
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    func setupCell() {
        guard let data = data else {
            print("setupCell Error")
            return
        }
        if let title = data.title, let selectedDate = data.selectedDate {
            let currentDate = Date()
            let currentDateOnly = Calendar.current.dateComponents([.year, .month, .day], from: currentDate)
            let selectedDateOnly = Calendar.current.dateComponents([.year, .month, .day], from: selectedDate)
            let daysLeft = Calendar.current.dateComponents([.day], from: currentDateOnly, to: selectedDateOnly).day ?? 0
            var dday = calculateDday(daysLeft: daysLeft)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            dateLabel.text = dateFormatter.string(from: selectedDate)
            ddayLabel.text = dday
            titleLabel.text = title
        }
    }
    
    func calculateDday(daysLeft: Int) -> String {
        if daysLeft > 0 {
            return "D-\(daysLeft)"
        } else if daysLeft == 0 {
            return "D-Day"
        } else {
            return "D+\(abs(daysLeft))"
        }
    }
}
