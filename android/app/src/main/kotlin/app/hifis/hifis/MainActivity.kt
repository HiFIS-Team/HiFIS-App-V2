package app.hifis.hifis

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    /**
     * 화면 캡처 방지 — MASTER 밑으로는 못 찍게 막는다.
     *
     * `FLAG_SECURE` 하나로 **셋이 한꺼번에** 막힌다 — 스크린샷("앱에서 스크린샷을
     * 저장할 수 없습니다"), 화면 녹화(검은 화면으로 녹화된다), 최근 앱 목록의
     * 미리보기. 안드로이드는 진짜로 막히므로 iOS 처럼 사후 신고를 할 일이 없다.
     */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.hifis/capture")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSecure" -> {
                        val on = call.arguments as? Boolean ?: true
                        runOnUiThread {
                            if (on) {
                                window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            } else {
                                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            }
                        }
                        // true = 이 플랫폼은 실제로 막아 준다 (iOS 만 false)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
