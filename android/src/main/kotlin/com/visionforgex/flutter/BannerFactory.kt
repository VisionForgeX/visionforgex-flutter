package com.visionforgex.flutter

import android.content.Context
import android.view.View
import com.visionforgex.ads.VfxBannerView
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/** The banner as a Flutter platform view: the SDK's own VfxBannerView, which loads and refreshes itself. */
class BannerFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val placement = ((args as? Map<*, *>)?.get("placement") as? String) ?: ""
        val view = VfxBannerView(context, placement)
        return object : PlatformView {
            override fun getView(): View = view
            override fun dispose() {}
        }
    }
}
