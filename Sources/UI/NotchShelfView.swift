import SwiftUI
import UniformTypeIdentifiers

struct NotchShelfView: View {
    @StateObject private var notchManager = NotchDetectionManager.shared
    @StateObject private var storageManager = StorageManager.shared
    @StateObject private var batteryManager = BatteryManager.shared
    @StateObject private var clipboardManager = ClipboardManager.shared
    @ObservedObject private var notchState = NotchState.shared
    @ObservedObject private var settings = SettingsManager.shared
    
    var body: some View {
        ZStack(alignment: .top) {
            if notchManager.hasNotch || settings.useSimulatedNotch {
                VStack(spacing: 0) {
                    // Spacer for the notch height itself
                    // Keep a tiny hit-testable strip aligned to the notch height.
                    ZStack(alignment: .bottom) {
                        Color.clear
                        // Small handle to indicate presence
                        Capsule()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 40, height: 4)
                            .padding(.bottom, 4)
                    }
                    .frame(height: (notchManager.hasNotch ? notchManager.safeAreaTop : 32))
                    .contentShape(Rectangle())
                    
                    if isExpanded {
                        ZStack {
                            // Background
                            UnevenRoundedRectangle(
                                topLeadingRadius: 0,
                                bottomLeadingRadius: 20,
                                bottomTrailingRadius: 20,
                                topTrailingRadius: 0,
                                style: .continuous
                            )
                            .fill(Color.black)
                            .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
                            
                            VStack(spacing: 16) {
                                // Top Bar
                                HStack(spacing: 16) {
                                    Text("Notch Buddy")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white.opacity(0.8))
                                    
                                    HStack(spacing: 12) {
                                        Button {
                                            notchState.selectedTab = .home
                                        } label: {
                                            Image(systemName: "house.fill")
                                                .foregroundColor(notchState.selectedTab == .home ? .white : .gray)
                                        }
                                        .buttonStyle(.plain)

                                        Button {
                                            notchState.selectedTab = .tray
                                        } label: {
                                            Image(systemName: "tray.fill")
                                                .foregroundColor(notchState.selectedTab == .tray ? .white : .gray)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    
                                    Spacer()
                                    
                                    HStack(spacing: 4) {
                                        Text(batteryText)
                                            .font(.system(size: 12, weight: .bold))
                                        if batteryManager.isCharging || batteryManager.isPluggedIn {
                                            Image(systemName: "bolt.fill")
                                                .font(.system(size: 10))
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green)
                                    .foregroundColor(.black)
                                    .cornerRadius(4)
                                    
                                    Button(action: {
                                        SettingsWindowController.shared.show()
                                    }) {
                                        Image(systemName: "gearshape")
                                            .foregroundColor(.white)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 10)
                                
                                Group {
                                    if notchState.selectedTab == .tray {
                                        traySection
                                    } else {
                                        homeSection
                                    }
                                }
                                
                                // Footer
                                HStack {
                                    Spacer()
                                    Button {
                                        notchState.isPinned.toggle()
                                        if notchState.isPinned {
                                            notchState.isExpanded = true
                                        }
                                    } label: {
                                        Image(systemName: notchState.isPinned ? "lock.fill" : "lock.open.fill")
                                            .foregroundColor(.white)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 20)
                                .padding(.bottom, 10)
                            }
                        }
                        .frame(width: CGFloat(settings.windowWidth), height: CGFloat(settings.windowHeight))
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            } else {
                Text("No Notch Detected")
                    .padding()
            }
        }
        .edgesIgnoringSafeArea(.top)
    }
    
    var isExpanded: Bool {
        notchState.isExpanded
    }

    private var batteryText: String {
        if let pct = batteryManager.percentage {
            return "\(pct)%"
        }
        return "--%"
    }

    private var traySection: some View {
        VStack(spacing: 14) {
            HStack(spacing: 16) {
                DropZoneView(
                    icon: "dot.radiowaves.left.and.right",
                    title: "AirDrop",
                    isActive: notchState.activeDropZone == .airdrop
                )

                DropZoneView(
                    icon: "tray.and.arrow.down",
                    title: "Drop files here",
                    isActive: notchState.activeDropZone == .store
                )
            }
            .padding(.horizontal, 20)
            .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 8) {
                if storageManager.storedItems.isEmpty {
                    Text("No items in tray")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHGrid(rows: [GridItem(.fixed(70), spacing: 10)], spacing: 10) {
                            ForEach(storageManager.storedItems) { item in
                                TrayIcon(
                                    item: item,
                                    onDelete: { storageManager.deleteItem(item) },
                                    onMoveToBin: { storageManager.moveItemToTrash(item) }
                                )
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .frame(height: 78)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var homeSection: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Text("Clipboard")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
            }
            .padding(.horizontal, 20)

            ScrollView {
                VStack(spacing: 6) {
                    ForEach(clipboardManager.history) { item in
                        ClipboardRow(item: item)
                            .onTapGesture {
                                copyClipboardItem(item)
                            }
                    }
                }
                .padding(.horizontal, 20)
            }
            .frame(maxHeight: .infinity)
        }
    }

    private func copyClipboardItem(_ item: ClipboardItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        if let url = item.fileURL {
            pb.writeObjects([url as NSURL])
        } else {
            pb.setString(item.content, forType: .string)
        }
    }
}

private struct ClipboardRow: View {
    let item: ClipboardItem

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.white.opacity(0.8))

            Text(item.content)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(white: 0.16))
        .cornerRadius(10)
    }

    private var icon: String {
        switch item.type {
        case .text: return "doc.text"
        case .image: return "photo"
        case .file: return "doc"
        }
    }
}

private struct TrayIcon: View {
    let item: StoredItem
    let onDelete: () -> Void
    let onMoveToBin: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 6) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                    .resizable()
                    .frame(width: 34, height: 34)

                Text(item.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)
                    .frame(width: 74)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(white: 0.16))
            .cornerRadius(12)
            .contentShape(Rectangle())
            .contextMenu {
                Button("Move to Bin") {
                    onMoveToBin()
                }

                Divider()

                Button("Remove from Tray") {
                    onDelete()
                }
            }
            .onDrag {
                NSItemProvider(object: item.url as NSURL)
            }

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
            }
            .buttonStyle(.plain)
            .padding(6)
        }
    }
}

struct DropZoneView: View {
    let icon: String
    let title: String
    let isActive: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(isActive ? .white : .gray)
            
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isActive ? .white : .gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.2))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActive ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
}
