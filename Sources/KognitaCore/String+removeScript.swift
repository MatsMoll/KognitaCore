//
//  String+removeScript.swift
//  App
//
//  Created by Mats Mollestad on 10/01/2019.
//

import Foundation

extension String {
    public mutating func makeHTMLSafe() {
        self = replacingOccurrences(of: "<script>", with: "")
        self = replacingOccurrences(of: "<\\script>", with: "")
    }
}
