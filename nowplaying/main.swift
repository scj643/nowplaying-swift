//
//  main.swift
//  nowplaying
//
//  Created by Charles Surett on 11/22/22.
//

import Foundation
import AppKit
import ArgumentParser


var ver = "Unknown"
if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
    #if DEBUG
    ver = "\(version)-DEBUG"
    #else
    ver = "\(version)-RELEASE"
    #endif
} else {
    ver = "Unknown"
}

struct NowPlayingOptions: ParsableCommand {
    static var configuration = CommandConfiguration(commandName: "nowplaying", version: ver)
    @Flag(help: "Get artwork")
    var artwork = false
    
    @Flag(help: "Get the album link")
    var album = false
    
    @Flag(name:.shortAndLong, help: "Output link to stdout\n(disables clipboard)")
    var stdout = false
    
    @Flag(name:.shortAndLong, help: "Print data of now playing")
    var data = false
    
    @Flag(help: "Output as a /me is now playing text")
    var me = false
    
    @Flag(help: "Output as a text string")
    var str = false
    
    @Flag(help: "Output as a markdown italics")
    var ital = false
    
    @Flag(help: "Listen for nowplaying changes")
    var listen = false
    
    @Flag(help: "Get bundle ID of nowplaying app")
    var bundle = false
    
    @Flag(help: "Get name of nowplaying app")
    var name = false
}

let options = NowPlayingOptions.parseOrExit()


let remote = MediaRemoteBridge()

if options.bundle {
    (remote.MRMediaRemoteGetNowPlayingClient)(DispatchQueue.main) { clientObject in
        let appBundleIdentifier = remote.MRNowPlayingClientGetBundleIdentifier(clientObject)
        print(appBundleIdentifier)
        exit(EXIT_SUCCESS)
    }
} else if options.name {
    (remote.MRMediaRemoteGetNowPlayingClient)(DispatchQueue.main) { clientObject in
        let appName = remote.MRNowPlayingClientGetDisplayName(clientObject)
        print(appName)
        exit(EXIT_SUCCESS)
    }
} else if options.listen {
    var nowPlaying = NowPlayingInfo( info: ["Empty": true] )
    (remote.MRMediaRemoteGetNowPlayingInfo)(DispatchQueue.main) { information in
        nowPlaying = NowPlayingInfo(info: information)
        print(nowPlaying.string())
    }
    NotificationCenter.default.addObserver(forName: NowPlayingNotificationsChanges.info, object: nil, queue: nil, using: { notification in
        (remote.MRMediaRemoteGetNowPlayingInfo)(DispatchQueue.main) { information in
            let newNowPlaying = NowPlayingInfo(info: information)
            if newNowPlaying.string() != nowPlaying.string() {
                print(newNowPlaying.string())
                nowPlaying = newNowPlaying
            }
        }
    })
    remote.MRMediaRemoteRegisterForNowPlayingNotifications(DispatchQueue.main)
    
} else {
    (remote.MRMediaRemoteGetNowPlayingInfo)(DispatchQueue.main) { information in
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
            let song = NowPlayingInfo(info: information)
            var songString = song.string()
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
        let song = NowPlayingInfo(info: information)
        var link: String
        if options.album {
            if song.albumID != nil {
                link = song.albumLinkStr()!
            } else {exit(EXIT_FAILURE)}
        } else {
            if song.songID != nil {
                link = song.songLinkStr()!
            } else {exit(EXIT_FAILURE)}
        }
        if options.stdout {
            print(link)
        } else {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(link,
                                           forType: NSPasteboard.PasteboardType.string)
        }
        exit(EXIT_SUCCESS)
    }
}
dispatchMain()
