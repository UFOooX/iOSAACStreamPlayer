//
//  AACParser.swift
//  SampleBufferPlayer
//
//  Created by mbp on 2019/12/15.
//  Copyright © 2019 Apple. All rights reserved.
//

import Foundation
import CoreMedia

public class ADTSFormatHelper {
    public class func parseHeader(adtsData:Data, dataOffset:Int) -> ADTSHeader? {
        let data = adtsData.subdata(in: dataOffset..<dataOffset+7)
        guard data[0] == 0xff else { return nil }
        guard (data[1] & 0xf0) == 0xf0 else { return nil }
        let ID = (data[1] & 0x8) >> 3
        let layer = (data[1] & 0x6) >> 1
        let protection_absent = (data[1] & 0x1)
        var profile = (data[2] & 0xc0) >> 6
        var sampling_frequency_index = (data[2] & 0x3c) >> 2
        //let private_bit = (data[2] & 0x20) >> 1
        var channel_configuration = ((data[2] & 1) << 2) | ((data[3]&0xc0) >> 6)
        //let original_copy = ((data[3] & 0x20)>>5)
        //let home = ((data[3] & 0x10)>>4)
        //let copyright_identification_bit = ((data[3] & 0x8) >> 3)
        //let copyright_identification_start = ((data[3] & 0x4) >> 2)
        let aac_frame_length:UInt16 = (UInt16(data[3] & 0x3) << 11) | (UInt16(data[4]) << 3)|(UInt16(data[5] & 0xe0) >> 5)
        let adts_buffer_fullness:UInt16 = (UInt16(data[5] & 0x1f) << 6) | (UInt16(data[6] & 0xfc) >> 2)
        //let number_of_raw_data_blocks_in_frame = data[6] & 0x3
        /// - Tag: AACHEExtension
        var formatID:AudioFormatID = kAudioFormatMPEG4AAC
        var samplesPerFrame:Int = 1024
        if profile == 1 {
            if sampling_frequency_index == 7 {  //  HE-AAC has 22050 sample rate setting
                sampling_frequency_index = 4    //  but the real sample rate is 44100, as AAC-LC
                samplesPerFrame = 2048          //  and for HE-AAC, they have 2048 samplesPerFrame, as well as framesPerPacket in ASBD.
                if channel_configuration == 1 { //  Also, channel == 1 means HE-AAC v2.
                    channel_configuration = 2   //  Which real channel is 2.
                    profile = UInt8(ADTSHeader.PROFILE.EXTENSION_HE_V2.rawValue)
                    formatID = kAudioFormatMPEG4AAC_HE_V2
                } else {
                    profile = UInt8(ADTSHeader.PROFILE.EXTENSION_HE_V1.rawValue)
                    formatID = kAudioFormatMPEG4AAC_HE
                }
            } else {
                formatID = kAudioFormatMPEG4AAC
            }
        } else if profile == 0 {
            formatID = kAudioFormatMPEG4AAC_HE_V2
        }

        
        return ADTSHeader(mpegID: ADTSHeader.MPEG_ID(rawValue: Int(ID))!, layer: Int(layer), profile: ADTSHeader.PROFILE(rawValue: Int(profile))!, protectionAbsent: (protection_absent == 1), sampleRate: ADTSHeader.SAMPLE_RATE_TABLE[Int(sampling_frequency_index)], channels: Int(channel_configuration), frameLength: Int(aac_frame_length), variableSampleRate: (adts_buffer_fullness == 0x7ff), dataOffset: dataOffset, samplesPerFrame: samplesPerFrame, formatID: formatID)
    }
    
    /// - Tag: AACAudioFormatDescriptionCreating
    public class func createAudioFormatDescription(adtsHeader:ADTSHeader) -> CMAudioFormatDescription? {
        var audioFormatDescription:CMAudioFormatDescription?

        var audioStreamBasicDescription = createAudioStreamBaseDescription(adtsHeader: adtsHeader)
        let status = CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault, asbd: &audioStreamBasicDescription, layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &audioFormatDescription)
        
        guard status == noErr else {
            return nil
        }
        return audioFormatDescription
    }
    
    public class func createAudioStreamBaseDescription(adtsHeader:ADTSHeader) -> AudioStreamBasicDescription {
        /*
         For compressed streams like AAC, set mBytesPerPacket, mBytesPerFrame, mBitsPerChannel to 0.
         The packet layout will set when create samplebuffer with packets.
         */
        return AudioStreamBasicDescription(mSampleRate: Float64(adtsHeader.sampleRate), mFormatID: adtsHeader.formatID, mFormatFlags: 0, mBytesPerPacket: 0, mFramesPerPacket: UInt32(adtsHeader.samplesPerFrame), mBytesPerFrame: 0, mChannelsPerFrame: UInt32(adtsHeader.channels), mBitsPerChannel: 0, mReserved: 0)
    }
    
    public class func createAudioStreamPacketDescription(adtsHeader:ADTSHeader) -> AudioStreamPacketDescription {
        return AudioStreamPacketDescription(mStartOffset: Int64(adtsHeader.dataOffset), mVariableFramesInPacket: 0, mDataByteSize: UInt32(adtsHeader.frameLength))
    }
 
}

