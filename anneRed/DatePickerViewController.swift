//
//  DatePickerViewController.swift
//  anneRed
//
//  Created by zongbeen on 4/20/26.
//

import UIKit

protocol DatePickerViewControllerDelegate: AnyObject {
    func datePickerDidFinish()
}

class DatePickerViewController: UIViewController {
    @IBOutlet weak var datePicker: UIDatePicker!
    @IBOutlet weak var tableView: UITableView!

    weak var delegate: DatePickerViewControllerDelegate?
    let manager = DdayDataManager.shared
    var data: DdayData? {
        didSet {
            titleText = data?.title ?? ""
        }
    }

    var dday: String?
    var daysLeft: Int?
    var selectedDate: Date?

    private var ddayResultText: String = ""
    private var titleText: String = ""
    private var calcInputText: String = ""
    private var calcResultText: String = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        setupTableView()
        setupKeyboard()
        getCurrentDay()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }

    private func setupNavigationBar() {
        self.title = (data == nil) ? "새 D-Day" : "편집"

        let leftBarButton = UIBarButtonItem(title: "취소", style: .plain, target: self, action: #selector(leftBarButtonTapped))
        let rightBarButton = UIBarButtonItem(title: "저장", style: .plain, target: self, action: #selector(rightBarButtonTapped))

        leftBarButton.tintColor = .systemOrange
        rightBarButton.tintColor = .systemOrange

        navigationItem.leftBarButtonItem = leftBarButton
        navigationItem.rightBarButtonItem = rightBarButton
    }

    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.isScrollEnabled = true
        tableView.register(ValueCell.self, forCellReuseIdentifier: ValueCell.reuseID)
        tableView.register(InputCell.self, forCellReuseIdentifier: InputCell.reuseID)

        datePicker.translatesAutoresizingMaskIntoConstraints = true
        datePicker.frame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 216)
        tableView.tableHeaderView = datePicker

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    private func setupKeyboard() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    private func getCurrentDay() {
        datePicker.date = Date()
        updateDdayLabel()
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let inset = keyboardFrame.height - view.safeAreaInsets.bottom
        tableView.contentInset.bottom = inset
        tableView.verticalScrollIndicatorInsets.bottom = inset
        tableView.scrollToRow(at: IndexPath(row: 0, section: 1), at: .bottom, animated: true)
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        tableView.contentInset.bottom = 0
        tableView.verticalScrollIndicatorInsets.bottom = 0
    }

    func updateDdayLabel() {
        let target = datePicker.date
        selectedDate = target
        let days = DdayCalculator.days(from: Date(), to: target)
        daysLeft = days
        dday = DdayCalculator.text(daysLeft: days)
        ddayResultText = dday ?? ""
        tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .none)
    }

    func calculateDay() {
        guard let days = Int(calcInputText) else {
            calcResultText = ""
            updateCalcResultFooter()
            return
        }
        let calendar = Calendar.current
        if let resultDate = calendar.date(byAdding: .day, value: days, to: datePicker.date) {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy년 MM월 dd일"
            calcResultText = dateFormatter.string(from: resultDate)
        } else {
            calcResultText = "error"
        }
        updateCalcResultFooter()
    }

    private func updateCalcResultFooter() {
        // footer만 직접 갱신해 입력 포커스를 유지한다
        UIView.performWithoutAnimation {
            let footer = self.tableView.footerView(forSection: 1)
            footer?.textLabel?.text = self.calcResultText
            footer?.textLabel?.setNeedsLayout()
        }
    }

    @objc func leftBarButtonTapped() {
        self.dismiss(animated: true)
    }

    @objc func rightBarButtonTapped() {
        updateDdayLabel()
        let finalDday = dday ?? DdayCalculator.text(from: Date(), to: datePicker.date)
        if let existing = data {
            existing.dday = finalDday
            existing.title = titleText
            existing.selectedDate = selectedDate
            manager.updateData(targetId: existing.selectedDate ?? Date(), newData: existing) {
                self.dismissAndReload()
            }
        } else {
            manager.saveData(title: titleText.isEmpty ? "empty" : titleText, dday: finalDday, selectedDate: selectedDate) {
                Haptics.saveSuccess()
                self.dismissAndReload()
            }
        }
    }

    private func dismissAndReload() {
        delegate?.datePickerDidFinish()
        dismiss(animated: true)
    }

    @IBAction func datePickerValueChanged(_ sender: UIDatePicker) {
        updateDdayLabel()
        if !calcInputText.isEmpty {
            calculateDay()
        }
    }
}

extension DatePickerViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? 2 : 1
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 1 ? "선택한 날짜로부터 계산하기" : nil
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return section == 1 ? (calcResultText.isEmpty ? nil : calcResultText) : nil
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 && indexPath.row == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: ValueCell.reuseID, for: indexPath) as! ValueCell
            cell.configure(title: "D-Day", value: ddayResultText,
                           valueFont: .systemFont(ofSize: 22, weight: .medium))
            return cell
        }
        if indexPath.section == 0 && indexPath.row == 1 {
            let cell = tableView.dequeueReusableCell(withIdentifier: InputCell.reuseID, for: indexPath) as! InputCell
            cell.configure(title: "제목", text: titleText, placeholder: "제목")
            cell.onChange = { [weak self] in self?.titleText = $0 }
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: InputCell.reuseID, for: indexPath) as! InputCell
        cell.configure(title: "일수", text: calcInputText, placeholder: "일수", keyboard: .numberPad)
        cell.onChange = { [weak self] in
            self?.calcInputText = $0
            self?.calculateDay()
        }
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
}
