/*
See LICENSE folder for this sample’s licensing information.

Abstract:
`PlaylistViewController` is a table view controller subclass that manages the items
 in the playlist. It is a child of the `ControlsViewController` that manages the
 playback controls.
*/

import UIKit
import AVFoundation

/// A table view controller that manages a playlist.
class PlaylistViewController: UITableViewController {
    
    // The original playlist items, used to restore the playlist
    // after it has been edited.
    private var originalItems: [PlaylistItem] = []
    
    // The player containing the playlist managed by this table view.
    private var sampleBufferPlayer: SampleBufferPlayer {
        
        guard let player = (parent as? ControlsViewController)?.sampleBufferPlayer
            else { fatalError("sampleBufferPlayer has not been set") }
        
        return player
    }
    
    // Loads the initial master playlist.
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.allowsSelectionDuringEditing = false
        
        // Create an initial playlist.
        createOriginalPlaylist()
    }
    
    // The list of audio files provided in the app bundle.
    private static let initialItems = [
        ("Melody", "AirPlay Too", "m4a"),
        ("Synth", "DJ AVF", "m4a"),
        ("Rhythm", "The Air Players", "m4a"),
        ("twotigers", "For AAC test music", "aac"),
    ]
    
    // A helper method that creates the initial playlist.
    private func createOriginalPlaylist() {
        
        // Create placeholder items.
        
        // Note that this simplifies the next step by creating the entire array.
        // Array entries are replaced by real items as asset loading completes,
        // which may happen in any item order.
        var newItems = PlaylistViewController.initialItems.map { PlaylistItem(title: $0.0, artist: $0.1, ext: $0.2) }
        
        // Start loading the durations of each of the items.
        
        // Note that loading is asynchronous, so a dispatch group is used to
        // detect when all item loading is complete.
        let group = DispatchGroup()
        
        for itemIndex in 0 ..< newItems.count {
            
            // Find the existing placeholder item to replace.
            let placeholder = newItems [itemIndex]
            let title = placeholder.title
            let artist = placeholder.artist
            let ext = placeholder.ext
            
            // Locate the asset file for this item, if possible,
            // otherwise replace the placeholder with an error item.
            guard let url = Bundle.main.url(forResource: title, withExtension: ext) else {
                
                let error = NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError)
                let item = PlaylistItem(title: title, artist: artist, ext: ext, error: error)
                
                newItems [itemIndex] = item
                
                continue
            }
            
            // Load the asset duration for this item asynchronously.
            group.enter()
            
            let asset = AVURLAsset(url: url)
            asset.loadValuesAsynchronously(forKeys: ["duration"]) {
                
                var error: NSError? = nil
                let item: PlaylistItem
                
                // If the duration was loaded, construct a "normal" item,
                // otherwise construct an error item.
                switch asset.statusOfValue(forKey: "duration", error: &error) {
                case .loaded:
                    item = PlaylistItem(url: url, title: title, artist: artist, ext: ext, duration: asset.duration)
                    
                case .failed where error != nil:
                    item = PlaylistItem(title: title, artist: artist, ext: ext, error: error!)
                    
                default:
                    let error = NSError(domain: NSCocoaErrorDomain, code: NSFileReadCorruptFileError)
                    item = PlaylistItem(title: title, artist: artist, ext: ext, error: error)
                }
                
                // Replace the placeholder with the constructed item.
                newItems [itemIndex] = item
                
                group.leave()
            }
        }
        
        // When all of the items are replaced, make the playlist available for use.
        group.notify(queue: .main) {
            self.originalItems = newItems
            self.replaceAllItems()
        }
    }
    
    // Returns the number of rows in the table view.
    // Note that the number of rows may requested before the player reference is available
    // to this view controller. In that case, the number of rows is necessarily 0.
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sampleBufferPlayer.itemCount
    }
    
    // Creates the cell for a row in the table view.
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        // Get a playlist cell.
        let cell = tableView.dequeueReusableCell(withIdentifier: "PlaylistCell", for: indexPath)
        let row = indexPath.row
        let item = sampleBufferPlayer.item(at: row)
        
        // Configure the cell with textual information.
        cell.textLabel?.text = item.title
        cell.detailTextLabel?.text = item.artist
        cell.backgroundColor = .clear
        
        // Mark items that failed to load with an error icon.
        if item.error != nil {
            cell.detailTextLabel?.text = NSLocalizedString("[Error]", comment: "")
        }
        
        // Mark the "current" item with a different background color.
        if sampleBufferPlayer.currentItemIndex == row {
            cell.backgroundColor = UIColor(named: "Current")
            cell.textLabel?.backgroundColor = .clear
            cell.detailTextLabel?.backgroundColor = .clear
        }
        
        return cell
    }
    
    // Handles the user's row selection.
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        // Check for a valid playlist item.
        guard sampleBufferPlayer.containsItem(at: indexPath.row) else { return }
        
        // Play from the specified item.
        sampleBufferPlayer.seekToItem(at: indexPath.row)
        sampleBufferPlayer.play()
    }
    
    // Prevents rows from showing as deletable when the table view
    // is in editing mode. Only rearrangement is allowed in that mode.
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .none
    }
    
    // Provide a row action for duplicating an item (swipe from left to right).
    override func tableView(_ tableView: UITableView,
                            leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        // Configure the action.
        let duplicateAction = UIContextualAction(style: .normal, title: NSLocalizedString("Duplicate", comment: "")) {
            [unowned self] _, _, completionHandler in
            
            self.duplicateItem(at: indexPath.row)
            completionHandler(true)
        }
        
        // Choose a suitable background color for the button.
        duplicateAction.backgroundColor = UIColor(named: "Duplicate")
        
        // Allow full swiping to perform the action.
        let configuration = UISwipeActionsConfiguration(actions: [duplicateAction])
        configuration.performsFirstActionWithFullSwipe = true
        
        return configuration
    }
    
    // Provides a row action for deletion (swipe from right to left).
    override func tableView(_ tableView: UITableView,
                            trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        // Configure the action.
        let deleteAction = UIContextualAction(style: .destructive,
                                              title: NSLocalizedString("Delete", comment: "")) { [unowned self] _, _, completionHandler in
            
            self.removeItem(at: indexPath.row)
            completionHandler(true)
        }
        
        // Allow full swiping to perform the action.
        let configuration = UISwipeActionsConfiguration(actions: [deleteAction])
        configuration.performsFirstActionWithFullSwipe = true
        
        return configuration
    }
    
    // Moves a row from the source index path to the destination index path.
    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        
        // Check if the source item is actually moving.
        let sourceRow = sourceIndexPath.row
        let destinationRow = destinationIndexPath.row
        
        guard sourceRow != destinationRow,
            sampleBufferPlayer.containsItem(at: sourceRow),
            sampleBufferPlayer.containsItem(at: destinationRow) else { return }
        
        // Move the item.
        moveItem(from: sourceRow, to: destinationRow)
    }
    
    // Start rearranging, stop rearranging, and restore the playlist.
    // Note that these are actually called via same-named action methods in ControlsViewController.
    @IBAction func rearrangePlaylist() {
        tableView.setEditing(true, animated: true)
    }
    
    @IBAction func doneWithPlaylist() {
        tableView.setEditing(false, animated: true)
    }
    
    @IBAction func restorePlaylist() {
        replaceAllItems()
    }
    
    // Updates the current item when it changes.
    // Note that this is called from the ControlsViewController.
    func updateCurrentItem() {
        tableView.reloadData()
    }
    
    // A helper method that replaces the table view contents.
    private func replaceAllItems() {
        
        sampleBufferPlayer.replaceItems(with: originalItems)
        
        tableView.reloadData()
    }
    
    // A helper method that replaces a single item in the table view.
    private func replaceItem(at row: Int, with newItem: PlaylistItem) {
        
        sampleBufferPlayer.replaceItem(at: row, with: newItem)
        
        tableView.reloadData()
    }
    
    // A helper method that removes an item from the table view.
    private func removeItem(at row: Int) {
        
        sampleBufferPlayer.removeItem(at: row)
        
        tableView.reloadData()
    }
    
    // A helper method that moves an item within the table view.
    private func moveItem(from sourceRow: Int, to destinationRow: Int) {
        
        sampleBufferPlayer.moveItem(at: sourceRow, to: destinationRow)
        
        tableView.reloadData()
    }
    
    // A helper method that duplicates the item in the table view, placing the
    // duplicated item at the end of the playlist.
    private func duplicateItem(at row: Int) {
        
        let item = sampleBufferPlayer.item(at: row)
        sampleBufferPlayer.insertItem(item, at: sampleBufferPlayer.itemCount)
        
        tableView.reloadData()
    }
}
