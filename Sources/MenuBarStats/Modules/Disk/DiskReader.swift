import Foundation
import Darwin
import IOKit
import IOKit.storage

// MARK: - Data models

struct DiskInfo {
    var name: String         // e.g. "Macintosh HD"
    var mountPoint: String   // e.g. "/"
    var total: UInt64
    var used: UInt64
    var free: UInt64
    var usedFraction: Double
    var isInternal: Bool
}

struct DiskActivity {
    var readBytesPerSec: Double
    var writeBytesPerSec: Double
    var readHistory: [Double]
    var writeHistory: [Double]
    var processes: [DiskProcess]
}

struct DiskStats {
    var volumes: [DiskInfo]
    var activity: DiskActivity
}

struct DiskProcess {
    var pid: Int32
    var name: String
    var readBytes: UInt64
    var writeBytes: UInt64
}

// MARK: - Reader

final class DiskReader: BaseReader<DiskStats> {
    private var prevReadBytes: UInt64 = 0
    private var prevWriteBytes: UInt64 = 0
    private var prevTimestamp: Date = Date()
    private var readHistory: [Double] = []
    private var writeHistory: [Double] = []

    // Track per-process previous values for delta
    private var prevProcessBytes: [Int32: (read: UInt64, write: UInt64)] = [:]

    override init(label: String = "disk") {
        super.init(label: label)
    }

    override func read() {
        publish(collectStats())
    }

    private func collectStats() -> DiskStats {
        let volumes = readVolumes()
        let activity = readActivity()
        return DiskStats(volumes: volumes, activity: activity)
    }

    // MARK: - Volume capacities via getmntinfo / statfs

    private func readVolumes() -> [DiskInfo] {
        var mounts: UnsafeMutablePointer<statfs>?
        let count = getmntinfo(&mounts, MNT_NOWAIT)
        guard count > 0, let mounts = mounts else { return [] }

        var volumes: [DiskInfo] = []
        for i in 0 ..< Int(count) {
            let fs = mounts[i]

            // Skip pseudo filesystems
            let fsType = withUnsafeBytes(of: fs.f_fstypename) { ptr -> String in
                String(cString: ptr.bindMemory(to: CChar.self).baseAddress!)
            }
            guard !["devfs", "autofs", "synthfs", "kernfs"].contains(fsType) else { continue }

            let mountPoint = withUnsafeBytes(of: fs.f_mntonname) { ptr -> String in
                String(cString: ptr.bindMemory(to: CChar.self).baseAddress!)
            }
            _ = withUnsafeBytes(of: fs.f_mntfromname) { _ in () }

            let blockSize = UInt64(fs.f_bsize)
            let total = UInt64(fs.f_blocks) * blockSize
            let free  = UInt64(fs.f_bavail) * blockSize
            let used  = total > free ? total - free : 0
            let usedFraction = total > 0 ? Double(used) / Double(total) : 0

            guard total > 0 else { continue }

            let displayName = mountPoint == "/" ? "Macintosh HD" : URL(fileURLWithPath: mountPoint).lastPathComponent

            volumes.append(DiskInfo(
                name: displayName,
                mountPoint: mountPoint,
                total: total,
                used: used,
                free: free,
                usedFraction: usedFraction,
                isInternal: mountPoint == "/"
            ))
        }
        return volumes
    }

    // MARK: - I/O throughput via IOKit

    private func readActivity() -> DiskActivity {
        var totalRead: UInt64 = 0
        var totalWrite: UInt64 = 0

        let matchingDict = IOServiceMatching("IOBlockStorageDriver")
        var iterator: io_iterator_t = 0
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator)

        if kr == KERN_SUCCESS {
            var service = IOIteratorNext(iterator)
            while service != 0 {
                var props: Unmanaged<CFMutableDictionary>?
                if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                   let dict = props?.takeRetainedValue() as? [String: AnyObject],
                   let stats = dict["Statistics"] as? [String: AnyObject] {
                    totalRead  += (stats["Bytes (Read)"] as? UInt64) ?? 0
                    totalWrite += (stats["Bytes (Write)"] as? UInt64) ?? 0
                }
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            IOObjectRelease(iterator)
        }

        let now = Date()
        let elapsed = max(now.timeIntervalSince(prevTimestamp), 0.1)
        let readRate  = prevReadBytes  > 0 ? Double(totalRead  > prevReadBytes  ? totalRead  - prevReadBytes  : 0) / elapsed : 0
        let writeRate = prevWriteBytes > 0 ? Double(totalWrite > prevWriteBytes ? totalWrite - prevWriteBytes : 0) / elapsed : 0

        prevReadBytes  = totalRead
        prevWriteBytes = totalWrite
        prevTimestamp  = now

        // History: normalise to a reasonable max (100 MB/s)
        let maxRate: Double = 100 * 1024 * 1024
        readHistory.append(min(readRate / maxRate, 1.0))
        writeHistory.append(min(writeRate / maxRate, 1.0))
        if readHistory.count  > 60 { readHistory.removeFirst() }
        if writeHistory.count > 60 { writeHistory.removeFirst() }

        let processes = readTopProcesses()

        return DiskActivity(
            readBytesPerSec: readRate,
            writeBytesPerSec: writeRate,
            readHistory: readHistory,
            writeHistory: writeHistory,
            processes: processes
        )
    }

    // MARK: - Top processes by disk I/O

    private func readTopProcesses() -> [DiskProcess] {
        var pids = [Int32](repeating: 0, count: 4096)
        let count = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<Int32>.size))
        guard count > 0 else { return [] }

        var results: [DiskProcess] = []
        for i in 0 ..< Int(count) {
            let pid = pids[i]
            guard pid > 0 else { continue }

            var ruinfo = rusage_info_v4()
            guard withUnsafeMutablePointer(to: &ruinfo, {
                proc_pid_rusage(pid, RUSAGE_INFO_V4, UnsafeMutableRawPointer($0))
            }) == 0 else { continue }

            let read  = ruinfo.ri_diskio_bytesread
            let write = ruinfo.ri_diskio_byteswritten
            guard read + write > 0 else { continue }

            var nameBuffer = [CChar](repeating: 0, count: Int(MAXCOMLEN) + 1)
            proc_name(pid, &nameBuffer, UInt32(nameBuffer.count))
            let name = String(cString: nameBuffer)
            guard !name.isEmpty else { continue }

            results.append(DiskProcess(pid: pid, name: name, readBytes: read, writeBytes: write))
        }

        return Array(results.sorted { ($0.readBytes + $0.writeBytes) > ($1.readBytes + $1.writeBytes) }.prefix(5))
    }
}
