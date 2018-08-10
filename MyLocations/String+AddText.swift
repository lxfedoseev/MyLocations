//
//  String+AddText.swift
//  MyLocations
//
//  Created by Alex Fedoseev on 07.08.2018.
//  Copyright © 2018 Alex Fedoseev. All rights reserved.
//

extension String {
    mutating func add(text: String?, separatedBy separator: String = "") {
        if let text = text {
            if !isEmpty {
                self += separator
            }
            self += text }
    }
    
}
