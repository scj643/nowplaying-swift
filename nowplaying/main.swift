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
    
    @Flag(help: "Get the album link")
    var album = false
    
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
    
    @Flag(help: "Show version")
    var version = false
    
    @Flag(help: "Listen for nowplaying changes")
    var listen = false
}

let options = NowPlayingOptions.parseOrExit()


let remote = MediaRemoteBridge()

if options.version {
    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
        print(version)
        exit(EXIT_SUCCESS)
    } else {
        print("Unknown version")
        exit(EXIT_FAILURE)
    }
}

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
        let song = SongInfo(info: information)
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
    let songID = SongIDs(info: information)
    var link: String
    if options.album {
        if songID.albumID != nil {
            link = songID.albumLinkStr()!
        } else {exit(EXIT_FAILURE)}
    } else {
        if songID.songID != nil {
            link = songID.songLinkStr()!
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
dispatchMain()
