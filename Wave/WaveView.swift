//
//  WaveView.swift
//  Wave
//
//  Created by Andrew Finke on 11/17/18.
//  Copyright © 2018 Andrew Finke. All rights reserved.
//

import UIKit

class WaveView: UIView {

    // MARK: - Properties

    let uuid: UUID

    // MARK: - Initialization

    init(uuid: UUID) {
        self.uuid = uuid
        super.init(frame: .zero)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
