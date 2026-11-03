package com.visionforgex.flutter

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import com.visionforgex.ads.VfxEvent
import com.visionforgex.ads.VfxFormat
import com.visionforgex.ads.VfxFullScreen
import com.visionforgex.ads.VfxInitListener
import com.visionforgex.ads.VfxLogLevel
import com.visionforgex.ads.VfxOptions
import com.visionforgex.ads.VfxShowListener
import com.visionforgex.ads.VisionForgeX
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Flutter's side of the VisionForgeX Android SDK: calls in, ad events out. No decision is made here. */
class VisionForgeXPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private var methods: MethodChannel? = null
    private var events: EventChannel? = null
    private var sink: EventChannel.EventSink? = null
    private var appContext: Context? = null
    private var activity: Activity? = null
    private val main = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        methods = MethodChannel(binding.binaryMessenger, "com.visionforgex.sdk/methods").also { it.setMethodCallHandler(this) }
        events = EventChannel(binding.binaryMessenger, "com.visionforgex.sdk/events").also { it.setStreamHandler(this) }
        binding.platformViewRegistry.registerViewFactory("com.visionforgex.sdk/banner", BannerFactory())
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methods?.setMethodCallHandler(null); events?.setStreamHandler(null)
        methods = null; events = null; sink = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivityForConfigChanges() { activity = null }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivity() { activity = null }

    override fun onListen(arguments: Any?, es: EventChannel.EventSink?) { sink = es }
    override fun onCancel(arguments: Any?) { sink = null }

    private fun emit(m: Map<String, Any?>) { main.post { sink?.success(m) } }

    /** Values the Flutter codec can carry. */
    private fun plain(v: Any?): Any? = when (v) { null, is String, is Boolean, is Int, is Long, is Double -> v; is Number -> v.toDouble(); else -> v.toString() }

    private fun fullScreen(call: MethodCall): VfxFullScreen? {
        val name = call.argument<String>("placement") ?: return null
        return when (VfxFormat.fromWire(call.argument<String>("format") ?: "")) {
            VfxFormat.INTERSTITIAL -> VisionForgeX.interstitial(name)
            VfxFormat.REWARDED -> VisionForgeX.rewarded(name)
            VfxFormat.REWARDED_INTERSTITIAL -> VisionForgeX.rewardedInterstitial(name)
            VfxFormat.APP_OPEN -> VisionForgeX.appOpen(name)
            else -> null
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> initialize(call, result)
            "isReady" -> result.success(VisionForgeX.isReady())
            "fullScreenReady" -> result.success(fullScreen(call)?.isReady() == true)
            "load" -> { fullScreen(call)?.load(); result.success(null) }
            "show" -> show(call, result)
            "preloadAll" -> { VisionForgeX.preloadAll(); result.success(null) }
            "setKeyValue" -> { VisionForgeX.setKeyValue(call.argument<String>("key") ?: "", call.argument<String>("value")); result.success(null) }
            "isPrivacyOptionsRequired" -> result.success(VisionForgeX.isPrivacyOptionsRequired())
            "showPrivacyOptions" -> {
                val a = activity
                if (a == null) result.success("no activity") else VisionForgeX.showPrivacyOptions(a) { err -> result.success(err) }
            }
            "setMuted" -> { VisionForgeX.setMuted(call.argument<Boolean>("muted") == true); result.success(null) }
            "openAdInspector" -> { (activity ?: appContext)?.let { VisionForgeX.openAdInspector(it) }; result.success(null) }
            "settingsSource" -> result.success(VisionForgeX.settingsSource())
            "flush" -> { VisionForgeX.flush(); result.success(null) }
            else -> result.notImplemented()
        }
    }

    private fun initialize(call: MethodCall, result: MethodChannel.Result) {
        val key = call.argument<String>("appKey") ?: ""
        val o = call.argument<Map<String, Any?>>("options") ?: emptyMap()
        val b = VfxOptions.Builder()
        (o["testDeviceIds"] as? List<*>)?.mapNotNull { it as? String }?.let { b.testDeviceIds(it) }
        when (o["logLevel"] as? String) {
            "none" -> b.logLevel(VfxLogLevel.NONE); "error" -> b.logLevel(VfxLogLevel.ERROR); "warn" -> b.logLevel(VfxLogLevel.WARN)
            "info" -> b.logLevel(VfxLogLevel.INFO); "debug" -> b.logLevel(VfxLogLevel.DEBUG)
        }
        if (o["consentDebugEea"] == true) b.consentDebugEea(true, (o["consentTestDeviceHashedIds"] as? List<*>)?.mapNotNull { it as? String } ?: emptyList())
        (o["baseUrl"] as? String)?.takeIf { it.isNotBlank() }?.let { b.baseUrl(it) }
        b.autoPreload(o["autoPreload"] != false)
        if (o["googleDemoAds"] == true) b.googleDemoAds()
        (o["settingsForTesting"] as? String)?.takeIf { it.isNotBlank() }?.let { b.settingsForTesting(it) }

        VisionForgeX.setEventListener { e: VfxEvent ->
            emit(mapOf("kind" to "event", "type" to e.type, "placement" to e.placement, "format" to e.format.wire, "time" to e.time,
                "details" to e.details.mapValues { plain(it.value) }))
        }
        VisionForgeX.setRevenueListener { placement, format, micros, currency, precision, source ->
            emit(mapOf("kind" to "revenue", "placement" to placement, "format" to format.wire, "valueMicros" to micros, "currency" to currency, "precision" to precision, "source" to source))
        }
        var answered = false
        val ctx: Context = activity ?: appContext ?: run { result.error("no_context", "The plugin is not attached to an app yet.", null); return }
        VisionForgeX.initialize(ctx, key, b.build(), VfxInitListener { st ->
            main.post {
                if (!answered) { answered = true; result.success(mapOf("ready" to st.ready, "reason" to st.reason, "fromCache" to st.fromCache)) }
            }
        })
    }

    private fun show(call: MethodCall, result: MethodChannel.Result) {
        val fs = fullScreen(call)
        val id = call.argument<Int>("id") ?: 0
        val a = activity
        if (fs == null) { result.success(mapOf("shown" to false, "reason" to "unknown_placement")); return }
        if (a == null) { result.success(mapOf("shown" to false, "reason" to "no_activity")); return }
        var shown = false
        var done = false
        fun finish(reason: String?) { if (!done) { done = true; result.success(mapOf("shown" to shown, "reason" to reason)) } }
        fs.show(a, object : VfxShowListener {
            override fun onShown() { shown = true; emit(mapOf("kind" to "show", "id" to id, "event" to "shown")) }
            override fun onClicked() { emit(mapOf("kind" to "show", "id" to id, "event" to "clicked")) }
            override fun onDismissed() { finish(null) }
            override fun onNotShown(reason: String) { finish(reason) }
            override fun onReward(type: String, amount: Int) { emit(mapOf("kind" to "show", "id" to id, "event" to "reward", "type" to type, "amount" to amount)) }
        })
    }
}
