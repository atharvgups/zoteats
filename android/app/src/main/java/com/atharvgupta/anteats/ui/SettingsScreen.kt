package com.atharvgupta.anteats.ui

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.MenuBook
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.outlined.ChatBubbleOutline
import androidx.compose.material.icons.outlined.DarkMode
import androidx.compose.material.icons.outlined.LightMode
import androidx.compose.material.icons.outlined.LocalCafe
import androidx.compose.material.icons.outlined.NorthEast
import androidx.compose.material.icons.outlined.Restaurant
import androidx.compose.material.icons.automirrored.outlined.ShowChart
import androidx.compose.material.icons.outlined.Tonality
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.atharvgupta.anteats.data.Appearance
import com.atharvgupta.anteats.data.PreferencesStore

private const val FEEDBACK_URL =
    "https://docs.google.com/forms/d/e/1FAIpQLSesZHPTDKKyD0lZ2EXUPtfCdAhWvdi6eT8RgchWjtDqWFXzMw/viewform"

@Composable
fun SettingsScreen(
    prefs: PreferencesStore,
    versionName: String,
    onClose: () -> Unit,
) {
    val colors = MaterialTheme.colorScheme
    val appearance by prefs.appearance.collectAsState()
    val notifications by prefs.notifications.collectAsState()
    val context = LocalContext.current
    var taps by remember { mutableIntStateOf(0) }
    var cheer by remember { mutableStateOf(false) }

    Column(
        Modifier
            .fillMaxWidth()
            .background(colors.background)
            .verticalScroll(rememberScrollState())
            .padding(top = 12.dp, bottom = 32.dp)
            .testTag("settings-screen"),
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.Top) {
            Column(Modifier.weight(1f)) {
                ScreenHeader(title = "Settings", subtitle = "Appearance, alerts, and sources")
            }
            IconButton(onClick = onClose) {
                Icon(Icons.Default.Close, contentDescription = "Close settings", tint = colors.onSurfaceVariant)
            }
        }
        Column(Modifier.padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Column(
                Modifier
                    .fillMaxWidth()
                    .zotCard()
                    .padding(14.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Text("APPEARANCE", fontSize = SectionSize, fontWeight = FontWeight.SemiBold, color = colors.onSurfaceVariant)
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    AppearanceTile("System", Icons.Outlined.Tonality, appearance == Appearance.System, Modifier.weight(1f)) {
                        prefs.setAppearance(Appearance.System)
                    }
                    AppearanceTile("Light", Icons.Outlined.LightMode, appearance == Appearance.Light, Modifier.weight(1f)) {
                        prefs.setAppearance(Appearance.Light)
                    }
                    AppearanceTile("Dark", Icons.Outlined.DarkMode, appearance == Appearance.Dark, Modifier.weight(1f)) {
                        prefs.setAppearance(Appearance.Dark)
                    }
                }
            }

            Row(
                Modifier
                    .fillMaxWidth()
                    .zotCard()
                    .clickable {
                        context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(FEEDBACK_URL)))
                    }
                    .padding(14.dp)
                    .testTag("settings-feedback-row"),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Icon(Icons.Outlined.ChatBubbleOutline, contentDescription = null, tint = colors.onBackground, modifier = Modifier.size(15.dp))
                Column(Modifier.weight(1f)) {
                    Text("Feedback", fontWeight = FontWeight.Medium, color = colors.onBackground)
                    Text("Share ideas or report a problem", fontSize = 14.sp, color = colors.onSurfaceVariant)
                }
                Icon(Icons.Outlined.NorthEast, contentDescription = null, tint = colors.onSurfaceVariant.copy(alpha = 0.5f), modifier = Modifier.size(14.dp))
            }

            Column(
                Modifier
                    .fillMaxWidth()
                    .zotCard()
                    .padding(14.dp),
            ) {
                Text("NOTIFICATIONS", fontSize = SectionSize, fontWeight = FontWeight.SemiBold, color = colors.onSurfaceVariant, modifier = Modifier.padding(bottom = 8.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text("Notifications", fontWeight = FontWeight.Medium, color = colors.onBackground)
                        Text("Pings for halls, campus, and study.", fontSize = 14.sp, color = colors.onSurfaceVariant)
                    }
                    Switch(
                        checked = notifications,
                        onCheckedChange = prefs::setNotifications,
                        colors = SwitchDefaults.colors(checkedTrackColor = accentGold()),
                    )
                }
                Text(
                    "Android alerts are saved here. Hall, campus, and library pings ship on iOS first.",
                    fontSize = 13.sp,
                    color = colors.onSurfaceVariant,
                    modifier = Modifier.padding(top = 8.dp),
                )
            }

            Column(
                Modifier
                    .fillMaxWidth()
                    .zotCard()
                    .padding(14.dp),
            ) {
                Text("SOURCES", fontSize = SectionSize, fontWeight = FontWeight.SemiBold, color = colors.onSurfaceVariant, modifier = Modifier.padding(bottom = 8.dp))
                SourceRow(Icons.Outlined.Restaurant, "Anteater API", "Live hall menus, plus nutrition when a dish posts it.", "https://anteaterapi.com")
                Hairline()
                SourceRow(Icons.Outlined.LocalCafe, "Dining Hub", "Retail hours. Live cafe board only when Hub publishes; typical packs stay labeled, never as today. Oasis is still Coming Soon.", "https://uci.campusdish.com")
                Hairline()
                SourceRow(Icons.AutoMirrored.Outlined.ShowChart, "Waitz", "Live occupancy for Langson and Science - not Student Center.", "https://waitz.io/irvine")
                Hairline()
                SourceRow(Icons.AutoMirrored.Outlined.MenuBook, "LibCal", "Official Langson and Science building hours.", "https://www.lib.uci.edu/hours")
            }

            Column(
                Modifier
                    .fillMaxWidth()
                    .zotCard()
                    .padding(14.dp),
            ) {
                Text("ABOUT", fontSize = SectionSize, fontWeight = FontWeight.SemiBold, color = colors.onSurfaceVariant, modifier = Modifier.padding(bottom = 8.dp))
                Text(
                    "Unofficial student project for UC Irvine. Not affiliated with the university.",
                    fontSize = 14.sp,
                    color = colors.onSurfaceVariant,
                    modifier = Modifier.padding(vertical = 8.dp),
                )
                Hairline()
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clickable {
                            taps += 1
                            if (taps >= 3) {
                                taps = 0
                                cheer = true
                            }
                        }
                        .padding(vertical = 6.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    Text("Version", fontWeight = FontWeight.Medium, color = colors.onBackground)
                    Text(versionName, fontWeight = FontWeight.Medium, color = colors.onSurfaceVariant)
                }
                if (cheer) {
                    Text(
                        "Zot! Zot! Zot!",
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 8.dp)
                            .clip(RoundedCornerShape(CardRadius))
                            .background(UciBlue)
                            .padding(horizontal = 28.dp, vertical = 20.dp),
                        fontWeight = FontWeight.Medium,
                        fontSize = 20.sp,
                        color = androidx.compose.ui.graphics.Color.White,
                    )
                }
            }
        }
    }
}

@Composable
private fun AppearanceTile(label: String, icon: ImageVector, selected: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val colors = MaterialTheme.colorScheme
    Column(
        modifier
            .clip(RoundedCornerShape(InnerRadius))
            .background(if (selected) colors.onBackground.copy(alpha = 0.06f) else androidx.compose.ui.graphics.Color.Transparent)
            .border(1.dp, if (selected) colors.onBackground.copy(alpha = 0.28f) else colors.outline, RoundedCornerShape(InnerRadius))
            .clickable(onClick = onClick)
            .padding(vertical = 14.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(7.dp),
    ) {
        Icon(icon, contentDescription = null, tint = if (selected) colors.onBackground else colors.onSurfaceVariant)
        Text(label, fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Medium, color = if (selected) colors.onBackground else colors.onBackground)
    }
}

@Composable
private fun SourceRow(icon: ImageVector, title: String, subtitle: String, url: String) {
    val colors = MaterialTheme.colorScheme
    val context = LocalContext.current
    Row(
        Modifier
            .fillMaxWidth()
            .clickable { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url))) }
            .padding(vertical = 6.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Icon(icon, contentDescription = null, tint = colors.onBackground, modifier = Modifier.size(15.dp).padding(top = 2.dp))
        Column(Modifier.weight(1f)) {
            Text(title, fontWeight = FontWeight.Medium, color = colors.onBackground)
            Text(subtitle, fontSize = 14.sp, color = colors.onSurfaceVariant)
        }
        Icon(Icons.Outlined.NorthEast, contentDescription = null, tint = colors.onSurfaceVariant.copy(alpha = 0.5f), modifier = Modifier.size(14.dp).padding(top = 4.dp))
    }
}

@Composable
private fun Hairline() {
    Spacer(
        Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp)
            .height(1.dp)
            .background(MaterialTheme.colorScheme.outline),
    )
}
