// SMCKit.swift — IOKit-based SMC (System Management Controller) reader.
// Ported from the open-source Stats app by exelban (MIT license).
// https://github.com/exelban/stats

import Foundation
import IOKit

// MARK: - SMC Constants

private let kIOSMCServiceName = "AppleSMC"

private enum SMCPacketType: UInt8 {
    case readKey  = 5
    case getCount = 8
}

// MARK: - SMC Key types

struct SMCKey {
    let code: UInt32

    init(_ string: String) {
        var value: UInt32 = 0
        for char in string.unicodeScalars.prefix(4) {
            value = (value << 8) | char.value
        }
        self.code = value
    }

    static func from(_ uint32: UInt32) -> SMCKey { SMCKey(uint32) }
    private init(_ uint32: UInt32) { self.code = uint32 }
}

// MARK: - Well-known sensor keys

enum SMCSensorKey {
    // Temperatures (°C)
    static let cpuProximity  = SMCKey("TC0P")
    static let cpuDie        = SMCKey("TC0E")
    static let cpuTemp       = SMCKey("Tc0C")   // Apple Silicon
    static let gpuTemp       = SMCKey("TGOP")
    static let gpuProximity  = SMCKey("TG0P")
    static let batteryTemp   = SMCKey("TB0T")
    static let ambientTemp   = SMCKey("TA0P")
    static let heatsink      = SMCKey("Th0H")

    // Fans
    static let fan0CurrentRPM = SMCKey("F0Ac")
    static let fan1CurrentRPM = SMCKey("F1Ac")
    static let fan0MaxRPM     = SMCKey("F0Mx")
    static let fan1MaxRPM     = SMCKey("F1Mx")
    static let fanCount       = SMCKey("FNum")
}

// MARK: - SMCKit

final class SMCKit {
    private var connection: io_connect_t = 0
    private var isOpen = false

    static let shared = SMCKit()

    private init() {
        open()
    }

    deinit {
        close()
    }

    // MARK: - Connection management

    private func open() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault,
                                                  IOServiceMatching(kIOSMCServiceName))
        guard service != 0 else { return }
        defer { IOObjectRelease(service) }
        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        isOpen = (result == kIOReturnSuccess)
    }

    private func close() {
        if isOpen {
            IOServiceClose(connection)
            isOpen = false
        }
    }

    // MARK: - Key reading

    func readTemperature(_ key: SMCKey) -> Double? {
        guard let bytes = readKey(key, size: 2) else { return nil }
        // sp78 format: fixed point, first byte is integer, second is fractional
        let integer    = Double(bytes[0])
        let fractional = Double(bytes[1]) / 256.0
        let temp = integer + fractional
        guard temp > 0 && temp < 200 else { return nil }
        return temp
    }

    func readRPM(_ key: SMCKey) -> Double? {
        guard let bytes = readKey(key, size: 2) else { return nil }
        // fpe2 format: 14-bit unsigned integer + 2 fractional bits
        let hi = UInt16(bytes[0])
        let lo = UInt16(bytes[1])
        let rpm = Double((hi << 8 | lo)) / 4.0
        guard rpm > 0 else { return nil }
        return rpm
    }

    func readUInt8(_ key: SMCKey) -> UInt8? {
        guard let bytes = readKey(key, size: 1) else { return nil }
        return bytes[0]
    }

    // MARK: - Low-level key read

    private func readKey(_ key: SMCKey, size: Int) -> [UInt8]? {
        guard isOpen else { return nil }

        // Build input struct
        var input = SMCParamStruct()
        var output = SMCParamStruct()
        input.key = key.code
        input.data8 = SMCPacketType.readKey.rawValue
        input.keyInfo.dataSize = UInt32(size)

        var inputSize = MemoryLayout<SMCParamStruct>.size
        var outputSize = MemoryLayout<SMCParamStruct>.size

        let result = IOConnectCallStructMethod(
            connection,
            UInt32(2),  // kSMCReadKey
            &input,
            inputSize,
            &output,
            &outputSize
        )

        guard result == kIOReturnSuccess && output.result == 0 else { return nil }

        var bytes = [UInt8](repeating: 0, count: size)
        withUnsafeBytes(of: output.bytes) { ptr in
            for i in 0 ..< min(size, ptr.count) {
                bytes[i] = ptr[i]
            }
        }
        return bytes
    }
}

// MARK: - SMC struct layout (matches AppleSMC IOKit interface)

private struct SMCKeyInfoData {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
}

private struct SMCParamStruct {
    var key: UInt32 = 0
    var vers = SMCVersion()
    var pLimitData = SMCPLimitData()
    var keyInfo = SMCKeyInfoData()
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) =
        (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
}

private struct SMCVersion {
    var major: UInt8 = 0
    var minor: UInt8 = 0
    var build: UInt8 = 0
    var reserved: UInt8 = 0
    var release: UInt16 = 0
}

private struct SMCPLimitData {
    var version: UInt16 = 0
    var length: UInt16 = 0
    var cpuPLimit: UInt32 = 0
    var gpuPLimit: UInt32 = 0
    var memPLimit: UInt32 = 0
}
