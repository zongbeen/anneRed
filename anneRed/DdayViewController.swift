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
    private let pinnedIDsKey = "pinnedIDs"
    private let legacyPinnedDatesKey = "pinnedDates"

    static let appGroupID = "group.com.zongbeen.anneRed"
    static var sharedDefaults: UserDefaults { UserDefaults(suiteName: appGroupID) ?? .standard }

    private var pinnedData: [DdayData] = []
    private var unpinnedData: [DdayData] = []
    private var itemsByID: [UUID: DdayData] = [:]
    private var dataSource: UITableViewDiffableDataSource<Int, UUID>!

    private enum Section: Int {
        case pinned = 0, normal = 1
    }

    lazy var leftBarButton: UIBarButtonItem = {
        UIBarButtonItem(title: "편집", style: .plain, target: self, action: #selector(leftBarButtonTapped))
    }()

    lazy var rightBarButton: UIBarButtonItem = {
        UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(rightBarButtonTapped))
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        setupTableView()
        // 날짜가 바뀌면(자정) D-Day 자동 갱신
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDayChanged),
            name: .NSCalendarDayChanged,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleDayChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.reloadAllData()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadAllData()
    }

    private func setupNavigationBar() {
        self.navigationController?.navigationBar.prefersLargeTitles = true
        self.title = "기록"
        leftBarButton.tintColor = .systemOrange
        rightBarButton.tintColor = .systemOrange
        self.navigationItem.leftBarButtonItem = leftBarButton
        self.navigationItem.rightBarButtonItem = rightBarButton
    }

    private func setupTableView() {
        tableView.register(DdayCell.self, forCellReuseIdentifier: DdayCell.reuseID)
        tableView.sectionHeaderTopPadding = 0
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 90

        dataSource = UITableViewDiffableDataSource<Int, UUID>(tableView: tableView) { [weak self] tableView, indexPath, id in
            let cell = tableView.dequeueReusableCell(withIdentifier: DdayCell.reuseID, for: indexPath) as! DdayCell
            if let data = self?.itemsByID[id] { cell.configure(with: data) }
            return cell
        }
        dataSource.defaultRowAnimation = .fade
        tableView.delegate = self
    }

    private func loadPinnedIDs() -> [UUID] {
        let shared = DdayViewController.sharedDefaults

        // UserDefaults.standard → App Group 1회 이관 (기존 마이그레이션 유지)
        if let migrated = UserDefaults.standard.stringArray(forKey: legacyPinnedDatesKey) {
            shared.set(migrated, forKey: legacyPinnedDatesKey)
            UserDefaults.standard.removeObject(forKey: legacyPinnedDatesKey)
        }

        // 이미 UUID 배열이 있으면 그대로
        if let ids = shared.stringArray(forKey: pinnedIDsKey) {
            return ids.compactMap { UUID(uuidString: $0) }
        }

        // 레거시 ISO 날짜 배열 → UUID 1회 변환
        guard let legacy = shared.stringArray(forKey: legacyPinnedDatesKey) else { return [] }
        let formatter = ISO8601DateFormatter()
        let dates = legacy.compactMap { formatter.date(from: $0) }
        let all = manager.getSavedData()
        let ids: [UUID] = dates.compactMap { date in
            all.first { Calendar.current.isDate($0.selectedDate ?? .distantPast, inSameDayAs: date) }?.id
        }
        shared.set(ids.map { $0.uuidString }, forKey: pinnedIDsKey)
        shared.removeObject(forKey: legacyPinnedDatesKey)
        return ids
    }

    private func savePinnedIDs() {
        let ids = pinnedData.compactMap { $0.id?.uuidString }
        DdayViewController.sharedDefaults.set(ids, forKey: pinnedIDsKey)
        saveWidgetData()
    }

    private func saveWidgetData() {
        let shared = DdayViewController.sharedDefaults
        guard let first = pinnedData.first else {
            shared.removeObject(forKey: "widgetData")
            WidgetCenter.shared.reloadAllTimelines()
            return
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = first.selectedDate.map { dateFormatter.string(from: $0) } ?? ""

        // dday는 위젯이 매일 자정에 직접 계산하므로 날짜만 전달
        let dict: [String: String] = [
            "title": first.title ?? "",
            "date": dateString
        ]
        shared.set(dict, forKey: "widgetData")
        WidgetCenter.shared.reloadAllTimelines()
    }

    func reloadAllData() {
        let all = manager.getSavedData()
        let pinnedIDs = loadPinnedIDs()

        // 저장된 순서 유지
        pinnedData = pinnedIDs.compactMap { id in all.first { $0.id == id } }
        let pinnedSet = Set(pinnedData.compactMap { $0.id })
        unpinnedData = all.filter { $0.id.map { !pinnedSet.contains($0) } ?? true }
        saveWidgetData()

        itemsByID = Dictionary(uniqueKeysWithValues: all.compactMap { d in d.id.map { ($0, d) } })
        applySnapshot(animated: false)
    }

    private func applySnapshot(animated: Bool) {
        var snapshot = NSDiffableDataSourceSnapshot<Int, UUID>()
        snapshot.appendSections([Section.pinned.rawValue, Section.normal.rawValue])
        snapshot.appendItems(pinnedData.compactMap { $0.id }, toSection: Section.pinned.rawValue)
        snapshot.appendItems(unpinnedData.compactMap { $0.id }, toSection: Section.normal.rawValue)
        dataSource.apply(snapshot, animatingDifferences: animated && !Motion.reduce)
    }

    @objc func leftBarButtonTapped() {
        isEditingMode = !isEditingMode
        leftBarButton.title = isEditingMode ? "완료" : "편집"
        setEditing(!tableView.isEditing, animated: true)
    }

    @objc func rightBarButtonTapped() {
        let datePickerViewController = self.storyboard?.instantiateViewController(identifier: "DatePickerViewController") as! DatePickerViewController
        datePickerViewController.delegate = self
        let navigationController = UINavigationController(rootViewController: datePickerViewController)
        self.present(navigationController, animated: true, completion: nil)
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        tableView.setEditing(editing, animated: animated)
    }
}

extension DdayViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let container = UIView()
        let label = UILabel()
        label.text = section == Section.pinned.rawValue ? "고정" : "나머지"
        label.font = UIFontMetrics(forTextStyle: .headline).scaledFont(for: .boldSystemFont(ofSize: 18))
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

        if section == Section.pinned.rawValue {
            let count = UILabel()
            count.text = "\(pinnedData.count)/\(maxPinnedCount)"
            count.font = UIFontMetrics(forTextStyle: .footnote).scaledFont(for: .systemFont(ofSize: 13, weight: .regular))
            count.adjustsFontForContentSizeCategory = true
            count.textColor = .tertiaryLabel
            count.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(count)
            NSLayoutConstraint.activate([
                count.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
                count.centerYAnchor.constraint(equalTo: label.centerYAnchor),
            ])
        }
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

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete, let id = dataSource.itemIdentifier(for: indexPath) else { return }
        let isPinned = indexPath.section == Section.pinned.rawValue
        if isPinned { pinnedData.removeAll { $0.id == id } }
        else { unpinnedData.removeAll { $0.id == id } }
        savePinnedIDs()
        Haptics.delete()
        manager.removeData(id: id) { [weak self] in
            self?.itemsByID[id] = nil
            self?.applySnapshot(animated: true)
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.performSegue(withIdentifier: "DdayViewController", sender: self)
        tableView.deselectRow(at: indexPath, animated: true)
    }

    func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let isPinned = indexPath.section == Section.pinned.rawValue
        Haptics.prepareImpact()
        Haptics.prepareNotification()

        if !isPinned && pinnedData.count >= maxPinnedCount {
            let action = UIContextualAction(style: .normal, title: "고정 해제 후 가능") { _, _, completion in
                Haptics.limitWarning()
                completion(false)
            }
            action.image = UIImage(systemName: "pin.slash")
            action.backgroundColor = .systemGray
            return UISwipeActionsConfiguration(actions: [action])
        }

        let title = isPinned ? "고정 해제" : "고정"
        let action = UIContextualAction(style: .normal, title: title) { [weak self] _, _, completion in
            guard let self, let id = self.dataSource.itemIdentifier(for: indexPath),
                  let target = self.itemsByID[id] else { completion(false); return }
            if isPinned {
                self.pinnedData.removeAll { $0.id == id }
                self.unpinnedData.insert(target, at: 0)
            } else {
                self.unpinnedData.removeAll { $0.id == id }
                self.pinnedData.append(target)
            }
            self.savePinnedIDs()
            Haptics.pinToggle()
            self.applySnapshot(animated: !Motion.reduce)
            completion(true)
        }
        action.image = UIImage(systemName: isPinned ? "pin.slash.fill" : "pin.fill")
        action.backgroundColor = .systemOrange
        return UISwipeActionsConfiguration(actions: [action])
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "DdayViewController", let indexPath = tableView.indexPathForSelectedRow,
           let id = dataSource.itemIdentifier(for: indexPath), let selected = itemsByID[id] {
            guard let navigationController = segue.destination as? DatePickerNavigationViewController,
                  let viewController = navigationController.viewControllers.first as? DatePickerViewController else {
                return
            }
            viewController.data = selected
            viewController.delegate = self
            viewController.loadViewIfNeeded()
            if let date = selected.selectedDate {
                viewController.datePicker.setDate(date, animated: false)
            }
            viewController.updateDdayLabel()
            viewController.tableView.reloadData()
        }
    }
}

extension DdayViewController: DatePickerViewControllerDelegate {
    func datePickerDidFinish() { reloadAllData() }
}
