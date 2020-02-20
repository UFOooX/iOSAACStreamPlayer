//
//  AACHeader.swift
//  SampleBufferPlayer
//
//  Created by mbp on 2019/12/15.
//  Copyright © 2019 Apple. All rights reserved.
//

import Foundation
import CoreMedia

public struct ADTSHeader {
    public static let SAMPLE_RATE_TABLE:[Int] = [96000,88200,64000,48000,44100,32000,24000,22050,16000,12000,11025,8000,7350,0,0,-1]
    public enum MPEG_ID: Int {
        case MPEG_4 = 0
        case MPEG_2 = 1
    }
    public enum PROFILE: Int {
        case MAIN = 0
        case LOW_COMPLEXITY = 1
        case SCALABLE_SAMPLING_RATE = 2
        case ELSE = 3
        case EXTENSION_HE_V1 = 4
        case EXTENSION_HE_V2 = 5
    }
    
    public var mpegID: MPEG_ID = .MPEG_4
    public var layer:Int = 0
    public var profile:PROFILE = .LOW_COMPLEXITY
    public var protectionAbsent:Bool = true
    public var sampleRate:Int = 44100
    public var channels:Int = 2
    public var frameLength:Int = 0
    public var variableSampleRate:Bool = false
    public var dataOffset:Int = 0
    public var samplesPerFrame:Int = 1024
    public var formatID:AudioFormatID = kAudioFormatMPEG4AAC

    func toInt64() -> UInt64 {
        var adts : UInt64 = 0

        let a = UInt64(0x00FFF00000000000)
        let b = UInt64(mpegID.rawValue) << 43
        let d = UInt64(protectionAbsent ? 1 : 0) << 40
        let e = UInt64(profile.rawValue - 1) << 38
        let f = UInt64(ADTSHeader.SAMPLE_RATE_TABLE.firstIndex(of: sampleRate)!) << 34
        let h = UInt64(channels) << 30
        let m = UInt64(frameLength + (protectionAbsent ? 7 : 9)) << 13

        adts |= a
        adts |= b
        adts |= d
        adts |= e
        adts |= f
        adts |= h
        adts |= m

        return CFSwapInt64(adts) >> 8
    }

    func toData() -> Data {
        var integer = toInt64()
        return Data(bytes:&integer, count: protectionAbsent ? 7 : 9)
    }
}

