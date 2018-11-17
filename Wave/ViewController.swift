//
//  ViewController.swift
//  Wave
//
//  Created by Andrew Finke on 11/16/18.
//  Copyright © 2018 Andrew Finke. All rights reserved.
//

import UIKit
import MultipeerConnectivity

class ViewController: UIViewController {

    // MARK: - Properties

    private let network = MultipeerNetwork()
    private var isHost = false

    private let sharedView = UIView(frame: .zero)
    private var waveViews = [UUID: UIView]()
    private var deviceFrames = [UUID: CGRect]()

    private var localDevice: WaveDevice!
    private var throwGestureRecognizer: UIPanGestureRecognizer!

    private let encoder = JSONEncoder()

    private var gotInitalOffset = false

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        isHost = UIDevice.current.name == "A.T"
        localDevice = WaveDevice(name: UIDevice.current.name,
                                 bounds: UIScreen.main.bounds,
                                 uuid: UUID())

        handleNewDevice(device: localDevice)

        sharedView.backgroundColor = UIColor.blue.withAlphaComponent(0.5)
        view.addSubview(sharedView)

        network.start(isHost: isHost, localDevice: localDevice) { object, peer in
            DispatchQueue.main.async {
                self.received(object, from: peer)
            }
        }

        sharedView.frame = CGRect(x: 0,
                                  y: 0,
                                  width: 4000,
                                  height: 4000)

        throwGestureRecognizer = UIPanGestureRecognizer(target: self,
                                                        action: #selector(panGestureRecognizerFired(_:)))

        let tapGestureRecognizer = UITapGestureRecognizer(target: self,
                                                          action: #selector(tapGestureRecognizerFired))
        sharedView.addGestureRecognizer(tapGestureRecognizer)
    }

    // MARK: - Gesture Recognizers

    @objc
    func tapGestureRecognizerFired(_ gestureRecognizer: UITapGestureRecognizer) {
        let center = gestureRecognizer.location(in: sharedView)
        let hue = CGFloat(arc4random() % 192) / 256 + 0.25
        let saturation = CGFloat(arc4random() % 128) / 256 + 0.5
        let brightness = CGFloat(arc4random() % 128) / 256 + 0.5

        let uuid = UUID()
        let update = WaveViewStateUpdate(state: .create,
                                         center: center,
                                         duration: nil,
                                         uuid: uuid,
                                         h: hue,
                                         s: saturation,
                                         b: brightness)

        do {
            let data = try encoder.encode(update)
            let object = WaveNetworkObject(key: .viewStateUpdate, data: data)

            network.send(object: object)
            received(update)
        } catch {
            print(error.localizedDescription)
        }
    }

    @objc
    func panGestureRecognizerFired(_ gestureRecognizer: UIPanGestureRecognizer) {
        guard let throwView = gestureRecognizer.view as? WaveView else { fatalError() }
        do {
            switch gestureRecognizer.state {
            case .possible, .began, .cancelled, .failed:
                break
            case .changed:
                let offset = gestureRecognizer.translation(in: sharedView)
                gestureRecognizer.setTranslation(.zero, in: sharedView)
                let update = WaveViewStateUpdate(state: .update,
                                                 center: CGPoint(x: throwView.center.x + offset.x, y: throwView.center.y + offset.y),
                                                 duration: nil,
                                                 uuid: throwView.uuid,
                                                 h: 0,
                                                 s: 0,
                                                 b: 0)
                let data = try encoder.encode(update)
                let object = WaveNetworkObject(key: .viewStateUpdate, data: data)
                network.send(object: object)
                received(update)
            case .ended:
                let newCenter = gestureRecognizer.location(in: sharedView)
                let decelerationRate: CGFloat = UIScrollView.DecelerationRate.normal.rawValue
                let xDistance = (gestureRecognizer.velocity(in: sharedView).x / 1000.0)
                    * decelerationRate / (1.0 - decelerationRate) / 2
                let yDistance = (gestureRecognizer.velocity(in: sharedView).y / 1000.0)
                    * decelerationRate / (1.0 - decelerationRate) / 2

                let update = WaveViewStateUpdate(state: .thrown,
                                                 center: CGPoint(x: newCenter.x + xDistance,
                                                                 y: newCenter.y + yDistance),
                                                 duration: 1,
                                                 uuid: throwView.uuid,
                                                 h: 0,
                                                 s: 0,
                                                 b: 0)
                let data = try encoder.encode(update)
                let object = WaveNetworkObject(key: .viewStateUpdate, data: data)
                network.send(object: object)
                received(update)
            }
        } catch {
            print(error.localizedDescription)
        }

    }

    // MARK: - Wave View

    func createWaveView(uuid: UUID, center: CGPoint, color: UIColor) {
        let waveView = WaveView(uuid: uuid)
        waveViews[uuid] = waveView
        waveView.frame.size = CGSize(width: 200, height: 200)
        waveView.center = center
        waveView.backgroundColor = color
        waveView.layer.cornerRadius = 15
        waveView.layer.borderColor = UIColor.white.cgColor
        waveView.layer.borderWidth = 5
        waveView.addGestureRecognizer(throwGestureRecognizer)
        sharedView.addSubview(waveView)
    }

    func received(_ update: WaveViewStateUpdate) {
        switch update.state {
        case .create:
            let color = UIColor(hue: update.h,
                                saturation: update.s,
                                brightness: update.b,
                                alpha: 1.0)
            
            createWaveView(uuid: update.uuid,
                           center: update.center,
                           color: color)
        case .thrown:
            guard let duration = update.duration,
                let waveView = waveViews[update.uuid] else {
                    fatalError()
            }
            UIView.animate(withDuration: TimeInterval(duration),
                           delay: 0,
                           options: .curveEaseOut,
                           animations: {
                            waveView.center = update.center
            }, completion: nil)
        case .update:
            guard let waveView = waveViews[update.uuid] else { fatalError() }
            waveView.center = update.center
        }
    }

    // MARK: - Wave Network

    func received(_ object: WaveNetworkObject, from sender: MCPeerID) {
        guard Thread.isMainThread else { fatalError() }
        do {
            switch object.key {
            case .viewStateUpdate:
                let update = try JSONDecoder().decode(WaveViewStateUpdate.self, from: object.data)
                received(update)
            case .device:
                let device = network.decodeDevice(data: object.data,
                                                  peerID: sender)
                handleNewDevice(device: device)
            case .sharedViewOrigin:
                guard !gotInitalOffset else { return }
                let point = try JSONDecoder().decode(CGPoint.self, from: object.data)
                sharedView.frame.origin = point
                gotInitalOffset = true
            }
        } catch {
            print(error)
        }
    }

    // MARK: - Other

    func handleNewDevice(device: WaveDevice) {
        guard isHost, deviceFrames[device.uuid] == nil else { return }

        let maxX = deviceFrames.values.sorted(by: { (lhs, rhs) -> Bool in
            return lhs.maxX > rhs.maxX
        }).first?.maxX ?? 0

        let newFrame = CGRect(x: maxX + 20,
                              y: 0,
                              width: device.bounds.width,
                              height: device.bounds.height)
        deviceFrames[device.uuid] = newFrame

        do {
            let offset = CGPoint(x: -newFrame.origin.x,
                                 y: -newFrame.origin.y)

            let offsetData = try encoder.encode(offset)

            let object = WaveNetworkObject(key: .sharedViewOrigin,
                                           data: offsetData)

            network.send(object: object)
        } catch {
            fatalError(error.localizedDescription)
        }
    }

}


