//
//  ProductivityViewController.swift
//  timer
//
//  Created by Jeong Jin Eun on 09/04/2019.
//  Copyright © 2019 Jeong Jin Eun. All rights reserved.
//

import RxSwift
import RxCocoa
import ReactorKit
import RxDataSources
import JSReorderableCollectionView

class ProductivityViewController: BaseHeaderViewController, ViewControllable, View {
    // MARK: - view properties
    private var productivityView: ProductivityView { return view as! ProductivityView }
    
    override var headerView: CommonHeader { return productivityView.headerView }
    
    private var timerInputView: TimerInputView { return productivityView.timerInputView }
    private var timerClearButton: UIButton { return productivityView.timerInputView.timerClearButton }
    
    private var timeInfoView: UIView { return productivityView.timeInfoView }
    private var allTimeLabel: UILabel { return productivityView.allTimeLabel }
    private var endOfTimeSetLabel: UILabel { return productivityView.endOfTimeSetLabel }
    private var timerInputLabel: UILabel { return productivityView.timeInputLabel }
    
    private var keyPadView: NumberKeyPad { return productivityView.keyPadView }
    
    private var timeKeyView: TimeKeyPad { return productivityView.timeKeyPadView }
    
    private var timerBadgeCollectionView: TimerBadgeCollectionView { return productivityView.timerBadgeCollectionView }
    
    private var timerOptionView: TimerOptionView { return productivityView.timerOptionView }
    
    private var saveButton: FooterButton { return productivityView.saveButton }
    private var startButton: FooterButton { return productivityView.startButton }
    private var footerView: Footer { return productivityView.footerView }
    
    // MARK: - properties
    private let canTimeSetStart: BehaviorRelay<Bool> = BehaviorRelay(value: false)
    private let isTimerOptionVisible: BehaviorRelay<Bool> = BehaviorRelay(value: false)
    private var isBadgeMoving: Bool = false
    
    var coordinator: ProductivityViewCoordinator
    
    // MARK: - constructor
    init(coordinator: ProductivityViewCoordinator) {
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - lifecycle
    override func loadView() {
        view = ProductivityView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(longPressHandler(gesture:)))
        timerBadgeCollectionView.addGestureRecognizer(longPressGesture)
        
        // Set move item closure on timer badge datasource
        timerBadgeCollectionView._dataSource.moveItem = { [weak self] dataSource, sourceIndexPath, destinationIndexPath in
            let section = TimerBadgeSectionType.regular.rawValue
            guard let reactor = self?.reactor,
                sourceIndexPath.section == section && destinationIndexPath.section == section else { return }
            
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            reactor.action.onNext(.moveTimer(at: sourceIndexPath.item, to: destinationIndexPath.item))
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Add footer view when view did appear because footer view should remove after will appear due to animation (add view)
        addFooterView()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Remove footer view when view controller disappeared
        showFooterView(isShow: false) {
            self.footerView.removeFromSuperview()
        }
    }
    
    // MARK: - bind
    override func bind() {
        super.bind()
        
        rx.viewDidAppear // For get super view controller
            .take(1)
            .flatMap { [weak self] () -> Observable<Void> in
                guard let self = self else { return .empty() }

                return Observable.merge([
                    self.navigationController?.rx.didShow
                        .skip(1) // Skip until did finished drawing of tab bar controller
                        .filter { [weak self] in ($0.viewController as? UITabBarController)?.selectedViewController == self }
                        .map { _ in Void() },
                    self.tabBarController?.rx.didSelect
                        .filter { [weak self] in $0 == self }
                        .map { _ in Void() }
                ].compactMap { $0 })
            }
            .withLatestFrom(canTimeSetStart)
            .subscribe(onNext: { [weak self] in self?.showFooterView(isShow: $0) })
            .disposed(by: disposeBag)
        
        headerView.rx.tap
            .subscribe(onNext: { [weak self] in self?.handleHeaderAction($0) })
            .disposed(by: disposeBag)
        
        canTimeSetStart
            .subscribe(onNext: { [weak self] in self?.updateLayoutFrom(canTimeSetStart: $0) })
            .disposed(by: disposeBag)
        
        isTimerOptionVisible
            .distinctUntilChanged()
            .map { !$0 }
            .do(onNext: { [weak self] in self?.productivityView.isEnabled = $0 })
            .do(onNext: { [weak self] in self?.timerBadgeCollectionView.isScrollEnabled = $0 })
            .bind(to: timerOptionView.rx.isHiddenWithAnimation)
            .disposed(by: disposeBag)
    }
    
    func bind(reactor: TimeSetEditViewReactor) {
        // DI
        timerOptionView.reactor = reactor.timerOptionViewReactor
        bind(timerOption: timerOptionView)
        
        // MARK: action
        timerClearButton.rx.tap
            .do(onNext: { UIImpactFeedbackGenerator(style: .light).impactOccurred() })
            .map { Reactor.Action.clearTimer }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)
    
        keyPadView.rx.keyPadTap
            .filter { $0 != .cancel }
            .compactMap { [weak self] in self?.updateTime(key: $0) }
            .map { Reactor.Action.updateTime($0) }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)
        
        keyPadView.rx.keyPadTap
            .filter { $0 == .cancel }
            .subscribe(onNext: { [weak self] _ in self?.showTimeSetInitWarningAlert() })
            .disposed(by: disposeBag)
        
        timeKeyView.rx.tap
            .compactMap { [weak self] in self?.getBaseTime(from: $0) }
            .map { Reactor.Action.addTime(base: $0) }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)
        
        let itemSelected = timerBadgeCollectionView.rx.itemSelected
            .do(onNext: { _ in UIImpactFeedbackGenerator(style: .light).impactOccurred() })
            .withLatestFrom(reactor.state.map { $0.selectedIndex }, resultSelector: { ($0, $1) })
            .share(replay: 1)
        
        itemSelected
            .compactMap { [weak self] in self?.selectBadge(at: $0.0) }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)
        
        itemSelected
            .filter { $0.0.section == TimerBadgeSectionType.regular.rawValue }
            .filter { $0.0.item == $0.1 }
            .map { [weak self] _ in !(self?.isTimerOptionVisible.value ?? true) }
            .bind(to: isTimerOptionVisible)
            .disposed(by: disposeBag)
        
        saveButton.rx.tap
            .map { Reactor.Action.saveTimeSet }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)
        
        startButton.rx.tap
            .map { Reactor.Action.startTimeSet }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)
        
        // MARK: state
        // Can time set start
        reactor.state
            .map { $0.allTime > 0 }
            .distinctUntilChanged()
            .bind(to: canTimeSetStart)
            .disposed(by: disposeBag)
        
        // Timer end time
        reactor.state
            .map { $0.endTime }
            .distinctUntilChanged()
            .do(onNext: { [weak self] _ in self?.isTimerOptionVisible.accept(false) })
            .bind(to: timerInputView.rx.timer)
            .disposed(by: disposeBag)
        
        // Current inputed time
        reactor.state
            .map { $0.time }
            .distinctUntilChanged()
            .map { $0 > 0 ? "\("productivity_time_input_prefix_title".localized)\($0)" : "" }
            .bind(to: timerInputLabel.rx.text)
            .disposed(by: disposeBag)
        
        // All time
        reactor.state
            .map { $0.allTime }
            .distinctUntilChanged()
            .map { getTime(interval: $0) }
            .map { String(format: "time_set_all_time_title_format".localized, $0.0, $0.1, $0.2) }
            .bind(to: allTimeLabel.rx.text)
            .disposed(by: disposeBag)
        
        // End of time set
        Observable.combineLatest(
            reactor.state
                .map { $0.allTime }
                .distinctUntilChanged(),
            Observable<Int>.timer(.seconds(0), period: .seconds(30), scheduler: ConcurrentDispatchQueueScheduler(qos: .default)))
            .map { Date().addingTimeInterval($0.0) }
            .map { getDateString(format: "time_set_end_time_format".localized, date: $0, locale: Locale(identifier: Constants.Locale.USA)) }
            .map { String(format: "time_set_end_time_title_format".localized, $0) }
            .bind(to: endOfTimeSetLabel.rx.text)
            .disposed(by: disposeBag)
        
        // Time info view
        reactor.state
            .map { $0.time > 0 || $0.allTime == 0 }
            .distinctUntilChanged()
            .bind(to: timeInfoView.rx.isHiddenWithAnimation)
            .disposed(by: disposeBag)
        
        // Time key
        reactor.state
            .map { $0.time == 0 && $0.allTime == 0 }
            .distinctUntilChanged()
            .bind(to: timeKeyView.rx.isHiddenWithAnimation, keyPadView.cancelButton.rx.isHiddenWithAnimation)
            .disposed(by: disposeBag)
        
        reactor.state
            .map { $0.time }
            .distinctUntilChanged()
            .withLatestFrom(reactor.state.map { $0.endTime }, resultSelector: { ($0, $1) })
            .compactMap { [weak self] in self?.getEnableTimeKey(from: $0.0, endTime: $0.1) }
            .bind(to: timeKeyView.rx.enableKey)
            .disposed(by: disposeBag)
        
        // Timer badge
        reactor.state
            .map { $0.sections }
            .distinctUntilChanged()
            .map { $0.value }
            .bind(to: timerBadgeCollectionView.rx.items(dataSource: timerBadgeCollectionView._dataSource))
            .disposed(by: disposeBag)
        
        reactor.state
            .map { $0.selectedIndex }
            .distinctUntilChanged()
            .do(onNext: { [weak self] _ in self?.isTimerOptionVisible.accept(false) })
            .map { IndexPath(item: $0, section: TimerBadgeSectionType.regular.rawValue) }
            .subscribe(onNext: { [weak self] in self?.badgeScrollIfCan(at: $0) })
            .disposed(by: disposeBag)
        
        reactor.state
            .map { $0.shouldSave }
            .distinctUntilChanged()
            .compactMap { $0.value }
            .filter { $0 }
            .subscribe(onNext: { [weak self] _ in _ = self?.coordinator.present(for: .timeSetSave(reactor.timeSetItem), animated: true) })
            .disposed(by: disposeBag)
        
        reactor.state
            .map { $0.shouldStart }
            .distinctUntilChanged()
            .compactMap { $0.value }
            .filter { $0 }
            .do(onNext: { [weak self] _ in _ = self?.coordinator.present(for: .timeSetProcess(reactor.timeSetItem), animated: true) })
            .observeOn(MainScheduler.asyncInstance)
            .map { _ in Reactor.Action.clearTimeSet }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)
        
        // Scroll to selected badge when timer option view visible
        isTimerOptionVisible
            .filter { $0 }
            .withLatestFrom(reactor.state.map { $0.selectedIndex })
            .map { IndexPath(item: $0, section: TimerBadgeSectionType.regular.rawValue) }
            .subscribe(onNext: { [weak self] in self?.badgeScrollIfCan(at: $0) })
            .disposed(by: disposeBag)
    }
    
    private func bind(timerOption view: TimerOptionView) {
        guard let reactor = reactor else { return }
        
        view.rx.tapApplyAll
            .do(onNext: { Toast(content: String(format: "toast_alarm_all_apply_title".localized, $0.title)).show(animated: true, withDuration: 3) })
            .map { Reactor.Action.alarmApplyAll($0) }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)
        
        view.rx.tapDelete
            .do(onNext: { [weak self] in self?.isTimerOptionVisible.accept(false) })
            .map { Reactor.Action.deleteTimer }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)
    }

    // MARK: - action method
    func handleHeaderAction(_ action: CommonHeader.Action) {
        switch action {
        case .history:
            _ = coordinator.present(for: .history, animated: true)
            
        case .setting:
            _ = coordinator.present(for: .setting, animated: true)
            
        default:
            break
        }
    }
    
    /// Convert number key pad input to time value
    private func updateTime(key: NumberKeyPad.Key) -> Int {
        guard let text = timerInputLabel.text else { return 0 }
        
        let prefix = "productivity_time_input_prefix_title".localized
        let range = Range(uncheckedBounds: (text.range(of: prefix)?.upperBound ?? text.startIndex, text.endIndex))
        var time = String(text[range])
        
        switch key {
        case .cancel:
            break
            
        case .back:
            guard !time.isEmpty else { return 0 }
            time.removeLast()
            
        default:
            time.append(String(key.rawValue))
        }
        
        return Int(time) ?? 0
    }
    
    /// Get base time (second) from key of time key view
    private func getBaseTime(from key: TimeKeyPad.Key) -> TimeInterval {
        switch key {
        case .hour:
            return Constants.Time.hour
            
        case .minute:
            return Constants.Time.minute
            
        case .second:
            return 1
        }
    }
    
    /// Convert badge select event to reactor action
    private func selectBadge(at indexPath: IndexPath) -> TimeSetEditViewReactor.Action? {
        guard let reactor = reactor else { return nil }
        
        let cellType = reactor.currentState.sections.value[indexPath.section].items[indexPath.item]
        switch cellType {
        case .regular(_):
            return .selectTimer(at: indexPath.item)
            
        case let .extra(type):
            switch type {
            case .add:
                return .addTimer
                
            case .repeat:
                return nil
            }
        }
    }
    
    // MARK: - state method
    /// Get enable time key from values of time & timer
    private func getEnableTimeKey(from time: Int, endTime: TimeInterval) -> TimeKeyPad.Key {
        if endTime + (TimeInterval(time) * Constants.Time.minute) > TimeSetEditViewReactor.MAX_TIME_INTERVAL {
            return .second
        } else if endTime + (TimeInterval(time) * Constants.Time.hour) > TimeSetEditViewReactor.MAX_TIME_INTERVAL {
            return .minute
        } else {
            return .hour
        }
    }
    
    /// Update layout according to time set can start
    /// - Show/Hide timer badge collection view
    ///   - Scroll default badge position when view is visibled
    /// - Set tab bar swipe enabled
    /// - Show/Hide footer view
    private func updateLayoutFrom(canTimeSetStart: Bool) {
        timerBadgeCollectionView.setHidden(!canTimeSetStart, animated: true)
        
        if canTimeSetStart {
            // Scroll timer badge to seleted index if badge is visible
            timerBadgeCollectionView.scrollToBadge(at: IndexPath(item: 0, section: TimerBadgeSectionType.regular.rawValue), animated: false)
        }
        
        // Prevent tab bar swipe gesture
        if let tabBarController = tabBarController as? MainViewController {
            tabBarController.swipeEnable = !canTimeSetStart
        }
        
        // Show timer option footer view
        showFooterView(isShow: canTimeSetStart)
    }
    
    /// Scroll timer badge view if badge isn't moving
    private func badgeScrollIfCan(at indexPath: IndexPath) {
        guard !isBadgeMoving else { return }
        timerBadgeCollectionView.scrollToBadge(at: indexPath, animated: true)
    }
    
    // MARK: - private method
    /// Show popup alert about warning to init time set
    private func showTimeSetInitWarningAlert() {
        guard let reactor = reactor else { return }
        
        let alert = AlertBuilder(title: "alert_warning_time_set_init_title".localized,
                                 message: "alert_warning_time_set_init_description".localized)
            .addAction(title: "alert_button_cancel".localized, style: .cancel)
            .addAction(title: "alert_button_init".localized, style: .destructive, handler: { _ in
                reactor.action.onNext(.clearTimers)
            })
            .build()
        // Present warning alert view controller
        present(alert, animated: true)
    }
    
    /// Add footer view into tab bar controller's view to show top of the tab bar hierarchy
    private func addFooterView() {
        guard let tabBarController = tabBarController else { return }
        tabBarController.view.addSubview(footerView)
        
        let tabBar = tabBarController.tabBar
        var frame = tabBar.frame
        
        // TODO: Need to refactor footer view to set frame
        frame.size.height = 64.adjust() + tabBarController.view._safeAreaInsets.bottom
        // Positioning out of screen
        frame.origin.y = tabBar.frame.maxY
        footerView.frame = frame
    }
    
    /// Show footer view (save & add & start)
    private func showFooterView(isShow: Bool, completion: (() -> Void)? = nil) {
        guard let tabBar = tabBarController?.tabBar, footerView.superview != nil else { return }
        
        var frame = footerView.frame
        frame.origin.y = isShow ? tabBar.frame.maxY - frame.height : tabBar.frame.maxY
        
        let animator = UIViewPropertyAnimator(duration: 0.3, curve: .easeIn, animations: {
            self.footerView.frame = frame
        })
        
        animator.addCompletion({ position in
            if position == .end {
                completion?()
            }
        })
        
        animator.startAnimation()
    }
    
    // MARK: - selector
    @objc private func longPressHandler(gesture: UILongPressGestureRecognizer) {
        let location = gesture.location(in: timerBadgeCollectionView.superview)
        
        switch gesture.state {
        case .began:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            
            isTimerOptionVisible.accept(false)
            isBadgeMoving = true
            
            timerBadgeCollectionView.beginInteractiveWithLocation(location)
            
        case .changed:
            timerBadgeCollectionView.updateInteractiveWithLocation(location)
            
        default:
            isBadgeMoving = false
            timerBadgeCollectionView.finishInteractive()
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
    }
    
    deinit {
        Logger.verbose()
    }
}
