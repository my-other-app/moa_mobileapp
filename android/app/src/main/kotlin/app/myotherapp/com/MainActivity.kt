package app.myotherapp.com

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    // The icon's shortcuts (Scan, My QR, Network, My tickets): published at each launch.
    AppShortcuts.publish(this)
    if (savedInstanceState == null) AppShortcuts.reportUsed(this, intent)
  }

  override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    AppShortcuts.reportUsed(this, intent)
  }
}
