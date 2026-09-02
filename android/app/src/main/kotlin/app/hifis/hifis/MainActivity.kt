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
import androidx.core.content.FileProvider
import java.io.File
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
        wireReels(flutterEngine)
    }

    /**
     * 추첨 영상을 인스타그램으로 넘긴다.
     *
     * 길이 둘인데 **어느 쪽이든 캡션은 사람이 인스타 안에서 쓴다.** 우리가
     * 대신 올리는 게 아니라서 심사가 없다.
     *
     * | | 언제 | 어디로 |
     * |---|---|---|
     * | **공유 시트** | 늘 된다 (기본) | 인스타를 고르면 인스타가 릴스·스토리를 묻는다 |
     * | 릴스 직행 | 메타 앱 ID 가 있을 때 | 릴스 작성 화면이 영상을 물고 열린다 |
     *
     * 공유 시트는 **앱 ID 가 필요 없다** — 그냥 파일을 넘기는 것이라 인스타와
     * 아무 약속이 없다. 직행은 인스타가 우리를 알아야 해서 ID 를 본다.
     *
     * `file://` 을 인텐트에 실으면 안드로이드 7 부터 터진다
     * (`FileUriExposedException`) — 둘 다 FileProvider 로 `content://` 를 준다.
     */
    private fun wireReels(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.hifis/reels")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // 공유 시트는 늘 있다 — 인스타가 안 깔려 있어도 시트는 뜬다
                    "available" -> result(true)
                    "share" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrEmpty()) {
                            result(false)
                        } else {
                            result(shareVideo(path, call.argument<String>("appId") ?: ""))
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun shareVideo(path: String, appId: String): Boolean {
        return try {
            val uri = FileProvider.getUriForFile(this, "$packageName.reels", File(path))

            // ① 앱 ID 가 있으면 릴스 작성 화면으로 바로 — 시트를 한 번 덜 거친다
            if (appId.isNotEmpty()) {
                val direct = Intent("com.instagram.share.ADD_TO_REEL").apply {
                    setPackage("com.instagram.android")
                    type = "video/*"
                    putExtra("com.instagram.platform.extra.APPLICATION_ID", appId)
                    putExtra(Intent.EXTRA_STREAM, uri)
                    flags = Intent.FLAG_GRANT_READ_URI_PERMISSION
                }
                if (packageManager.resolveActivity(direct, 0) != null) {
                    // `FLAG_GRANT_READ_URI_PERMISSION` 만으로는 못 읽는 기기가 있다 —
                    // 메타 문서가 이걸 같이 부르라고 한다
                    grantUriPermission(
                        "com.instagram.android", uri, Intent.FLAG_GRANT_READ_URI_PERMISSION
                    )
                    startActivity(direct)
                    return true
                }
            }

            // ② 없으면 공유 시트 — 여기서 인스타를 고르면 릴스로 갈 수 있다
            val send = Intent(Intent.ACTION_SEND).apply {
                type = "video/mp4"
                putExtra(Intent.EXTRA_STREAM, uri)
                flags = Intent.FLAG_GRANT_READ_URI_PERMISSION
            }
            startActivity(Intent.createChooser(send, "추첨 영상 공유"))
            // **연 것까지만 참이다.** 올렸는지는 우리가 알 수 없다
            true
        } catch (e: Exception) {
            false
        }
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
