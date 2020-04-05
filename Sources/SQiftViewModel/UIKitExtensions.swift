//
//  UIKitExtensions.swift
//  VMSampler
//
//  Created by Jobe, Jason on 12/8/19.
//  Copyright © 2019 Jobe, Jason. All rights reserved.
//

import UIKit

public struct ViewControllerKey {
    public let storyboardName: String
    public let viewControllerIdentifier: String

    public init (_ key: String) {
        let parts = key.components(separatedBy: ".")
        storyboardName = parts.first ?? "Main"
        viewControllerIdentifier = parts.last ?? ""
    }

    func instantiateInitialViewController(from bundle: Bundle? = nil) -> UIViewController? {
        let sb = UIStoryboard(name:storyboardName, bundle: bundle)
        if viewControllerIdentifier.isEmpty { return sb.instantiateInitialViewController() }
        // else
        var vc: UIViewController?

//        let error = objc_try {
            vc = sb.instantiateViewController(withIdentifier: self.viewControllerIdentifier)
//        }
        // Report Missing view controller?
        return vc
    }

}

extension UIView {
    public var viewController: UIViewController? {
        return (next as? UIViewController) ?? superview?.viewController
    }
}
