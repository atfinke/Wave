//
//  WKRMultipeerNetwork.swift
//  WKRKit
//
//  Created by Andrew Finke on 8/5/17.
//  Copyright © 2017 Andrew Finke. All rights reserved.
//

import Foundation
import MultipeerConnectivity

internal class MultipeerNetwork: NSObject, MCSessionDelegate, MCNearbyServiceBrowserDelegate, MCNearbyServiceAdvertiserDelegate {

    // MARK: - Closures

    private var objectReceived: ((WaveNetworkObject, MCPeerID) -> Void)?

    // MARK: - Properties

    private var isHost = false
    private var localDevice: WaveDevice?

    let peerID: MCPeerID
    private let session: MCSession
    private let serviceType = "Wave"

    private var browser: MCNearbyServiceBrowser?
    private var advertiser: MCNearbyServiceAdvertiser?

    private var peers = [UUID: MCPeerID]()

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - Initialization

    override init() {
        peerID = MCPeerID(displayName: UIDevice.current.name)
        session = MCSession(peer: peerID)
        super.init()
        session.delegate = self
    }

    // MARK: - Helpers

    func start(isHost: Bool,
               localDevice: WaveDevice,
               objectReceived: @escaping ((WaveNetworkObject, MCPeerID) -> Void)) {
        self.isHost = isHost
        self.localDevice = localDevice
        self.objectReceived = objectReceived
        if isHost {
            startBrowsing()
        } else {
            startAdvertising()
        }
    }


    func send(object: WaveNetworkObject) {
        guard let data = try? encoder.encode(object) else { return }
        do {
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            print(error)
        }
    }

    func decodeDevice(data: Data, peerID: MCPeerID) -> WaveDevice {
        do {
            let device = try decoder.decode(WaveDevice.self, from: data)
            peers[device.uuid] = peerID
            return device
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    // MARK: - MCNearbyServiceBrowserDelegate

    private func startBrowsing() {
        browser?.stopBrowsingForPeers()
        browser = nil

        browser = MCNearbyServiceBrowser(peer: peerID,
                                         serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
    }

    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        browser.invitePeer(peerID,
                           to: session,
                           withContext: nil,
                           timeout: 0)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}

    // MARK: - MCAdvertiserAssistantDelegate

    private func startAdvertising() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil

        advertiser = MCNearbyServiceAdvertiser(peer: peerID,
                                               discoveryInfo: nil,
                                               serviceType: serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
        advertiser.stopAdvertisingPeer()
    }

    // MARK: - MCSessionDelegate

    open func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        do {
            let object = try decoder.decode(WaveNetworkObject.self, from: data)
            objectReceived?(object, peerID)
        } catch {
            print(data.description)
        }
    }

    open func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        guard let localDevice = localDevice else { fatalError() }
        if state == .connected {
            do {
                let deviceData = try encoder.encode(localDevice)
                let object = WaveNetworkObject(key: .device, data: deviceData)
                let data = try encoder.encode(object)
                try session.send(data, toPeers: [peerID], with: .reliable)
            } catch {
                print(error)
            }
        }
    }

    // Not needed

    open func session(_ session: MCSession,
                      didStartReceivingResourceWithName resourceName: String,
                      fromPeer peerID: MCPeerID,
                      with progress: Progress) {
    }

    open func session(_ session: MCSession,
                      didFinishReceivingResourceWithName resourceName: String,
                      fromPeer peerID: MCPeerID,
                      at localURL: URL?,
                      withError error: Error?) {
    }

    open func session(_ session: MCSession,
                      didReceive stream: InputStream,
                      withName streamName: String,
                      fromPeer peerID: MCPeerID) {
    }

}
