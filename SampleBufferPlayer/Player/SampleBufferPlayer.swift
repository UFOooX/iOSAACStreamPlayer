/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Class `SampleBufferPlayer` is the thread-safe public interface to the player.
*/

import AVFoundation

class SampleBufferPlayer {
    
    // Struct `Playlist` contains the items in the current playlist,
    // and the index of the current item (if any).

    // All members of this type must be accessed under the protection of
    // the atomicity semaphore.

    // The player is regarded as stopped whenever there is no current index.
    // The current index is always valid (and within the range of the items array)
    // when the state is paused or playing.
    private struct Playlist {
        
        // Items in the playlist.
        var items: [SampleBufferItem] = []
        
        // The current item index, or nil if the player is stopped.
        var currentIndex: Int?
        
    }

    // Notifications for playback events.
    static let currentOffsetDidChange = Notification.Name("SampleBufferPlayerCurrentOffsetDidChange")
    
    static let currentOffsetKey = "SampleBufferPlayerCurrentOffsetKey"
    
    static let currentItemDidChange = Notification.Name("SampleBufferPlayerCurrentItemDidChange")
    static let playbackRateDidChange = Notification.Name("SampleBufferPlayerPlaybackRateDidChange")
    
    // Private observers.
    private var currentOffsetObserver: NSObjectProtocol!
    private var currentItemObserver: NSObjectProtocol!
    private var playbackRateObserver: NSObjectProtocol!
    
    // Objects used for thread safety.
    private let atomicitySemaphore = DispatchSemaphore(value: 1)
    
    // Private properties whose accesses must be atomic, protected by the atomicity semaphore.
    private var playlist = Playlist()
    
    // The serialized playback logic that executes on the serialization queue.
    private var playbackSerializer: SampleBufferSerializer!
    
    /// Initializes a sample buffer player.
    init() {
        
        // Create a "serializer" object to manage playback.
        playbackSerializer = SampleBufferSerializer()

        // Create observers for the notifications sent by the serializer.
        let notificationCenter = NotificationCenter.default
        
        currentOffsetObserver = notificationCenter.addObserver(forName: SampleBufferSerializer.currentOffsetDidChange,
                                                               object: playbackSerializer,
                                                               queue: .main) { [unowned self] notification in
            
            guard let offsetValue = notification.userInfo? [SampleBufferSerializer.currentOffsetKey] else { return }
            
            let userInfo = [SampleBufferPlayer.currentOffsetKey: offsetValue]
            notificationCenter.post(name: SampleBufferPlayer.currentOffsetDidChange, object: self, userInfo: userInfo)
        }
        
        currentItemObserver = notificationCenter.addObserver(forName: SampleBufferSerializer.currentItemDidChange,
                                                             object: playbackSerializer,
                                                             queue: .main) { [unowned self] _ in
            let uniqueID = self.playbackSerializer.currentItem?.uniqueID
            self.setCurrentItemIndex(uniqueID)
            notificationCenter.post(name: SampleBufferPlayer.currentItemDidChange, object: self)
        }
        
        playbackRateObserver = notificationCenter.addObserver(forName: SampleBufferSerializer.playbackRateDidChange,
                                                              object: playbackSerializer,
                                                              queue: .main) { [unowned self] _ in
            notificationCenter.post(name: SampleBufferPlayer.playbackRateDidChange, object: self)
        }
    }
    
    /// The number of items in the current playlist.
    var itemCount: Int {
        atomicitySemaphore.wait()
        defer { atomicitySemaphore.signal() }
        return playlist.items.count
    }
    
    /// The items in the current playlist.
    var items: [PlaylistItem] {
        atomicitySemaphore.wait()
        defer { atomicitySemaphore.signal() }
        return playlist.items.map { $0.playlistItem }
    }
    
    /// Return the specified item in the playlist.
    func item(at index: Int) -> PlaylistItem {
        atomicitySemaphore.wait()
        defer { atomicitySemaphore.signal() }
        return playlist.items [index].playlistItem
    }
    
    /// 'true' if the playlist contains an item at the specified index.
    func containsItem(at index: Int) -> Bool {
        atomicitySemaphore.wait()
        defer { atomicitySemaphore.signal() }
        return (0 ..< playlist.items.count).contains(index)
    }
    
    /// Replaces all of the items in the playlist.
    func replaceItems(with newItems: [PlaylistItem]) {
        
        playbackSerializer.printLog(component: .player, message: "replacing all items")
        atomicitySemaphore.wait()
        defer { atomicitySemaphore.signal() }
        
        // Replace the playlist items.
        playlist.items = newItems.map { playbackSerializer.sampleBufferItem(playlistItem: $0, fromOffset: .zero) }
        
        // If the player was paused or playing, try to restart playback from the first item.
        let index = playlist.currentIndex != nil ? 0 : nil
        
        restartWithItems(fromIndex: index, atOffset: .zero)
    }
    
    /// Plays from the start of the specified item, and continue with the following items
    /// already in the playlist.
    func seekToItem(at index: Int) {
        
        playbackSerializer.printLog(component: .player, message: "seeking item at playlist#\(index)")
        atomicitySemaphore.wait()
        defer { atomicitySemaphore.signal() }
        
        // Start playback from the specified item.
        restartWithItems(fromIndex: index, atOffset: .zero)
    }
    
    /// Moves the current offset to the specified offset in the current item.
    func seekToOffset(_ offset: CMTime) {
        
        playbackSerializer.printLog(component: .player, message: "seeking offset +\(offset.seconds)")
        atomicitySemaphore.wait()
        defer { atomicitySemaphore.signal() }
        
        // Start playback at the specified offset.
        restartWithItems(fromIndex: playlist.currentIndex, atOffset: offset)
    }
    
    /// Replaces a single item in the playlist, without stopping the current item, if possible.
    func replaceItem(at index: Int, with newItem: PlaylistItem) {
        
        playbackSerializer.printLog(component: .player, message: "replacing item at playlist#\(index)")
        atomicitySemaphore.wait()
        defer { atomicitySemaphore.signal() }
        
        playlist.items [index] = playbackSerializer.sampleBufferItem(playlistItem: newItem, fromOffset: .zero)
        
        // If the current item is not being replaced, let it continue playing.
        if let currentIndex = playlist.currentIndex, currentIndex != index {
            continueWithCurrentItems()
        }
        
        // Otherwise, stop the current item before restarting with the replacement item.
        else {
            restartWithItems(fromIndex: index, atOffset: .zero)
        }
    }
    
    /// Removes a single item from the playlist without stopping the current item, if possible.
    @discardableResult
    func removeItem(at index: Int) -> PlaylistItem {
        
        playbackSerializer.printLog(component: .player, message: "removing item at playlist#\(index)")
        atomicitySemaphore.wait()
        defer { atomicitySemaphore.signal() }

        let oldItem = playlist.items.remove(at: index).playlistItem
        
        // Stop playing if there are no items left, or the current item was removed.
        guard !playlist.items.isEmpty else { stopCurrentItems(); return oldItem }
        guard let currentIndex = playlist.currentIndex, currentIndex != index else { stopCurrentItems(); return oldItem }
        
        // Adjust the current item to account for the removal.
        if index < currentIndex {
            playlist.currentIndex = currentIndex - 1
        }
        
        // Let the current item continue playing.
        continueWithCurrentItems()

        return oldItem
    }
    
    /// Inserts a single item into the playlist.
    func insertItem(_ newItem: PlaylistItem, at index: Int) {
        
        playbackSerializer.printLog(component: .player, message: "inserting item at playlist#\(index)")
        atomicitySemaphore.wait()
        defer { atomicitySemaphore.signal() }

        playlist.items.insert(playbackSerializer.sampleBufferItem(playlistItem: newItem, fromOffset: .zero), at: index)
        
        // Adjust the current index, if necessary.
        if let currentIndex = playlist.currentIndex, index <= currentIndex {
            playlist.currentIndex = currentIndex + 1
        }

        // Let the current item continue playing.
        continueWithCurrentItems()
    }
    
    /// Moves a single item within the playlist.
    /// Note that both source and destination indexes refer to the playlist before the move.
    func moveItem(at sourceIndex: Int, to destinationIndex: Int) {
        
        playbackSerializer.printLog(component: .player, message: "moving item at playlist#\(sourceIndex) to playlist#\(destinationIndex)")
        atomicitySemaphore.wait()
        defer { atomicitySemaphore.signal() }
        
        guard sourceIndex != destinationIndex else { return }
        
        // Move the item.
        let sourceItem = playlist.items.remove(at: sourceIndex)
        playlist.items.insert(sourceItem, at: destinationIndex)
        
        // Adjust the current index, if necessary.
        guard let currentIndex = playlist.currentIndex else { stopCurrentItems(); return }
            
        if sourceIndex < currentIndex, currentIndex <= destinationIndex {
            playlist.currentIndex = currentIndex - 1
        } else if destinationIndex <= currentIndex, currentIndex < sourceIndex {
            playlist.currentIndex = currentIndex + 1
        } else if currentIndex == sourceIndex {
            playlist.currentIndex = destinationIndex
        }
        
        // Let the current item continue playing.
        continueWithCurrentItems()
    }
    
    // A helper method that stops the playback of the current item.
    private func stopCurrentItems() {
        playlist.currentIndex = nil
        playbackSerializer.stopQueue()
    }
    
    // A helper method that restarts playback from a given time offset of the specified item.
    private func restartWithItems(fromIndex proposedIndex: Int?, atOffset offset: CMTime) {
        
        // Stop the player if there is no current item.
        guard let currentIndex = proposedIndex,
            (0 ..< playlist.items.count).contains(currentIndex) else { stopCurrentItems(); return }
        
        // Start playing the requested items.
        playlist.currentIndex = currentIndex
        let playbackItems = Array(playlist.items [currentIndex ..< playlist.items.count])
        
        playbackSerializer.restartQueue(with: playbackItems, atOffset: offset)
    }

    // A helper method that continues playback of the current item, if possible, and the following items.
    private func continueWithCurrentItems() {

        // Stop the player if there's actually nothing to play.
        guard let currentIndex = playlist.currentIndex else { stopCurrentItems(); return }

        // Continue playing with a list of items to play starting from the current item.
        let playbackItems = Array(playlist.items [currentIndex ..< playlist.items.count])
        
        playbackSerializer.continueQueue(with: playbackItems)
    }

    /// The index of the current item, if any.
    /// Note that the a non-nil index indicates that the player is playing or paused.
    var currentItemIndex: Int? {
        atomicitySemaphore.wait()
        defer { atomicitySemaphore.signal() }
        return playlist.currentIndex
    }
    
    /// The current item, if any.
    /// Note that the a non-nil item indicates that the player is playing or paused.
    var currentItem: PlaylistItem? {
        
        atomicitySemaphore.wait()
        defer { atomicitySemaphore.signal() }
        
        guard let index = playlist.currentIndex else { return nil }
        
        return playlist.items [index].playlistItem
    }
    
    /// The current offset of the current item, if any.
    var currentItemEndOffset: CMTime? {
        
        atomicitySemaphore.wait()
        defer { atomicitySemaphore.signal() }
        
        guard let index = playlist.currentIndex else { return nil }
        
        return playlist.items [index].endOffset
    }
    
    // A helper method that sets the current item index.
    // Note that this is used privately (via a closure) by the sample buffer serializer.
    private func setCurrentItemIndex(_ uniqueID: UUID?) {
        
        atomicitySemaphore.wait()
        defer { atomicitySemaphore.signal() }
        
        // Set the current item index to the item with the specified ID.
        if let index = playlist.items.firstIndex (where: { $0.uniqueID == uniqueID }) {
            playlist.currentIndex = index
            playbackSerializer.printLog(component: .player, message: "setting current item at playlist#\(index) of \(playlist.items.count)")
        }
        
        // Or set the current item index to nil if there is no current item.
        else {
            playlist.currentIndex = nil
            playbackSerializer.printLog(component: .player, message: "setting no current item")
        }
        
        // Generate a notification, but do it on the main queue to avoid deadlocking on the semaphore.
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: SampleBufferPlayer.currentItemDidChange, object: self)
        }
    }
    
    /// Pauses playback, if the player is playing.
    func pause() {
        
        playbackSerializer.printLog(component: .player, message: "pause requested")
        atomicitySemaphore.wait()
        defer { atomicitySemaphore.signal() }
        
        if playlist.currentIndex != nil, playbackSerializer.playbackRate != 0 {
            playbackSerializer.pauseQueue()
        }
    }
    
    /// Starts or resumes playback, if the player is stopped or paused.
    func play() {
        
        playbackSerializer.printLog(component: .player, message: "play requested")
        atomicitySemaphore.wait()
        defer { atomicitySemaphore.signal() }
        
        // If there is no current item, try to set a current item
        // before starting playback.
        if playlist.currentIndex == nil {
            
            restartWithItems(fromIndex: 0, atOffset: .zero)
            
            if playlist.currentIndex != nil {
                playbackSerializer.resumeQueue()
            }
        }
        
        // Otherwise just make sure playback is actually paused.
        else if playbackSerializer.playbackRate == 0 {
            playbackSerializer.resumeQueue()
        }
    }
    
    /// 'true' if the player is currently playing.
    var isPlaying: Bool {
        
        atomicitySemaphore.wait()
        defer { atomicitySemaphore.signal() }
        
        return playlist.currentIndex != nil && playbackSerializer.playbackRate != 0
    }
    
    /// Gets the current playback rate.
    // Note that this method doesn't need synchronization using the serialization queue.
    var rate: Float {
        return playbackSerializer.playbackRate
    }
}
