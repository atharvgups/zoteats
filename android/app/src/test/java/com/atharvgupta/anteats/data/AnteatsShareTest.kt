package com.atharvgupta.anteats.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AnteatsShareTest {
    @Test
    fun usesLiveAppStoreListing() {
        assertEquals(
            "https://apps.apple.com/us/app/anteats/id6790896660",
            AnteatsShare.APP_STORE_URL,
        )
        assertTrue(AnteatsShare.APP_STORE_URL.contains("id6790896660"))
        assertFalse(AnteatsShare.MESSAGE.contains('\u2014'))
        assertFalse(AnteatsShare.SHARE_TEXT.contains('\u2014'))
        assertTrue(AnteatsShare.SHARE_TEXT.contains(AnteatsShare.MESSAGE))
        assertTrue(AnteatsShare.SHARE_TEXT.contains(AnteatsShare.APP_STORE_URL))
        assertEquals("Share Anteats", AnteatsShare.ROW_TITLE)
        assertFalse(AnteatsShare.ROW_SUBTITLE.contains('\u2014'))
    }
}
