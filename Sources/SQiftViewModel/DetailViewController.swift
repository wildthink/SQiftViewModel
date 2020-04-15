//
//  DetailViewController.swift
//  Freds Bank
//
//  Created by Jason Jobe on 4/5/20.
//  Copyright © 2020 Jason Jobe. All rights reserved.
//

import UIKit

open class DetailViewController: UIViewController {

    open override func refresh(from model: ViewModel) {
        guard let viewModel = viewModel,
              let modelId = modelId else { return }
        
        let parts = modelId.components(separatedBy: "/")
        guard let table = parts.first, let key = parts.last,
              let id: Int64 = viewModel.get(env: key, default: 0)
        else { return }
        viewModel.refresh(view: view, from: table, id: Int(id))
    }

    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let viewModel = viewModel {
            refresh(from: viewModel)
        }
    }

}

