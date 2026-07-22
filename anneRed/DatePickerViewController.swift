//
//  DatePickerViewController.swift
//  anneRed
//
//  Created by zongbeen on 4/20/26.
//

import UIKit

class DatePickerViewController: UIViewController {
    @IBOutlet weak var datePicker: UIDatePicker!
    @IBOutlet weak var tableView: UITableView!

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
    private var caculInputText: String = ""
    private var caculResultText: String = ""

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
        self.title = "Add List"

        let leftBarButton = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(leftBarButtonTapped))
        let rightBarButton = UIBarButtonItem(title: "Save", style: .plain, target: self, action: #selector(rightBarButtonTapped))

        leftBarButton.tintColor = .systemOrange
        rightBarButton.tintColor = .systemOrange

        navigationItem.leftBarButtonItem = leftBarButton
        navigationItem.rightBarButtonItem = rightBarButton
    }

    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.isScrollEnabled = true

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
        selectedDate = datePicker.date
        let currentDate = Date()
        let currentDateOnly = Calendar.current.dateComponents([.year, .month, .day], from: currentDate)
        let selectedDateOnly = Calendar.current.dateComponents([.year, .month, .day], from: selectedDate!)
        daysLeft = Calendar.current.dateComponents([.day], from: currentDateOnly, to: selectedDateOnly).day ?? 0

        if daysLeft! > 0 {
            dday = "D-\(daysLeft ?? 0)"
            ddayResultText = "D-\(daysLeft ?? 0)"
        } else if daysLeft == 0 {
            dday = "D-Day"
            ddayResultText = "D-Day"
        } else {
            dday = "D+\(abs(daysLeft ?? 0))"
            ddayResultText = "D+\(abs(daysLeft ?? 0))"
        }

        if let cell = tableView.cellForRow(at: IndexPath(row: 0, section: 0)) {
            cell.detailTextLabel?.text = ddayResultText
        }
    }

    func caculateDay() {
        guard let days = Int(caculInputText) else {
            caculResultText = ""
            updateCaculResultCell()
            return
        }
        let calendar = Calendar.current
        if let resultDate = calendar.date(byAdding: .day, value: days, to: datePicker.date) {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy년 MM월 dd일"
            caculResultText = dateFormatter.string(from: resultDate)
        } else {
            caculResultText = "error"
        }
        updateCaculResultCell()
    }

    private func updateCaculResultCell() {
        guard let cell = tableView.cellForRow(at: IndexPath(row: 0, section: 1)) else { return }
        (cell.contentView.viewWithTag(3) as? UILabel)?.text = caculResultText
    }

    @objc func leftBarButtonTapped() {
        self.dismiss(animated: true)
    }

    @objc func rightBarButtonTapped() {
        updateDdayLabel()
        if data != nil {
            let originalDate = data!.selectedDate!  // 수정 전 날짜를 먼저 저장
            let newData = data
            newData?.dday = dday
            newData?.title = titleText
            newData?.selectedDate = selectedDate
            manager.updateData(targetId: originalDate, newData: newData!) {
                self.dismissAndReload(originalDate: originalDate)
            }
        } else {
            manager.saveData(title: titleText.isEmpty ? "empty" : titleText, dday: dday!, selectedDate: selectedDate) {
                self.dismissAndReload()
            }
        }
    }

    private func dismissAndReload(originalDate: Date? = nil) {
        let presentingVC = self.presentingViewController

        let ddayVC: DdayViewController? = {
            if let vc = presentingVC as? DdayViewController {
                return vc
            }
            if let navVC = presentingVC as? UINavigationController,
               let vc = navVC.viewControllers.first as? DdayViewController {
                return vc
            }
            if let tabVC = presentingVC as? UITabBarController,
               let navVC = tabVC.viewControllers?.first as? DdayNavigationViewController,
               let vc = navVC.viewControllers.first as? DdayViewController {
                return vc
            }
            return nil
        }()

        ddayVC?.reloadAllData()
        self.dismiss(animated: true)
    }

    @IBAction func datePickerValueChanged(_ sender: UIDatePicker) {
        updateDdayLabel()
        if !caculInputText.isEmpty {
            caculateDay()
        }
    }

    @objc private func titleTextFieldChanged(_ sender: UITextField) {
        titleText = sender.text ?? ""
    }

    @objc private func caculTextFieldChanged(_ sender: UITextField) {
        caculInputText = sender.text ?? ""
        caculateDay()
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

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.selectionStyle = .none

        if indexPath.section == 0 {
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "D-Day"
                cell.detailTextLabel?.text = ddayResultText
                cell.detailTextLabel?.font = .systemFont(ofSize: 22, weight: .medium)

            case 1:
                cell.textLabel?.text = "Title"
                cell.detailTextLabel?.text = nil

                let tf = UITextField()
                tf.placeholder = "title"
                tf.textAlignment = .right
                tf.text = titleText
                tf.clearButtonMode = .whileEditing
                tf.translatesAutoresizingMaskIntoConstraints = false
                tf.addTarget(self, action: #selector(titleTextFieldChanged(_:)), for: .editingChanged)
                cell.contentView.addSubview(tf)
                NSLayoutConstraint.activate([
                    tf.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
                    tf.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
                    tf.widthAnchor.constraint(equalToConstant: 200)
                ])

            default:
                break
            }
        } else {
            cell.textLabel?.text = "Calculate"
            cell.detailTextLabel?.text = nil

            let tf = UITextField()
            tf.placeholder = "days"
            tf.textAlignment = .right
            tf.keyboardType = .numberPad
            tf.text = caculInputText
            tf.clearButtonMode = .whileEditing
            tf.translatesAutoresizingMaskIntoConstraints = false
            tf.addTarget(self, action: #selector(caculTextFieldChanged(_:)), for: .editingChanged)

            let resultLabel = UILabel()
            resultLabel.tag = 3
            resultLabel.text = caculResultText
            resultLabel.textAlignment = .right
            resultLabel.font = .systemFont(ofSize: 13)
            resultLabel.textColor = .systemGray
            resultLabel.adjustsFontSizeToFitWidth = true
            resultLabel.translatesAutoresizingMaskIntoConstraints = false

            cell.contentView.addSubview(tf)
            cell.contentView.addSubview(resultLabel)
            NSLayoutConstraint.activate([
                tf.trailingAnchor.constraint(equalTo: cell.contentView.centerXAnchor, constant: 10),
                tf.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
                tf.widthAnchor.constraint(equalToConstant: 80),
                resultLabel.leadingAnchor.constraint(equalTo: cell.contentView.centerXAnchor, constant: 16),
                resultLabel.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
                resultLabel.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor)
            ])
        }

        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50
    }
}
