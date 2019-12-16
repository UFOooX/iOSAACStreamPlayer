/*
See LICENSE folder for this sample’s licensing information.

Abstract:
`ControlsViewController` controls the presentation of the playback UI controls,
 such as play/pause buttons, playback times, etc. It has a single child view controller
 of class `PlaylistViewController` which manages the playlist.
*/

import UIKit
import AVKit
import CoreMedia
import AVFoundation
import MediaPlayer

class ControlsViewController: UIViewController, RemoteCommandHandler {
    
    // Outlets to various UI controls.
    @IBOutlet private weak var rearrangeButton: UIButton!
    @IBOutlet private weak var restoreButton: UIButton!
    @IBOutlet private weak var doneButton: UIButton!
    @IBOutlet private weak var titleView: UILabel!
    @IBOutlet private weak var artistView: UILabel!
    @IBOutlet private weak var currentTimeLabel: UILabel!
    @IBOutlet private weak var durationLabel: UILabel!
    @IBOutlet private weak var timeSlider: UISlider!
    @IBOutlet private weak var playPauseButton: UIButton!
    @IBOutlet private weak var volumeViewContainer: UIView!
    @IBOutlet private weak var routePickerViewContainer: UIView!
    
    // The sample buffer player.
    let sampleBufferPlayer = SampleBufferPlayer()
    
    // The child view controller that maintains the playlist table view.
    private var playlistViewController: PlaylistViewController {
        
        guard let viewController = children.first as? PlaylistViewController
            else { fatalError("playlistViewController has not been set") }
        
        return viewController
    }
    
    // Private notification observers.
    private var currentOffsetObserver: NSObjectProtocol!
    private var currentItemObserver: NSObjectProtocol!
    private var playbackRateObserver: NSObjectProtocol!
    
    // Sets up the view and view controller.
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Observe various notifications.
        let notificationCenter = NotificationCenter.default
        
        currentOffsetObserver = notificationCenter.addObserver(forName: SampleBufferPlayer.currentOffsetDidChange,
                                                               object: sampleBufferPlayer,
                                                               queue: .main) { [unowned self] notification in
            
            let offset = (notification.userInfo? [SampleBufferPlayer.currentOffsetKey] as? NSValue)?.timeValue.seconds
            self.updateOffsetLabel(offset)
        }
        
        currentItemObserver = notificationCenter.addObserver(forName: SampleBufferPlayer.currentItemDidChange,
                                                             object: sampleBufferPlayer,
                                                             queue: .main) { [unowned self] _ in
            
            self.updateCurrentItemInfo()
        }
        
        playbackRateObserver = notificationCenter.addObserver(forName: SampleBufferPlayer.playbackRateDidChange,
                                                              object: sampleBufferPlayer,
                                                              queue: .main) { [unowned self] _ in
            
            self.updatePlayPauseButton()
            self.updateCurrentPlaybackInfo()
        }
        
        // Configure the view's controls.
        doneButton.alpha = 0
        
        updateOffsetLabel(0)
        updatePlayPauseButton()
        
        configureVolumeView()
        
        // Start using the Now Playing Info panel.
        RemoteCommandCenter.handleRemoteCommands(using: self)
        
        // Configure now-playing info initially.
        updateCurrentItemInfo()
    }
    
    // A helper method that updates the play/pause button state.
    private func updatePlayPauseButton() {
        
        let title = sampleBufferPlayer.isPlaying ? NSLocalizedString("Pause", comment: "") : NSLocalizedString("Play", comment: "")
        
        playPauseButton.setTitle(title, for: .normal)
    }
    
    private static let format = NSLocalizedString("%.1f", comment: "")

    // A helper method that updates the elapsed time within the current playlist item.
    private func updateOffsetLabel(_ offset: Double?) {
        
        // During scrubbing, the label represents the slider position instead.
        guard !isDraggingOffset else { return }
        
        // Otherwise update the label and the slider position when something is playing ...
        if let currentOffset = offset {
            currentTimeLabel.text = String(format: ControlsViewController.format, currentOffset)
            timeSlider.value = Float(currentOffset)
        }
        
        // ... or when the player is stopped.
        else {
            currentTimeLabel.text = ""
            timeSlider.value = 0
        }
    }
    
    // A helper method that updates the current playlist item's fixed information when the item changes.
    private func updateCurrentItemInfo() {
        
        // Update the Now Playing Info with the new item information.
        NowPlayingCenter.handleItemChange(item: sampleBufferPlayer.currentItem,
                                          index: sampleBufferPlayer.currentItemIndex ?? 0,
                                          count: sampleBufferPlayer.itemCount)

        // Update the item information when something is playing ...
        if let currentItem = sampleBufferPlayer.currentItem {
            
            let duration = currentItem.duration.seconds
            durationLabel.text = String(format: ControlsViewController.format, duration)
            
            timeSlider.isEnabled = true
            timeSlider.maximumValue = Float(duration)
            
            titleView.text = currentItem.title
            artistView.text = currentItem.artist
            
            // Also make sure the Now Playing Info gets updated with
            // playback information, initially.
            updateCurrentPlaybackInfo()
        }
        
        // ... or when the player is stopped.
        else {
            
            timeSlider.isEnabled = false
            timeSlider.value = 0.0
            currentTimeLabel.text = " "
            titleView.text = " "
            artistView.text = " "
            durationLabel.text = " "
        }
        
        // Tell the playlist items to update, too.
        playlistViewController.updateCurrentItem()
    }
    
    // A helper method that updates the Now Playing playback information.
    private func updateCurrentPlaybackInfo() {
        
        NowPlayingCenter.handlePlaybackChange(playing: sampleBufferPlayer.isPlaying,
                                              rate: sampleBufferPlayer.rate,
                                              position: sampleBufferPlayer.currentItemEndOffset?.seconds ?? 0,
                                              duration: sampleBufferPlayer.currentItem?.duration.seconds ?? 0)
    }
    
    // A helper method that adds and configures the system volume view.
    // Note that the volume view can provide a route selection button,
    // but its icon doesn't display well over a light background, so
    // that button is hidden, and and instance of AVRoutePickerView
    // displayed instead.
    private func configureVolumeView() {
        
        let volumeView = MPVolumeView(frame: volumeViewContainer.bounds)
        volumeView.showsRouteButton = false
        
        volumeViewContainer.addSubview(volumeView)
        volumeView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            volumeViewContainer.topAnchor.constraint(equalTo: volumeView.topAnchor),
            volumeViewContainer.bottomAnchor.constraint(equalTo: volumeView.bottomAnchor),
            volumeViewContainer.leadingAnchor.constraint(equalTo: volumeView.leadingAnchor),
            volumeViewContainer.trailingAnchor.constraint(equalTo: volumeView.trailingAnchor)
        ])
        
        let routePickerView = AVRoutePickerView(frame: routePickerViewContainer.bounds)
        routePickerViewContainer.addSubview(routePickerView)
    }
    
    // Performs the remote command.
    func performRemoteCommand(_ command: RemoteCommand) {
        
        switch command {
            
        case .pause:
            pause()
            
        case .play:
            play()
            
        case .nextTrack:
            nextTrack()
            
        case .previousTrack:
            previousTrack()
            
        case .skipForward(let distance):
            skip(by: distance)
            
        case .skipBackward(let distance):
            skip(by: -distance)

        case .changePlaybackPosition(let offset):
            skip(to: offset)
        }
    }
    
    // 'true' when the time offset slider is being dragged.
    private var isDraggingOffset: Bool = false
    
    // Action methods: start, continue, and stop dragging the time offset slider.
    @IBAction func offsetDraggingDidStart() {
        isDraggingOffset = true
    }
    
    @IBAction func offsetDraggingDidDrag() {
        currentTimeLabel.text = String(format: ControlsViewController.format, timeSlider.value)
    }
    
    @IBAction func offsetDraggingDidEnd() {
        skip(to: TimeInterval(timeSlider.value))
        isDraggingOffset = false
    }
    
    // Pauses playback.
    @IBAction func pause() {
        sampleBufferPlayer.pause()
    }
    
    // Begins or resumes playback.
    @IBAction func play() {
		sampleBufferPlayer.play()
    }
    
    @IBAction func togglePlayPause() {
        if sampleBufferPlayer.isPlaying {
			sampleBufferPlayer.pause()
        } else {
            sampleBufferPlayer.play()
        }
    }
    
    // Skips to the previous track.
    @IBAction func previousTrack() {
        skipToCurrentItem(offsetBy: -1)
    }
    
    // Skips to the next track.
    @IBAction func nextTrack() {
        skipToCurrentItem(offsetBy: 1)
    }
    
    // A helper method that skips to a different playlist item.
    private func skipToCurrentItem(offsetBy offset: Int) {
        
        guard let currentItemIndex = sampleBufferPlayer.currentItemIndex,
            sampleBufferPlayer.containsItem(at: currentItemIndex + offset)
            else { return }
        
        sampleBufferPlayer.seekToItem(at: currentItemIndex + offset)
    }
    
    // A helper method that skips to a playlist item offset, making sure to update the Now Playing Info.
    private func skip(to offset: TimeInterval) {
        
        sampleBufferPlayer.seekToOffset(CMTime(seconds: Double(offset), preferredTimescale: 10))
        updateCurrentPlaybackInfo()
    }
    
    // A helper method that skips a specified distance in the current item, making sure to update the Now Playing Info.
    private func skip(by distance: TimeInterval) {
        
        guard let offset = sampleBufferPlayer.currentItemEndOffset else { return }
        
        sampleBufferPlayer.seekToOffset(offset + CMTime(seconds: distance, preferredTimescale: 10))
        updateCurrentPlaybackInfo()
    }
    
    // Starts rearranging the playlist.
    @IBAction func rearrangePlaylist() {

        // Tell the playlist view controller to do it.
        playlistViewController.rearrangePlaylist()
        
        // Change the button configuration with a short animation.
        UIViewPropertyAnimator.runningPropertyAnimator(withDuration: 0.3, delay: 0, animations: {
            self.doneButton.alpha = 1
            self.rearrangeButton.alpha = 0
            self.restoreButton.alpha = 0
        })
    }
    
    // Stops rearranging the playlist.
    @IBAction func doneWithPlaylist() {
        // Tell the playlist view controller to do it.
        playlistViewController.doneWithPlaylist()
        
        // Change the button configuration with a short animation.
        UIViewPropertyAnimator.runningPropertyAnimator(withDuration: 0.3, delay: 0, animations: {
            self.doneButton.alpha = 0
            self.rearrangeButton.alpha = 1
            self.restoreButton.alpha = 1
        })
    }
    
    // Restores the original playlist.
    @IBAction func restorePlaylist() {
        // Tell the playlist view controller to do it.
        playlistViewController.restorePlaylist()
    }
}
