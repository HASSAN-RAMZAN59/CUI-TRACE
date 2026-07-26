package com.example.cui_trace

import io.flutter.embedding.android.FlutterActivity
import androidx.core.view.WindowCompat

class MainActivity: FlutterActivity() {
    override fun onResume() {
        super.onResume()
        // Handle edge-to-edge display
        WindowCompat.setDecorFitsSystemWindows(window, false)
    }
}
