//
//  AACSampleBufferSource.swift
//  SampleBufferPlayer
//
//  Created by mbp on 2019/12/14.
//  Copyright © 2019 Apple. All rights reserved.
//

import Foundation
import CoreMedia

class ADTSSampleBufferSource {
    var adtsData:Data?
    private let firstSampleOffset: CMTime
    var infoHeader = ADTSHeader()
    var framePosition:Int = 0
    init?(fileURL: URL, fromOffset offset: CMTime) {
        firstSampleOffset = offset
        self.nextSampleOffset = CMTimeMake(value: 0, timescale: Int32(self.infoHeader.sampleRate))
        guard loadData(url:fileURL) else {
            return nil
        }
        
        guard parseFrames() else {
            return nil
        }
        self.nextSampleOffset = offset.convertScale(Int32(self.infoHeader.sampleRate), method: .default)
        framePosition = Int(nextSampleOffset.value / Int64(infoHeader.samplesPerFrame))
        
        if framePosition >= audioFrames.count {
            framePosition = 0
        }
    }
    
    func loadData(url:URL) -> Bool {
        if let data = try? Data.init(contentsOf: url) {
            self.adtsData = data
            return true
        }
        return false
    }
    
    
    var audioFrames = [ADTSHeader]()
    var audioFormatDesc:CMAudioFormatDescription?
    /// - Tag: AACParseADTSFrames
    func parseFrames() -> Bool {
        if let data = self.adtsData {
            var dataOffset:Int = 0
            while dataOffset < data.count {
                if let adtsHeader = ADTSFormatHelper.parseHeader(adtsData: data, dataOffset: dataOffset) {
                    dataOffset += adtsHeader.frameLength
                    if dataOffset > data.count {
                        break
                    }
                    if adtsHeader.dataOffset == 0 {
                        self.audioFormatDesc = ADTSFormatHelper.createAudioFormatDescription(adtsHeader: adtsHeader)
                        if self.audioFormatDesc == nil {
                            return false
                        }
                        self.infoHeader = adtsHeader
                    }
                    audioFrames.append(adtsHeader)
                } else {
                    return false
                }
            }
            return true
        }
        return false
    }
    
    private(set) var nextSampleOffset: CMTime
    func nextSampleBuffer() throws -> CMSampleBuffer {
        if audioFrames.count == 0 {
            throw NSError(domain: "ADTS Source", code: -1, userInfo: nil)
        }
        if framePosition >= audioFrames.count {
            throw NSError(domain: "ADTS Source", code: -2, userInfo: nil)
        }
        
        let frameCount = min(16384/infoHeader.samplesPerFrame, audioFrames.count - framePosition)
        let sampleBuffer = buildSampleBuffer(framePos: framePosition, frameCount: frameCount, presentationTimeStamp: self.nextSampleOffset)!

        framePosition += frameCount
        let pts = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer)
        let duration = CMSampleBufferGetOutputDuration(sampleBuffer)
        nextSampleOffset = pts + duration
        print("NEXT SAMPLE OFFSET:", stime(nextSampleOffset), stime(pts), stime(duration))
        return sampleBuffer
    }
    
    /// - Tag: AACBuildSampleBuffer
    public func buildSampleBuffer(framePos:Int, frameCount:Int, presentationTimeStamp:CMTime) -> CMSampleBuffer? {
        var aspdArray:[AudioStreamPacketDescription] = [AudioStreamPacketDescription]()
        aspdArray.reserveCapacity(frameCount)
        /*
         header length
         */
        let adtsHeaderLength = self.infoHeader.protectionAbsent ? 7 : 9
        
        var offset = adtsHeaderLength
        for headerIndex in framePos..<framePos+frameCount {
            let frameLength = self.audioFrames[headerIndex].frameLength
            aspdArray.append(AudioStreamPacketDescription(mStartOffset: Int64(offset), mVariableFramesInPacket: 0, mDataByteSize: UInt32(frameLength-adtsHeaderLength)))
            offset += frameLength
        }

        let dataOffset = self.audioFrames[framePos].dataOffset
        let dataSize = self.audioFrames[framePos+frameCount-1].dataOffset + self.audioFrames[framePos+frameCount-1].frameLength - dataOffset

        var blockBuffer:CMBlockBuffer?
        var osstatus = CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault, memoryBlock: nil, blockLength: dataSize, blockAllocator: nil, customBlockSource: nil, offsetToData: 0, dataLength: dataSize, flags: 0, blockBufferOut: &blockBuffer)
        
        guard osstatus == kCMBlockBufferNoErr else {
            print(NSError(domain: NSOSStatusErrorDomain, code: Int(osstatus)))
            return nil
        }

        var sampleBuffer:CMSampleBuffer?
        
        osstatus = self.adtsData!.subdata(in: dataOffset..<dataOffset+dataSize).withUnsafeBytes( { (vp:UnsafeRawBufferPointer) -> OSStatus in
            return CMBlockBufferReplaceDataBytes(with: vp.baseAddress!, blockBuffer: blockBuffer!, offsetIntoDestination: 0, dataLength: dataSize)
        })
        
        guard osstatus == kCMBlockBufferNoErr else {
            print(NSError(domain: NSOSStatusErrorDomain, code: Int(osstatus)))
            return nil
        }

        osstatus = CMAudioSampleBufferCreateReadyWithPacketDescriptions(allocator: kCFAllocatorDefault, dataBuffer: blockBuffer!, formatDescription: self.audioFormatDesc!, sampleCount: frameCount, presentationTimeStamp: presentationTimeStamp, packetDescriptions: aspdArray, sampleBufferOut: &sampleBuffer)
        
        guard osstatus == kCMBlockBufferNoErr else {
            print(NSError(domain: NSOSStatusErrorDomain, code: Int(osstatus)))
            return nil
        }
        
        return sampleBuffer
    }
    
    public func stime(_ time:CMTime?) -> String {
        if time == nil {
            return "(null)"
        } else {
            return String(format: "%.4f", time!.seconds)
        }
    }
}


