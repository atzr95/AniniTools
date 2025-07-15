package anini.aninitools.ui.flashlight

import android.content.Context
import android.graphics.Color
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.InputMethodManager
import android.widget.EditText
import android.widget.SeekBar
import android.widget.TextView
import com.google.android.material.textfield.TextInputEditText
import com.google.android.material.slider.Slider
import com.google.android.material.card.MaterialCardView
import androidx.databinding.DataBindingUtil
import androidx.fragment.app.Fragment
import androidx.lifecycle.Observer
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import anini.aninitools.MainActivity
import anini.aninitools.R
import anini.aninitools.databinding.FragmentFlashBinding
import anini.aninitools.util.Prefs
import com.afollestad.assent.Permission
import com.afollestad.assent.askForPermissions
import com.afollestad.assent.runWithPermissions
import com.google.android.material.snackbar.Snackbar
import com.flask.colorpicker.ColorPickerView
import com.flask.colorpicker.builder.ColorPickerDialogBuilder
import android.app.Dialog
import android.content.pm.ActivityInfo
import android.content.res.Configuration
import android.view.Window
import android.view.WindowManager


//TODO: Add flashlight using main display screen
//TODO: Add word to morse code converter
//TODO: Add Music festival light stripe rolling text

/* UI related tasks for FlashLight Fragment*/
class FlashFragment : Fragment() {

    private lateinit var seekBar: SeekBar

    private lateinit var screenFlashOverlay: View
    private lateinit var fragmentFlashBinding: FragmentFlashBinding
    private lateinit var prefs : Prefs
    private lateinit var flashViewModel : FlashViewModel

    // Concert mode dialog
    private var concertModeDialog: Dialog? = null

    // Obtain ViewModel from ViewModelProviders

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View? {
        fragmentFlashBinding = DataBindingUtil.inflate(inflater,R.layout.fragment_flash, container, false)
        fragmentFlashBinding.lifecycleOwner = this

        return fragmentFlashBinding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        prefs = Prefs(requireActivity().applicationContext)

        flashViewModel = ViewModelProvider(this).get(FlashViewModel::class.java)
        fragmentFlashBinding.viewmodel = flashViewModel // Binding to the 'viewmodel' variable in the layout

        initializeViews(view)
        setupObservers()
    }

    private fun initializeViews(view: View) {
        seekBar = view.findViewById(R.id.seekBar)
        screenFlashOverlay = view.findViewById(R.id.screenFlashOverlay)

        val value = prefs.flashStrobe
        seekBar.progress = when {
            value == 0 -> 0
            value == 31 -> 100
            value < 1000 -> (1000 - value) / 10
            else -> prefs.flashStrobe
        }
    }

    private fun setupObservers() {
        // Flash status observer
        flashViewModel.status.observe(viewLifecycleOwner, Observer { status ->
            status?.let {
                if (!it) {
                    //Reset status value at first to prevent multitriggering
                    //and to be available to trigger action again
                    flashViewModel.status.value = null

                    runWithPermissions(Permission.CAMERA) { result ->
                        if (!result.isAllGranted(Permission.CAMERA)) {
                            checkCameraPermission()
                        }
                    }
                    Snackbar.make(
                        requireActivity().findViewById(R.id.content),
                        getString(R.string.flash_camera_unavailable),
                        Snackbar.LENGTH_LONG
                    ).show()
                }
            }
        })

        // Screen flash enabled observer - disable strobing when screen flash is enabled
        flashViewModel.screenFlashEnabled.observe(viewLifecycleOwner, Observer { enabled ->
            if (enabled) {
                // Stop any ongoing camera flash strobing when screen flash is enabled
                if (flashViewModel.buttonstate.value == anini.aninitools.ui.flashlight.ButtonState.ON) {
                    // If flash is currently on, turn it off to prevent conflicts
                    flashViewModel.enableFlash()
                }
            }
        })
        
        // Observe strobe time changes to update seekbar UI
        flashViewModel.getStrobeTime().observe(viewLifecycleOwner, Observer { strobeTime ->
            // Update seekbar progress based on strobe time
            val value = strobeTime.toInt()
            val progress = when {
                value == 0 -> 0
                value == 31 -> 100
                value < 1000 -> (1000 - value) / 10
                else -> value
            }
            if (seekBar.progress != progress) {
                seekBar.progress = progress
            }
        })

        // Screen flash observer - handles full screen mode
        flashViewModel.screenFlashActive.observe(viewLifecycleOwner, Observer { active ->
            if (active) {
                // Boost screen brightness for maximum flash effect
                flashViewModel.getScreenBrightnessUtil().maxBrightness(requireActivity())
                // The overlay visibility is handled by data binding
            } else {
                // Restore original screen brightness
                flashViewModel.getScreenBrightnessUtil().restoreBrightness(requireActivity())
            }
        })

        // Color picker dialog observer
        flashViewModel.openColorPicker.observe(viewLifecycleOwner, Observer { shouldOpen ->
            if (shouldOpen) {
                openColorPickerDialog()
                flashViewModel.onColorPickerOpened()
            }
        })

        // Navigation observer - show full-screen concert mode dialog
        flashViewModel.navigateToConcertMode.observe(viewLifecycleOwner, Observer { navigate ->
            if (navigate) {
                showConcertModeDialog()
                flashViewModel.onConcertModeNavigated()
            }
        })
    }

    private fun showConcertModeDialog() {
        // Create full-screen dialog (no orientation change yet)
        concertModeDialog = Dialog(requireContext(), android.R.style.Theme_Black_NoTitleBar_Fullscreen).apply {
            requestWindowFeature(Window.FEATURE_NO_TITLE)
            
            // Hide system UI for true full-screen experience
            window?.apply {
                setFlags(
                    WindowManager.LayoutParams.FLAG_FULLSCREEN or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                    WindowManager.LayoutParams.FLAG_FULLSCREEN or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
                )
                
                // Set soft input mode to adjust resize for keyboard handling
                //setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE)
                
                // Hide navigation bar and status bar
                decorView.systemUiVisibility = (
                    View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                    View.SYSTEM_UI_FLAG_FULLSCREEN or
                    View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
                    View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
                    View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
                    View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                )
            }
        }
        
        // Inflate concert mode layout
        val concertView = LayoutInflater.from(requireContext())
            .inflate(R.layout.concert_mode_fullscreen, null)
        
        concertModeDialog?.setContentView(concertView)
        
        // Set up concert mode functionality
        setupConcertModeDialog(concertView)
        
        // Set dismiss listener with safety check
        concertModeDialog?.setOnDismissListener {
            // Restore orientation when dialog is dismissed
            if (isAdded && activity != null) {
                requireActivity().requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
            }
            concertModeDialog = null
        }
        
        concertModeDialog?.show()
    }

    private fun setupConcertModeDialog(view: View) {
        // Find all views with null checks and logging
        val rollingTextDisplay = view.findViewById<anini.aninitools.ui.flashlight.SmoothMarqueeTextView>(R.id.rollingTextDisplay)
        val textInput = view.findViewById<TextInputEditText>(R.id.concertTextInput)
        val speedSlider = view.findViewById<Slider>(R.id.concertSpeedSeekBar)
        val blinkSpeedSlider = view.findViewById<Slider>(R.id.concertBlinkSpeedSlider)
        val textSizeSlider = view.findViewById<Slider>(R.id.concertTextSizeSlider)
        val startButton = view.findViewById<View>(R.id.startConcertButton)
        val stopButton = view.findViewById<View>(R.id.stopConcertButton)
        val closeButton = view.findViewById<View>(R.id.closeConcertButton)
        val closeControlsButton = view.findViewById<View>(R.id.closeControlsButton)
        val controlPanel = view.findViewById<View>(R.id.controlPanel)
        val tapOverlay = view.findViewById<View>(R.id.tapToHideOverlay)
        val textColorCard = view.findViewById<MaterialCardView>(R.id.textColorCard)
        val backgroundColorCard = view.findViewById<MaterialCardView>(R.id.backgroundColorCard)
        val textColorSwatch = view.findViewById<View>(R.id.textColorSwatch)
        val backgroundColorSwatch = view.findViewById<View>(R.id.backgroundColorSwatch)
        val mainLayout = view.findViewById<View>(R.id.concert_mode_layout)
        val landscapeInstruction = view.findViewById<View>(R.id.landscapeInstruction)
        
        // Return early if essential views are null
        if (rollingTextDisplay == null || textInput == null || speedSlider == null || blinkSpeedSlider == null || textSizeSlider == null) {
            return
        }
        
        var blinkingRunnable: Runnable? = null
        var isBlinking = false
        var isControlsVisible = true
        var currentTextColor = Color.WHITE
        var currentBackgroundColor = Color.BLACK
        val blinkHandler = android.os.Handler(android.os.Looper.getMainLooper())
        
        // Smooth scrolling text animation using our custom view
        val startRollingText = {
            val message = textInput.text.toString().takeIf { it.isNotEmpty() } ?: "MESSAGE"
            
            // Set text and start smooth scrolling
            rollingTextDisplay?.setText(message)
            rollingTextDisplay?.setSpeed(speedSlider?.value?.toInt() ?: 60)
            rollingTextDisplay?.startScrolling()
            
            // Handle blinking animation (separate from rolling) - only if speed > 0
            val blinkSpeedValue = blinkSpeedSlider?.value?.toLong() ?: 0L
            if (blinkSpeedValue > 0) {
                blinkingRunnable = object : Runnable {
                    override fun run() {
                        try {
                            // Blinking effect
                            isBlinking = !isBlinking
                            val alpha = if (isBlinking) 1.0f else 0.3f
                            rollingTextDisplay?.alpha = alpha
                            
                            // Convert slider value (0-1000) to delay (1000-50ms)
                            // Higher slider value = faster blinking = shorter delay
                            val currentSliderValue = blinkSpeedSlider?.value?.toLong() ?: 0L
                            val blinkDelay = if (currentSliderValue <= 0) {
                                1000L // Very slow if at minimum
                            } else {
                                // Invert: 1000 slider = 50ms delay, 50 slider = 1000ms delay
                                (1050L - currentSliderValue).coerceIn(50L, 1000L)
                            }
                            
                            // Stop blinking if speed is set to 0
                            if (currentSliderValue <= 0) {
                                rollingTextDisplay?.alpha = 1.0f
                                return
                            }
                            
                            // Continue blinking animation using Handler
                            blinkHandler.postDelayed(this, blinkDelay)
                        } catch (e: Exception) {
                            // Blinking animation stopped
                        }
                    }
                }
                blinkHandler.post(blinkingRunnable!!)
            } else {
                // No blinking - keep text fully visible
                rollingTextDisplay?.alpha = 1.0f
                blinkingRunnable = null
            }
        }
        
        val stopRollingText = {
            // Stop smooth scrolling
            rollingTextDisplay?.stopScrolling()
            
            // Stop blinking animation
            blinkingRunnable?.let { blinkHandler.removeCallbacks(it) }
            rollingTextDisplay?.alpha = 1.0f
            
            // Set static text
            val message = textInput.text.toString().takeIf { it.isNotEmpty() } ?: "MESSAGE"
            rollingTextDisplay?.setText(message)
        }
        
        // Update colors with null checks
        val updateColors = {
            try {
                rollingTextDisplay?.setTextColor(currentTextColor)
                mainLayout?.setBackgroundColor(currentBackgroundColor)
                
                // Create bordered drawable for text color swatch
                textColorSwatch?.let { swatch ->
                    val textSwatchDrawable = android.graphics.drawable.GradientDrawable().apply {
                        shape = android.graphics.drawable.GradientDrawable.RECTANGLE
                        setColor(currentTextColor)
                        setStroke(4, android.graphics.Color.parseColor("#40000000"))
                        cornerRadius = 16f
                    }
                    swatch.background = textSwatchDrawable
                }
                
                // Create bordered drawable for background color swatch  
                backgroundColorSwatch?.let { swatch ->
                    val bgSwatchDrawable = android.graphics.drawable.GradientDrawable().apply {
                        shape = android.graphics.drawable.GradientDrawable.RECTANGLE
                        setColor(currentBackgroundColor)
                        setStroke(4, android.graphics.Color.parseColor("#60FFFFFF"))
                        cornerRadius = 16f
                    }
                    swatch.background = bgSwatchDrawable
                }
                
            } catch (e: Exception) {
                // Error updating colors
            }
        }
        
        // Update text size
        val updateTextSize = {
            try {
                val textSize = textSizeSlider?.value ?: 96f
                rollingTextDisplay?.setTextSize(textSize)
            } catch (e: Exception) {
                // Error updating text size
            }
        }
        
        // Color picker dialogs
        val showTextColorPicker = {
            ColorPickerDialogBuilder
                .with(requireContext())
                .setTitle("Choose Text Color")
                .initialColor(currentTextColor)
                .wheelType(ColorPickerView.WHEEL_TYPE.FLOWER)
                .density(12)
                .setOnColorSelectedListener { selectedColor: Int ->
                    currentTextColor = selectedColor
                    updateColors()
                }
                .setPositiveButton(android.R.string.ok) { dialog, selectedColor: Int, allColors ->
                    currentTextColor = selectedColor
                    updateColors()
                }
                .setNegativeButton(android.R.string.cancel) { dialog, which -> }
                .build()
                .show()
        }
        
        val showBackgroundColorPicker = {
            ColorPickerDialogBuilder
                .with(requireContext())
                .setTitle("Choose Background Color")
                .initialColor(currentBackgroundColor)
                .wheelType(ColorPickerView.WHEEL_TYPE.FLOWER)
                .density(12)
                .setOnColorSelectedListener { selectedColor: Int ->
                    currentBackgroundColor = selectedColor
                    updateColors()
                }
                .setPositiveButton(android.R.string.ok) { dialog, selectedColor: Int, allColors ->
                    currentBackgroundColor = selectedColor
                    updateColors()
                }
                .setNegativeButton(android.R.string.cancel) { dialog, which -> }
                .build()
                .show()
        }
        
        // Toggle controls visibility
        val toggleControls = {
            isControlsVisible = !isControlsVisible
            controlPanel?.visibility = if (isControlsVisible) View.VISIBLE else View.GONE
            // Only show instruction if controls are visible and animations are not running
            if (isControlsVisible && blinkingRunnable == null) {
                landscapeInstruction?.visibility = View.VISIBLE
            } else {
                landscapeInstruction?.visibility = View.GONE
            }
        }
        
        // Set up buttons
        startButton?.setOnClickListener { 
            // Hide keyboard when starting concert mode
            hideKeyboard(view, textInput)
            
            // Force landscape orientation when concert mode starts
            if (isAdded && activity != null) {
                requireActivity().requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
            }
            
            startRollingText()
            
            // Immediately hide controls and instruction when starting
            isControlsVisible = false
            controlPanel?.visibility = View.GONE
            landscapeInstruction?.visibility = View.GONE
        }
        stopButton?.setOnClickListener { 
            stopRollingText()
            
            // Show controls and instruction again when stopped
            isControlsVisible = true
            controlPanel?.visibility = View.VISIBLE
            landscapeInstruction?.visibility = View.VISIBLE
            
            // Allow orientation changes when stopped
            if (isAdded && activity != null) {
                requireActivity().requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
            }
        }
        closeButton?.setOnClickListener { 
            // Stop any running animation and restore orientation
            stopRollingText()
            if (isAdded && activity != null) {
                requireActivity().requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
            }
            concertModeDialog?.dismiss() 
        }
        
        // X button to close controls - easier way to hide control panel
        closeControlsButton?.setOnClickListener {
            // Hide controls without starting animation
            isControlsVisible = false
            controlPanel?.visibility = View.GONE
            landscapeInstruction?.visibility = View.GONE
        }
        
        // Color picker buttons with null checks
        textColorCard?.setOnClickListener { showTextColorPicker() }
        backgroundColorCard?.setOnClickListener { showBackgroundColorPicker() }
        
        // Rolling speed slider listener
        speedSlider?.addOnChangeListener { slider, value, fromUser ->
            if (fromUser) {
                rollingTextDisplay?.setSpeed(value.toInt())
            }
        }
        
        // Blink speed slider listener
        blinkSpeedSlider?.addOnChangeListener { slider, value, fromUser ->
            if (fromUser) {
                // If blinking is currently active, restart it with new speed
                if (blinkingRunnable != null) {
                    // Stop current blinking
                    blinkHandler.removeCallbacks(blinkingRunnable!!)
                    
                    // Restart with new speed if speed > 0
                    if (value > 0) {
                        blinkHandler.post(blinkingRunnable!!)
                    } else {
                        // Stop blinking if speed is 0
                        rollingTextDisplay?.alpha = 1.0f
                        blinkingRunnable = null
                    }
                }
            }
        }
        
        // Text size slider listener
        textSizeSlider?.addOnChangeListener { slider, value, fromUser ->
            if (fromUser) {
                updateTextSize()
                rollingTextDisplay?.setTextSize(value)
            }
        }
        
        // Tap anywhere to toggle controls
        tapOverlay?.setOnClickListener { 
            toggleControls()
            hideKeyboard(view, textInput)
        }
        rollingTextDisplay?.setOnClickListener { 
            toggleControls()
            hideKeyboard(view, textInput)
        }
        
        // Hide keyboard when tapping on main concert layout
        mainLayout?.setOnClickListener {
            hideKeyboard(view, textInput)
        }
        
        // Initialize with null checks
        speedSlider?.value = 60f
        blinkSpeedSlider?.value = 0f
        textSizeSlider?.value = 96f
        rollingTextDisplay?.setText("MESSAGE")
        updateColors()
        updateTextSize()
        

        
        // Set initial focus to text input
        textInput?.requestFocus()
    }
    
    private fun hideKeyboard(view: View, textInput: TextInputEditText? = null) {
        val inputMethodManager = requireContext().getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
        
        // First, specifically clear focus from the text input if provided
        textInput?.let { input ->
            input.clearFocus()
            inputMethodManager.hideSoftInputFromWindow(input.windowToken, 0)
        }
        
        // Try to get the currently focused view
        val currentFocusedView = concertModeDialog?.currentFocus ?: activity?.currentFocus
        
        if (currentFocusedView != null) {
            // Hide keyboard from the focused view
            inputMethodManager.hideSoftInputFromWindow(currentFocusedView.windowToken, 0)
            currentFocusedView.clearFocus()
        } else {
            // Fallback: hide keyboard from the provided view
            inputMethodManager.hideSoftInputFromWindow(view.windowToken, 0)
        }
        
        // Additional fallback: try to hide from the dialog's window
        concertModeDialog?.window?.let { window ->
            inputMethodManager.hideSoftInputFromWindow(window.decorView.windowToken, 0)
        }
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
    }

    private fun openColorPickerDialog() {
        val currentColor = flashViewModel.getScreenFlashColorValue()
        
        val dialog = ColorPickerDialogBuilder
            .with(requireContext())
            .setTitle(getString(R.string.color_picker_dialog_title))
            .initialColor(currentColor)
            .wheelType(ColorPickerView.WHEEL_TYPE.FLOWER)
            .density(12)
            .setOnColorSelectedListener { selectedColor: Int ->
                // User selected a color
                flashViewModel.setScreenFlashColor(selectedColor)
            }
            .setPositiveButton(android.R.string.ok) { dialog, selectedColor: Int, allColors ->
                flashViewModel.setScreenFlashColor(selectedColor)
            }
            .setNegativeButton(android.R.string.cancel) { dialog, which ->
                // User cancelled color selection
            }
            .build()
        
        // Apply rounded corners to dialog
        dialog.window?.setBackgroundDrawableResource(R.drawable.dialog_rounded_background)
        
        dialog.show()
    }

    fun checkCameraPermission() = askForPermissions(Permission.CAMERA) { result ->
        // Check the result, see the Using Results section
        //prefs.cameraPermission = result.isAllGranted(Permission.CAMERA)
    }

    override fun onDestroy() {
        super.onDestroy()
        // Clean up dialog
        concertModeDialog?.dismiss()
        concertModeDialog = null
    }

}