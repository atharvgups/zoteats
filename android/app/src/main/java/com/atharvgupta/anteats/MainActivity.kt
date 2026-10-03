package com.atharvgupta.anteats

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.atharvgupta.anteats.ui.AppTab
import com.atharvgupta.anteats.ui.RootApp

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val app = application as AnteatsApp
        val screenshot = intent.getStringExtra(EXTRA_SCREENSHOT)
        val tabExtra = intent.getStringExtra(EXTRA_TAB)
        val forceDark = if (intent.hasExtra(EXTRA_DARK)) intent.getBooleanExtra(EXTRA_DARK, false) else null
        val initialTab = when (tabExtra?.lowercase() ?: screenshot?.lowercase()) {
            "campus" -> AppTab.Campus
            "study" -> AppTab.Study
            else -> AppTab.Eat
        }
        val version = runCatching {
            packageManager.getPackageInfo(packageName, 0).versionName
        }.getOrNull() ?: "1.0.337"
        setContent {
            RootApp(
                prefs = app.preferences,
                plate = app.plate,
                screenshotMode = screenshot,
                initialTab = initialTab,
                versionName = version ?: "1.0.337",
                forceDark = forceDark,
            )
        }
    }

    companion object {
        const val EXTRA_SCREENSHOT = "screenshot"
        const val EXTRA_DARK = "dark"
        const val EXTRA_TAB = "tab"
    }
}
