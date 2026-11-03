import Flutter
import UIKit
import VisionForgeX

/// Flutter's side of the VisionForgeX iOS SDK: calls in, ad events out. No decision is made here.
public class VisionForgeXPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var sink: FlutterEventSink?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = VisionForgeXPlugin()
        let methods = FlutterMethodChannel(name: "com.visionforgex.sdk/methods", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: methods)
        let events = FlutterEventChannel(name: "com.visionforgex.sdk/events", binaryMessenger: registrar.messenger())
        events.setStreamHandler(instance)
        registrar.register(BannerFactory(), withId: "com.visionforgex.sdk/banner")
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? { sink = events; return nil }
    public func onCancel(withArguments arguments: Any?) -> FlutterError? { sink = nil; return nil }

    private func emit(_ m: [String: Any]) { DispatchQueue.main.async { self.sink?(m) } }

    /// Values the Flutter codec can carry.
    private func plain(_ v: Any) -> Any {
        switch v {
        case is String, is Bool, is Int, is Int64, is Double: return v
        case let n as NSNumber: return n.doubleValue
        default: return "\(v)"
        }
    }

    private func fullScreen(_ args: [String: Any]) -> VfxFullScreen? {
        guard let name = args["placement"] as? String else { return nil }
        switch VfxFormat.fromWire((args["format"] as? String) ?? "") {
        case .interstitial: return VisionForgeX.interstitial(name)
        case .rewarded: return VisionForgeX.rewarded(name)
        case .rewardedInterstitial: return VisionForgeX.rewardedInterstitial(name)
        case .appOpen: return VisionForgeX.appOpen(name)
        default: return nil
        }
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = (call.arguments as? [String: Any]) ?? [:]
        switch call.method {
        case "initialize": initialize(args, result)
        case "isReady": result(VisionForgeX.isReady)
        case "fullScreenReady": result(fullScreen(args)?.isReady() == true)
        case "load": fullScreen(args)?.load(); result(nil)
        case "show": show(args, result)
        case "preloadAll": VisionForgeX.preloadAll(); result(nil)
        case "setKeyValue": VisionForgeX.setKeyValue((args["key"] as? String) ?? "", args["value"] as? String); result(nil)
        case "isPrivacyOptionsRequired": result(VisionForgeX.isPrivacyOptionsRequired)
        case "showPrivacyOptions":
            if let vc = topViewController() { VisionForgeX.showPrivacyOptions(from: vc) { err in result(err) } } else { result("no screen") }
        case "setMuted": VisionForgeX.setMuted((args["muted"] as? Bool) == true); result(nil)
        case "openAdInspector": if let vc = topViewController() { VisionForgeX.openAdInspector(from: vc) }; result(nil)
        case "settingsSource": result(VisionForgeX.settingsSource())
        case "flush": VisionForgeX.flush(); result(nil)
        default: result(FlutterMethodNotImplemented)
        }
    }

    private func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap { $0.windows }.first { $0.isKeyWindow }
        var vc = window?.rootViewController
        while let p = vc?.presentedViewController { vc = p }
        return vc
    }

    private func initialize(_ args: [String: Any], _ result: @escaping FlutterResult) {
        let key = (args["appKey"] as? String) ?? ""
        let o = (args["options"] as? [String: Any]) ?? [:]
        var opts = VfxOptions()
        if o["googleDemoAds"] as? Bool == true { opts = VfxOptions.googleDemoAds() }
        if let ids = o["testDeviceIds"] as? [String] { opts.testDeviceIds = ids }
        switch o["logLevel"] as? String {
        case "none": opts.logLevel = VfxLogLevel.none
        case "error": opts.logLevel = .error
        case "warn": opts.logLevel = .warn
        case "info": opts.logLevel = .info
        case "debug": opts.logLevel = .debug
        default: break
        }
        if o["consentDebugEea"] as? Bool == true { opts.consentDebugEea = true; opts.consentTestDeviceHashedIds = (o["consentTestDeviceHashedIds"] as? [String]) ?? [] }
        if let u = o["baseUrl"] as? String, !u.isEmpty { opts.baseUrl = u }
        opts.autoPreload = (o["autoPreload"] as? Bool) != false
        if let t = o["settingsForTesting"] as? String, !t.isEmpty { opts.settingsForTesting = t }

        VisionForgeX.initialize(appKey: key, options: opts) { st in
            result(["ready": st.ready, "reason": st.reason, "fromCache": st.fromCache])
        }
        VisionForgeX.eventListener = { [weak self] e in
            var d: [String: Any] = [:]
            for (k, v) in e.details { d[k] = self?.plain(v) ?? "\(v)" }
            self?.emit(["kind": "event", "type": e.type, "placement": e.placement, "format": e.format.wire, "time": e.time, "details": d])
        }
        VisionForgeX.revenueListener = { [weak self] r in
            self?.emit(["kind": "revenue", "placement": r.placement, "format": r.format.wire, "valueMicros": r.valueMicros, "currency": r.currency, "precision": r.precision, "source": r.source as Any])
        }
    }

    private func show(_ args: [String: Any], _ result: @escaping FlutterResult) {
        let id = (args["id"] as? Int) ?? 0
        guard let fs = fullScreen(args) else { result(["shown": false, "reason": "unknown_placement"]); return }
        var shown = false
        var done = false
        func finish(_ reason: String?) { if !done { done = true; result(["shown": shown, "reason": reason as Any]) } }
        fs.show(from: topViewController(), callbacks: VfxShowCallbacks(
            onShown: { shown = true; self.emit(["kind": "show", "id": id, "event": "shown"]) },
            onClicked: { self.emit(["kind": "show", "id": id, "event": "clicked"]) },
            onDismissed: { finish(nil) },
            onNotShown: { finish($0) },
            onReward: { type, amount in self.emit(["kind": "show", "id": id, "event": "reward", "type": type, "amount": amount]) }))
    }
}

/// The banner as a Flutter platform view: the SDK's own VfxBannerView, which loads and refreshes itself.
class BannerFactory: NSObject, FlutterPlatformViewFactory {
    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        let placement = ((args as? [String: Any])?["placement"] as? String) ?? ""
        return BannerPlatformView(placement: placement)
    }
}

class BannerPlatformView: NSObject, FlutterPlatformView {
    private let banner: VfxBannerView
    init(placement: String) { banner = VfxBannerView(placement: placement); super.init() }
    func view() -> UIView { banner }
}
