//
//  AppInfoView.swift
//  timer
//
//  Created by Jeong Jin Eun on 13/04/2019.
//  Copyright © 2019 Jeong Jin Eun. All rights reserved.
//

import UIKit

class AppInfoView: UIView {
    let developer: UILabel = {
        let view = UILabel()
        view.text = "Jeong Jin Eun"
        view.font = Constants.Font.ExtraBold.withSize(26.adjust())
        return view
    }()
    
    let email: UILabel = {
        let view = UILabel()
        view.text = "email : jsilver.dev@gmail.com"
        view.font = Constants.Font.Regular.withSize(17.adjust())
        return view
    }()
    
    let version: UILabel = {
        let view = UILabel()
        view.text = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        view.font = Constants.Font.Regular.withSize(17.adjust())
        return view
    }()
    
    lazy var stackView: UIStackView = { [unowned self] in
        let view = UIStackView(arrangedSubviews: [self.developer, self.email, self.version])
        view.axis = .vertical
        view.alignment = .center
        view.spacing = 8.adjust()
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Constants.Color.white
        
        addAutolayoutSubview(stackView)
        
        stackView.snp.makeConstraints({ make in
            make.center.equalToSuperview()
        })
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}