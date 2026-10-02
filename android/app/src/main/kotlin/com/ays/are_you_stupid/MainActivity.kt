package com.ays.are_you_stupid

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Multiplayer permissions UX — docs/Architecture/Multiplayer Client
        // (Mobile).md, "Permissions". NSD needs no runtime permission on
        // Android, so local network is always "granted"; the channel exists
        // for the shared "open this app's Settings" shortcut (camera).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ays/permissions")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "localNetworkStatus" -> result.success("granted")
                    "openAppSettings" -> {
                        try {
                            startActivity(
                                Intent(
                                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                    Uri.fromParts("package", packageName, null),
                                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                            )
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
