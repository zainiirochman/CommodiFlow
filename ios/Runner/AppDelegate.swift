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
                  
                  let url = URL(fileURLWithPath: path)
                  let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                  
                  if let popoverController = activityViewController.popoverPresentationController {
                      popoverController.sourceView = controller.view
                      popoverController.sourceRect = CGRect(x: controller.view.bounds.midX, y: controller.view.bounds.midY, width: 0, height: 0)
                      popoverController.permittedArrowDirections = []
                  }
                  
                  controller.present(activityViewController, animated: true, completion: nil)
                  result(true)
              } else {
                  result(FlutterError(code: "INVALID_ARGUMENT", message: "Path is missing", details: nil))
              }
          } else {
              result(FlutterMethodNotImplemented)
          }
        })
    }
      
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}