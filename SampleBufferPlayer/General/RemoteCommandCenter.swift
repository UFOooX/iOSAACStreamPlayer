/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Class `RemoteCommandCenter` interacts with MPRemoteCommandCenter.
*/

import MediaPlayer

/// Types of remote commands.
enum RemoteCommand {
    case pause, play, nextTrack, previousTrack
    case skipForward(TimeInterval)
    case skipBackward(TimeInterval)
    case changePlaybackPosition(TimeInterval)
}

/// Behavior of an object that handles remote commands.
protocol RemoteCommandHandler: AnyObject {
    func performRemoteCommand(_: RemoteCommand)
}

class RemoteCommandCenter {
    
    /// Registers callbacks for various remote commands.
    static func handleRemoteCommands(using handler: RemoteCommandHandler) {
        
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.pauseCommand.addTarget { [weak handler] _ in
            guard let handler = handler else { return .noActionableNowPlayingItem }
            handler.performRemoteCommand(.pause)
            return .success
        }
        
        commandCenter.playCommand.addTarget { [weak handler] _ in
            guard let handler = handler else { return .noActionableNowPlayingItem }
            handler.performRemoteCommand(.play)
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { [weak handler] _ in
            guard let handler = handler else { return .noActionableNowPlayingItem }
            handler.performRemoteCommand(.nextTrack)
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [weak handler] _ in
            guard let handler = handler else { return .noActionableNowPlayingItem }
            handler.performRemoteCommand(.previousTrack)
            return .success
        }
        
        commandCenter.skipForwardCommand.preferredIntervals = [15.0]
        commandCenter.skipForwardCommand.addTarget { [weak handler] event in
            guard let handler = handler,
                let event = event as? MPSkipIntervalCommandEvent
                else { return .noActionableNowPlayingItem }
            
            handler.performRemoteCommand(.skipForward(event.interval))
            return .success
        }
        
        commandCenter.skipBackwardCommand.preferredIntervals = [15.0]
        commandCenter.skipBackwardCommand.addTarget { [weak handler] event in
            guard let handler = handler,
                let event = event as? MPSkipIntervalCommandEvent
                else { return .noActionableNowPlayingItem }
            
            handler.performRemoteCommand(.skipBackward(event.interval))
            return .success
        }
        
        commandCenter.changePlaybackPositionCommand.addTarget { [weak handler] event in
            guard let handler = handler,
                let event = event as? MPChangePlaybackPositionCommandEvent
                else { return .noActionableNowPlayingItem }
            
            handler.performRemoteCommand(.changePlaybackPosition(event.positionTime))
            return .success
        }
    }
}
