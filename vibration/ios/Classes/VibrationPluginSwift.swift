import AudioToolbox
import CoreHaptics
import Flutter
import UIKit

public class VibrationPluginSwift: NSObject, FlutterPlugin {
    #if targetEnvironment(simulator)
        private let isDevice = false
    #else
        private let isDevice = true
    #endif
    
    // TODO: mine
    var isPlaying: Bool = false

    @available(iOS 13.0, *)
    public static var engine: CHHapticEngine?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "vibration", binaryMessenger: registrar.messenger())
        let instance = VibrationPluginSwift()
        
        if #available(iOS 13.0, *) {
            VibrationPluginSwift.createEngine()
        }
        
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    @available(iOS 13.0, *)
    public static func createEngine() {
        // Create and configure a haptic engine.
        do {
            VibrationPluginSwift.engine = try CHHapticEngine()
        } catch {
            print("Engine creation error: \(error)")
            return
        }
        
        if VibrationPluginSwift.engine == nil {
            print("Failed to create engine!")
        }
        
        // The stopped handler alerts you of engine stoppage due to external causes.
        VibrationPluginSwift.engine?.stoppedHandler = { reason in
            print("The engine stopped for reason: \(reason.rawValue)")
        }
        
        // The reset handler provides an opportunity for your app to restart the engine in case of failure.
        VibrationPluginSwift.engine?.resetHandler = {
            // Try restarting the engine.
            print("The engine reset --> Restarting now!")
            
            do {
                try VibrationPluginSwift.engine?.start()
            } catch {
                print("Failed to restart the engine: \(error)")
            }
        }
    }
    
    private func supportsHaptics() -> Bool {
        if #available(iOS 13.0, *) {
            return CHHapticEngine.capabilitiesForHardware().supportsHaptics
        }
        
        return false;
    }


    @available(iOS 13.0, *)
    private func playHapticPattern(hapticEvents: [CHHapticEvent], engine: CHHapticEngine) -> Void{
           do{
                let pattern = try  CHHapticPattern(events: hapticEvents, parameters: [])
                let player = try engine.makeAdvancedPlayer(with: pattern)
                    
                    player.completionHandler = { error in
                        if let error = error {
                            print("Error playing haptic pattern: \(error.localizedDescription)")
                        } else {
                            print("Haptic pattern finished playing.")
                            if self.isPlaying{
                                self.playHapticPattern(hapticEvents: hapticEvents, engine: engine)
                            }
                        }
                    }

                    try player.start(atTime: 0)
                } catch {
                    print("Faield to play")
                }
    }
    
    @available(iOS 13.0, *)
    private func playPattern(myArgs: [String: Any], pattern: [Int]) -> Void {
        // Get event parameters, if any
        var params: [CHHapticEventParameter] = []
        let amplitudes = myArgs["intensities"] as! [Int] 
     
        let hapticTapsPattern = myArgs["hapticTapsPattern"] as! [Int]
        print("Got haptic taps patterh: \(hapticTapsPattern.count)")
        
        let hapticTapsIntensities = myArgs["hapticTapsIntensities"] as! [Int]
        print("hapticTapsIntensities: \(hapticTapsIntensities.count)")

        // Create haptic events
        var hapticEvents: [CHHapticEvent] = []
        var i: Int = 0
        var rel: Double = 0.0

        while i < pattern.count {
            // Get intensity parameter, if any
            if (i < amplitudes.count) {
                if(amplitudes[i] != 0) {
                    let p = CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(Double(amplitudes[i]) / 255.0))
                    // Get wait time and duration
                        let duration = Double(pattern[i]) / 1000.0
                    // Create haptic event
                    let e = CHHapticEvent(
                        eventType: .hapticContinuous,
                        parameters: [p],
                        relativeTime: rel,
                        duration: duration
                    )
                    hapticEvents.append(e)

                    // Add duration to relative time
                    rel += duration
                }
                else {
                    let waitTime = Double(pattern[i]) / 1000.0
                    rel += waitTime
                }
            }
            i += 1    
        }
        print("before start")
        var totalRelTime: Double = 0.0
        var j: Int = 0
        while j < hapticTapsPattern.count{
            if(j < hapticTapsIntensities.count){
                totalRelTime += Double(hapticTapsPattern[j]) / 1000.0
                
                 let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(Double(hapticTapsIntensities[j]) / 255.0))
                 let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(Double(hapticTapsIntensities[j]) / 255.0))
                let transientEvent = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: totalRelTime)
                print("Adding haptic with rel time: \(totalRelTime)")
                hapticEvents.append(transientEvent)
            }
            j += 1
        }
        

        do {
            if let engine = VibrationPluginSwift.engine {
                try engine.start()
                playHapticPattern(hapticEvents: hapticEvents, engine: engine)
            }
        } catch {
            print("Failed to play pattern: \(error.localizedDescription).")
        }
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "hasCustomVibrationsSupport":
            result(supportsHaptics())
        case "vibrate":
            guard let args = call.arguments else {
                result(false)
                return
            }
            
            guard let myArgs = args as? [String: Any] else {
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                result(true)
                return
            }
            
            guard let pattern = myArgs["pattern"] as? [Int] else {
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                result(true)
                return
            }
            
            if pattern.count == 0 {
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                result(true)
                return
            }
            
            assert(pattern.count % 2 == 0, "Pattern must have even number of elements!")
            
            if !supportsHaptics() {
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                result(true)
                return
            }
            
            if #available(iOS 13.0, *) {
                isPlaying = true;
                playPattern(myArgs: myArgs, pattern: pattern)
            }
            
            result(isDevice)
        case "cancel":
            if #available(iOS 13.0, *) {
                print("Lets cancel bro!")
                VibrationPluginSwift.engine?.stop()
                isPlaying = false;
            }
            
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
