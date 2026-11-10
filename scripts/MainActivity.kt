package dz.eps.assistant.eps_assistant

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "eps/brightness")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "max" -> { setBrightness(1.0f); result.success(null) }
                    "reset" -> {
                        setBrightness(WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun setBrightness(value: Float) {
        val lp = window.attributes
        lp.screenBrightness = value
        window.attributes = lp
    }
}
