//
//  main.swift
//  nowplaying
//
//  Created by Charles Surett on 11/22/22.
//

import Foundation
import AppKit
import ArgumentParser


struct SongInfo {
    var title: String
    var album: String
    var artist: String
}

struct NowPlayingOptions: ParsableCommand {
    @Flag(help: "Get artwork")
    var artwork = false
    
    @Flag(help: "Output link to stdout\n(disables clipboard)")
    var stdout = false
    
    @Flag(help: "Print data of now playing")
    var data = false
    
    @Flag(help: "Output as a /me is now playing text")
    var me = false
    
    @Flag(help: "Output as a text string")
    var str = false
    
    @Flag(help: "Output as a markdown italics")
    var ital = false
}

let options = NowPlayingOptions.parseOrExit()


func getNowPlayingSongInfo(info: [String : Any]) -> SongInfo? {
    let song = SongInfo(title: info["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? "Unknown", album: info["kMRMediaRemoteNowPlayingInfoAlbum"] as? String ?? "Unknown", artist: info["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? "Unknown")
    return song
}

typealias MRMediaRemoteRegisterForNowPlayingNotificationsFunction = @convention(c) (DispatchQueue) -> Void
typealias MRMediaRemoteGetNowPlayingInfoFunction = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
typealias MRMediaRemoteGetNowPlayingApplicationIsPlayingFunction = @convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void

var MRMediaRemoteGetNowPlayingInfo: MRMediaRemoteGetNowPlayingInfoFunction

// Load Bundle
let bundle = CFBundleCreate(kCFAllocatorDefault, NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework"))
guard let MRMediaRemoteGetNowPlayingInfoPointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString) else {
    fatalError("Failed to get function pointer: MRMediaRemoteGetNowPlayingInfo")
}
MRMediaRemoteGetNowPlayingInfo = unsafeBitCast(MRMediaRemoteGetNowPlayingInfoPointer, to: MRMediaRemoteGetNowPlayingInfoFunction.self)

(MRMediaRemoteGetNowPlayingInfo)(DispatchQueue.main) { information in
    if options.data
    {
        
        if information.keys.isEmpty == false {
            for key in information.keys {
                print(key)
                if !key.contains("ArtworkData")
                {
                    print(information[key] ?? "None")
                }
            }
            exit(EXIT_SUCCESS)
        }
        else {
            exit(EXIT_FAILURE)
        }
    }
    if options.str || options.me || options.ital
    {
        let song = getNowPlayingSongInfo(info: information)
        var songString = "\(song?.title ?? "Unknown") by \(song?.artist ?? "Unknown") (\(song?.album ?? "Unknown"))"
        if options.me {
            songString = "/me is playing \(songString)"
        }
        if options.ital {
            songString = "_is playing \(songString)_"
        }
        if options.stdout {
            print(songString)
        } else {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(songString,
                                           forType: NSPasteboard.PasteboardType.string)
        }
        exit(EXIT_SUCCESS)
    }
    if options.artwork
    {
        guard let artwork = information["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data
        else {
            exit(EXIT_FAILURE)
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setData(artwork, forType: NSPasteboard.PasteboardType.png)
        exit(EXIT_SUCCESS)
    }
    // Defualt to copying now playing to the clipboard
    guard let id = information["kMRMediaRemoteNowPlayingInfoiTunesStoreIdentifier"] as? Int
    else {
        exit(EXIT_FAILURE)
    }
    let songLink = String(format: "https://song.link/i/%d", id)
    if options.stdout {
        print(songLink)
    } else {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(songLink,
                                       forType: NSPasteboard.PasteboardType.string)
    }
    exit(EXIT_SUCCESS)
}
dispatchMain()
