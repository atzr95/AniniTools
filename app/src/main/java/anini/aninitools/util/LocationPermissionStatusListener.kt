package anini.aninitools.util

import android.content.Context
import androidx.lifecycle.LiveData
import com.afollestad.assent.Permission
import com.afollestad.assent.isAllGranted

/**
 * Listens to Runtime Permission Status of provided [permissionToListen] which comes under the
 * category of "Dangerous" and then responds with appropriate state specified in {@link PermissionStatus}
 */
class LocationPermissionStatusListener(context: Context) : LiveData<Boolean>() {

    private val mContext = context

    override fun onActive() {
        handlePermissionCheck()
    }

    private fun handlePermissionCheck() {

        val isFinePermissionGranted = mContext.isAllGranted(Permission.ACCESS_FINE_LOCATION)
        value = isFinePermissionGranted
    }
}