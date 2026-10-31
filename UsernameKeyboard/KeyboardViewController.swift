//
//  KeyboardViewController.swift
//  UsernameKeyboard
//
//  A keyboard that types a fresh username into any text field. It never asks for Full Access,
//  so it has no network and can't see what you type. Its few options are kept in its own storage.
//

import Observation
import SwiftUI
import UIKit

/// Lets the SwiftUI view know whether the system wants a "next keyboard" key.
@Observable
final class KeyboardHost {
    var showsGlobe = false
}

final class KeyboardViewController: UIInputViewController {
    private let host = KeyboardHost()

    override func viewDidLoad() {
        super.viewDidLoad()

        let content = UIHostingController(rootView: KeyboardView(
            host: host,
            controller: self,
            insert: { [weak self] text in self?.textDocumentProxy.insertText(text) },
            deleteBackward: { [weak self] in self?.textDocumentProxy.deleteBackward() }
        ))
        addChild(content)
        content.view.translatesAutoresizingMaskIntoConstraints = false
        content.view.backgroundColor = .clear
        view.addSubview(content.view)
        NSLayoutConstraint.activate([
            content.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            content.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            content.view.topAnchor.constraint(equalTo: view.topAnchor),
            content.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        content.didMove(toParent: self)

        // A fixed height that the system may still override, so it never causes a layout conflict.
        let height = view.heightAnchor.constraint(equalToConstant: 260)
        height.priority = .defaultHigh
        height.isActive = true
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        host.showsGlobe = needsInputModeSwitchKey
    }
}
