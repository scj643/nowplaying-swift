//
//  main.swift
//  nowplaying
//
//  Created by Charles Surett on 11/22/22.
//

import Foundation
import AppKit
import ArgumentParser


struct NowPlayingOptions: ParsableCommand {
    @Flag(help: "Get artwork")
    var artwork = false
    
    @Flag(help: "Output link to stdout\n(disables clipboard)")
    var stdout = false
    
    @Flag(help: "Output keys of now playing item")
    var keys = false
}

let options = NowPlayingOptions.parseOrExit()


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
    if options.keys
    {
        if information.keys.isEmpty == false {
            for key in information.keys {
                print(key)
            }
            exit(EXIT_SUCCESS)
        }
        else {
            exit(EXIT_FAILURE)
        }
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
    } else {
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
}
dispatchMain()
