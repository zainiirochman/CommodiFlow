import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    GeneratedPluginRegistrant.register(with: self)
    
    if let controller = window?.rootViewController as? FlutterViewController {
        let shareChannel = FlutterMethodChannel(name: "commodiflow/share", binaryMessenger: controller.binaryMessenger)
        
        shareChannel.setMethodCallHandler({
          (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
          
          if call.method == "shareExcel" {
              if let args = call.arguments as? [String: Any],
                 let path = args["path"] as? String {
                  
                  DispatchQueue.main.async {
                      let url = URL(fileURLWithPath: path).standardizedFileURL
                      
                      let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                      
                      guard let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                            let window = windowScene.windows.first(where: { $0.isKeyWindow }),
                            var topController = window.rootViewController else {
                          result(FlutterError(code: "UI_ERROR", message: "Gagal menemukan layar aktif", details: nil))
                          return
                      }
                      while let presentedController = topController.presentedViewController {
                          topController = presentedController
                      }
                      if let popover = activityViewController.popoverPresentationController {
                          popover.sourceView = topController.view
                          popover.sourceRect = CGRect(x: topController.view.bounds.midX, y: topController.view.bounds.midY, width: 0, height: 0)
                          popover.permittedArrowDirections = []
                      }
                      topController.present(activityViewController, animated: true, completion: nil)
                      result(true)
                  }
              }
          }
        })
    }
      
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}