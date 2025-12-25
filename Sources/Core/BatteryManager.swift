import Foundation
import IOKit.ps

@MainActor
final class BatteryManager: ObservableObject {
    static let shared = BatteryManager()

    @Published private(set) var percentage: Int?
    @Published private(set) var isCharging: Bool = false
    @Published private(set) var isPluggedIn: Bool = false

    private var timer: Timer?

    private init() {
        refresh()
    }

    func startMonitoring(pollInterval: TimeInterval = 20) {
        timer?.invalidate()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        let snapshot = Self.readBatterySnapshot()
        percentage = snapshot.percentage
        isCharging = snapshot.isCharging
        isPluggedIn = snapshot.isPluggedIn
    }

    private static func readBatterySnapshot() -> (percentage: Int?, isCharging: Bool, isPluggedIn: Bool) {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            return (nil, false, false)
        }

        for ps in list {
            guard let description = IOPSGetPowerSourceDescription(info, ps)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }

            let type = description[kIOPSTypeKey as String] as? String
            if type != (kIOPSInternalBatteryType as String) {
                continue
            }

            let current = description[kIOPSCurrentCapacityKey as String] as? Int
            let max = description[kIOPSMaxCapacityKey as String] as? Int
            let isCharging = (description[kIOPSIsChargingKey as String] as? Bool) ?? false

            let powerState = description[kIOPSPowerSourceStateKey as String] as? String
            let isPluggedIn = (powerState == (kIOPSACPowerValue as String))

            let percent: Int?
            if let current, let max, max > 0 {
                percent = Int((Double(current) / Double(max) * 100).rounded())
            } else {
                percent = nil
            }

            return (percent, isCharging, isPluggedIn)
        }

        return (nil, false, false)
    }
}
