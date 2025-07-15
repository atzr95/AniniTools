package anini.aninitools.util

import android.app.Activity
import android.content.Context
import android.provider.Settings
import android.view.WindowManager

class ScreenBrightnessUtil(private val context: Context) {
    private var originalBrightness: Float = -1f
    private var originalMode: Int = -1
    private var brightnessOperationInProgress = false

    fun maxBrightness(activity: Activity) {
        try {
            // Prevent multiple operations from interfering
            if (brightnessOperationInProgress) {
                android.util.Log.d("ScreenBrightness", "Brightness operation already in progress, skipping")
                return
            }
            
            brightnessOperationInProgress = true
            
            // Store original brightness and mode only if not already stored
            if (originalBrightness == -1f) {
                val currentBrightness = activity.window.attributes.screenBrightness
                
                // If current brightness is auto (system controlled), get it from system settings
                if (currentBrightness < 0) {
                    originalBrightness = Settings.System.getInt(
                        context.contentResolver,
                        Settings.System.SCREEN_BRIGHTNESS
                    ) / 255f
                } else {
                    originalBrightness = currentBrightness
                }
                
                originalMode = Settings.System.getInt(
                    context.contentResolver,
                    Settings.System.SCREEN_BRIGHTNESS_MODE
                )
                
                android.util.Log.d("ScreenBrightness", "Stored original brightness: $originalBrightness, mode: $originalMode")
            }

            // Set maximum brightness
            val params = activity.window.attributes
            params.screenBrightness = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_FULL
            activity.window.attributes = params
            
            android.util.Log.d("ScreenBrightness", "Set to max brightness")
        } catch (e: Exception) {
            android.util.Log.e("ScreenBrightness", "Error setting max brightness", e)
            e.printStackTrace()
        } finally {
            brightnessOperationInProgress = false
        }
    }

    fun restoreBrightness(activity: Activity) {
        try {
            // Prevent multiple operations from interfering
            if (brightnessOperationInProgress) {
                android.util.Log.d("ScreenBrightness", "Brightness operation already in progress, skipping")
                return
            }
            
            brightnessOperationInProgress = true
            if (originalBrightness != -1f) {
                val params = activity.window.attributes
                
                // Restore the original brightness
                params.screenBrightness = originalBrightness
                activity.window.attributes = params
                
                android.util.Log.d("ScreenBrightness", "Restored brightness to: $originalBrightness")
                
                // Reset stored values so they can be captured fresh next time
                originalBrightness = -1f
                originalMode = -1
            } else {
                // Fallback: restore to system default if no original brightness was stored
                val params = activity.window.attributes
                params.screenBrightness = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
                activity.window.attributes = params
                
                android.util.Log.d("ScreenBrightness", "No original brightness stored, restored to system default")
            }
        } catch (e: Exception) {
            android.util.Log.e("ScreenBrightness", "Error restoring brightness", e)
            e.printStackTrace()
        } finally {
            brightnessOperationInProgress = false
        }
    }

    fun getCurrentBrightness(): Float {
        return try {
            Settings.System.getInt(
                context.contentResolver,
                Settings.System.SCREEN_BRIGHTNESS
            ) / 255f
        } catch (e: Exception) {
            0.5f // Default brightness
        }
    }
} 