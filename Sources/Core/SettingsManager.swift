import Foundation
import SwiftUI

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @AppStorage("windowWidth") var windowWidth: Double = 600
    @AppStorage("windowHeight") var windowHeight: Double = 250
    @AppStorage("verticalOffset") var verticalOffset: Double = 0
    @AppStorage("horizontalOffset") var horizontalOffset: Double = 0
    @AppStorage("useSimulatedNotch") var useSimulatedNotch: Bool = false
    
    private init() {}
}
