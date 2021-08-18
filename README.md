# audiodeviceplayer

A macOS commandline executable that uses CoreAudio to play a file directly to an AudioDevice bypassing other layers such as AudioUnits, converters, and mixers.

I wrote this to learn how CoreAudio works. I couldn't find a simple example online, so this might help people starting out.

# Installation

```
git clone https://github.com/jolonf/audiodeviceplayer.git
cd audiodeviceplayer
swift build
.build/debug/audiodeviceplayer <path_to_audio_file>
```

# Limitations

This is designed as a simple example and has some limitations:

## PCM formats

AudioDevices have a virtual and physical format. At this layer we are still dealing with the virtual format. It appears that 
all devices support the Float32 format and is the default. CoreAudio then converts it to the physical format. Note that
Audio MIDI Setup shows the physical formats not the virtual formats. So you could set a device to "16 bit" in Audio MIDI Setup
but internally are still required to output Float32 for the virtual format. The only way to view the virtual formats is to use
HALLab (see "Additional Tools for Xcode 10.2.dmg"). 

It is possible to include logic to try to find the best virtual and physical formats to match the selected track, but to keep this 
example simple they are omitted.

Files are read into Int32 sized PCM sample buffers, which should be enough for most integer file formats.

Virtual formats of 16, 24, and 32 bit integer and Float32 are supported.

## Output device

The example uses the currently selected default output device. It can easily be altered specify a custom device.

## Reading audio file

The example reads the entire file into a buffer.

## AudioDevicePlayer

The AudioDevicePlayer class starts and stops the audio device and sets up the callback for providing new data to the audio device.
At the moment only one audio buffer is supported. Once that has been written out, the player notifies the AudioDevicePlayer client
through a callback, but doesn't stop. At this point the callback to provide new data keeps getting called, but the AudioDevicePlayer
doesn't fill the buffers with any audio. The audio will be silent but the device is still running. Call AudioDevicePlayer.stop() to
stop the device.

# Package dependencies

The example depends on the excellent [SimplyCoreAudio](https://github.com/rnine/SimplyCoreAudio) package.


