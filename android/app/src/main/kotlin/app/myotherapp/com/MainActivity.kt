package app.myotherapp.com

import android.content.Intent
import android.os.Bundle
import app.myotherapp.com.eventday.EventDayNotifications
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    // The icon's shortcuts (Scan, My QR, Network, My tickets): published at each launch.
    AppShortcuts.publish(this)
    if (savedInstanceState == null) AppShortcuts.reportUsed(this, intent)
  }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    // The event-day card on the lock screen (an ongoing notification), from Dart.
    EventDayNotifications.register(flutterEngine.dartExecutor.binaryMessenger, this)
  }

  override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    AppShortcuts.reportUsed(this, intent)
  }
}
