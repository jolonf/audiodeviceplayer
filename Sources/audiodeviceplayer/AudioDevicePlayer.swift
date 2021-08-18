//
//  AudioDevicePlayer.swift
//  AudioDevicePlayer
//
//  Created by Jolon on 18/8/21.
//

import Foundation
import AVFoundation
import SimplyCoreAudio

/**
 Play audio directly through an AudioDevice bypassing AudioUnits, mixers, converters, and other layers.
 */
public class AudioDevicePlayer {
    
    let audioDevice: AudioDevice?
    let buffersEmptyCallback: () -> Void
    var procID: AudioDeviceIOProcID?
    var outputFormat: AudioStreamBasicDescription?
    var buffer: AVAudioPCMBuffer?
    
    /// Keeps track of how many samples we have written out to the AudioDevice, note this is a sample not frame (2 samples per frame)
    var sampleCount = 0
    
    /// Set to true when the buffers are empty
    var buffersEmpty = false
    
    /**
     - Parameter audioDevice: The AudioDevice to play audio through.
     - Parameter buffersEmptyCallback: Closure will be called when the buffers are empty, note there is no way to refill the buffers at the moment.
     */
    init(audioDevice: AudioDevice, buffersEmptyCallback: @escaping () -> Void) {
        self.audioDevice = audioDevice
        self.buffersEmptyCallback = buffersEmptyCallback
        
        // Set up the callback which will be called when playback has started to fill the buffers
        let err = AudioDeviceCreateIOProcIDWithBlock(&procID, audioDevice.id, nil /* DispatchQueue */) {
            inNow /* UnsafePointer<AudioTimeStamp> */,
            inInputData, /* UnsafePointer<AudioBufferList> */
            inInputTime, /* UnsafePointer<AudioTimeStamp> */
            outOutputData, /* UnsafeMutablePointer<AudioBufferList> */
            inOutputTime /* UnsafePointer<AudioTimeStamp> */
            in
            
            // Fill output AudioBuffers
            self.fillOutputBuffers(outOutputData: outOutputData, inOutputTime: inOutputTime)
        }
        
        guard err == noErr else {
            print("AudioDevicePlayer: Error Creating IO Proc \(err)")
            return
        }
    }
    
    /**
     This should append to the end of an internal buffer, but for now just retains it and uses it directly for audio data
     */
    func addData(buffer: AVAudioPCMBuffer) {
        self.buffer = buffer
    }
    
    /**
     Start the device. This causes a callback to be called (setup in init) to fill buffers and playback will start.
     Call stop() to stop playback.
     */
    func start() {
        // Get the output format
        guard let outputDevice = audioDevice,
              let streams = outputDevice.streams(scope: .output),
              streams.count > 0 else {
                  print("AudioDevicePlayer.start(): Couldn't access AudioDevice streams")
                  return
              }
        
        outputFormat = streams[0].virtualFormat
        
        AudioDeviceStart(outputDevice.id, procID)
    }
    
    /**
     Stops playback started by start().
     */
    func stop() {
        guard let outputDevice = audioDevice else {
            print("AudioDevicePlayer.stop(): No output device set")
            return
        }
        AudioDeviceStop(outputDevice.id, procID)
    }
    
    /**
     Fills the provided AudioBufferList with samples from the buffer. The main output bitdepths are supported: Int16, Int24, Int32, and Float32.
     Ideally the virtual and physical output formats of the AudioDevice are set to match beforehand so that the playback is bitperfect (not done at the moment).
     Called from the callback set up in init.
     */
    func fillOutputBuffers(outOutputData: UnsafeMutablePointer<AudioBufferList>, inOutputTime: UnsafePointer<AudioTimeStamp>) {

        // Make sure we have been setup properly
        guard let outputFormat = outputFormat else {
            print("AudioDevicePlayer.fillOutputBuffers(): No outputFormat, not filling buffers")
            return
        }
        guard let buffer = buffer else {
            print("AudioDevicePlayer.fillOutputBuffers(): No buffer, not filling buffers")
            return
        }
        
        guard let int32ChannelData = buffer.int32ChannelData else {
            print("AudioDevicePlayer.fillOutputBuffers(): No Int32 channel data, not filling buffers")
            return
        }
        
        // Handy wrapper
        let audioBufferList = UnsafeMutableAudioBufferListPointer(outOutputData)
        
        // For interleaved channels there is only one buffer in the buffer list (non-interleaved have a buffer for each channel)
        if let audioBuffer = audioBufferList.first {
            if outputFormat.mBitsPerChannel == 32 && outputFormat.mFormatFlags & kLinearPCMFormatFlagIsFloat != 0 {
                // Float32
                let outBuffer = UnsafeMutableBufferPointer<Float32>(audioBuffer)
                for i in outBuffer.startIndex ..< outBuffer.endIndex {
                    if sampleCount >= Int(buffer.frameLength) * buffer.stride {
                        if !buffersEmpty { buffersEmptyCallback() }
                        buffersEmpty = true
                        return
                    }
                    // Scale Int32 to -1 .. 1
                    outBuffer[i] = Float32(int32ChannelData[0][sampleCount]) / Float32(Int32.max) // Should it be Int32.max + 1?
                    sampleCount += 1
                }
            } else if outputFormat.mBitsPerChannel == 16 {
                // 16 bit
                let outBuffer = UnsafeMutableBufferPointer<Int16>(audioBuffer)
                for i in outBuffer.startIndex ..< outBuffer.endIndex {
                    if sampleCount >= Int(buffer.frameLength) * buffer.stride {
                        if !buffersEmpty { buffersEmptyCallback() }
                        buffersEmpty = true
                        return
                    }
                    // Shift Int32 to Int16
                    outBuffer[i] = Int16(int32ChannelData[0][sampleCount] >> 16)
                    sampleCount += 1
                }
            } else if outputFormat.mBitsPerChannel == 24 {
                // 24 bit (aligned low or high)
                let outBuffer = UnsafeMutableBufferPointer<Int32>(audioBuffer)
                for i in outBuffer.startIndex ..< outBuffer.endIndex {
                    if sampleCount >= Int(buffer.frameLength) * buffer.stride {
                        if !buffersEmpty { buffersEmptyCallback() }
                        buffersEmpty = true
                        return
                    }
                    // Conditionally shift Int32 down 8 bits if isn't aligned high
                    let shift: Int32 = outputFormat.mFormatFlags & kLinearPCMFormatFlagIsAlignedHigh != 0 ? 0 : 8
                    outBuffer[i] = int32ChannelData[0][sampleCount] >> shift
                    sampleCount += 1
                }
            } else if outputFormat.mBitsPerChannel == 32 {
                // 32 bit
                let outBuffer = UnsafeMutableBufferPointer<Int32>(audioBuffer)
                for i in outBuffer.startIndex ..< outBuffer.endIndex {
                    if sampleCount >= Int(buffer.frameLength) * buffer.stride {
                        if !buffersEmpty { buffersEmptyCallback() }
                        buffersEmpty = true
                        return
                    }
                    // No conversion required
                    outBuffer[i] = int32ChannelData[0][sampleCount]
                    sampleCount += 1
                }
            }
        }
    }
}


