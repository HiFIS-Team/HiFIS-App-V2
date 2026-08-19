package app.hifis.hifis

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.firebase.messaging.FirebaseMessaging
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pushChannel: MethodChannel? = null

    /** Dart 가 받을 준비를 마쳤나 — 그 전에 눌린 알림은 담아 뒀다 흘려보낸다 */
    private var dartReady = false
    private var pendingLink: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        wireCapture(flutterEngine)
        wirePush(flutterEngine)
    }

    /**
     * 화면 캡처 방지 — MASTER 밑으로는 못 찍게 막는다.
     *
     * `FLAG_SECURE` 하나로 **셋이 한꺼번에** 막힌다 — 스크린샷("앱에서 스크린샷을
     * 저장할 수 없습니다"), 화면 녹화(검은 화면으로 녹화된다), 최근 앱 목록의
     * 미리보기. 안드로이드는 진짜로 막히므로 iOS 처럼 사후 신고를 할 일이 없다.
     */
    private fun wireCapture(flutterEngine: FlutterEngine) {
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

    /**
     * 푸시 알림 — **iOS(AppDelegate)와 같은 채널 규약**을 쓴다.
     *
     * ```
     * Dart → 네이티브   ready · register
     * 네이티브 → Dart   onToken {token, platform, sandbox} · onTap <link>
     * ```
     *
     * 규약이 같아서 `push.dart` 가 플랫폼을 안 가린다. 애플만 APNs 로 직접 치고
     * 안드로이드는 FCM 을 거치는데, **그 차이는 서버가 안다** (기기 토큰에
     * `platform` 이 붙어 있다).
     */
    private fun wirePush(flutterEngine: FlutterEngine) {
        val channel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.hifis/push")
        pushChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "ready" -> {
                    dartReady = true
                    flushPendingLink()
                    result.success(null)
                }
                "register" -> requestPush(result)
                else -> result.notImplemented()
            }
        }
    }

    /**
     * 알림 권한을 묻고 FCM 토큰을 받아 Dart 로 넘긴다.
     *
     * **거절해도 토큰은 넘긴다** — 나중에 설정에서 켜면 바로 오게 하려는 것이다
     * (iOS 도 같다). 안드로이드 13(API 33)부터 권한을 물어야 하고, 그 아래는
     * 설치할 때 이미 허용된 것으로 친다.
     */
    private fun requestPush(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            // 답을 기다리지 않는다 — 창은 떠 있고 토큰 등록은 그대로 진행한다.
            // 기다렸다가 넘기면 사용자가 창을 안 누르는 동안 로그인이 멈춘다.
            ActivityCompat.requestPermissions(
                this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), PUSH_PERMISSION_CODE,
            )
        }
        FirebaseMessaging.getInstance().token
            .addOnCompleteListener { task ->
                if (!task.isSuccessful) {
                    // 구글 플레이 서비스가 없는 기기 등 — 앱은 그대로 돌아간다
                    // (앱 안 알림함은 살아 있다). iOS 의 didFailToRegister 와 같은 자리다.
                    result.success(false)
                    return@addOnCompleteListener
                }
                pushChannel?.invokeMethod(
                    "onToken",
                    // sandbox 는 애플 전용 구분이라 안드로이드는 늘 false 다
                    mapOf("token" to task.result, "platform" to "ANDROID", "sandbox" to false),
                )
                result.success(true)
            }
    }

    // ── 알림을 눌렀다 ─────────────────────────────────────────────────────
    //
    // FCM 이 `notification` 을 실어 보내면 **안드로이드가 알아서 배너를 띄우고**,
    // 누르면 이 액티비티가 뜨면서 `data` 가 인텐트에 담겨 온다.
    //
    // **앱이 앞에 떠 있을 때만 예외다** — 그때는 시스템이 안 띄우고
    // `PushService.onMessageReceived` 만 불려서, 거기서 직접 그린다
    // (2026-08-19). 누르면 결국 이 액티비티로 와서 아래 `deliver` 를 탄다.

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ensureChannel()
        deliver(intent) // 앱이 꺼져 있을 때 눌린 것
    }

    /**
     * 알림 채널을 만들어 둔다 — 안드로이드 8부터 채널이 없으면 알림이 안 뜬다.
     *
     * 매니페스트의 `default_notification_channel_id` 만 두면 시스템이 그 id 로
     * **이름 없는 채널**을 만들어서, 설정에서 알림을 끄고 켤 때 무슨 알림인지
     * 알 수 없다. 여기서 미리 만들어 이름을 준다.
     *
     * 채널은 **하나만 둔다.** 근태·프로젝트·사내톡을 따로 끄고 싶다는 이야기가
     * 나오면 그때 나눈다 — 미리 나누면 설정 화면만 복잡해진다.
     */
    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        manager.createNotificationChannel(
            NotificationChannel(
                getString(R.string.notification_channel_id),
                getString(R.string.notification_channel_name),
                NotificationManager.IMPORTANCE_HIGH,
            ),
        )
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        deliver(intent) // 앱이 떠 있는 채로 눌린 것
    }

    private fun deliver(intent: Intent?) {
        val link = intent?.extras?.getString("link")
        if (link.isNullOrEmpty()) return
        if (!dartReady) {
            pendingLink = link
            return
        }
        pushChannel?.invokeMethod("onTap", link)
    }

    private fun flushPendingLink() {
        val link = pendingLink ?: return
        pendingLink = null
        pushChannel?.invokeMethod("onTap", link)
    }

    companion object {
        private const val PUSH_PERMISSION_CODE = 1001
    }
}
