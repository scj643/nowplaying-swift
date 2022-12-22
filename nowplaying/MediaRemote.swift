//
//  MediaRemote.swift
//  nowplaying
//
//  Created by Charles Surett on 12/21/22.
//

import Foundation

let BUNDLE_LOCATION = "/System/Library/PrivateFrameworks/MediaRemote.framework"

// MediaRemote types
typealias MRMediaRemoteRegisterForNowPlayingNotificationsFunction = @convention(c) (DispatchQueue) -> Void
typealias MRMediaRemoteGetNowPlayingInfoFunction = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
typealias MRMediaRemoteGetNowPlayingApplicationIsPlayingFunction = @convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void


struct NowPlayingNotificationsChanges {
    static let info = Notification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification")
    static let queue = Notification.Name("kMRNowPlayingPlaybackQueueChangedNotification")
    static let isPlaying = Notification.Name("kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification")
    static let application = Notification.Name("kMRMediaRemoteNowPlayingApplicationDidChangeNotification")
    static let all = [info, queue, isPlaying, application]
}

class SongInfo {
    var title: String
    var album: String
    var artist: String
    
    init(info: [String : Any]) {
        title = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? "Unknown"
        album = info["kMRMediaRemoteNowPlayingInfoAlbum"] as? String ?? "Unknown"
        artist = info["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? "Unknown"
    }
    
    func string() -> String {
        return "\(title) by \(artist) (\(album))"
    }
}


class SongIDs {
    var songID: Int?
    var albumID: Int?
    
    init(info: [String : Any]) {
        songID = info["kMRMediaRemoteNowPlayingInfoiTunesStoreIdentifier"] as? Int
        albumID = info["kMRMediaRemoteNowPlayingInfoAlbumiTunesStoreAdamIdentifier"] as? Int
    }
    
    func songLinkStr() -> String? {
        if songID != nil {
            return String(format: "https://song.link/i/%d", songID!)
        } else {
            return nil
        }
    }
    
    func albumLinkStr() -> String? {
        if songID != nil {
            return String(format: "https://album.link/i/%d", albumID!)
        } else {
            return nil
        }
    }
    
    func songLink() -> URL? {
        if songID != nil {
            return URL(string: songLinkStr()!)
        } else {
            return nil
        }
    }
    
    func albumLink() -> URL? {
        if albumID != nil {
            return URL(string: albumLinkStr()!)
        } else {
            return nil
        }
    }
}


class MediaRemote {
    var bundle: CFBundle
    private var MRMediaRemoteGetNowPlayingInfoPointer: UnsafeMutableRawPointer
    var MRMediaRemoteGetNowPlayingInfo: MRMediaRemoteGetNowPlayingInfoFunction
    init() {
        bundle = CFBundleCreate(kCFAllocatorDefault, NSURL(fileURLWithPath: BUNDLE_LOCATION))
        // TODO: Better handling of failures
        guard let MRMediaRemoteGetNowPlayingInfoPointer = CFBundleGetFunctionPointerForName(self.bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString) else { fatalError("Failed to get function pointer: MRMediaRemoteGetNowPlayingInfo") }
        self.MRMediaRemoteGetNowPlayingInfoPointer = MRMediaRemoteGetNowPlayingInfoPointer
        self.MRMediaRemoteGetNowPlayingInfo = unsafeBitCast(MRMediaRemoteGetNowPlayingInfoPointer, to: MRMediaRemoteGetNowPlayingInfoFunction.self)
    }

}

@available(macOS 10.15, *)
class NowPlayingService:ObservableObject {
    var MRMediaRemoteGetNowPlayingInfo: MRMediaRemoteGetNowPlayingInfoFunction
    
    private var observers: [NSObjectProtocol?]
    
    @Published var nowPlaying: SongInfo?
    @Published var nowPlayingIDs: SongIDs?
    
    init() {
        nowPlaying = nil
        // TODO: Split this out to it's own function
        let bundle = CFBundleCreate(kCFAllocatorDefault, NSURL(fileURLWithPath: BUNDLE_LOCATION))
        guard let MRMediaRemoteRegisterForNowPlayingNotificationsPointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteRegisterForNowPlayingNotifications" as CFString) else {
            fatalError("Failed to get function pointer: MRMediaRemoteGetNowPlayingInfo")
        }
        let MRMediaRemoteRegisterForNowPlayingNotifications = unsafeBitCast(MRMediaRemoteRegisterForNowPlayingNotificationsPointer, to: MRMediaRemoteRegisterForNowPlayingNotificationsFunction.self)
        
        MRMediaRemoteRegisterForNowPlayingNotifications(DispatchQueue.main)
        
        guard let MRMediaRemoteGetNowPlayingInfoPointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString) else {
            fatalError("Failed to get function pointer: MRMediaRemoteGetNowPlayingInfo")
        }
        MRMediaRemoteGetNowPlayingInfo = unsafeBitCast(MRMediaRemoteGetNowPlayingInfoPointer, to: MRMediaRemoteGetNowPlayingInfoFunction.self)
        
        observers = []
        for o in NowPlayingNotificationsChanges.all {
            observers.append(
                NotificationCenter.default.addObserver(forName: o, object: nil, queue: .main, using: { notification in
                    self.handleNowPlayingChanged(notification: notification)
                })
            )
        }
        updateSong()
    }
    deinit {
        for observer in observers {
            if let observer = observer {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
    
    func updateSong() {
        (MRMediaRemoteGetNowPlayingInfo)(DispatchQueue.main) { information in
            self.nowPlaying = SongInfo(info: information)
            self.nowPlayingIDs = SongIDs(info: information)
        }
    }
    func handleNowPlayingChanged(notification: Notification) {
        switch notification.name {
        case NowPlayingNotificationsChanges.info:
            updateSong()
            NSLog("nowPlayingInfoDidChangeNotification")
        case NowPlayingNotificationsChanges.queue:
            NSLog("nowPlayingPlaybackQueueChangedNotification")
        case NowPlayingNotificationsChanges.isPlaying:
            NSLog("nowPlayingApplicationIsPlayingDidChange")
        case NowPlayingNotificationsChanges.application:
            NSLog("nowPlayingApplicationChanged")
        default:
            NSLog("Other")
        }
    }
}

