import Foundation
import AVFoundation
import CoreMedia

@available(macOS 14.0, *)
class AudioStreamer {
    private var cachedInputFormat: AVAudioFormat?
    private var converter: AVAudioConverter?
    private let targetFormat: AVAudioFormat
    private let onAudioData: (Data) -> Void
    
    init(onAudioData: @escaping (Data) -> Void) {
        self.onAudioData = onAudioData
        // Target format: 48kHz, 16-bit, Stereo, Interleaved Linear PCM.
        self.targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 48000.0,
            channels: 2,
            interleaved: true
        )!
    }
    
    func processAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) else { return }
        var asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)!.pointee
        
        guard let inputFormat = AVAudioFormat(streamDescription: &asbd) else { return }
        
        // Recreate converter if input format changes
        let isFormatEqual = (cachedInputFormat?.sampleRate == inputFormat.sampleRate &&
                             cachedInputFormat?.channelCount == inputFormat.channelCount &&
                             cachedInputFormat?.commonFormat == inputFormat.commonFormat)
        if !isFormatEqual || converter == nil {
            cachedInputFormat = inputFormat
            converter = AVAudioConverter(from: inputFormat, to: targetFormat)
            if converter == nil {
                print("❌ AudioStreamer: Failed to create AVAudioConverter from \(inputFormat) to \(targetFormat)")
                return
            }
        }
        
        guard let converter = converter else { return }
        
        let numSamples = CMSampleBufferGetNumSamples(sampleBuffer)
        guard numSamples > 0 else { return }
        
        let channelCount = Int(asbd.mChannelsPerFrame)
        let bufferListSize = MemoryLayout<AudioBufferList>.size + (channelCount - 1) * MemoryLayout<AudioBuffer>.size
        let ablPointer = UnsafeMutableRawPointer.allocate(
            byteCount: bufferListSize,
            alignment: MemoryLayout<AudioBufferList>.alignment
        ).assumingMemoryBound(to: AudioBufferList.self)
        defer { ablPointer.deallocate() }
        
        var blockBuffer: CMBlockBuffer?
        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: ablPointer,
            bufferListSize: bufferListSize,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
            blockBufferOut: &blockBuffer
        )
        
        guard status == noErr else { return }
        
        guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: AVAudioFrameCount(numSamples)) else { return }
        inputBuffer.frameLength = inputBuffer.frameCapacity
        
        let bufferPointer = UnsafeMutableAudioBufferListPointer(ablPointer)
        let destBufferPointer = UnsafeMutableAudioBufferListPointer(inputBuffer.mutableAudioBufferList)
        
        for i in 0..<channelCount {
            if i < bufferPointer.count, i < destBufferPointer.count {
                if let srcData = bufferPointer[i].mData,
                   let destData = destBufferPointer[i].mData {
                    let srcSize = bufferPointer[i].mDataByteSize
                    memcpy(destData, srcData, Int(srcSize))
                }
            }
        }
        
        let ratio = 48000.0 / inputFormat.sampleRate
        let targetFrames = AVAudioFrameCount(Double(inputBuffer.frameLength) * ratio) + 16
        
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: targetFrames) else { return }
        
        var error: NSError?
        var inputCompleted = false
        
        let outputStatus = converter.convert(to: outputBuffer, error: &error) { inNumPackets, outStatus in
            if inputCompleted {
                outStatus.pointee = .noDataNow
                return nil
            }
            outStatus.pointee = .haveData
            inputCompleted = true
            return inputBuffer
        }
        
        if outputStatus == .error || error != nil {
            print("❌ AudioStreamer: AVAudioConverter error: \(error?.localizedDescription ?? "unknown")")
            return
        }
        
        if outputBuffer.frameLength > 0 {
            if let channelData = outputBuffer.int16ChannelData?[0] {
                let byteSize = Int(outputBuffer.frameLength) * 4 // 16-bit (2 bytes) * 2 channels
                let data = Data(bytes: UnsafeRawPointer(channelData), count: byteSize)
                onAudioData(data)
            }
        }
    }
}
