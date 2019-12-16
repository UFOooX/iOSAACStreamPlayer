/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The `AppDelegate` application delegate object manages the application lifecycle.
*/

import UIKit
import AVFoundation

@UIApplicationMain
class AppDelegate: NSObject, UIApplicationDelegate {
    
    var window: UIWindow?
    var audioSessionObserver: Any!
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Observe AVAudioSession notifications.
        
        // Note that a real app might need to observe other AVAudioSession notifications, too,
        // especially if it needs to properlay handle playback interruptions when the app is
        // in the background.
        let notificationCenter = NotificationCenter.default
        
        audioSessionObserver = notificationCenter.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification,
                                                              object: nil,
                                                              queue: nil) { [unowned self] _ in
            print("AUDIO RESET")
            self.setUpAudioSession()
        }
        
        // Configure the audio session initially.
        setUpAudioSession()
        
        return true
    }
    
    // A helper method that configures the app's audio session.
    // Note that the `.longForm` policy indicates that the app's audio output should use AirPlay 2
    // for playback.
    /// - Tag: LongForm
    private func setUpAudioSession() {
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, policy: .longFormAudio)
        } catch {
            print("Failed to set audio session route sharing policy: \(error)")
        }
        let requestedCodecs = [
            AudioClassDescription(mType: kAudioEncoderComponentType, mSubType: kAudioFormatMPEG4AAC, mManufacturer: kAppleHardwareAudioCodecManufacturer),
            AudioClassDescription(mType: kAudioDecoderComponentType, mSubType: kAudioFormatMPEG4AAC, mManufacturer: kAppleHardwareAudioCodecManufacturer)
        ]
        
        let req = UnsafeMutablePointer<AudioClassDescription>.allocate(capacity: 2)
        req[0].mType = kAudioEncoderComponentType
        req[0].mSubType = kAudioFormatMPEG4AAC
        req[0].mManufacturer = kAppleSoftwareAudioCodecManufacturer
        req[1].mType = kAudioDecoderComponentType
        req[1].mSubType = kAudioFormatMPEG4AAC
        req[1].mManufacturer = kAppleSoftwareAudioCodecManufacturer
        
        print(MemoryLayout.size(ofValue: req))
        
        var successfulCodecs:UInt32 = 0
        var len:UInt32 = UInt32(MemoryLayout.size(ofValue: successfulCodecs))
        let result = AudioFormatGetProperty(kAudioFormatProperty_HardwareCodecCapabilities, 24, requestedCodecs, &len, &successfulCodecs)
        if result == noErr {
            print("SUCODE:", successfulCodecs)
        } else if result == kAudioFormatUnsupportedPropertyError {
            print("NOT SUPPORTED PROPERTY")
        }
/*
        switch successfulCodecs {
            case 0:
            
                // aac hardware encoder is unavailable. aac hardware decoder availability
                // is unknown; could ask again for only aac hardware decoding
            
            case 1:
                // aac hardware encoder is available but, while using it, no hardware
                // decoder is available.
            case 2:
                // hardware encoder and decoder are available simultaneously
        }*/

    }
}
