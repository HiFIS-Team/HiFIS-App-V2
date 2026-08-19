package app.hifis.hifis

import android.app.PendingIntent
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

/**
 * **앱을 보고 있을 때 배너를 띄우는 곳** (2026-08-19 대표 요청)
 *
 * FCM 은 `notification` 을 실은 메시지를 이렇게 다룬다.
 *
 * | 앱 상태 | 시스템이 배너를 띄우나 | `onMessageReceived` |
 * |---|---|---|
 * | 뒤에 있음·꺼져 있음 | **띄운다** | 안 불린다 |
 * | 앞에 떠 있음 | 안 띄운다 | **불린다** |
 *
 * 그래서 이 서비스가 없으면 **앱을 보고 있는 동안 온 알림은 어디에도 안 뜬다**
 * (앱 안 알림함에는 쌓인다). 여기서 앞에 떠 있을 때만 직접 그려 준다 —
 * 뒤에 있을 때는 이 함수가 안 불리므로 **두 번 뜨지 않는다.**
 *
 * iOS 는 같은 일을 `AppDelegate.willPresent` 가 한다.
 */
class PushService : FirebaseMessagingService() {

    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)

        val notification = message.notification
        val title = notification?.title ?: return
        val body = notification.body.orEmpty()

        // 누르면 알림함에서 누른 것과 **같은 곳**으로 간다 —
        // `MainActivity.deliver` 가 이 `link` 를 Dart 로 넘긴다
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            message.data["link"]?.let { putExtra("link", it) }
        }
        val pending = PendingIntent.getActivity(
            this,
            // 알림마다 다른 요청 코드 — 같으면 나중 것이 앞 것의 인텐트를 덮는다
            System.currentTimeMillis().toInt(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val built = NotificationCompat.Builder(
            this,
            getString(R.string.notification_channel_id),
        )
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            // 여러 줄짜리 본문(사내톡 메시지)이 잘리지 않게
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pending)
            .build()

        try {
            NotificationManagerCompat.from(this)
                .notify(System.currentTimeMillis().toInt(), built)
        } catch (_: SecurityException) {
            // 안드로이드 13+ 에서 알림 권한을 거절한 상태 — 조용히 넘어간다
            // (앱 안 알림함에는 그대로 쌓인다)
        }
    }
}
