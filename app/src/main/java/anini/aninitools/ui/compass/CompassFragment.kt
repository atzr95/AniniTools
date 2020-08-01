package anini.aninitools.ui.compass

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.databinding.DataBindingUtil
import androidx.fragment.app.Fragment
import androidx.lifecycle.Observer
import androidx.lifecycle.ViewModelProvider
import anini.aninitools.R
import anini.aninitools.databinding.FragmentCompassBinding

//TODO: add true north calculation
//TODO: add orientation and warning in compassview

class CompassFragment : Fragment() {

    private lateinit var fragmentCompassBinding: FragmentCompassBinding

    private lateinit var compassViewModel:CompassViewModel

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View? {
        fragmentCompassBinding = DataBindingUtil.inflate(inflater,R.layout.fragment_compass,container,false)
        fragmentCompassBinding.lifecycleOwner = this

        return fragmentCompassBinding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        compassViewModel = ViewModelProvider(this).get(CompassViewModel::class.java)
        fragmentCompassBinding.viewmodel = compassViewModel

    }

    override fun onResume() {
        super.onResume()

        compassViewModel.azimuth.observe(viewLifecycleOwner, Observer {result ->
            result?.let {
                fragmentCompassBinding.compassPointer.updateRotation(result)
            }
        })
    }

}