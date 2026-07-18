package com.williamtheisen.kolkhoz

import com.google.android.gms.games.PlayGames
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.williamtheisen.kolkhoz/identity",
        ).setMethodCallHandler { call, result ->
            if (call.method != "authenticatePlayGames") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val serverClientId = BuildConfig.PLAY_GAMES_SERVER_CLIENT_ID
            if (serverClientId.isBlank()) {
                result.error("not_configured", "Play Games server client ID is missing.", null)
                return@setMethodCallHandler
            }
            val signIn = PlayGames.getGamesSignInClient(this)
            signIn.isAuthenticated.addOnCompleteListener { authTask ->
                if (!authTask.isSuccessful || authTask.result?.isAuthenticated != true) {
                    result.success(null)
                    return@addOnCompleteListener
                }
                signIn.requestServerSideAccess(serverClientId, false)
                    .addOnCompleteListener { codeTask ->
                        if (codeTask.isSuccessful) {
                            result.success(mapOf("serverAuthCode" to codeTask.result.authCode))
                        } else {
                            result.error("play_games", "Play Games authentication failed.", null)
                        }
                    }
            }
        }
    }
}
