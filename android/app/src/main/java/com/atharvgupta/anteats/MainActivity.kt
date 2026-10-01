package com.atharvgupta.anteats

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import com.atharvgupta.anteats.ui.AnteatsTheme
import com.atharvgupta.anteats.ui.EatScreen

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val screenshot = intent.getStringExtra(EXTRA_SCREENSHOT)
        val forceDark = intent.getBooleanExtra(EXTRA_DARK, false)
        setContent {
            AnteatsTheme(darkTheme = if (intent.hasExtra(EXTRA_DARK)) forceDark else androidx.compose.foundation.isSystemInDarkTheme()) {
                Surface(modifier = Modifier.fillMaxSize()) {
                    EatScreen(screenshotMode = screenshot)
                }
            }
        }
    }

    companion object {
        const val EXTRA_SCREENSHOT = "screenshot"
        const val EXTRA_DARK = "dark"
    }
}
