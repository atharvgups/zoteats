package com.atharvgupta.anteats.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.outlined.Star
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun ScreenHeader(
    title: String,
    subtitle: String?,
    onSettings: (() -> Unit)? = null,
) {
    val colors = MaterialTheme.colorScheme
    Row(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp)
            .padding(bottom = 8.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(title, fontSize = HeroSize, fontWeight = FontWeight.Bold, color = colors.onBackground)
            if (subtitle != null) {
                Text(subtitle, fontSize = 16.sp, fontWeight = FontWeight.Medium, color = colors.onSurfaceVariant)
            }
        }
        if (onSettings != null) {
            Box(
                Modifier
                    .size(44.dp)
                    .clip(CircleShape)
                    .background(colors.surface)
                    .border(1.dp, colors.outline, CircleShape)
                    .clickable(onClick = onSettings),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    Icons.Outlined.Settings,
                    contentDescription = "Open settings",
                    tint = colors.onSurfaceVariant,
                    modifier = Modifier.size(15.dp),
                )
            }
        }
    }
}

@Composable
fun Modifier.zotCard(): Modifier {
    val colors = MaterialTheme.colorScheme
    return this
        .clip(RoundedCornerShape(CardRadius))
        .background(colors.surface)
        .border(1.dp, colors.outline, RoundedCornerShape(CardRadius))
}

@Composable
fun TagChip(text: String, color: Color) {
    val look = dietChipLook(text, color, isSystemInDarkTheme())
    Text(
        text,
        modifier = Modifier
            .clip(RoundedCornerShape(ChipRadius))
            .background(look.background)
            .padding(horizontal = 7.dp, vertical = 3.dp),
        fontSize = 13.sp,
        fontWeight = FontWeight.SemiBold,
        color = look.foreground,
    )
}

@Composable
fun StatusPill(isOpen: Boolean, openText: String = "Open", closedText: String = "Closed") {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        Box(
            Modifier
                .size(6.dp)
                .clip(CircleShape)
                .background(if (isOpen) OpenGreen else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f)),
        )
        Text(
            if (isOpen) openText else closedText,
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            color = if (isOpen) OpenGreen else MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
fun StarRating(
    stars: Int,
    size: Dp = 28.dp,
    interactive: Boolean = true,
    onRate: ((Int) -> Unit)? = null,
) {
    Row(horizontalArrangement = Arrangement.spacedBy(if (size > 20.dp) 8.dp else 3.dp)) {
        (1..5).forEach { value ->
            val filled = value <= stars
            Icon(
                imageVector = if (filled) Icons.Rounded.Star else Icons.Outlined.Star,
                contentDescription = if (interactive) "$value stars" else null,
                tint = if (filled) accentGold() else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = if (stars == 0) 0.28f else 0.4f),
                modifier = Modifier
                    .size(size)
                    .then(if (interactive && onRate != null) Modifier.clickable { onRate(if (stars == value) 0 else value) } else Modifier),
            )
        }
    }
}

@Composable
fun EmptyState(
    icon: ImageVector,
    title: String,
    message: String,
    actionTitle: String? = null,
    onAction: (() -> Unit)? = null,
) {
    val colors = MaterialTheme.colorScheme
    Column(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 28.dp, vertical = 52.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Icon(icon, contentDescription = null, tint = colors.onSurfaceVariant, modifier = Modifier.size(28.dp))
        Text(title, fontWeight = FontWeight.SemiBold, fontSize = 16.sp, color = colors.onBackground, textAlign = TextAlign.Center)
        Text(message, fontWeight = FontWeight.Medium, fontSize = 14.sp, color = colors.onSurfaceVariant, textAlign = TextAlign.Center)
        if (actionTitle != null && onAction != null) {
            Text(
                actionTitle,
                modifier = Modifier
                    .padding(top = 6.dp)
                    .clip(RoundedCornerShape(InnerRadius))
                    .border(1.dp, colors.outline, RoundedCornerShape(InnerRadius))
                    .clickable(onClick = onAction)
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                fontWeight = FontWeight.SemiBold,
                color = colors.onBackground,
            )
        }
    }
}

@Composable
fun OccupancyBar(percent: Int?, color: Color, height: Dp = 10.dp) {
    Box(
        Modifier
            .fillMaxWidth()
            .height(height)
            .clip(RoundedCornerShape(ChipRadius))
            .background(MaterialTheme.colorScheme.onBackground.copy(alpha = 0.08f)),
    ) {
        if (percent != null) {
            Box(
                Modifier
                    .fillMaxWidth(percent.coerceIn(0, 100) / 100f)
                    .height(height)
                    .clip(RoundedCornerShape(ChipRadius))
                    .background(color),
            )
        }
    }
}

@Composable
fun SkeletonCard(height: Dp = 92.dp) {
    Box(
        Modifier
            .fillMaxWidth()
            .height(height)
            .clip(RoundedCornerShape(CardRadius))
            .background(MaterialTheme.colorScheme.onBackground.copy(alpha = 0.08f)),
    )
}

@Composable
fun SectionHeader(title: String, count: Int? = null, goldBar: Boolean = true, icon: ImageVector? = null) {
    val colors = MaterialTheme.colorScheme
    Row(
        Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        if (icon != null) {
            Icon(icon, contentDescription = null, tint = accentGold(), modifier = Modifier.size(12.dp))
        } else if (goldBar) {
            Box(
                Modifier
                    .width(3.dp)
                    .height(14.dp)
                    .clip(RoundedCornerShape(1.dp))
                    .background(accentGold()),
            )
        }
        Text(title, fontSize = SectionSize, fontWeight = FontWeight.SemiBold, color = colors.onBackground, modifier = Modifier.weight(1f))
        if (count != null) {
            Text("$count", fontSize = 14.sp, fontWeight = FontWeight.Medium, color = colors.onSurfaceVariant)
        }
    }
}

fun busyColor(percent: Int?): Color = when {
    percent == null -> Color.Unspecified
    percent < 40 -> OpenGreen
    percent < 70 -> BusyOrange
    else -> CrowdedRed
}

fun busyLabel(percent: Int?): String = when {
    percent == null -> "No data"
    percent < 40 -> "Not busy"
    percent < 70 -> "Busy"
    else -> "Very busy"
}
