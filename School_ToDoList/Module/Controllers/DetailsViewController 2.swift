import UIKit
import CocoaLumberjackSwift
import FileCachePackage

class DetailsViewController: UIViewController, UITableViewDataSource {
    
    // MARK: ToDoItem initialization
    
    enum OpenType {
        case add
        case edit
    }
    
    public var completionHandler: ((String, String, Importance, Date?, Bool, Date, Date?, Bool) -> Void)?
    
    private let openType: OpenType
    private var item: ToDoItem?
    private var itemImportance: Importance = .regular
    
    // MARK: View initialization
    
    let scrollView = CustomScrollView()
    let detailsTextView = DetailsTextView()
    let segmentedControl: UISegmentedControl = {
        let control = UISegmentedControl()
        control.insertSegment(with: UIImage(named: "unimportant")?.withRenderingMode(.alwaysOriginal), at: 0, animated: false)
        control.insertSegment(withTitle: "нет", at: 1, animated: false)
        control.insertSegment(with: UIImage(named: "important")?.withRenderingMode(.alwaysOriginal), at: 2, animated: false)
        control.selectedSegmentIndex = 1
        
        return control
    }()
    let tableView = UITableView()
    let switchControl = UISwitch()
    
    // MARK: Constraints for animations initialization
    
    var labelConstraint1: NSLayoutConstraint? = nil
    var dateLabelConstraint: NSLayoutConstraint? = nil
    
    // MARK: Extend initialization
    
    var selectedDate: Date?
    var isCalendarShown: Bool = false
    var isLandscapeOrientation: Bool = false
    var data = ["", ""]
    var datePickerVisible = false
    var deadlineAlreadyHere = false
    
    // MARK: Views initialization
    
    let datePicker: UIDatePicker = {
        let picker = UIDatePicker()
        picker.locale = .current
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .inline
        picker.calendar.firstWeekday = 2
        picker.minimumDate = Calendar.current.startOfDay(for: Date())
        
        return picker
    }()
    
    let deleteButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Удалить", for: .normal)
        button.setTitleColor(UIColor(named: "Red"), for: .normal)
        button.backgroundColor = UIColor(named: "BackSecondary")
        button.layer.cornerRadius = 16
        
        return button
    }()
    
    let importanceLabel: UILabel = {
        let label = UILabel()
        label.text = "Важность"
        label.textColor = UIColor(named: "LabelPrimary")
        label.font = .body()
        
        return label
    }()
    
    let doneUntilLabel: UILabel = {
        let label = UILabel()
        label.text = "Сделать до"
        label.textColor = UIColor(named: "LabelPrimary")
        label.font = .body()
        
        return label
    }()
    
    let dateUntilLabel: UIButton = {
        let button = UIButton()
        button.setTitleColor(UIColor(named: "Blue"), for: .normal)
        button.titleLabel?.font = .footnote()
        
        return button
    }()
    
    // MARK: NavigationBar setup
    
    func navigationBarSetup() {
        navigationItem.title = "Дело"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Отменить",
            style: .plain,
            target: self,
            action: #selector(cancelButtonTapped)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Сохранить",
            style: .done,
            target: self,
            action: #selector(saveButtonTapped)
        )
    }
    
    func saveButtonEnableCheck() {
        if !detailsTextView.text.isEmpty && detailsTextView.text != "Что надо сделать?" {
            navigationItem.rightBarButtonItem?.isEnabled = true
        }
    }
    
    // MARK: dateCell views setup
    
    func dateCellViewSetup() {
        dateUntilLabel.setTitle(dateConfiguration().0, for: .normal)
        dateUntilLabel.addTarget(self, action: #selector(dateButtonPressed), for: .touchUpInside)
        datePicker.date = dateConfiguration().1 ?? Date(timeIntervalSinceNow: 86400)
        datePicker.addTarget(self, action: #selector(datePickerValueChanged), for: .valueChanged)
    }

    // MARK: @objc functions
    
    @objc func datePickerValueChanged(_ sender: UIDatePicker) {
        dismissKeyboard()
        selectedDate = sender.date
        DDLogDebug("Date changed to \(String(describing: selectedDate))", level: .debug)
        dateUntilLabel.setTitle(dateConfiguration(date: selectedDate).0, for: .normal)
        saveButtonEnableCheck()
    }
    
    @objc func cancelButtonTapped() {
        DDLogDebug("Cancel button pressed", level: .debug)
        dismiss(animated: true)
    }
    
    @objc func deleteButtonTapped() {
        DDLogDebug("Delete button pressed", level: .debug)
        completionHandler?(item?.id ?? "", item?.taskText ?? "", item?.importance ?? .regular, item?.deadline, item?.completed ?? false, item?.createDate ?? Date(), item?.editDate, true)
        dismiss(animated: true)
    }
    
    @objc func segmentValueChanged(_ sender: UISegmentedControl) {
        dismissKeyboard()
        let selectedSegment = sender.selectedSegmentIndex
        switch selectedSegment {
        case 0:
            itemImportance = .unimportant
        case 1:
            itemImportance = .regular
        case 2:
            itemImportance = .important
        default:
            itemImportance = .regular
        }
        DDLogDebug("Importance changed to \(itemImportance)", level: .debug)
        saveButtonEnableCheck()
    }
    
    @objc private func saveButtonTapped() {
        DDLogDebug("Save button pressed", level: .debug)
        var toEditDate: Date? = nil
        if item != nil {
            toEditDate = Date()
        }
        let newItem = ToDoItem(taskText: detailsTextView.text,
                               importance: itemImportance,
                               deadline: selectedDate)
        
        completionHandler?(item?.id ?? newItem.id, newItem.taskText, newItem.importance, newItem.deadline, item?.completed ?? false, item?.createDate ?? newItem.createDate, toEditDate ?? newItem.editDate, false)
        dismiss(animated: true)
    }
    
    // MARK: Working with keyboard show
    
    @objc func keyboardWillShow(_ notification: Notification) {
        Task {
            await MainActor.run {
                guard let userInfo = notification.userInfo,
                      let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
                    return
                }
                
                let keyboardHeight = keyboardFrame.size.height
                scrollView.contentInset.bottom = keyboardHeight
                scrollView.verticalScrollIndicatorInsets.bottom = keyboardHeight
                
                let rect = CGRect(x: 0, y: detailsTextView.frame.origin.y, width: detailsTextView.frame.width, height: detailsTextView.frame.height)
                scrollView.scrollRectToVisible(rect, animated: true)
            }
        }
    }
    
    @objc func keyboardWillHide(_ notification: Notification) {
        Task {
            await MainActor.run {
                scrollView.contentInset = .zero
                scrollView.verticalScrollIndicatorInsets = .zero
            }
        }
    }
    
    @objc func dismissKeyboard() {
        scrollView.endEditing(true)
    }
    
    // MARK: Date configuration
    
    func dateConfiguration(date: Date? = nil) -> (String, Date?) {
        let calendar = NSCalendar.current
        let currentDate = Date()
        var outputDay = calendar.date(byAdding: .day, value: 1, to: currentDate)
        if selectedDate != nil {
            outputDay = selectedDate
        }
        if let date = date {
            outputDay = date
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"
        let nextDayString = dateFormatter.string(from: outputDay!)
        return (nextDayString, outputDay)
    }
    
    // MARK: Main part
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.contentSize = contentSize
    }
    
    init(openType: OpenType, item: ToDoItem?) {
        self.openType = openType
        self.item = item
        super.init(nibName: nil, bundle: nil)
        if openType == .edit {
            deleteButton.isEnabled = true
        } else {
            deleteButton.isEnabled = false
            deleteButton.setTitleColor(UIColor(named: "LabelTertiary"), for: .normal)
        }
        
        if let date = item?.deadline {
            selectedDate = date
            switchControl.isOn = true
            deadlineAlreadyHere = true
            
        }
        
        if let text = item?.taskText {
            detailsTextView.text = text
            detailsTextView.textColor = UIColor(named: "LabelPrimary")
            navigationItem.rightBarButtonItem?.isEnabled = true
        }
        
        if let importance = item?.importance {
            switch importance {
            case .unimportant:
                segmentedControl.selectedSegmentIndex = 0
            case .regular:
                segmentedControl.selectedSegmentIndex = 1
            case .important:
                segmentedControl.selectedSegmentIndex = 2
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        DDLogDebug("Details view loaded", level: .debug)
        
        itemImportance = item?.importance ?? .regular

        navigationBarSetup()
        view.backgroundColor = UIColor(named: "BackPrimary")
        navigationItem.rightBarButtonItem?.isEnabled = false
        
        scrollView.frame = view.bounds
        scrollView.showsVerticalScrollIndicator = false
        tableViewConfiguration()
        
        detailsTextView.delegate = self
        tableView.delegate = self
        
        view.addSubview(scrollView)
        scrollView.addSubview(detailsTextView)
        scrollView.addSubview(tableView)
        scrollView.addSubview(deleteButton)
        scrollView.isScrollEnabled = true
        
        scrollViewSetup()
        detailsTextViewSetup()
        tableViewSetup()
        deleteButtonSetup()
        dateCellViewSetup()
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        tableView.addObserver(self, forKeyPath: "contentSize", options: .new, context: nil)
    }
    
    deinit {
        if tableView.observationInfo != nil {
            tableView.removeObserver(self, forKeyPath: "contentSize")
        }
//        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
//        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    // MARK: Constraints setup methods
    
    func deleteButtonSetup() {
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.topAnchor.constraint(equalTo: tableView.bottomAnchor, constant: 16).isActive = true
        deleteButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16).isActive = true
        deleteButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16).isActive = true
        deleteButton.heightAnchor.constraint(equalToConstant: 56).isActive = true
        deleteButton.addTarget(self, action: #selector(deleteButtonTapped), for: .touchUpInside)
    }
    
    func detailsTextViewSetup() {
        detailsTextView.translatesAutoresizingMaskIntoConstraints = false
        detailsTextView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16).isActive = true
        detailsTextView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20).isActive = true
        detailsTextView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16).isActive = true
        detailsTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true

    }
    
    func tableViewConfiguration() {
        tableView.dataSource = self
        tableView.layer.cornerRadius = 16
        tableView.isScrollEnabled = false
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
    }
    
    func tableViewSetup() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16).isActive = true
        tableView.topAnchor.constraint(equalTo: detailsTextView.bottomAnchor, constant: 16).isActive = true
        tableView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16).isActive = true
        
        let constraint = tableView.heightAnchor.constraint(equalToConstant: 112)
        constraint.priority = .defaultLow
        constraint.isActive = true
        
    }
    
    func scrollViewSetup() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    }
    
    // MARK: Working with tableView
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = data[indexPath.row]
        cell.textLabel?.font = .body()
        cell.backgroundColor = UIColor(named: "BackSecondary")
        
        if indexPath.row == 0 {
            
            segmentedControl.addTarget(self, action: #selector(segmentValueChanged(_:)), for: .valueChanged)
            segmentedControl.backgroundColor = UIColor(named: "SupportSegmented")
            
            cell.contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 56).isActive = true
            cell.contentView.addSubview(importanceLabel)
            cell.contentView.addSubview(segmentedControl)
            importanceLabel.translatesAutoresizingMaskIntoConstraints = false
            importanceLabel.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16).isActive = true
            importanceLabel.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor).isActive = true
            segmentedControl.translatesAutoresizingMaskIntoConstraints = false
            segmentedControl.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -14).isActive = true
            segmentedControl.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor).isActive = true
            segmentedControl.widthAnchor.constraint(equalToConstant: 150).isActive = true
            
        } else if indexPath.row == 1 {
            
            switchControl.addTarget(self, action: #selector(switchValueChanged(_:)), for: .valueChanged)
            cell.contentView.addSubview(switchControl)
            cell.contentView.addSubview(doneUntilLabel)
            cell.contentView.addSubview(dateUntilLabel)
            if !deadlineAlreadyHere {
                dateUntilLabel.alpha = 0
            } else {
                dateUntilLabel.alpha = 1
            }
            
            cell.contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 56).isActive = true
            switchControl.translatesAutoresizingMaskIntoConstraints = false
            switchControl.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -14).isActive = true
            switchControl.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor).isActive = true
            
            if !deadlineAlreadyHere {
                labelConstraint1 = doneUntilLabel.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor, constant: 0)
            } else {
                labelConstraint1 = doneUntilLabel.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor, constant: -10)
            }
            doneUntilLabel.translatesAutoresizingMaskIntoConstraints = false
            doneUntilLabel.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16).isActive = true
            labelConstraint1?.isActive = true
            dateUntilLabel.translatesAutoresizingMaskIntoConstraints = false
            dateUntilLabel.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16).isActive = true
            dateUntilLabel.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor, constant: 10).isActive = true
            dateUntilLabel.heightAnchor.constraint(equalToConstant: 18).isActive = true
        } else {
            
            cell.contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 332).isActive = true
            cell.contentView.addSubview(datePicker)
            datePicker.translatesAutoresizingMaskIntoConstraints = false
            datePicker.centerXAnchor.constraint(equalTo: cell.contentView.centerXAnchor).isActive = true
            datePicker.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor).isActive = true

        }
        
        return cell
    }
    
    // MARK: Calendar to appear
    
    @objc func dateButtonPressed() {
        
        let calendarRowNumber = 2
        let constraintWithCalendar = tableView.heightAnchor.constraint(equalToConstant: 112 + 332)
        let constraintNoCalendar = tableView.heightAnchor.constraint(equalToConstant: 112)
        
        if !isCalendarShown {
            datePickerVisible = true
            data.insert("", at: calendarRowNumber)
            
            let calendarIndexPath = IndexPath(row: calendarRowNumber, section: 0)
            
            tableView.beginUpdates()
            tableView.insertRows(at: [calendarIndexPath], with: .fade)
            tableView.endUpdates()
            
            constraintWithCalendar.priority = .defaultHigh
            constraintNoCalendar.priority = .defaultLow
            constraintWithCalendar.isActive = true
            constraintNoCalendar.isActive = false
            scrollView.contentSize = contentSize
            
            UIView.animate(withDuration: 0.5) {
                self.scrollView.layoutIfNeeded()
            }
            isCalendarShown = true
        } else {
            datePickerVisible = false
            data.remove(at: calendarRowNumber)
            
            let calendarIndexPath = IndexPath(row: calendarRowNumber, section: 0)
            
            constraintWithCalendar.priority = .defaultLow
            constraintNoCalendar.priority = .defaultHigh
            constraintWithCalendar.isActive = false
            constraintNoCalendar.isActive = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.tableView.beginUpdates()
                self.tableView.deleteRows(at: [calendarIndexPath], with: .fade)
                self.tableView.endUpdates()
            }
            
            UIView.animate(withDuration: 0.5) {
                self.scrollView.layoutIfNeeded()
            }
            isCalendarShown = false
        }
    }
    
    // MARK: Done until button to show
    
    @objc func switchValueChanged(_ sender: UISwitch) {
        DDLogDebug("Switch controller changed value", level: .debug)
        dismissKeyboard()
        if let cell = sender.superview?.superview as? UITableViewCell,
           let tableView = cell.superview as? UITableView {
            let isSwitchOn = sender.isOn
            let dateCell = IndexPath(row: 1, section: 0)
            
            if isSwitchOn {
                DDLogDebug("Deadline activated", level: .debug)
                labelConstraint1?.constant = -10
                if selectedDate == nil {
                    selectedDate = Date(timeIntervalSinceNow: 86400)
                }
                UIView.animate(withDuration: 0.5) {
                    self.dateUntilLabel.alpha = 1
                    self.scrollView.layoutIfNeeded()
                }
            } else {
                DDLogDebug("Deadline disactivated", level: .debug)
                if isCalendarShown {
                    dateButtonPressed()
                }
                tableView.cellForRow(at: dateCell)?.textLabel?.alpha = 1
                UIView.animate(withDuration: 0.5) {
                    self.labelConstraint1?.constant = 0
                    self.dateUntilLabel.alpha = 0
                    self.scrollView.layoutIfNeeded()
                }
                selectedDate = nil
            }
        }
        saveButtonEnableCheck()
    }
    
    // MARK: Working with scrollView
    
    private var contentSize: CGSize {
        CGSize(width: view.frame.width, height: detailsTextView.frame.height + tableView.frame.height + deleteButton.frame.height + 100)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "contentSize" {
            scrollView.contentSize = contentSize
        }
    }
}
