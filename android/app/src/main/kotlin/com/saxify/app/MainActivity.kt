package com.saxify.app

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        SaxifyBoot.noteLaunch(this)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val bridge = SaxifyBridge(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.saxify.app/bridge")
            .setMethodCallHandler { call, result -> bridge.handle(call, result) }
    }
}
