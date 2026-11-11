package com.dror.metra // Old name, kept on purpose: see ui-spec.md › Name.

import android.content.Intent
import android.content.res.Resources
import android.media.AudioManager
import android.net.Uri
import android.view.accessibility.AccessibilityManager
import androidx.core.content.FileProvider
import java.io.File
import android.os.Build
import android.os.Bundle
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Shares one Flutter engine with audio_service's background service; a plain
// FlutterActivity makes audio_service start a second engine, which runs
// main() again and re-initializes SoLoud under the first one.
class MainActivity : AudioServiceActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Before the engine: Dart picks it up with "takePendingStart".
        if (intent?.action == TileBridge.ACTION_START) TileBridge.pendingStart = true
        super.onCreate(savedInstanceState)
        // Volume keys change media volume in the app even while stopped,
        // never the ringer.
        volumeControlStream = AudioManager.STREAM_MUSIC
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        TileBridge.attach(this, flutterEngine)
        ShareBridge.attach(flutterEngine)
        MicBridge.attach(this, flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "metra/android")
        this.channel = channel
        CallMonitor.attach(this, channel)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "setLaunchTheme" -> {
                    setLaunchTheme(call.arguments as String)
                    result.success(null)
                }
                // Android's "Time to take action": how long the Undo bar
                // stays (never shorter than asked).
                "recommendedTimeout" -> {
                    val base = (call.arguments as Number).toInt()
                    result.success(
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            getSystemService(AccessibilityManager::class.java)
                                .getRecommendedTimeoutMillis(
                                    base,
                                    AccessibilityManager.FLAG_CONTENT_TEXT or
                                        AccessibilityManager.FLAG_CONTENT_CONTROLS,
                                )
                        } else {
                            base
                        },
                    )
                }
                // The phone's share menu with plain text (a setlist).
                "shareText" -> {
                    val send = Intent(Intent.ACTION_SEND)
                        .setType("text/plain")
                        .putExtra(Intent.EXTRA_TEXT, call.arguments as String)
                    startActivity(Intent.createChooser(send, null))
                    result.success(null)
                }
                // A click track export: Android's own "Save to" screen, then
                // the file is copied there. True when saved, false when the
                // user backed out.
                "saveFile" -> {
                    val args = call.arguments as Map<*, *>
                    pendingSave?.success(false)
                    pendingSave = result
                    pendingSavePath = args["path"] as String
                    val create = Intent(Intent.ACTION_CREATE_DOCUMENT)
                        .addCategory(Intent.CATEGORY_OPENABLE)
                        .setType(args["mime"] as String)
                        .putExtra(Intent.EXTRA_TITLE, args["name"] as String)
                    startActivityForResult(create, SAVE_REQUEST)
                }
                // A click track export to the phone's share menu.
                "shareFile" -> {
                    val args = call.arguments as Map<*, *>
                    val uri = FileProvider.getUriForFile(
                        this,
                        "$packageName.exports",
                        File(args["path"] as String),
                    )
                    val send = Intent(Intent.ACTION_SEND)
                        .setType(args["mime"] as String)
                        .putExtra(Intent.EXTRA_STREAM, uri)
                        .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    send.clipData = android.content.ClipData.newRawUri(null, uri)
                    startActivity(Intent.createChooser(send, null))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private var channel: MethodChannel? = null
    private var pendingSave: MethodChannel.Result? = null
    private var pendingSavePath: String? = null

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != SAVE_REQUEST) return
        val result = pendingSave ?: return
        val path = pendingSavePath
        pendingSave = null
        val uri: Uri? = data?.data
        if (resultCode != RESULT_OK || uri == null || path == null) {
            result.success(false)
            return
        }
        // Off the main thread: a big WAV takes a moment.
        Thread {
            try {
                contentResolver.openOutputStream(uri, "wt").use { out ->
                    File(path).inputStream().use { it.copyTo(out!!) }
                }
                runOnUiThread { result.success(true) }
            } catch (e: Exception) {
                // Don't leave a broken file in the folder they picked.
                try {
                    android.provider.DocumentsContract.deleteDocument(contentResolver, uri)
                } catch (_: Exception) {
                }
                runOnUiThread { result.error("save", e.toString(), null) }
            }
        }.start()
    }

    private companion object {
        const val SAVE_REQUEST = 4711
    }

    // Every return to the front asks Flutter for a frame. A screen rebuilt
    // over the running engine (a system display setting changed while the
    // app was alive) waits to draw until Flutter shows a frame, and with
    // nothing asking for one it waited forever.
    override fun onPostResume() {
        super.onPostResume()
        channel?.invokeMethod("redraw", null)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == MicBridge.REQUEST) MicBridge.onPermissionResult()
    }

    // The microphone never outlives the app's screen.
    override fun onDestroy() {
        MicBridge.stop()
        super.onDestroy()
    }

    // Already running (warm): the tile asked to start.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.action == TileBridge.ACTION_START) {
            TileBridge.channel?.invokeMethod("start", null)
        }
    }

    /// The splash theme for the next launches (Android 13+), so a Dark or
    /// Daylight choice in the app opens without a flash of the other.
    private fun setLaunchTheme(mode: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        splashScreen.setSplashScreenTheme(
            when (mode) {
                "dark" -> R.style.LaunchTheme_Dark
                "light" -> R.style.LaunchTheme_Light
                else -> Resources.ID_NULL
            },
        )
    }
}
