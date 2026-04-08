import Cocoa
import SwiftUI
import Logging

class About {
  private let logger = Logger(label: "org.p0deje.Maccy.About")
  private var window: NSWindow?

  @objc
  func openAbout(_ sender: NSMenuItem?) {
    logger.info("Opening custom About panel")
    
    if window == nil {
      let aboutView = AboutView()
      let hostingController = NSHostingController(rootView: aboutView)
      
      window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 300, height: 250),
        styleMask: [.titled, .closable, .fullSizeContentView],
        backing: .buffered,
        defer: false
      )
      window?.center()
      window?.title = ""
      window?.titlebarAppearsTransparent = true
      window?.isReleasedWhenClosed = false
      window?.contentView = hostingController.view
    }
    
    NSApp.activate(ignoringOtherApps: true)
    window?.makeKeyAndOrderFront(nil)
  }
}

struct AboutView: View {
  private var appName: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Maccy"
  }
  
  private var version: String {
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
    return "Version \(version) (\(build))"
  }
  
  var body: some View {
    VStack(spacing: 16) {
      if let image = NSImage(named: "AppIcon") {
        Image(nsImage: image)
          .resizable()
          .frame(width: 128, height: 128)
      }
      
      Text(appName)
        .font(.system(size: 24, weight: .bold))
      
      Text(version)
        .font(.system(size: 13))
        .foregroundStyle(.secondary)
      
      Spacer()
    }
    .padding(32)
    .frame(width: 300, height: 250)
  }
}
