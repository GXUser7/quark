import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController.init()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Делаем title bar прозрачным
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    
    // Расширяем контент под title bar
    self.styleMask.insert(.fullSizeContentView)
    
    // Убираем фон title bar
    self.backgroundColor = NSColor.clear
    
    // Опционально: убрать разделительную линию
    self.hasShadow = false

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}