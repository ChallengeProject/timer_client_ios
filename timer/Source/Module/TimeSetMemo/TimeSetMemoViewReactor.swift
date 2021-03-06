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
    enum Action {
        /// Update memo of current time set
        case updateMemo(String)
    }
    
    enum Mutation {
        /// Set memo of the time set
        case setMemo(String)
    }
    
    struct State {
        /// Memo of time set
        var memo: String
    }
    
    // MARK: - properties
    var initialState: State
    
    private let history: History
    
    // MARK: - constructor
    init(history: History) {
        self.history = history
        initialState = State(memo: history.memo)
    }
    
    // MARK: - mutation
    func mutate(action: Action) -> Observable<Mutation> {
        switch action {
        case let .updateMemo(memo):
            return actionUpdateMemo(memo)
        }
    }
    
    // MARK: - reduce
    func reduce(state: State, mutation: Mutation) -> State {
        var state = state
        
        switch mutation {
        case let .setMemo(memo):
            state.memo = memo
            return state
        }
    }
    
    // MARK: - action method
    private func actionUpdateMemo(_ memo: String) -> Observable<Mutation> {
        // Update timer comment
        history.memo = memo
        return .just(.setMemo(memo))
    }
    
    deinit {
        Logger.verbose()
    }
}
