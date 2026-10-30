package com.parentcontrol.parent_control

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

/**
 * Hosts the single process-scoped FlutterEngine.
 *
 * The engine lives in [FlutterEngineCache] instead of being owned by this
 * Activity. Destroying the UI (Recents swipe, Activity finish, configuration
 * recreation) therefore no longer destroys the WebRTC peer connection or the
 * microphone tracks of an already authorized session: flutter_webrtc only
 * detaches from the Activity and keeps capture/peers while the engine lives.
 *
 * FlutterActivity does not execute the Dart entrypoint for cached engines
 * (`doInitialFlutterViewRun` returns early), so [ensureEngine] starts it here
 * exactly once. The engine is intentionally not destroyed with the host
 * (`destroy_engine_with_activity` is never set), and [NativeBridge] is
 * engine-scoped: it only swaps its Activity reference on attach/detach.
 */
class MainActivity : FlutterActivity() {
    companion object {
        const val ENGINE_ID = "parentcontrol_main_engine"
        const val AUTH_SCHEME = "parentcontrol"
        const val AUTH_HOST = "auth-callback"
    }

    override fun getCachedEngineId(): String = ENGINE_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        // The activity is exported for the browser redirect. A cold start from a
        // malformed parentcontrol:// link must open the app normally instead of
        // forwarding the link to Flutter/Supabase: drop the data before the
        // engine and plugins read the intent.
        val data = intent?.data
        if (data != null && data.scheme == AUTH_SCHEME && !isAuthCallback(intent)) {
            intent.data = null
            intent.action = Intent.ACTION_MAIN
        }
        ensureEngine()
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        // singleTop while the app is running: only a well-formed auth callback
        // reaches Flutter. Anything else is ignored (the UI stays unchanged).
        if (isAuthCallback(intent)) {
            super.onNewIntent(intent)
        }
    }

    /**
     * Accepts only `parentcontrol://auth-callback` links that carry a PKCE
     * `code` query parameter or an implicit-flow `access_token` (query or
     * fragment). Everything else is not an auth callback.
     */
    private fun isAuthCallback(intent: Intent?): Boolean {
        if (intent == null || intent.action != Intent.ACTION_VIEW) return false
        val data = intent.data ?: return false
        if (data.scheme != AUTH_SCHEME || data.host != AUTH_HOST) return false
        if (!data.getQueryParameter("code").isNullOrEmpty()) return true
        val token = data.getQueryParameter("access_token")
            ?: fragmentParameter(data.fragment, "access_token")
        return !token.isNullOrEmpty()
    }

    private fun fragmentParameter(fragment: String?, name: String): String? {
        if (fragment.isNullOrEmpty()) return null
        // Reuse Uri's query parser so percent-encoding matches query handling.
        return Uri.parse("$AUTH_SCHEME://$AUTH_HOST?$fragment").getQueryParameter(name)
    }

    private fun ensureEngine() {
        val cache = FlutterEngineCache.getInstance()
        if (cache.get(ENGINE_ID) != null) return
        val engine = try {
            FlutterEngine(applicationContext)
        } catch (_: Throwable) {
            // A failed engine leaves onCreate to the normal error path instead
            // of caching a broken instance.
            return
        }
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )
        cache.put(ENGINE_ID, engine)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        NativeBridge
            .attach(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
            .attachActivity(this)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        // The engine (and its bridge subscription) outlives this Activity.
        // Only the Activity reference used for permission prompts and
        // foreground-only intents is released.
        NativeBridge.peek()?.detachActivity(this)
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        NativeBridge.peek()?.onRequestPermissionsResult(
            requestCode,
            permissions,
            grantResults
        )
    }
}
