package com.atharvgupta.anteats.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.MenuBook
import androidx.compose.material.icons.outlined.LocalCafe
import androidx.compose.material.icons.outlined.Restaurant
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.atharvgupta.anteats.data.Appearance
import com.atharvgupta.anteats.data.PlateStore
import com.atharvgupta.anteats.data.PreferencesStore

enum class AppTab(val label: String, val icon: ImageVector) {
    Eat("Eat", Icons.Outlined.Restaurant),
    Campus("Campus", Icons.Outlined.LocalCafe),
    Study("Study", Icons.AutoMirrored.Outlined.MenuBook),
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RootApp(
    prefs: PreferencesStore,
    plate: PlateStore,
    screenshotMode: String? = null,
    initialTab: AppTab = AppTab.Eat,
    versionName: String,
    forceDark: Boolean? = null,
) {
    val appearance by prefs.appearance.collectAsState()
    val dark = when {
        forceDark != null -> forceDark
        appearance == Appearance.Dark -> true
        appearance == Appearance.Light -> false
        else -> androidx.compose.foundation.isSystemInDarkTheme()
    }
    AnteatsTheme(darkTheme = dark) {
        var tab by remember { mutableStateOf(initialTab) }
        var showSettings by remember { mutableStateOf(screenshotMode == "settings") }
        val eatVm: EatViewModel = viewModel(factory = EatViewModelFactory(plate, prefs))

        LaunchedEffect(screenshotMode) {
            when (screenshotMode) {
                "campus" -> tab = AppTab.Campus
                "study" -> tab = AppTab.Study
                "settings" -> showSettings = true
            }
        }

        val colors = MaterialTheme.colorScheme
        Column(
            Modifier
                .fillMaxSize()
                .background(colors.background)
                .statusBarsPadding()
                .testTag("root-app"),
        ) {
            Column(Modifier.weight(1f).fillMaxWidth()) {
                when (tab) {
                    AppTab.Eat -> EatScreen(
                        screenshotMode = screenshotMode,
                        onSettings = { showSettings = true },
                        viewModel = eatVm,
                    )
                    AppTab.Campus -> CampusScreen(
                        onSettings = { showSettings = true },
                        prefs = prefs,
                    )
                    AppTab.Study -> StudyScreen(onSettings = { showSettings = true })
                }
            }
            NavigationBar(
                modifier = Modifier
                    .navigationBarsPadding()
                    .testTag("tab-bar"),
                containerColor = colors.background,
                contentColor = colors.onBackground,
            ) {
                AppTab.entries.forEach { item ->
                    val selected = tab == item
                    NavigationBarItem(
                        selected = selected,
                        onClick = { tab = item },
                        icon = { Icon(item.icon, contentDescription = item.label) },
                        label = {
                            Text(item.label, fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Medium, fontSize = 12.sp)
                        },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = colors.onBackground,
                            selectedTextColor = colors.onBackground,
                            unselectedIconColor = colors.onSurfaceVariant,
                            unselectedTextColor = colors.onSurfaceVariant,
                            indicatorColor = colors.onBackground.copy(alpha = 0.06f),
                        ),
                    )
                }
            }
        }

        if (showSettings) {
            ModalBottomSheet(
                onDismissRequest = { showSettings = false },
                sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
                containerColor = colors.background,
            ) {
                SettingsScreen(
                    prefs = prefs,
                    versionName = versionName,
                    onClose = { showSettings = false },
                )
            }
        }
    }
}
