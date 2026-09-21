package com.example.demo_accelerometer

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    companion object {
        // Tham chiếu tĩnh để R8 / Proguard không bao giờ xóa file raw trong bản Release
        val keepRawSounds = intArrayOf(
            R.raw.motion_detected,
            R.raw.motion_stopped
        )
    }
}
