package anini.aninitools.ui.sensor

import android.annotation.SuppressLint
import android.app.Application
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import androidx.lifecycle.LiveData

class BatteryLiveData(application: Application) : LiveData<List<String>>(){

    private var broadcastReceiver: BroadcastReceiver? = null

    private var app: Application = application


    override fun onActive() {
        super.onActive()
        registerBroadcastReceiver()
    }

    override fun onInactive() {
        super.onInactive()
        unregisterBroadcastReceiver()
    }

    private fun registerBroadcastReceiver() {
        if (broadcastReceiver == null) {
            val filter = IntentFilter()
            filter.addAction(Intent.ACTION_BATTERY_CHANGED)

            broadcastReceiver = object : BroadcastReceiver() {

                override fun onReceive(_context: Context, intent: Intent) {

                    val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL,0).toString()
                    val voltage = intent.getIntExtra(BatteryManager.EXTRA_VOLTAGE,0).toString()
                    val temperature = intent.getIntExtra(BatteryManager.EXTRA_TEMPERATURE,0).toFloat()/10
                    val status = intent.getIntExtra(BatteryManager.EXTRA_STATUS,0)
                    val technology = intent.getStringExtra(BatteryManager.EXTRA_TECHNOLOGY)

                    var chargingstate = ""
                    when(status){
                        1 -> chargingstate = "Unknown"
                        2 -> chargingstate = "Charging"
                        3 -> chargingstate = "Discharging"
                        4 -> chargingstate = "Not Charging"
                        5 -> chargingstate = "Battery Full"
                    }
                    value = mutableListOf(level,voltage,temperature.toString(),chargingstate,technology,getBatteryCapacity(_context).toString())
                }
            }

            app.registerReceiver(broadcastReceiver, filter)
        }
    }

    private fun unregisterBroadcastReceiver() {
        if (broadcastReceiver != null) {
            app.unregisterReceiver(broadcastReceiver)
            broadcastReceiver = null
        }
    }

    @SuppressLint("PrivateApi")
    fun getBatteryCapacity(context: Context): Int {
        val mPowerProfile: Any
        var batteryCapacity = 0.0
        val POWER_PROFILE_CLASS = "com.android.internal.os.PowerProfile"

        try {
            mPowerProfile = Class.forName(POWER_PROFILE_CLASS)
                .getConstructor(Context::class.java)
                .newInstance(context)

            batteryCapacity = Class
                .forName(POWER_PROFILE_CLASS)
                .getMethod("getBatteryCapacity")
                .invoke(mPowerProfile) as Double

        } catch (e: Exception) {
            e.printStackTrace()
        }

        return batteryCapacity.toInt()

    }
}