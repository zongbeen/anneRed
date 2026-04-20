//
//  UpdateViewController.swift
//  DdayApp
//
//  Created by zongbeen on 4/17/26.
//

import Foundation
import UIKit

class UpdateViewController: UIViewController {
    @IBOutlet weak var tf1: UITextField!
    @IBOutlet weak var tf2: UITextField!
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
}
