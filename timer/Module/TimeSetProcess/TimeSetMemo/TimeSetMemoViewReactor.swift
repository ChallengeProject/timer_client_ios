//
//  TimeSetMemoViewReactor.swift
//  timer
//
//  Created by JSilver on 25/08/2019.
//  Copyright © 2019 Jeong Jin Eun. All rights reserved.
//

import RxSwift
import ReactorKit

class TimeSetMemoViewReactor: Reactor {
    // MARK: - Constants
    static let MAX_MEMO_LENGTH = 1000
    
    enum Action {
        /// Update memo of current time set
        case updateMemo(String)
        
        /// Toggle the time set bookmark
        case toggleBookmark
    }
    
    enum Mutation {
        /// Set memo of time set
        case setMemo(String)
        
        /// Set remainted time of time set
        case setRemainedTime(TimeInterval)
        
        /// Set time set bookmark
        case setBookmark(Bool)
    }
    
    struct State {
        /// Title of time set
        let title: String
        
        /// Remained time of time set
        var remainedTime: TimeInterval
        
        /// Memo of time set
        var memo: String
        
        /// Bookmark setting value of time set
        var isBookmark: Bool
    }
    
    // MARK: - properties
    var initialState: State
    
    private let timeSetInfo: TimeSetInfo? // Original time set info
    private let timeSet: TimeSet // Running time set
    private var remainedTime: TimeInterval // Remained time that after executing timer of time set
    
    // MARK: - constructor
    init(timeSet: TimeSet, origin info: TimeSetInfo) {
        self.timeSetInfo = info
        self.timeSet = timeSet

        let index = timeSet.currentIndex
        self.remainedTime = timeSet.info.timers.enumerated()
            .filter { $0.offset > index }
            .reduce(0) { $0 + $1.element.endTime }
        
        let timer = timeSet.info.timers[index]
        let remainedTime = self.remainedTime + (timer.endTime + timer.extraTime - timer.currentTime)
        
        self.initialState = State(title: timeSet.info.title,
                                  remainedTime: remainedTime,
                                  memo: timeSet.info.memo,
                                  isBookmark: info.isBookmark)
    }
    
    // MARK: - mutation
    func mutate(action: Action) -> Observable<Mutation> {
        switch action {
        case let .updateMemo(memo):
            return actionUpdateMemo(memo)
            
        case .toggleBookmark:
            return actionToggleBookmark()
        }
    }
    
    func mutate(timeSetEvent: TimeSet.Event) -> Observable<Mutation> {
        switch timeSetEvent {
        case let .timerChanged(timer, at: index):
            return actionTimeSetTimerChanged(timer, at: index)
            
        case let .timeChanged(current: currentTime, end: endTime):
            return actionTimeSetTimeChanged(current: currentTime, end: endTime)
            
        default:
            return .empty()
        }
    }
    
    func transform(mutation: Observable<Mutation>) -> Observable<Mutation> {
        let timeSetEventMutation = timeSet.event
            .flatMap { [weak self] in self?.mutate(timeSetEvent: $0) ?? .empty() }
        
        return .merge(mutation, timeSetEventMutation)
    }
    
    func reduce(state: State, mutation: Mutation) -> State {
        var state = state
        
        switch mutation {
        case let .setMemo(memo):
            state.memo = memo
            return state
            
        case let .setRemainedTime(remainedTime):
            state.remainedTime = remainedTime
            return state
            
        case let .setBookmark(isBookmark):
            state.isBookmark = isBookmark
            return state
        }
    }
    
    // MARK: - action method
    private func actionUpdateMemo(_ memo: String) -> Observable<Mutation> {
        // Update time set's memo
        let length = memo.lengthOfBytes(using: .utf16)
        
        guard length <= TimeSetMemoViewReactor.MAX_MEMO_LENGTH else {
            return .just(.setMemo(timeSet.info.memo))
        }
        
        timeSet.info.memo = memo
        
        return .just(.setMemo(memo))
    }
    
    private func actionToggleBookmark() -> Observable<Mutation> {
        guard let timeSetInfo = timeSetInfo else { return .empty() }
        // Toggle original time set bookmark
        timeSetInfo.isBookmark.toggle()
        return .just(.setBookmark(timeSetInfo.isBookmark))
    }
    
    private func actionTimeSetTimerChanged(_ timer: TimerInfo, at index: Int) -> Observable<Mutation> {
       // Calculate remained time
       remainedTime = timeSet.info.timers.enumerated()
           .filter { $0.offset > index }
           .reduce(0) { $0 + $1.element.endTime }
       
       return .just(.setRemainedTime(remainedTime + timer.endTime))
   }
   
   private func actionTimeSetTimeChanged(current: TimeInterval, end: TimeInterval) -> Observable<Mutation> {
       return .just(.setRemainedTime(remainedTime + (end - floor(current))))
   }
}
