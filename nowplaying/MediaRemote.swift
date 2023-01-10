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

class NowPlayingInfo {
    var info: [String : Any]
    init(info: [String : Any]) {
        self.info = info
    }
}

class SongInfo: NowPlayingInfo {
    var title: String? {
        return self.info["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? nil
    }
    var album: String? {
        return self.info["kMRMediaRemoteNowPlayingInfoAlbum"] as? String ?? nil
    }
    var artist: String? {
        return self.info["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? nil
    }
    
    func string() -> String {
        var returnString = ""
        if (self.title != nil) {
            returnString += "\(title!)"
        }
        if (self.artist != nil) {
            returnString += " by \(artist!)"
        }
        if (self.album != nil) {
            returnString += " (\(album!))"
        }
        return returnString
    }
}


class SongIDs: NowPlayingInfo {
    var songID: Int? {
            return info["kMRMediaRemoteNowPlayingInfoiTunesStoreIdentifier"] as? Int
    }
    var albumID: Int? {
            return info["kMRMediaRemoteNowPlayingInfoAlbumiTunesStoreAdamIdentifier"] as? Int
    }
    
    private func strToUrl(string: String?) -> URL? {
        if string != nil {
            return URL(string: string!)
        } else {
            return nil
        }
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
        return strToUrl(string: songLinkStr())
    }
    
    func albumLink() -> URL? {
        return strToUrl(string: albumLinkStr())
    }
}


// Helper struct for Media Remote functions
struct MediaRemoteBridge {
    var MRMediaRemoteGetNowPlayingInfo: MRMediaRemoteGetNowPlayingInfoFunction
    var MRMediaRemoteRegisterForNowPlayingNotifications: MRMediaRemoteRegisterForNowPlayingNotificationsFunction
    let bundle = CFBundleCreate(kCFAllocatorDefault, NSURL(fileURLWithPath: BUNDLE_LOCATION))
    
    init() {
        guard let MRMediaRemoteGetNowPlayingInfoPointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString) else {
            fatalError("Failed to get function pointer: MRMediaRemoteGetNowPlayingInfo")
        }
        self.MRMediaRemoteGetNowPlayingInfo = unsafeBitCast(MRMediaRemoteGetNowPlayingInfoPointer, to: MRMediaRemoteGetNowPlayingInfoFunction.self)
        
        guard let MRMediaRemoteRegisterForNowPlayingNotificationsPointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteRegisterForNowPlayingNotifications" as CFString) else {
        fatalError("Failed to get function pointer: MRMediaRemoteGetNowPlayingInfo")
        }
        self.MRMediaRemoteRegisterForNowPlayingNotifications = unsafeBitCast(MRMediaRemoteRegisterForNowPlayingNotificationsPointer, to: MRMediaRemoteRegisterForNowPlayingNotificationsFunction.self)
    }
}

class NowPlayingService {
    let mediaRemote = MediaRemoteBridge()
    private var observers: [NSObjectProtocol?]
    var nowPlaying: SongInfo?
    var nowPlayingIDs: SongIDs?
    
    init() {
        mediaRemote.MRMediaRemoteRegisterForNowPlayingNotifications(DispatchQueue.main)
        
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
        (mediaRemote.MRMediaRemoteGetNowPlayingInfo)(DispatchQueue.main) { information in
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

@available(macOS 10.15, *)
class ObservableNowPlayingService: ObservableObject {
    @Published var nowPlaying: SongInfo?
    @Published var nowPlayingIDs: SongIDs?
    private var mediaRemote = MediaRemoteBridge()
    private var observer: NSObjectProtocol?
    
    init() {
        self.mediaRemote.MRMediaRemoteRegisterForNowPlayingNotifications(DispatchQueue.main)
        self.observer = NotificationCenter.default.addObserver(forName: NowPlayingNotificationsChanges.info, object: nil, queue: .main, using: { notification in
            self.updateSongs()
        })
        updateSongs()
    }
    
    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    func updateSongs() {
        (self.mediaRemote.MRMediaRemoteGetNowPlayingInfo)(DispatchQueue.main) { information in
            self.nowPlaying = SongInfo(info: information)
            self.nowPlayingIDs = SongIDs(info: information)
            print(self.nowPlaying?.string() ?? "NA")
        }
    }
}
