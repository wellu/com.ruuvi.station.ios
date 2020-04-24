//
//  KaltiotPickerTableViewController.swift
//  station
//
//  Created by Viik.ufa on 24.04.2020.
//  Copyright © 2020 Ruuvi Innovations Oy. BSD-3-Clause.
//

import UIKit

class KaltiotPickerTableViewController: UITableViewController {

    var output: KaltiotPickerViewOutput!
// MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        output.viewDidLoad()
    }
// MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 0
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 0
    }
}
// MARK: - KaltiotPickerViewInput
extension KaltiotPickerTableViewController: KaltiotPickerViewInput {
    func localize() {
    }
}
