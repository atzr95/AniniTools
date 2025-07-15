package anini.aninitools.ui.sensor

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.databinding.DataBindingUtil
import androidx.fragment.app.Fragment
import androidx.lifecycle.ViewModelProvider
import anini.aninitools.R
import anini.aninitools.databinding.FragmentSensorBinding
import androidx.lifecycle.Observer
import anini.aninitools.util.Prefs
import com.github.mikephil.charting.components.YAxis
import com.github.mikephil.charting.data.LineData
import android.graphics.Color
import anini.aninitools.MainActivity
import com.github.mikephil.charting.data.LineDataSet
import anini.aninitools.util.extension.observeNonNull
import com.afollestad.assent.Permission
import com.afollestad.assent.askForPermissions
import com.afollestad.assent.runWithPermissions
import com.github.mikephil.charting.charts.LineChart
import com.github.mikephil.charting.data.Entry

class SensorFragment : Fragment() {

    private lateinit var fragmentSensorBinding: FragmentSensorBinding
    private lateinit var prefs: Prefs
    private val lightChartData = LineData().also { it.setValueTextColor(Color.WHITE) }
    private val magnetChartData = LineData().also { it.setValueTextColor(Color.WHITE) }
    private val sounddBChartData = LineData().also { it.setValueTextColor(Color.WHITE) }
    private val soundPitchChartData = LineData().also { it.setValueTextColor(Color.WHITE) }
    private val linearAccChartData = LineData().also { it.setValueTextColor(Color.WHITE) }
    private val gyroscopeChartData = LineData().also { it.setValueTextColor(Color.WHITE) }

    private lateinit var sensorViewModel: SensorViewModel


    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        prefs = Prefs(requireActivity().applicationContext)
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View? {
        fragmentSensorBinding = DataBindingUtil.inflate(inflater, R.layout.fragment_sensor, container, false)
        fragmentSensorBinding.lifecycleOwner = this

        return fragmentSensorBinding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        sensorViewModel = ViewModelProvider(this).get(SensorViewModel::class.java)
        fragmentSensorBinding.viewmodel = sensorViewModel

        sensorViewModel.gpsPermission.observe(viewLifecycleOwner, Observer { permission ->
            permission?.let {
                when (permission) {
                    false -> {
                        askForPermissions(Permission.ACCESS_FINE_LOCATION) { result ->
                            if(result.isAllGranted(Permission.ACCESS_FINE_LOCATION)){
                                GpsUtils((activity as MainActivity)).turnGPSOn(object : GpsUtils.OnGpsListener {
                                    override fun gpsStatus(isGPSEnable: Boolean) {
                                    }
                                })
                                checkGPS()
                            }else{
                                sensorViewModel.onGpsPermissionResult(false,false )
                            }
                        }
                    }
                    true -> {
                        GpsUtils((activity as MainActivity)).turnGPSOn(object : GpsUtils.OnGpsListener {
                            override fun gpsStatus(isGPSEnable: Boolean) {
                            }
                        })

                        checkGPS()
                    }
                }
            }
        })

        sensorViewModel.audioPermission.observe(viewLifecycleOwner, Observer { permission ->
            permission?.let {
                when (permission) {
                    false -> {
                        runWithPermissions(Permission.RECORD_AUDIO){result ->
                            if(result.isAllGranted(Permission.RECORD_AUDIO)){
                                sensorViewModel.onAudioPermissionResult(true)
                            }
                        }
                    }

                    true -> {}
                }
                sensorViewModel.onAudioPermissionResult(permission)
            }
        })

        sensorViewModel.expandLight.observe(viewLifecycleOwner, Observer { expanded ->
            expanded?.let {
                when (expanded) {
                    ExpandState.ON -> {
                        setupLineChart(fragmentSensorBinding.lightGraph, lightChartData, "Light")
                        subscribeLight()
                    }
                    ExpandState.OFF -> {
                        unsubscribeLight()
                    }
                    ExpandState.START -> {
                    }

                    ExpandState.PERMISSION -> {}
                    ExpandState.ENABLED -> {}
                }
            }
        })

        sensorViewModel.expandMagnet.observe(viewLifecycleOwner, Observer { expanded ->
            expanded?.let {
                when (expanded) {
                    ExpandState.ON -> {
                        setupLineChart(fragmentSensorBinding.magnetGraph, magnetChartData, "Magnet")
                        subscribeMagnetic()
                    }
                    ExpandState.OFF -> {
                        unsubscribeMagnetic()
                    }
                    ExpandState.START -> {}
                    ExpandState.PERMISSION -> {}
                    ExpandState.ENABLED -> {}
                }
            }
        })

        sensorViewModel.expandSounddB.observe(viewLifecycleOwner, Observer { expanded ->
            expanded?.let {
                when (expanded) {
                    ExpandState.ON -> {

                        setupLineChart(
                            fragmentSensorBinding.sounddBGraph,
                            sounddBChartData,
                            "SoundDB"
                        )
                        subscribeSounddB()


                    }
                    ExpandState.OFF -> {
                        unsubscribeSounddB()
                    }
                    ExpandState.START -> {
                    }
                    ExpandState.PERMISSION -> {
                        sensorViewModel.audioPermission.observe(
                            viewLifecycleOwner,
                            Observer { permission ->
                                permission?.let {
                                    when (permission) {
                                        false -> {
                                            runWithPermissions(Permission.RECORD_AUDIO) { result ->
                                                if (result.isAllGranted(Permission.RECORD_AUDIO)) {
                                                    sensorViewModel.onAudioPermissionResult(true)
                                                }
                                            }
                                        }

                                        true -> {}
                                    }
                                }
                            })
                    }

                    ExpandState.ENABLED -> {}
                }
            }
        })

        sensorViewModel.expandSoundPitch.observe(viewLifecycleOwner, Observer { expanded ->
            expanded?.let {
                when (expanded) {
                    ExpandState.ON -> {

                        setupLineChart(
                            fragmentSensorBinding.soundPitchGraph,
                            soundPitchChartData,
                            "SoundPitch"
                        )
                        subscribeSoundPitch()


                    }
                    ExpandState.OFF -> {
                        unsubscribeSoundPitch()
                    }
                    ExpandState.START -> {
                    }
                    ExpandState.PERMISSION -> {
                        sensorViewModel.audioPermission.observe(
                            viewLifecycleOwner,
                            Observer { permission ->
                                permission?.let {
                                    when (permission) {
                                        false -> {
                                            runWithPermissions(Permission.RECORD_AUDIO) { result ->
                                                if (result.isAllGranted(Permission.RECORD_AUDIO)) {
                                                    sensorViewModel.onAudioPermissionResult(true)
                                                }
                                            }
                                        }

                                        true -> {}
                                    }
                                }
                            })
                    }

                    ExpandState.ENABLED -> {}
                }
            }
        })

        sensorViewModel.expandGPS.observe(viewLifecycleOwner, Observer { expanded ->
            expanded?.let {
                when (expanded) {
                    ExpandState.ON -> { }
                    ExpandState.OFF -> { }
                    ExpandState.START -> { }
                    ExpandState.PERMISSION -> {
                        sensorViewModel.gpsPermission.observe(viewLifecycleOwner, Observer { permission ->
                            permission?.let {
                                when (permission) {
                                    false -> {
                                        askForPermissions(Permission.ACCESS_FINE_LOCATION) { result ->
                                            if(result.isAllGranted(Permission.ACCESS_FINE_LOCATION)){
                                                GpsUtils((activity as MainActivity)).turnGPSOn(object : GpsUtils.OnGpsListener {
                                                    override fun gpsStatus(isGPSEnable: Boolean) {
                                                    }
                                                })
                                                checkGPS()
                                            }else{
                                                sensorViewModel.onGpsPermissionResult(false,false )
                                            }
                                        }
                                    }
                                    true -> {
                                        GpsUtils((activity as MainActivity)).turnGPSOn(object : GpsUtils.OnGpsListener {
                                            override fun gpsStatus(isGPSEnable: Boolean) {
                                            }
                                        })

                                        checkGPS()
                                    }
                                }
                            }
                        })
                    }
                    ExpandState.ENABLED ->{
                        GpsUtils((activity as MainActivity)).turnGPSOn(object : GpsUtils.OnGpsListener {
                            override fun gpsStatus(isGPSEnable: Boolean) {
                            }
                        })
                        checkGPS()
                    }
                }
            }
        })

        sensorViewModel.expandLinearAcc.observe(viewLifecycleOwner, Observer { expanded ->
            expanded?.let {
                when (expanded) {
                    ExpandState.ON -> {
                        setupLineChart(fragmentSensorBinding.linearAccGraph, linearAccChartData, "LinearAcc")
                        subscribeLinearAcc()
                    }
                    ExpandState.OFF -> {
                        unsubscribeLinearAcc()
                    }
                    ExpandState.START -> {
                    }

                    ExpandState.PERMISSION -> {}
                    ExpandState.ENABLED -> {}
                }
            }
        })

        sensorViewModel.expandGyroscope.observe(viewLifecycleOwner, Observer { expanded ->
            expanded?.let {
                when (expanded) {
                    ExpandState.ON -> {
                        setupLineChart(fragmentSensorBinding.gyroscopeGraph, gyroscopeChartData, "Gyroscope")
                        subscribeGyroscope()
                    }
                    ExpandState.OFF -> {
                        unsubscribeGyroscope()
                    }
                    ExpandState.START -> {
                    }

                    ExpandState.PERMISSION -> {}
                    ExpandState.ENABLED -> {}
                }
            }
        })

        sensorViewModel.orientation.observe(viewLifecycleOwner, Observer {result ->
            result?.let {
                fragmentSensorBinding.orientationView.updateOrientation(it[0],it[1])
            }
        })
    }

    override fun onPause() {
        super.onPause()
        sensorViewModel.resetCard()
    }

    private fun checkGPS(){
        sensorViewModel.gpsStatus.observe(viewLifecycleOwner, Observer {
            val status = it
            if(status){
                sensorViewModel.onGpsPermissionResult(true,true )
            }else{
                sensorViewModel.onGpsPermissionResult(true,false )
            }
        })

    }

    private fun unsubscribeLight() {
        sensorViewModel.lightGraph.removeSource(sensorViewModel.light)
        sensorViewModel.lightGraph.removeObservers(this)
        fragmentSensorBinding.lightGraph.also {
            it.data.clearValues()
            lightChartData.clearValues()
            it.notifyDataSetChanged()
            it.clear()
            it.invalidate()
        }
    }

    private fun subscribeLight() {
        sensorViewModel.lightDataRefresh()
        sensorViewModel.lightGraph.observeNonNull(this) { data ->
            if (data != null) {
                addEntry(fragmentSensorBinding.lightGraph, lightChartData, data)
            }
        }
    }

    private fun unsubscribeSounddB() {
        sensorViewModel.audioIntesityGraph.removeSource(sensorViewModel.audioIntesity)
        fragmentSensorBinding.sounddBGraph.also {
            it.data.clearValues()
            sounddBChartData.clearValues()
            it.notifyDataSetChanged()
            it.clear()
            it.invalidate()
        }
    }

    private fun subscribeSounddB() {
        sensorViewModel.sounddBGraphSource()
        sensorViewModel.audioIntesityGraph.observeNonNull(this) { data ->
            addEntry(fragmentSensorBinding.sounddBGraph, sounddBChartData, data)
        }
    }

    private fun unsubscribeSoundPitch() {
        sensorViewModel.audioPitchGraph.removeSource(sensorViewModel.audioPitch)
        fragmentSensorBinding.soundPitchGraph.also {
            it.data.clearValues()
            soundPitchChartData.clearValues()
            it.notifyDataSetChanged()
            it.clear()
            it.invalidate()
        }
    }

    private fun subscribeSoundPitch() {
        sensorViewModel.soundPitchGraphSource()
        sensorViewModel.audioPitchGraph.observeNonNull(this) { data ->
            addEntry(fragmentSensorBinding.soundPitchGraph, soundPitchChartData, data)
        }
    }

    private fun unsubscribeMagnetic() {
        sensorViewModel.magneticGraph.removeSource(sensorViewModel.magnetic)
        fragmentSensorBinding.magnetGraph.also {
            it.data.clearValues()
            magnetChartData.clearValues()
            it.notifyDataSetChanged()
            it.clear()
            it.invalidate()
        }
    }

    private fun subscribeMagnetic() {
        sensorViewModel.magneticGraphSource()
        sensorViewModel.magneticGraph.observeNonNull(this) { data ->
            addEntry(fragmentSensorBinding.magnetGraph, magnetChartData, data)
        }
    }

    private fun unsubscribeLinearAcc() {
        sensorViewModel.linearAccGraph.removeSource(sensorViewModel.linear_acceleration)
        fragmentSensorBinding.linearAccGraph.also {
            it.data.clearValues()
            linearAccChartData.clearValues()
            it.notifyDataSetChanged()
            it.clear()
            it.invalidate()
        }
    }

    private fun subscribeLinearAcc() {
        sensorViewModel.linearAccGraphSource()
        sensorViewModel.linearAccGraph.observeNonNull(this) { data ->
            addEntry(fragmentSensorBinding.linearAccGraph, linearAccChartData, data)
        }
    }

    private fun unsubscribeGyroscope() {
        sensorViewModel.gyroscopeGraph.removeSource(sensorViewModel.gyroscope)
        fragmentSensorBinding.gyroscopeGraph.also {
            it.data.clearValues()
            gyroscopeChartData.clearValues()
            it.notifyDataSetChanged()
            it.clear()
            it.invalidate()
        }
    }

    private fun subscribeGyroscope() {
        sensorViewModel.gyroscopeGraphSource()
        sensorViewModel.gyroscopeGraph.observeNonNull(this) { data ->
            addEntry(fragmentSensorBinding.gyroscopeGraph, gyroscopeChartData, data)
        }
    }

    //Function to set up line chart
    private fun setupLineChart(lineChart: LineChart, lineData: LineData, label: String) {
        // enable description text
        lineChart.also {
            // enable touch gestures
            it.setTouchEnabled(false)
            // enable scaling and dragging
            it.isDragEnabled = false
            it.setScaleEnabled(false)
            it.setDrawGridBackground(false)
            it.setPinchZoom(false)
            it.setBackgroundColor(Color.argb(0, 0, 0, 0))
            it.data = lineData
            it.axisLeft.also { leftAxis ->
                leftAxis.textColor = Color.WHITE
                leftAxis.setDrawGridLines(true)
            }
            it.description.isEnabled = false
            it.axisRight.isEnabled = false
            it.xAxis.isEnabled = false
            it.legend.isEnabled = false

            lineData.addDataSet(LineDataSet(null, label).also { set ->
                set.mode = LineDataSet.Mode.CUBIC_BEZIER
                set.cubicIntensity = 0.2f
                set.setDrawCircles(false)
                set.axisDependency = YAxis.AxisDependency.LEFT
                set.color = Color.MAGENTA
                set.lineWidth = 2f
                set.setDrawValues(false)
                //set.isVisible = set.entryCount != 0
            })
        }
    }

    private fun addEntry(lineChart: LineChart, lineData: LineData, data: Float) {
        val set = lineData.getDataSetByIndex(0)
        set.addEntry(Entry(set.entryCount.toFloat(), data))

        lineData.notifyDataChanged()

        lineChart.also { chart ->
            chart.notifyDataSetChanged()
            chart.setVisibleXRangeMaximum(100f)
            chart.setVisibleXRangeMinimum(100f)
            // move to the latest entry
            chart.moveViewToX(lineData.entryCount.toFloat())

            val lowestVisibleX = chart.lowestVisibleX
            val highestVisibleX = chart.highestVisibleX

            lineData.calcMinMaxY(lowestVisibleX, highestVisibleX)

            //calculating offsets for axes to display correct labels
            chart.xAxis.calculate(lineData.xMin, lineData.xMax)
            calculateMinMaxForYAxis(chart, lineData, YAxis.AxisDependency.LEFT)
            calculateMinMaxForYAxis(chart, lineData, YAxis.AxisDependency.RIGHT)
            //this is where the magic happens
            chart.calculateOffsets()
            //if nothing happens try adding
            //lineChart.invalidate();
        }
    }

    private fun calculateMinMaxForYAxis(lineChart: LineChart, lineData: LineData, axisDependency: YAxis.AxisDependency) {
        val yAxis = lineChart.getAxis(axisDependency)
        if (yAxis.isEnabled) {
            val yMin = lineData.getYMin(axisDependency)
            val yMax = lineData.getYMax(axisDependency)
            yAxis.calculate(yMin, yMax)
        }
    }


}