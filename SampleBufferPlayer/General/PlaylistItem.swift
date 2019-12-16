/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Struct `PlaylistItem` is a playable track as an item in a playlist.
*/

import AVFoundation

struct PlaylistItem {
    
    /// URL of the local file containing the track's audio.
    let url: URL!
    
    /// An error that prevents the track from playing.
    let error: Error?
    
    /// The title of the track.
    let title: String
    
    /// The artist heard on the track.
    let artist: String
    
    /// The ext name
    let ext:String
    
    /// The duration of the audio file.
    let duration: CMTime
    
    /// Initializes a valid item.
    init(url: URL, title: String, artist: String, ext:String, duration: CMTime) {
        self.url = url
        self.title = title
        self.artist = artist
        self.ext = ext
        self.duration = duration
        self.error = nil
    }
    
    /// Initializes an invalid item.n
    init(title: String, artist: String, ext:String, error: Error) {
        self.url = nil
        self.title = title
        self.artist = artist
        self.ext = ext
        self.duration = .zero
        self.error = error
    }
    
    /// Initializes a placeholder item.
    init(title: String, artist: String, ext:String) {
        self.url = nil
        self.title = title
        self.artist = artist
        self.ext = ext
        self.duration = .zero
        self.error = nil
    }
}
