//
//  DdayViewController.swift
//  anneRed
//
//  Created by zongbeen on 4/20/26.
//

import UIKit
import WidgetKit

class DdayViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!
    let manager = DdayDataManager.shared
    var isEditingMode = false

    private let maxPinnedCount = 2
    private let pinnedDatesKey = "pinnedDates"

    static let appGroupID = "group.com.zongbeen.anneRed"
    static var sharedDefaults: UserDefaults { UserDefaults(suiteName: appGroupID) ?? .standard }

    private var pinnedData: [DdayData] = []
    private var unpinnedData: [DdayData] = []

    private enum Section: Int {
        case pinned = 0, normal = 1
    }

    lazy var leftBarButton: UIBarButtonItem = {
        UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(leftBarButtonTapped))
    }()

    lazy var rightBarButton: UIBarButtonItem = {
        UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(rightBarButtonTapped))
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        setupTableView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadAllData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }

    private func setupNavigationBar() {
        self.navigationController?.navigationBar.prefersLargeTitles = true
        self.title = "Record"
        leftBarButton.tintColor = .systemOrange
        rightBarButton.tintColor = .systemOrange
        self.navigationItem.leftBarButtonItem = leftBarButton
        self.navigationItem.rightBarButtonItem = rightBarButton
    }

    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UINib(nibName: "TableViewCell", bundle: nil), forCellReuseIdentifier: "TableViewCell")
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
    }

    private func loadPinnedDates() -> [String] {
        let shared = DdayViewController.sharedDefaults
        if let migrated = UserDefaults.standard.stringArray(forKey: pinnedDatesKey) {
            shared.set(migrated, forKey: pinnedDatesKey)
            UserDefaults.standard.removeObject(forKey: pinnedDatesKey)
        }
        return shared.stringArray(forKey: pinnedDatesKey) ?? []
    }

    private func savePinnedDates() {
        let formatter = ISO8601DateFormatter()
        let dates = pinnedData.compactMap { $0.selectedDate }.map { formatter.string(from: $0) }
        DdayViewController.sharedDefaults.set(dates, forKey: pinnedDatesKey)
        saveWidgetData()
    }

    private func saveWidgetData() {
        let shared = DdayViewController.sharedDefaults
        let isAppGroup = UserDefaults(suiteName: DdayViewController.appGroupID) != nil
        print("🔍 App Group 유효: \(isAppGroup), pinnedData 수: \(pinnedData.count)")

        guard let first = pinnedData.first else {
            print("⚠️ pinnedData 비어있음 - widgetData 삭제")
            shared.removeObject(forKey: "widgetData")
            WidgetCenter.shared.reloadAllTimelines()
            return
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = first.selectedDate.map { dateFormatter.string(from: $0) } ?? ""
        let dday = calculateDday(selectedDate: first.selectedDate ?? Date())

        let dict: [String: String] = [
            "title": first.title ?? "",
            "date": dateString,
            "dday": dday
        ]
        shared.set(dict, forKey: "widgetData")
        print("✅ widgetData 저장: \(dict)")
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func calculateDday(selectedDate: Date) -> String {
        let currentDateOnly = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        let selectedDateOnly = Calendar.current.dateComponents([.year, .month, .day], from: selectedDate)
        let daysLeft = Calendar.current.dateComponents([.day], from: currentDateOnly, to: selectedDateOnly).day ?? 0
        if daysLeft > 0 { return "D-\(daysLeft)" }
        else if daysLeft == 0 { return "D-Day" }
        else { return "D+\(abs(daysLeft))" }
    }

    func updateStoredPinnedDate(from originalDate: Date, to newDate: Date) {
        let formatter = ISO8601DateFormatter()
        var savedDates = loadPinnedDates()
        guard !savedDates.isEmpty else { return }
        let pinnedDates = savedDates.compactMap { formatter.date(from: $0) }
        if let idx = pinnedDates.firstIndex(where: { Calendar.current.isDate($0, inSameDayAs: originalDate) }) {
            savedDates[idx] = formatter.string(from: newDate)
            DdayViewController.sharedDefaults.set(savedDates, forKey: pinnedDatesKey)
        }
    }

    func reloadAllData() {
        let all = manager.getSavedData()
        let formatter = ISO8601DateFormatter()
        let savedDates = loadPinnedDates()
        let pinnedDates = savedDates.compactMap { formatter.date(from: $0) }

        // 저장된 순서 유지
        pinnedData = pinnedDates.compactMap { date in
            all.first { Calendar.current.isDate($0.selectedDate ?? .distantPast, inSameDayAs: date) }
        }
        let pinnedSet = Set(pinnedData.compactMap { $0.selectedDate })
        unpinnedData = all.filter { $0.selectedDate.map { !pinnedSet.contains($0) } ?? true }
        saveWidgetData()
        tableView.reloadData()
    }

    private func item(at indexPath: IndexPath) -> DdayData {
        return indexPath.section == Section.pinned.rawValue ? pinnedData[indexPath.row] : unpinnedData[indexPath.row]
    }

    @objc func leftBarButtonTapped() {
        isEditingMode = !isEditingMode
        leftBarButton.title = isEditingMode ? "Done" : "Edit"
        setEditing(!tableView.isEditing, animated: true)
    }

    @objc func rightBarButtonTapped() {
        let datePickerViewController = self.storyboard?.instantiateViewController(identifier: "DatePickerViewController") as! DatePickerViewController
        let navigationController = UINavigationController(rootViewController: datePickerViewController)
        self.present(navigationController, animated: true, completion: nil)
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        tableView.setEditing(editing, animated: true)
        tableView.visibleCells.compactMap { $0 as? TableViewCell }.forEach { cell in
            if editing {
                cell.ddayLabel.isHidden = true
            } else {
                UIView.transition(with: cell.ddayLabel, duration: 0.5, options: .transitionCrossDissolve) {
                    cell.ddayLabel.isHidden = false
                }
            }
        }
    }
}

extension DdayViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == Section.pinned.rawValue ? pinnedData.count : unpinnedData.count
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let container = UIView()

        let label = UILabel()
        label.text = section == Section.pinned.rawValue ? "Pinned" : "Other"
        label.font = .boldSystemFont(ofSize: 18)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        let separator = UIView()
        separator.backgroundColor = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(separator)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
            label.bottomAnchor.constraint(equalTo: separator.topAnchor, constant: -4),
            separator.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5)
        ])

        return container
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 34
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 8
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "TableViewCell", for: indexPath) as? TableViewCell else {
            return UITableViewCell()
        }
        cell.data = item(at: indexPath)
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 90
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let target = item(at: indexPath)
            if indexPath.section == Section.pinned.rawValue {
                pinnedData.remove(at: indexPath.row)
            } else {
                unpinnedData.remove(at: indexPath.row)
            }
            savePinnedDates()
            manager.removeData(deleteTarget: target) {
                tableView.deleteRows(at: [indexPath], with: .automatic)
            }
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.performSegue(withIdentifier: "DdayViewController", sender: self)
        tableView.deselectRow(at: indexPath, animated: true)
    }

    func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let isPinned = indexPath.section == Section.pinned.rawValue

        if !isPinned && pinnedData.count >= maxPinnedCount {
            // 이미 2개 고정됨 → 고정 버튼 비활성
            let action = UIContextualAction(style: .normal, title: "최대 2개") { _, _, completion in
                completion(false)
            }
            action.backgroundColor = .systemGray
            return UISwipeActionsConfiguration(actions: [action])
        }

        let title = isPinned ? "고정 해제" : "고정"
        let image = UIImage(systemName: isPinned ? "pin.slash.fill" : "pin.fill")

        let action = UIContextualAction(style: .normal, title: title) { [weak self] _, _, completion in
            guard let self else { return }
            let target = self.item(at: indexPath)

            tableView.performBatchUpdates {
                if isPinned {
                    self.pinnedData.remove(at: indexPath.row)
                    self.unpinnedData.insert(target, at: 0)
                    tableView.deleteRows(at: [indexPath], with: .automatic)
                    tableView.insertRows(at: [IndexPath(row: 0, section: Section.normal.rawValue)], with: .automatic)
                } else {
                    self.unpinnedData.remove(at: indexPath.row)
                    self.pinnedData.append(target)
                    tableView.deleteRows(at: [indexPath], with: .automatic)
                    tableView.insertRows(at: [IndexPath(row: self.pinnedData.count - 1, section: Section.pinned.rawValue)], with: .automatic)
                }
            }
            self.savePinnedDates()
            completion(true)
        }
        action.image = image
        action.backgroundColor = .systemOrange

        return UISwipeActionsConfiguration(actions: [action])
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "DdayViewController", let indexPath = tableView.indexPathForSelectedRow {
            guard let navigationController = segue.destination as? DatePickerNavigationViewController,
                  let viewController = navigationController.viewControllers.first as? DatePickerViewController else {
                return
            }
            let selected = item(at: indexPath)
            viewController.data = selected
            viewController.loadViewIfNeeded()
            viewController.datePicker.setDate(selected.selectedDate!, animated: false)
            viewController.updateDdayLabel()
            viewController.tableView.reloadData()
        }
    }
}
