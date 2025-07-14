import Foundation
import AudioToolbox

enum AudioLoadError: Error {
    case openFailed(OSStatus)
    case getPropertyFailed(OSStatus)
    case setPropertyFailed(OSStatus)
    case readFailed(OSStatus)
    case unsupportedFormat
    case unknown(OSStatus)
}

func loadAudio(url: URL, samplingRate: Int) throws -> [Float] {
    var extAudioFile: ExtAudioFileRef?
    
    // Open the audio file
    var status = ExtAudioFileOpenURL(url as CFURL, &extAudioFile)
    guard status == noErr, let extFile = extAudioFile else {
        throw AudioLoadError.openFailed(status)
    }
    defer { ExtAudioFileDispose(extFile) }
    
    // Get file's original format and length
    var fileFormat = AudioStreamBasicDescription()
    var propertySize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
    status = ExtAudioFileGetProperty(extFile, kExtAudioFileProperty_FileDataFormat, &propertySize, &fileFormat)
    guard status == noErr else {
        throw AudioLoadError.getPropertyFailed(status)
    }
    
    var fileLengthFrames: Int64 = 0
    propertySize = UInt32(MemoryLayout<Int64>.size)
    status = ExtAudioFileGetProperty(extFile, kExtAudioFileProperty_FileLengthFrames, &propertySize, &fileLengthFrames)
    guard status == noErr else {
        throw AudioLoadError.getPropertyFailed(status)
    }
    
    // Define client format: mono, float32, target sample rate, interleaved/packed
    var clientFormat = AudioStreamBasicDescription(
        mSampleRate: Float64(samplingRate),
        mFormatID: kAudioFormatLinearPCM,
        mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
        mBytesPerPacket: 4,
        mFramesPerPacket: 1,
        mBytesPerFrame: 4,
        mChannelsPerFrame: 1,
        mBitsPerChannel: 32,
        mReserved: 0
    )
    
    propertySize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
    status = ExtAudioFileSetProperty(extFile, kExtAudioFileProperty_ClientDataFormat, propertySize, &clientFormat)
    guard status == noErr else {
        throw AudioLoadError.setPropertyFailed(status)
    }
    
    // Estimate client length for preallocation (optional but efficient)
    let fileSampleRate = fileFormat.mSampleRate
    let duration = Double(fileLengthFrames) / fileSampleRate
    let estimatedClientFrames = Int(duration * Double(samplingRate) + 0.5)
    var samples: [Float] = []
    samples.reserveCapacity(estimatedClientFrames)
    
    // Read in chunks until EOF
    let bufferFrameSize = 4096  // Arbitrary chunk size; adjust if needed
    var buffer = [Float](repeating: 0, count: bufferFrameSize)
    
    while true {
        var numFrames = UInt32(bufferFrameSize)
        
        let audioBuffer = buffer.withUnsafeMutableBytes { bytes in
            AudioBuffer(
                mNumberChannels: 1,
                mDataByteSize: UInt32(bufferFrameSize * MemoryLayout<Float>.size),
                mData: bytes.baseAddress
            )
        }
        var audioBufferList = AudioBufferList(mNumberBuffers: 1, mBuffers: audioBuffer)
        
        status = ExtAudioFileRead(extFile, &numFrames, &audioBufferList)
        guard status == noErr else {
            throw AudioLoadError.readFailed(status)
        }
        
        if numFrames == 0 {
            break  // EOF
        }
        
        samples.append(contentsOf: buffer[0..<Int(numFrames)])
    }
    
    return samples
}
