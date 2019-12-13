//
//  TimeSetDetailViewReactor.swift
//  timer
//
//  Created by JSilver on 06/08/2019.
//  Copyright © 2019 Jeong Jin Eun. All rights reserved.
//

import RxSwift
import ReactorKit

class TimeSetDetailViewReactor: Reactor {
    enum Action {
        /// Toggle time set bookmark
        case toggleBookmark
        
        /// Select the timer
        case selectTimer(at: Int)
        
        /// Save the time set
        case saveTimeSet
    }
    
    enum Mutation {
        /// Set time set bookmark
        case setBookmark(Bool)
        
        /// Set current timer
        case setTimer(TimerItem)
        
        /// Set selected index
        case setSelectedIndex(at: Int)
        
        /// Save the time set
        case save
    }
    
    struct State {
        /// Time set bookmarked mark
        var isBookmark: Bool
        
        /// Title of time set
        let title: String
        
        /// All time of time set
        let allTime: TimeInterval
        
        /// Current selected timer
        var timer: TimerItem
        
        /// Section datasource to make sections
        let sectionDataSource: TimerBadgeDataSource
        
        /// The timer list badge sections
        var sections: [TimerBadgeSectionModel] {
            sectionDataSource.makeSections()
        }
        
        /// Current selected timer index
        var selectedIndex: Int
        
        /// Flag that represent current time set can save
        var canTimeSetSave: Bool
        
        /// Flag that time set is saved
        var didTimeSetSaved: RevisionValue<Bool?>
        
        /// Need section reload
        var shouldSectionReload: Bool
    }
    
    // MARK: - properties
    var initialState: State
    var timeSetService: TimeSetServiceProtocol
    
    var timeSetItem: TimeSetItem
    
    // MARK: - constructor
    init(timeSetService: TimeSetServiceProtocol, timeSetItem: TimeSetItem, canSave: Bool) {
        self.timeSetService = timeSetService
        self.timeSetItem = timeSetItem
        
        // Create seciont datasource
        let dataSource = TimerBadgeDataSource(timers: timeSetItem.timers.toArray(), index: 0)
        
        initialState = State(
            isBookmark: timeSetItem.isBookmark,
            title: timeSetItem.title,
            allTime: timeSetItem.timers.reduce(0) { $0 + $1.end },
            timer: timeSetItem.timers.first ?? TimerItem(),
            sectionDataSource: dataSource,
            selectedIndex: 0,
            canTimeSetSave: canSave,
            didTimeSetSaved: RevisionValue(nil),
            shouldSectionReload: true
        )
    }
    
    // MARK: - mutation
    func mutate(action: Action) -> Observable<Mutation> {
        switch action {
        case .toggleBookmark:
            return actionToggleBookmark()

        case let .selectTimer(at: index):
            return actionSelectTimer(at: index)
            
        case .saveTimeSet:
            return actionSaveTimeSet()
        }
    }
    
    func reduce(state: State, mutation: Mutation) -> State {
        var state = state
        state.shouldSectionReload = false
        
        switch mutation {
        case let .setBookmark(isBookmark):
            state.isBookmark = isBookmark
            return state
            
        case let .setTimer(timer):
            state.timer = timer
            return state
            
        case let .setSelectedIndex(at: index):
            let section: Int = TimerBadgeSectionType.regular.rawValue
            guard index >= 0 && index < state.sections[section].items.count else { return state }
            
            state.selectedIndex = index
            return state
            
        case .save:
            state.canTimeSetSave = false
            state.didTimeSetSaved = state.didTimeSetSaved.next(true)
            return state
        }
    }
    
    // MARK: - action method
    private func actionToggleBookmark() -> Observable<Mutation> {
        // Toggle time set bookmark
        timeSetItem.isBookmark.toggle()
        
        return timeSetService.updateTimeSet(item: timeSetItem).asObservable()
            .map { .setBookmark($0.isBookmark) }
    }
    
    private func actionSelectTimer(at index: Int) -> Observable<Mutation> {
        guard index >= 0 && index < timeSetItem.timers.count else { return .empty() }
        
        let state = currentState
        let previousIndex = state.selectedIndex
        
        // Update selected timer state
        if index != previousIndex {
            state.sectionDataSource.regulars[previousIndex].action.onNext(.select(false))
        }
        state.sectionDataSource.regulars[index].action.onNext(.select(true))
        
        let setSelectedIndex: Observable<Mutation> = .just(.setSelectedIndex(at: index))
        let setTimer: Observable<Mutation> = .just(.setTimer(timeSetItem.timers[index]))
        
        return .concat(setSelectedIndex, setTimer)
    }
    
    private func actionSaveTimeSet() -> Observable<Mutation> {
        // Create the time set
        return timeSetService.createTimeSet(item: timeSetItem).asObservable()
            .do(onNext: { self.timeSetItem = $0 })
            .map { _ in .save }
    }
    
    deinit {
        Logger.verbose()
    }
}
