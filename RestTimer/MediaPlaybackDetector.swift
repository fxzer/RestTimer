//
//  MediaPlaybackDetector.swift
//  RestTimer
//
//  Created by Assistant on 2024
//

import Foundation
import CoreAudio
import AVFoundation

/// 媒体播放检测器，用于检测系统中是否有其他应用正在播放音频
class MediaPlaybackDetector: ObservableObject {
    static let shared = MediaPlaybackDetector()
    
    @Published var isMediaPlaying = false
    
    private var audioDeviceID: AudioDeviceID = kAudioObjectUnknown
    private var isMonitoring = false
    private var propertyListenerQueue = DispatchQueue(label: "com.resttimer.audio.listener", qos: .userInitiated)
    
    private init() {
        setupAudioDeviceMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    /// 开始监听媒体播放状态
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        setupAudioDeviceMonitoring()
        isMonitoring = true
        
        // 立即检查一次当前状态
        checkAudioPlaybackStatus()
        
        print("[MediaPlaybackDetector] 开始监听媒体播放状态")
    }
    
    /// 停止监听媒体播放状态
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        removeAudioDeviceListener()
        isMonitoring = false
        
        print("[MediaPlaybackDetector] 停止监听媒体播放状态")
    }
    
    // MARK: - Private Methods
    
    /// 设置音频设备监听
    private func setupAudioDeviceMonitoring() {
        // 获取默认输出设备
        audioDeviceID = getDefaultOutputDevice()
        
        guard audioDeviceID != kAudioObjectUnknown else {
            print("[MediaPlaybackDetector] 无法获取默认音频输出设备")
            return
        }
        
        // 添加设备运行状态监听器
        addAudioDeviceListener()
        
        // 监听默认输出设备变化
        addDefaultDeviceChangeListener()
    }
    
    /// 获取默认输出设备ID
    private func getDefaultOutputDevice() -> AudioDeviceID {
        var deviceID: AudioDeviceID = kAudioObjectUnknown
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceID
        )
        
        if status != noErr {
            print("[MediaPlaybackDetector] 获取默认输出设备失败: \(status)")
            return kAudioObjectUnknown
        }
        
        return deviceID
    }
    
    /// 添加音频设备监听器
    private func addAudioDeviceListener() {
        guard audioDeviceID != kAudioObjectUnknown else { return }
        
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let listenerBlock: AudioObjectPropertyListenerBlock = { [weak self] (_, _) in
            self?.propertyListenerQueue.async {
                self?.checkAudioPlaybackStatus()
            }
        }
        
        let status = AudioObjectAddPropertyListenerBlock(
            audioDeviceID,
            &propertyAddress,
            propertyListenerQueue,
            listenerBlock
        )
        
        if status != noErr {
            print("[MediaPlaybackDetector] 添加设备监听器失败: \(status)")
        }
    }
    
    /// 添加默认设备变化监听器
    private func addDefaultDeviceChangeListener() {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let listenerBlock: AudioObjectPropertyListenerBlock = { [weak self] (_, _) in
            self?.propertyListenerQueue.async {
                // 默认设备变化时，重新设置监听
                self?.removeAudioDeviceListener()
                self?.setupAudioDeviceMonitoring()
            }
        }
        
        let status = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            propertyListenerQueue,
            listenerBlock
        )
        
        if status != noErr {
            print("[MediaPlaybackDetector] 添加默认设备变化监听器失败: \(status)")
        }
    }
    
    /// 移除音频设备监听器
    private func removeAudioDeviceListener() {
        guard audioDeviceID != kAudioObjectUnknown else { return }
        
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        // 使用传统的 AudioObjectRemovePropertyListener 方法
        // 因为 AudioObjectRemovePropertyListenerBlock 需要确切的 block 引用
        let status = AudioObjectRemovePropertyListener(
            audioDeviceID,
            &propertyAddress,
            { (objectID, numAddresses, addresses, clientData) -> OSStatus in
                return noErr
            },
            nil
        )
        
        if status != noErr {
            print("[MediaPlaybackDetector] 移除设备监听器失败: \(status)")
        }
    }
    
    /// 检查音频播放状态
    private func checkAudioPlaybackStatus() {
        guard audioDeviceID != kAudioObjectUnknown else {
            DispatchQueue.main.async {
                self.isMediaPlaying = false
            }
            return
        }
        
        var isRunning: UInt32 = 0
        var propertySize = UInt32(MemoryLayout<UInt32>.size)
        
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyData(
            audioDeviceID,
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &isRunning
        )
        
        if status == noErr {
            let wasPlaying = isMediaPlaying
            let nowPlaying = isRunning != 0
            
            DispatchQueue.main.async {
                self.isMediaPlaying = nowPlaying
                
                // 只在状态变化时打印日志
                if wasPlaying != nowPlaying {
                    print("[MediaPlaybackDetector] 媒体播放状态变化: \(nowPlaying ? "开始播放" : "停止播放")")
                }
            }
        } else {
            print("[MediaPlaybackDetector] 检查音频播放状态失败: \(status)")
            DispatchQueue.main.async {
                self.isMediaPlaying = false
            }
        }
    }
}

// MARK: - 扩展：提供更高级的检测功能
extension MediaPlaybackDetector {
    
    /// 检查是否有特定应用在播放音频（需要额外的权限和实现）
    /// 注意：这个功能需要更复杂的实现，可能需要使用私有API或者其他方法
    func isSpecificAppPlayingAudio(bundleIdentifier: String) -> Bool {
        // 这里可以实现更具体的应用检测逻辑
        // 目前返回通用的媒体播放状态
        return isMediaPlaying
    }
    
    /// 获取当前音频设备的音量级别
    func getCurrentVolumeLevel() -> Float? {
        guard audioDeviceID != kAudioObjectUnknown else { return nil }
        
        var volume: Float32 = 0.0
        var propertySize = UInt32(MemoryLayout<Float32>.size)
        
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyData(
            audioDeviceID,
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &volume
        )
        
        return status == noErr ? volume : nil
    }
}