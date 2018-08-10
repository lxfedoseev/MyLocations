//
//  MyTabBarController.swift
//  MyLocations
//
//  Created by Alex Fedoseev on 09.08.2018.
//  Copyright © 2018 Alex Fedoseev. All rights reserved.
//

import UIKit

class MyTabBarController: UITabBarController {
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    override var childViewControllerForStatusBarStyle: UIViewController? {
        return nil
    } }
