//
//  main.swift
//  audiodeviceplayer
//
//  Created by Jolon on 17/8/21.
//

import Foundation
import AVFoundation
import SimplyCoreAudio

main()

/**
 Reads an audio file specified as a command line argument and plays it directly through the default AudioDevice, potentially bypassing AudioUnits,
 Audio Converters, Mixers, and other high level players.
 Note that the buffers we write to are in the virtual format not the physical format. All devices appear to have support for the Float32 virtual format and default to it.
 This requires conversion from the original integer format to Float32 and back to an integer format and may not be bitperfect. Note also that the formats listed in
 Audio MIDI Setup are physical formats not the virtual formats. You will need to use HALLab to view the virtual formats (available in "Additional Tools for Xcode 10.2.dmg").
 The physical and virtual formats can be get and set with`AudioStream.physicalFormat` and `AudioStream.virtualFormat`.
 Usage:
 ```
 audiodeviceplayer <filename>
 ```
 */
func main() {
    guard CommandLine.arguments.count > 1 else {
        print("Usage: audiodeviceplayer <filename>")
        return
    }

    let url = URL(fileURLWithPath: CommandLine.arguments[1])
    
    do {
        // Read entire file into a buffer
        guard let buffer: AVAudioPCMBuffer = try readFileIntoBuffer(url: url) else {
            print("Couldn't read audio file")
            return
        }
        
        // Create an instance of SimplyCoreAudio which gives us access to AudioDevice info
        let coreAudio = SimplyCoreAudio()
        
        // Get the default output device, alternatively you could select from a list, e.g. coreAudio.allOutputDevices
        guard let outputDevice = coreAudio.defaultOutputDevice else { return }
        
        // Create a player for the output device
        let player = AudioDevicePlayer(audioDevice: outputDevice) {
            print("👏 Finished playing buffer, press enter to stop...")
        }
        
        // Add data, note at the moment it just sets the data, it doesn't append
        player.addData(buffer: buffer)
        
        // Note that the virtual format and physical format haven't been changed.
        // For bitperfect audio the formats needs to be changed to match the file if they are
        // available. The virtual format is the format we write to.
        player.start()
        
        print("🔊 Playing audio, press enter to stop...")
        let _ = readLine()
        
    } catch {
        print("Error: \(error)")
    }
}

/**
 Reads entire file into an AVAudioPCMBuffer.
 */
func readFileIntoBuffer(url: URL) throws -> AVAudioPCMBuffer? {
    
    // Use AVAsset to determine the number of frames in the file, then use that to create buffer
    let asset = AVAsset(url: url)
    let frameLength = asset.duration.value // This is a close estimate but should overestimate, check buffer.frameLength for actual length read in
    
    // For simplicity read into Int32 which allows us to support most Int formats
    let file = try AVAudioFile(forReading: url,
                               commonFormat: .pcmFormatInt32,
                               interleaved: true)
    
    // Create buffer to hold the whole file
    guard let format = AVAudioFormat(commonFormat: .pcmFormatInt32,
                                     sampleRate: 0, // This won't affect the buffer and is just a placeholder
                                     channels: 2,
                                     interleaved: true),
          let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                        frameCapacity: AVAudioFrameCount(frameLength))
    else {
        print("AudioDevicePlayer.readFileIntoBuffer(): Couldn't create AVAudioPCMBuffer")
        return nil
    }
    
    // Read entire file
    try file.read(into: buffer)
    
    return buffer
}
