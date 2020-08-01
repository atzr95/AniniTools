package anini.aninitools

import android.os.Bundle
import com.google.android.material.bottomnavigation.BottomNavigationView
import androidx.appcompat.app.AppCompatActivity
import androidx.navigation.NavController
import anini.aninitools.util.Prefs
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorManager
import android.os.PersistableBundle
import androidx.lifecycle.LiveData

//control navigation and check sensor availability
class MainActivity : AppCompatActivity() {

    private var currentNavController: LiveData<NavController>? = null
    private lateinit var prefs: Prefs

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        prefs = Prefs(application.applicationContext)
        prefs.buttonState = 0
        prefs.flashStrobe = 0

        setContentView(R.layout.activity_main)
        if (savedInstanceState == null) {
            setupBottomNavigationBar()
        } // Else, need to wait for onRestoreInstanceState

        val manager = packageManager
        val sensorManager: SensorManager = getSystemService(SENSOR_SERVICE) as SensorManager
        val hasAccelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_LINEAR_ACCELERATION) != null
        val hasAmbientTemp = manager.hasSystemFeature(PackageManager.FEATURE_SENSOR_AMBIENT_TEMPERATURE)
        val hasLight = manager.hasSystemFeature(PackageManager.FEATURE_SENSOR_LIGHT)
        val hasMagnetic = sensorManager.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD) != null
        val hasProximity = manager.hasSystemFeature(PackageManager.FEATURE_SENSOR_PROXIMITY)
        val hasOrientation = manager.hasSystemFeature(PackageManager.FEATURE_SENSOR_GYROSCOPE)
        val hasGPS = manager.hasSystemFeature(PackageManager.FEATURE_LOCATION_GPS)
        val hasPressure = manager.hasSystemFeature(PackageManager.FEATURE_SENSOR_BAROMETER)
        val hasSound = manager.hasSystemFeature(PackageManager.FEATURE_MICROPHONE)

        prefs.sensorAccelerometer = hasAccelerometer
        prefs.sensorAmbientTemp = hasAmbientTemp
        prefs.sensorLight = hasLight
        prefs.sensorMagnetic = hasMagnetic
        prefs.sensorProximity = hasProximity
        prefs.sensorOrientation = hasOrientation
        prefs.sensorGPS = hasGPS
        prefs.sensorPressure = hasPressure
        prefs.sensorSound = hasSound
    }

    override fun onRestoreInstanceState(
        savedInstanceState: Bundle?,
        persistentState: PersistableBundle?
    ) {
        super.onRestoreInstanceState(savedInstanceState, persistentState)
        setupBottomNavigationBar()
    }

    /**
     * Called on first creation and when restoring state.
     */
    private fun setupBottomNavigationBar() {
        val bottomNavigationView = findViewById<BottomNavigationView>(R.id.nav_view)

        val navGraphIds = listOf(R.navigation.navigation_flash, R.navigation.navigation_sensor, R.navigation.navigation_compass)

        // Setup the bottom navigation view with a list of navigation graphs
        val controller = bottomNavigationView.setupWithNavController(
            navGraphIds = navGraphIds,
            fragmentManager = supportFragmentManager,
            containerId = R.id.nav_host_container,
            intent = intent
        )

        currentNavController = controller
    }

    override fun onSupportNavigateUp(): Boolean {
        return currentNavController?.value?.navigateUp() ?: false
    }

}

const val GPS_REQUEST = 101
