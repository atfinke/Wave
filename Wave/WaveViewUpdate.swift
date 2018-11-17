//
//  WaveViewUpdate.swift
//  Wave
//
//  Created by Andrew Finke on 11/17/18.
//  Copyright © 2018 Andrew Finke. All rights reserved.
//

import UIKit

enum WaveViewState: String, Codable {
    case create, thrown, update
}

struct WaveViewStateUpdate: Codable {
    let state: WaveViewState
    let center: CGPoint
    let duration: CGFloat?

    let uuid: UUID
    let h: CGFloat
    let s: CGFloat
    let b: CGFloat
}
