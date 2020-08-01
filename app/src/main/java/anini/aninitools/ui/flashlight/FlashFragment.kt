package anini.aninitools.ui.flashlight

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.SeekBar
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

//TODO: Add flashlight using main display screen
//TODO: Add word to morse code converter
//TODO: Add Music festival light stripe rolling text

/* UI related tasks for FlashLight Fragment*/
class FlashFragment : Fragment() {

    private lateinit var seekBar: SeekBar
    private lateinit var fragmentFlashBinding: FragmentFlashBinding
    private lateinit var prefs : Prefs
    private lateinit var flashViewModel : FlashViewModel

    // Obtain ViewModel from ViewModelProviders

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View? {
        fragmentFlashBinding = DataBindingUtil.inflate(inflater,R.layout.fragment_flash, container, false)
        fragmentFlashBinding.lifecycleOwner = this

        return fragmentFlashBinding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        prefs = Prefs(activity!!.applicationContext)

        flashViewModel = ViewModelProvider(this).get(FlashViewModel::class.java)
        fragmentFlashBinding.viewmodel = flashViewModel

        seekBar = view.findViewById(R.id.seekBar)
        val value = prefs.flashStrobe
        seekBar.progress = prefs.flashStrobe

        when {
            value == 0 -> seekBar.progress = 0
            value == 31 -> seekBar.progress = 100
            value < 1000  -> seekBar.progress = (1000 - value)/10
        }

        flashViewModel.status.observe(viewLifecycleOwner, Observer {status ->
            status?.let{
                if (!it){
                    //Reset status value at first to prevent multitriggering
                    //and to be available to trigger action again
                    flashViewModel.status.value = null

                    runWithPermissions(Permission.CAMERA){result ->
                        if(!result.isAllGranted(Permission.CAMERA)){
                            checkCameraPermission()
                        }
                    }
                    Snackbar.make(
                        activity!!.findViewById(R.id.content),
                        "Flash Camera is not available",
                        Snackbar.LENGTH_LONG
                    ).show()
                }

            }
        })
    }

    fun checkCameraPermission() = askForPermissions(Permission.CAMERA) { result ->
        // Check the result, see the Using Results section
        //prefs.cameraPermission = result.isAllGranted(Permission.CAMERA)
    }


}