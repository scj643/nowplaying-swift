//
//  Discord.swift
//  nowplaying
//
//  Created by Charles Surett on 1/24/23.
//

import Foundation
import SwordRPC
import Combine

@available(macOS 11.0, *)
class Discord {
    private var observer: NSObjectProtocol?
    var rpc = SwordRPC(appId: "1065440072826105896", handlerInterval: 500)
    var nowPlaying = NowPlayingInfo( info: ["Empty": true] )
    
    
    init(rpc: SwordRPC = SwordRPC(appId: "1065440072826105896", handlerInterval: 500)) {
        self.rpc = rpc
    }
    
    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    func connect() {
        self.rpc.onConnect { rpc in
            rpc.setPresence(self.getPresence())
        }
        rpc.connect()
    }
    
    func getPresence() -> RichPresence {
        (remote.MRMediaRemoteGetNowPlayingInfo)(DispatchQueue.main) { information in
            self.nowPlaying = NowPlayingInfo(info: information)
        }
        return self.npToPressence(song: self.nowPlaying)
    }
    func listen() {
        self.observer = NotificationCenter.default.addObserver(forName: NowPlayingNotificationsChanges.info, object: nil, queue: nil, using: { notification in
            (remote.MRMediaRemoteGetNowPlayingInfo)(DispatchQueue.main) { information in
                let newNowPlaying = NowPlayingInfo(info: information)
                if newNowPlaying.string() != self.nowPlaying.string() {
                    self.nowPlaying = newNowPlaying
                    self.rpc.setPresence(self.npToPressence(song: self.nowPlaying))
                }
            }
        })
        remote.MRMediaRemoteRegisterForNowPlayingNotifications(DispatchQueue.main)
    }
    
    func npToPressence(song: NowPlayingInfo) -> RichPresence {
        var presence = RichPresence()
        presence.instance = false
        presence.details = "\(song.title ?? "")"
        if (song.artist != nil) {
            presence.details = (presence.details ?? "") + " by \(song.artist ?? "")"
        }
        if (song.album != nil) {
            presence.state = "(\(song.album ?? ""))"
        }
        if (song.songID != nil) {
            if (song.songLinkStr() != nil) {
                let button = RPButton(label: "Song Link", url: (song.songLinkStr())!)
                presence.buttons = [button]
            }
        }
        return presence
    }
}
