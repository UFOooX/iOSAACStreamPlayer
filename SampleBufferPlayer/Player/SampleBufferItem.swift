/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Class `SampleBufferItem` represents one item in a list of items being played.
*/

import AVFoundation

class SampleBufferItem {
    
    // An identifier that uniquely identifies an item within a SampleBufferPlayer item list.
    // Note that this make it possible to distinguish between two `PlaylistItem` items in
    // the list, that are otherwise identical.
    let uniqueID: UUID
    
    // A shortened identifier used for logging.
    let logID: String
    
    // The underlying media item that this sample buffer playlist item represents.
    let playlistItem: PlaylistItem
    
    // The offset time, relative to the underlying media item, at which this item starts playing.
    var startOffset: CMTime {
        didSet {
            endOffset = startOffset
        }
    }
    
    // The offset time, relative to the underlying media item, at which the next sample
    // from this item should be presented.
    // Note that the actual duration of samples provided so far by this item is
    // `endOffset - startOffset`.
    private(set) var endOffset: CMTime
    
    // 'true' if this item has been (or is being) used to get sample buffers.
    private(set) var isEnqueued = false
    
    // A boundary time observer for this item.
    var boundaryTimeObserver: Any?
    
    
    private var aacSource: ADTSSampleBufferSource?
    // A source of sample buffers for this item.
    private var sampleBufferSource: SampleBufferSource?
    
    // An error reported by the sample buffer source.
    private(set) var sampleBufferError: Error?
    
    // Private properties that support logging.
    private var sampleBufferLogCount = 0
    
    private var printLog: (SampleBufferSerializer.LogComponentType, String, CMTime?) -> Void
    
    private var testItem:Bool = false
    // Initializes a playlist item.
    init(playlistItem: PlaylistItem,
         fromOffset offset: CMTime,
         printLog: @escaping (SampleBufferSerializer.LogComponentType, String, CMTime?) -> Void) {
        
        self.uniqueID = UUID()
        self.logID = String(uniqueID.uuidString.suffix(4))
        self.playlistItem = playlistItem
        self.printLog = printLog
        
        self.startOffset = offset > .zero && offset < playlistItem.duration ? offset : .zero
        self.endOffset = startOffset
        //if playlistItem.url.ex
        if playlistItem.ext == "aac" {
            self.testItem = true
        }
    }
    
    // Gets the next sample buffer for this item, or nil if no more are available.
    func nextSampleBuffer() -> CMSampleBuffer? {
        
        // No more sample buffers after an error.
        guard sampleBufferError == nil else { return nil }
        
        do {
            // Try to create a sample buffer source, if this is the first
            // time a sample buffer has been requested.
            if aacSource == nil && sampleBufferSource == nil {
                isEnqueued = true
                if self.testItem {
                    aacSource = ADTSSampleBufferSource(fileURL: playlistItem.url, fromOffset: startOffset)
                } else {
                    sampleBufferSource = try SampleBufferSource(fileURL: playlistItem.url, fromOffset: startOffset)
                }
                printLog(.enqueuer, "ID: \(logID) starting buffers at +", startOffset)
            }
            
            
            
            if sampleBufferLogCount > 0 {
                printLog(.enqueuer, "ID: \(logID) enqueuing buffer #\(sampleBufferLogCount) at +", endOffset)
            }
            
            sampleBufferLogCount += 1
            
            if let source = sampleBufferSource {
                // Try to read from a sample buffer source.
                //let source = sampleBufferSource!
                let sampleBuffer = try source.nextSampleBuffer()
                
                // Keep track of the actual duration of this source.
                endOffset = source.nextSampleOffset
                
                return sampleBuffer
            } else if let source = aacSource {
                
                let sampleBuffer = try source.nextSampleBuffer()
                
                
                // Keep track of the actual duration of this source.
                endOffset = source.nextSampleOffset
                return sampleBuffer
            }
            
            return nil
        }
            
        // End-of-file is caught as a thrown error, along with actual errors
        // encountered when reading the source file.
        catch {
            printLog(.enqueuer, "ID: \(logID) stopped after \(sampleBufferLogCount) buffers (\(error)) +", endOffset)
            sampleBufferError = error
            return nil
        }
    }
    
    // Stops getting samples from the current source, if any.
    func flushSource() {
        isEnqueued = false
        sampleBufferSource = nil
        aacSource = nil
        sampleBufferError = nil
        boundaryTimeObserver = nil
    }
    
    // Prevents the item from being used to get more buffers.
    func invalidateSource() {
        sampleBufferSource = nil
        aacSource = nil
        sampleBufferError = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError)
    }
}
