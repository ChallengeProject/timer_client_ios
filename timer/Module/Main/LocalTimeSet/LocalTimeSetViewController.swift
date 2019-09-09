//
//  LocalTimeSetViewController.swift
//  timer
//
//  Created by Jeong Jin Eun on 09/04/2019.
//  Copyright © 2019 Jeong Jin Eun. All rights reserved.
//

import RxSwift
import RxCocoa
import ReactorKit
import RxDataSources

class LocalTimeSetViewController: BaseViewController, View {
    // MARK: - view properties
    private var localTimeSetView: LocalTimeSetView { return view as! LocalTimeSetView }
    
    private var headerView: CommonHeader { return localTimeSetView.headerView }
    
    private var timeSetCollectionView: UICollectionView { return localTimeSetView.timeSetCollectionView }
    
    // MARK: - properties
    var coordinator: LocalTimeSetViewCoordinator
    
    // Time set datasource
    private lazy var dataSource = RxCollectionViewSectionedReloadDataSource<TimeSetSectionModel>(configureCell: { dataSource, collectionView, indexPath, cellType -> UICollectionViewCell in
        switch cellType {
        case let .regular(timeSetinfo):
            if indexPath.section == LocalTimeSetViewReactor.SAVED_TIME_SET_SECTION {
                // Saved time set
                if indexPath.row > 0 {
                    // Highlight time set
                    guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SavedTimeSetCollectionViewCell.name, for: indexPath) as? SavedTimeSetCollectionViewCell else { return UICollectionViewCell() }
                    return cell
                } else {
                    // Normal time set
                    guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SavedTimeSetHighlightCollectionViewCell.name, for: indexPath) as? SavedTimeSetHighlightCollectionViewCell else { return UICollectionViewCell() }
                    return cell
                }
            } else {
                // Bookmared time set
                guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: BookmaredTimeSetCollectionViewCell.name, for: indexPath) as? BookmaredTimeSetCollectionViewCell else { return UICollectionViewCell() }
                cell.dividerType = indexPath.row == 0 ? .both : .bottom
                return cell
            }
            
        case .empty:
            // Induce time set create
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TimeSetInduceCollectionViewCell.name, for: indexPath)
            return cell
        }
        
    }, configureSupplementaryView: { dataSource, collectionView, kind, indexPath -> UICollectionReusableView in
        switch kind {
        case JSCollectionViewLayout.Element.header.kind:
            // Global header
            guard let supplementaryView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: TimeSetHeaderCollectionReusableView.name, for: indexPath) as? TimeSetHeaderCollectionReusableView else {
                return UICollectionReusableView()
            }
            return supplementaryView
            
        case JSCollectionViewLayout.Element.sectionHeader.kind:
            // Section header
            guard let supplementaryView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: TimeSetSectionCollectionReusableView.name, for: indexPath) as? TimeSetSectionCollectionReusableView else {
                return UICollectionReusableView()
            }
            
            // Set view type
            let cellType = self.reactor?.currentState.sections[indexPath.section].items.first
            switch cellType {
            case .regular(_):
                supplementaryView.type = .header
                
            default:
                // Set title header except regular type cell
                supplementaryView.type = .title
            }
            
            // Set header text
            if indexPath.section == LocalTimeSetViewReactor.SAVED_TIME_SET_SECTION {
                // Saved time set
                supplementaryView.titleLabel.text = "저장한 타임셋"
                supplementaryView.additionalTitleLabel.text = "저장한 타임셋 관리"
            } else {
                // Bookmarked time set
                supplementaryView.titleLabel.text = "즐겨찾는 타임셋"
                supplementaryView.additionalTitleLabel.text = "즐겨찾는 타임셋 관리"
            }
            
            return supplementaryView
            
        case JSCollectionViewLayout.Element.sectionFooter.kind:
            guard let supplementaryView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: TimeSetSectionCollectionReusableView.name, for: indexPath) as? TimeSetSectionCollectionReusableView else {
                return UICollectionReusableView()
            }
            
            // Set view type footer
            supplementaryView.type = .footer
            
            if indexPath.section == LocalTimeSetViewReactor.SAVED_TIME_SET_SECTION {
                // Saved time set
                supplementaryView.additionalTitleLabel.text = "저장한 시간 모두보기"
            } else {
                // Bookmarked time set
                supplementaryView.additionalTitleLabel.text = "즐겨찾는 시간 모두보기"
            }
            
            return supplementaryView
            
        default:
            return UICollectionReusableView()
        }
    })
    
    // MARK: - constructor
    init(coordinator: LocalTimeSetViewCoordinator) {
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - lifecycle
    override func loadView() {
        view = LocalTimeSetView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Register supplimentary view
        timeSetCollectionView.register(TimeSetHeaderCollectionReusableView.self, forSupplementaryViewOfKind: JSCollectionViewLayout.Element.header.kind, withReuseIdentifier: TimeSetHeaderCollectionReusableView.name)
        timeSetCollectionView.register(TimeSetSectionCollectionReusableView.self, forSupplementaryViewOfKind: JSCollectionViewLayout.Element.sectionHeader.kind, withReuseIdentifier: TimeSetSectionCollectionReusableView.name)
        timeSetCollectionView.register(TimeSetSectionCollectionReusableView.self, forSupplementaryViewOfKind: JSCollectionViewLayout.Element.sectionFooter.kind, withReuseIdentifier: TimeSetSectionCollectionReusableView.name)
        // Register cell
        timeSetCollectionView.register(TimeSetInduceCollectionViewCell.self, forCellWithReuseIdentifier: TimeSetInduceCollectionViewCell.name)
        timeSetCollectionView.register(SavedTimeSetHighlightCollectionViewCell.self, forCellWithReuseIdentifier: SavedTimeSetHighlightCollectionViewCell.name)
        timeSetCollectionView.register(SavedTimeSetCollectionViewCell.self, forCellWithReuseIdentifier: SavedTimeSetCollectionViewCell.name)
        timeSetCollectionView.register(BookmaredTimeSetCollectionViewCell.self, forCellWithReuseIdentifier: BookmaredTimeSetCollectionViewCell.name)
        
        // Set layout delegate
        if let layout = timeSetCollectionView.collectionViewLayout as? JSCollectionViewLayout {
            layout.delegate = self
        }
    }
    
    override func bind() {
        rx.viewWillAppear
            .take(1)
            .subscribe(onNext: {
                if let tabBar = (self.tabBarController as? MainViewController)?._tabBar {
                    // Adjust time set collection view size by tab bar
                    self.timeSetCollectionView.snp.updateConstraints { make in
                        make.bottom.equalToSuperview().inset(tabBar.bounds.height)
                    }
                }
            })
            .disposed(by: disposeBag)
        
        timeSetCollectionView.rx.setDelegate(self).disposed(by: disposeBag)
    }
    
    // MARK: - bind
    func bind(reactor: LocalTimeSetViewReactor) {
        // MARK: action
        rx.viewWillAppear
            .map { Reactor.Action.viewWillAppear }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)
        
        timeSetCollectionView.rx.itemSelected
            .withLatestFrom(reactor.state.map { $0.sections }, resultSelector: { ($0, $1) })
            .subscribe(onNext: { [weak self] in self?.timeSetSelected(cell: $1[$0.section].items[$0.item]) })
            .disposed(by: disposeBag)
        
        // MARK: state
        reactor.state
            .filter { $0.shouldSectionReload }
            .map { $0.sections }
            .bind(to: timeSetCollectionView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)
    }
    
    // MARK: - action method
    /// Perform present by selected cell type
    private func timeSetSelected(cell type: TimeSetCellType) {
        switch type {
        case let .regular(timeSetInfo):
            _ = coordinator.present(for: .timeSetDetail(timeSetInfo))
            
        case .empty:
            tabBarController?.selectedIndex = MainViewController.TabType.Productivity.rawValue
        }
    }
    
    deinit {
        Logger.verbose()
    }
}

extension LocalTimeSetViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offsetThreshold: CGFloat = 3
        let blurThreshold: CGFloat = 10
        let weight: CGFloat = 5
        
        // Set shadow by scroll
        headerView.layer.shadow(alpha: 0.04,
                                offset: CGSize(width: 0, height: min(scrollView.contentOffset.y / weight, offsetThreshold)),
                                blur: min(scrollView.contentOffset.y / weight, blurThreshold))
    }
}

extension LocalTimeSetViewController: JSCollectionViewDelegateLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard let layout = collectionViewLayout as? UICollectionViewFlowLayout else { return .zero }
        
        let horizontalInset = collectionView.contentInset.left + collectionView.contentInset.right
        var size = CGSize(width: collectionView.bounds.width - horizontalInset, height: 0)
        
        if indexPath.section == LocalTimeSetViewReactor.SAVED_TIME_SET_SECTION {
            // Saved time set
            size.height = 140.adjust()
            if indexPath.row > 0 {
                // Set width that half of collection view width except first time set
                size.width = (size.width - layout.minimumInteritemSpacing) / 2
            }
        } else {
            // Bookmarked time set
            size.height = 90.adjust()
        }
        
        return size
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return section == LocalTimeSetViewReactor.SAVED_TIME_SET_SECTION ? 10.adjust() : 0
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        guard let reactor = reactor, let cellType = reactor.currentState.sections[section].items.first else {
            return .zero
        }
        
        let horizontalInset = collectionView.contentInset.left + collectionView.contentInset.right
        switch cellType {
        case .regular(_):
            // Common header
            return CGSize(width: collectionView.bounds.width - horizontalInset, height: 113.adjust())
            
        case .empty:
            // Title header
            return CGSize(width: collectionView.bounds.width - horizontalInset, height: 63.adjust())
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        let horizontalInset = collectionView.contentInset.left + collectionView.contentInset.right
        return CGSize(width: collectionView.bounds.width - horizontalInset, height: 40.adjust())
    }
    
    func referenceSizeForHeader(in collectionView: UICollectionView, layout collectionViewLayout: JSCollectionViewLayout) -> CGSize {
        let horizontalInset = collectionView.contentInset.left + collectionView.contentInset.right
        return CGSize(width: collectionView.bounds.width - horizontalInset, height: 103.adjust())
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: JSCollectionViewLayout, visibleHeaderInSection section: Int) -> Bool {
        guard let reactor = reactor, !reactor.currentState.sections[section].items.isEmpty else { return false }
        return true
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: JSCollectionViewLayout, visibleFooterInSection section: Int) -> Bool {
        guard let reactor = reactor else { return false }
        
        let savedTimeSetCount = reactor.currentState.savedTimeSetCount
        let bookmarkedTimeSetCount = reactor.currentState.bookmarkedTimeSetCount
        
        if section == LocalTimeSetViewReactor.SAVED_TIME_SET_SECTION {
            return savedTimeSetCount > LocalTimeSetViewReactor.MAX_SAVED_TIME_SET
        } else {
            return bookmarkedTimeSetCount > LocalTimeSetViewReactor.MAX_BOOKMARKED_TIME_SET
        }
    }
}
