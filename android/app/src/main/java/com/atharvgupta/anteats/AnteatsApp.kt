package com.atharvgupta.anteats

import android.app.Application
import com.atharvgupta.anteats.data.PlateStore
import com.atharvgupta.anteats.data.PreferencesStore

class AnteatsApp : Application() {
    lateinit var preferences: PreferencesStore
        private set
    lateinit var plate: PlateStore
        private set

    override fun onCreate() {
        super.onCreate()
        preferences = PreferencesStore(this)
        plate = PlateStore()
    }
}
