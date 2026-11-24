import Foundation
import CoreAudio

/// CoreAudio 进程级音频活跃流统一扫描器（消除跨模块重复，严格适配 Create/Copy 所有权规则）
enum CoreAudioProcessScanner {
    enum StreamDirection {
        case input
        case output

        var selector: AudioObjectPropertySelector {
            switch self {
            case .input:
                return kAudioProcessPropertyIsRunningInput
            case .output:
                return kAudioProcessPropertyIsRunningOutput
            }
        }
    }

    private static let selfBundle = Bundle.main.bundleIdentifier?.lowercased() ?? "fxzer.top.resttimer"

    /// 过滤系统底层音频驱动、语音听写及输入法语音进程
    static func isSystemOrIgnoredBundle(_ lower: String) -> Bool {
        if lower == selfBundle
            || lower.hasPrefix("com.apple.audio.")
            || lower == "com.apple.coreaudiod"
            || lower.hasPrefix("com.apple.speech")
            || lower.hasPrefix("com.apple.siri")
            || lower.hasPrefix("com.apple.accessibility.")
            || lower.contains("ime")
            || lower.hasPrefix("com.apple.quicklook")
            || lower.hasPrefix("com.apple.finder")
            || lower.contains("inputmethod")
            || lower.contains("sogou")
            || lower.contains("baidu")
            || lower.contains("wechatinput") {
            return true
        }
        return false
    }

    /// 获取当前指定方向（输入/麦克风 或 输出/扬声器耳机）活跃的所有用户级应用 BundleID 列表
    static func activeUserProcessBundleIDs(direction: StreamDirection) -> [String] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize) == noErr,
              dataSize > 0 else {
            return []
        }

        let count = Int(dataSize) / MemoryLayout<AudioObjectID>.size
        var processIDs = [AudioObjectID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &processIDs) == noErr else {
            return []
        }

        var result: [String] = []

        for objID in processIDs {
            var isRunning: UInt32 = 0
            var runSize = UInt32(MemoryLayout<UInt32>.size)
            var runAddr = AudioObjectPropertyAddress(
                mSelector: direction.selector,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            guard AudioObjectGetPropertyData(objID, &runAddr, 0, nil, &runSize, &isRunning) == noErr,
                  isRunning != 0 else {
                continue
            }

            var unmanagedBundle: Unmanaged<CFString>?
            var bSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            var bAddr = AudioObjectPropertyAddress(
                mSelector: kAudioProcessPropertyBundleID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            let status = withUnsafeMutablePointer(to: &unmanagedBundle) { ptr in
                AudioObjectGetPropertyData(objID, &bAddr, 0, nil, &bSize, ptr)
            }
            let bundleID = (status == noErr ? unmanagedBundle?.takeRetainedValue() as String? : nil) ?? ""
            let lower = bundleID.lowercased()

            if isSystemOrIgnoredBundle(lower) {
                continue
            }
            result.append(bundleID)
        }

        return result
    }

    /// 快速检查是否存在任意用户级正在输出音频的应用
    static func isAnyUserMediaOutputtingAudio() -> Bool {
        !activeUserProcessBundleIDs(direction: .output).isEmpty
    }
}
