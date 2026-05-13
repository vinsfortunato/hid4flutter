package com.github.vinsfortunato.hid4flutter

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.CoroutineExceptionHandler
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.TimeoutException
import kotlin.coroutines.coroutineContext
import kotlin.coroutines.resume

class Hid4flutterPlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
    companion object {
        private const val TAG = "hid4flutter"
        private const val DEFAULT_TRANSFER_TIMEOUT_MS = 1000
        private const val READER_POLL_TIMEOUT_MS = 250
        private const val READER_BUFFER_SIZE = 1024
        private const val PERMISSION_REQUEST_TIMEOUT_MS = 30_000L
        private const val USB_REQUEST_GET_DESCRIPTOR = 0x06
        private const val USB_DESCRIPTOR_TYPE_STRING = 0x03
        private const val DEFAULT_USB_LANG_ID = 0x0409
        private const val USB_RECIPIENT_INTERFACE = 0x01
        private const val HID_REPORT_TYPE_OUTPUT = 0x02
        private const val HID_REPORT_TYPE_FEATURE = 0x03
        private const val HID_REQ_GET_REPORT = 0x01
        private const val HID_REQ_SET_REPORT = 0x09
    }

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var applicationContext: Context

    private val mainHandler = Handler(Looper.getMainLooper())

    private val job = SupervisorJob()
    private val scope = CoroutineScope(
        Dispatchers.IO + job + CoroutineExceptionHandler { _, t ->
            Log.e(TAG, "Uncaught in plugin scope", t)
        }
    )

    private val ACTION_USB_PERMISSION by lazy { "${applicationContext.packageName}.USB_PERMISSION" }

    private class OpenHandle(
        val connection: UsbDeviceConnection,
        val intf: UsbInterface,
        val deviceId: Int
    ) {
        val mutex = Mutex()

        @Volatile
        var closed: Boolean = false
    }

    private val openHandles = ConcurrentHashMap<String, OpenHandle>()
    private val readerJobs = ConcurrentHashMap<String, Job>()
    private var detachReceiver: BroadcastReceiver? = null

    private fun keyFor(path: String, interfaceNumber: Int): String =
        "$path#$interfaceNumber"

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = flutterPluginBinding.applicationContext
        methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "hid4flutter")
        methodChannel.setMethodCallHandler(this)
        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "hid4flutter/events")
        eventChannel.setStreamHandler(this)
        registerDetachReceiver()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        unregisterDetachReceiver()
        // Cancel all in-flight coroutines (readers + method handlers).
        scope.cancel()
        readerJobs.clear()
        for (key in openHandles.keys.toList()) {
            openHandles.remove(key)?.let { closeHandleQuietly(it) }
        }
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        scope.launch {
            try {
                val value: Any? = when (call.method) {
                    "getDevices" -> listHidDevices(
                        call.argument<Int>("vendorId"),
                        call.argument<Int>("productId")
                    )
                    "openDevice" -> {
                        val (path, intf) = requirePathAndInterface(call)
                        openHidDevice(path, intf)
                        null
                    }
                    "closeDevice" -> {
                        val (path, intf) = requirePathAndInterface(call)
                        closeHidDevice(path, intf)
                        null
                    }
                    "sendReport" -> {
                        val (path, intf) = requirePathAndInterface(call)
                        val reportId = call.argument<Int>("reportId") ?: 0
                        val raw = call.argument<ByteArray>("data") ?: ByteArray(0)
                        sendOutputReport(path, intf, reportId, prependReportId(reportId, raw))
                        null
                    }
                    "receiveReport" -> {
                        val (path, intf) = requirePathAndInterface(call)
                        val reportLength = call.argument<Int>("reportLength")
                            ?: throw ArgumentError("Missing 'reportLength'")
                        val timeoutMs = call.argument<Int>("timeoutMs") ?: 0
                        readInputReport(path, intf, reportLength, timeoutMs)
                    }
                    "receiveFeatureReport" -> {
                        val (path, intf) = requirePathAndInterface(call)
                        val reportId = call.argument<Int>("reportId") ?: 0
                        val bufferSize = call.argument<Int>("bufferSize") ?: 1024
                        readFeatureReport(path, intf, reportId, bufferSize)
                    }
                    "sendFeatureReport" -> {
                        val (path, intf) = requirePathAndInterface(call)
                        val reportId = call.argument<Int>("reportId") ?: 0
                        val raw = call.argument<ByteArray>("data") ?: ByteArray(0)
                        sendFeatureReport(path, intf, reportId, prependReportId(reportId, raw))
                        null
                    }
                    "getIndexedString" -> {
                        val (path, intf) = requirePathAndInterface(call)
                        val index = call.argument<Int>("index")
                            ?: throw ArgumentError("Missing 'index'")
                        val maxLength = call.argument<Int>("maxLength") ?: 256
                        readIndexedString(path, intf, index, maxLength)
                    }
                    else -> {
                        withContext(Dispatchers.Main) { result.notImplemented() }
                        return@launch
                    }
                }
                withContext(Dispatchers.Main) { result.success(value) }
            } catch (e: ArgumentError) {
                respondError(result, "ARGUMENT_ERROR", e.message ?: "Invalid arguments")
            } catch (e: TimeoutException) {
                respondError(result, "TIMEOUT", e.message ?: "Operation timed out")
            } catch (e: SecurityException) {
                respondError(result, "PERMISSION_DENIED", e.message ?: "USB permission denied")
            } catch (e: IllegalStateException) {
                respondError(
                    result,
                    errorCodeForMethod(call.method, notOpen = true),
                    e.message ?: "Device/interface is not open"
                )
            } catch (e: Exception) {
                respondError(
                    result,
                    errorCodeForMethod(call.method, notOpen = false),
                    e.message ?: "Operation failed"
                )
            }
        }
    }

    private suspend fun respondError(result: Result, code: String, message: String) {
        withContext(Dispatchers.Main) { result.error(code, message, null) }
    }

    private fun errorCodeForMethod(method: String?, notOpen: Boolean): String {
        if (notOpen) return "NOT_OPEN"
        return when (method) {
            "getDevices" -> "GET_DEVICES_FAILED"
            "openDevice" -> "OPEN_FAILED"
            "closeDevice" -> "CLOSE_FAILED"
            "sendReport" -> "SEND_FAILED"
            "receiveReport" -> "RECEIVE_FAILED"
            "receiveFeatureReport" -> "RECEIVE_FEATURE_FAILED"
            "sendFeatureReport" -> "SEND_FEATURE_FAILED"
            "getIndexedString" -> "GET_STRING_FAILED"
            else -> "ERROR"
        }
    }

    private class ArgumentError(message: String) : IllegalArgumentException(message)

    private fun requirePathAndInterface(call: MethodCall): Pair<String, Int> {
        val path = call.argument<String>("path")
            ?: throw ArgumentError("Missing 'path'")
        val intf = call.argument<Int>("interfaceNumber")
            ?: throw ArgumentError("Missing 'interfaceNumber'")
        return path to intf
    }

    private fun prependReportId(reportId: Int, raw: ByteArray): ByteArray {
        val buffer = ByteArray(1 + raw.size)
        buffer[0] = reportId.toByte()
        System.arraycopy(raw, 0, buffer, 1, raw.size)
        return buffer
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        val (path, interfaceNumber) = try {
            parseStreamArguments(arguments)
        } catch (e: Exception) {
            mainHandler.post { events.error("ARGUMENT_ERROR", e.message, null) }
            return
        }
        val key = keyFor(path, interfaceNumber)

        // Reject if a reader is already running for this interface
        if (readerJobs.containsKey(key)) {
            mainHandler.post {
                events.error(
                    "ALREADY_LISTENING",
                    "An input stream is already active for $key",
                    null
                )
            }
            return
        }

        val readerJob = scope.launch {
            try {
                runReader(path, interfaceNumber, events)
            } catch (_: Exception) {
                // Surface errors via the event sink, but stay silent here
            } finally {
                mainHandler.post {
                    try { events.endOfStream() } catch (_: Exception) {}
                }
                readerJobs.remove(key)
            }
        }
        readerJobs[key] = readerJob
    }

    override fun onCancel(arguments: Any?) {
        val (path, interfaceNumber) = try {
            parseStreamArguments(arguments)
        } catch (_: Exception) {
            return
        }
        val key = keyFor(path, interfaceNumber)
        readerJobs.remove(key)?.cancel()
    }

    private fun parseStreamArguments(arguments: Any?): Pair<String, Int> {
        @Suppress("UNCHECKED_CAST")
        val map = (arguments as? Map<String, Any?>)
            ?: throw IllegalArgumentException("Stream arguments must be a map")
        val path = (map["path"] as? String)
            ?: throw IllegalArgumentException("Missing 'path' in stream arguments")
        val intf = (map["interfaceNumber"] as? Int)
            ?: throw IllegalArgumentException("Missing 'interfaceNumber' in stream arguments")
        return path to intf
    }

    private suspend fun runReader(
        path: String,
        interfaceNumber: Int,
        events: EventChannel.EventSink
    ) {
        val handle = openHandles[keyFor(path, interfaceNumber)] ?: run {
            mainHandler.post {
                try {
                    events.error("NOT_OPEN", "Device/interface not open: $path#$interfaceNumber", null)
                } catch (_: Exception) {}
            }
            return
        }
        val inEp = findInterruptEndpoint(handle.intf, UsbConstants.USB_DIR_IN) ?: run {
            mainHandler.post {
                try {
                    events.error(
                        "NO_ENDPOINT",
                        "No interrupt IN endpoint for $path#$interfaceNumber",
                        null
                    )
                } catch (_: Exception) {}
            }
            return
        }

        val buffer = ByteArray(READER_BUFFER_SIZE)
        while (coroutineContext.isActive && !handle.closed) {
            val read = handle.mutex.withLock {
                if (handle.closed) return@withLock -2
                handle.connection.bulkTransfer(inEp, buffer, buffer.size, READER_POLL_TIMEOUT_MS)
            }

            // -2 is our sentinel for "closed while we were trying to lock."
            if (read == -2) break

            // bulkTransfer returns -1 on timeout or error. Treat -1 as a
            // benign poll timeout and loop. If the device has been closed,
            // the next iteration's check will exit.
            if (read < 0) {
                coroutineContext.ensureActive()
                continue
            }

            if (read == 0) {
                coroutineContext.ensureActive()
                continue
            }

            val payload = buffer.copyOf(read)
            withContext(Dispatchers.Main) {
                try {
                    // Emit bytes individually to match the Dart Stream<int> contract.
                    for (b in payload) {
                        events.success((b.toInt() and 0xFF))
                    }
                } catch (_: Exception) {
                    // Sink already closed; the next loop iteration will exit
                    // via cancellation.
                }
            }
        }
    }

    private fun stopReaderFor(key: String) {
        readerJobs.remove(key)?.cancel()
    }

    private fun usbManager(): UsbManager =
        applicationContext.getSystemService(Context.USB_SERVICE) as UsbManager

    private fun listHidDevices(vendorId: Int?, productId: Int?): List<Map<String, Any>> {
        val deviceList = usbManager().deviceList.values
        val devices = mutableListOf<Map<String, Any>>()
        for (device in deviceList) {
            if (vendorId != null && device.vendorId != vendorId) continue
            if (productId != null && device.productId != productId) continue
            for (i in 0 until device.interfaceCount) {
                val intf = device.getInterface(i)
                if (intf.interfaceClass == UsbConstants.USB_CLASS_HID) {
                    devices.add(buildDeviceMap(device, intf))
                }
            }
        }
        return devices
    }

    private fun buildDeviceMap(device: UsbDevice, intf: UsbInterface): Map<String, Any> {
        val id = "${device.deviceName}#${intf.id}"
        val manufacturer = try { device.manufacturerName ?: "" } catch (_: Exception) { "" }
        val serialNumber = try { device.serialNumber ?: "" } catch (_: Exception) { "" }
        val productName = device.productName ?: device.deviceName

        return mapOf(
            "id" to id,
            "path" to device.deviceName,
            "vendorId" to device.vendorId,
            "productId" to device.productId,
            "serialNumber" to serialNumber,
            "releaseNumber" to parseBcdVersion(device),
            "manufacturer" to manufacturer,
            "productName" to productName,
            "usagePage" to 0,
            "usage" to 0,
            "interfaceNumber" to intf.id,
            "busType" to 1
        )
    }

    private fun parseBcdVersion(device: UsbDevice): Int = try {
        val v = device.version ?: ""
        if (v.isEmpty()) 0 else {
            val parts = v.split('.')
            val major = parts.getOrNull(0)?.toIntOrNull() ?: 0
            val minorStr = (parts.getOrNull(1) ?: "0").padEnd(2, '0').take(2)
            val highNibble = minorStr[0].digitToIntOrNull() ?: 0
            val lowNibble = minorStr[1].digitToIntOrNull() ?: 0
            val minorBcd = (highNibble shl 4) or lowNibble
            ((major and 0xFF) shl 8) or (minorBcd and 0xFF)
        }
    } catch (_: Exception) {
        0
    }

    private fun findDeviceByPath(path: String): UsbDevice? =
        usbManager().deviceList.values.firstOrNull { it.deviceName == path }

    private suspend fun requestUsbPermission(device: UsbDevice): Boolean {
        val manager = usbManager()
        if (manager.hasPermission(device)) return true

        val granted = withTimeoutOrNull(PERMISSION_REQUEST_TIMEOUT_MS) {
            suspendCancellableCoroutine<Boolean> { cont ->
                val receiver = object : BroadcastReceiver() {
                    override fun onReceive(context: Context?, intent: Intent?) {
                        if (intent?.action != ACTION_USB_PERMISSION) return
                        val d: UsbDevice? = intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                        if (d?.deviceId != device.deviceId) return
                        val ok = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
                        if (cont.isActive) cont.resume(ok)
                    }
                }
                val filter = IntentFilter(ACTION_USB_PERMISSION)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    applicationContext.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
                } else {
                    @Suppress("UnspecifiedRegisterReceiverFlag")
                    applicationContext.registerReceiver(receiver, filter)
                }

                cont.invokeOnCancellation {
                    try { applicationContext.unregisterReceiver(receiver) } catch (_: Exception) {}
                }

                val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                    (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
                val intent = Intent(ACTION_USB_PERMISSION).setPackage(applicationContext.packageName)
                val permissionIntent = PendingIntent.getBroadcast(applicationContext, 0, intent, flags)

                manager.requestPermission(device, permissionIntent)
            }
        }

        return granted ?: manager.hasPermission(device)
    }

    private suspend fun openHidDevice(path: String, interfaceNumber: Int) {
        val key = keyFor(path, interfaceNumber)
        if (openHandles.containsKey(key)) return

        val manager = usbManager()
        val device = findDeviceByPath(path)
            ?: throw IllegalArgumentException("Device not found: $path")

        if (!manager.hasPermission(device) && !requestUsbPermission(device)) {
            throw SecurityException("Missing USB permission for device: $path")
        }

        val intf = (0 until device.interfaceCount)
            .map { device.getInterface(it) }
            .firstOrNull { it.id == interfaceNumber }
            ?: throw IllegalArgumentException("Interface not found: $interfaceNumber")

        val connection = manager.openDevice(device)
            ?: throw IllegalStateException("Failed to open device: $path")

        val claimed = try {
            connection.claimInterface(intf, true)
        } catch (e: Exception) {
            connection.close()
            throw e
        }
        if (!claimed) {
            connection.close()
            throw IllegalStateException("Failed to claim interface: $interfaceNumber")
        }

        val handle = OpenHandle(connection, intf, device.deviceId)
        if (openHandles.putIfAbsent(key, handle) != null) {
            closeHandleQuietly(handle)
        }
    }

    private fun closeHidDevice(path: String, interfaceNumber: Int) {
        val key = keyFor(path, interfaceNumber)
        // Stop any active reader first so it doesn't see a half-torn-down handle.
        stopReaderFor(key)
        openHandles.remove(key)?.let { closeHandleQuietly(it) }
    }

    private fun closeHandleQuietly(handle: OpenHandle) {
        handle.closed = true
        try { handle.connection.releaseInterface(handle.intf) } catch (_: Exception) {}
        try { handle.connection.close() } catch (_: Exception) {}
    }

    private fun requireOpenHandle(path: String, interfaceNumber: Int): OpenHandle {
        val handle = openHandles[keyFor(path, interfaceNumber)]
            ?: throw IllegalStateException("Device/interface not open: $path#$interfaceNumber")
        if (handle.closed) {
            throw IllegalStateException("Device/interface not open: $path#$interfaceNumber")
        }
        return handle
    }

    private fun registerDetachReceiver() {
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action != UsbManager.ACTION_USB_DEVICE_DETACHED) return
                val device: UsbDevice? = intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                val deviceName = device?.deviceName ?: return
                for (key in openHandles.keys.toList()) {
                    if (key.startsWith("$deviceName#")) {
                        stopReaderFor(key)
                        openHandles.remove(key)?.let { closeHandleQuietly(it) }
                    }
                }
            }
        }
        val filter = IntentFilter(UsbManager.ACTION_USB_DEVICE_DETACHED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            applicationContext.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            applicationContext.registerReceiver(receiver, filter)
        }
        detachReceiver = receiver
    }

    private fun unregisterDetachReceiver() {
        detachReceiver?.let {
            try { applicationContext.unregisterReceiver(it) } catch (_: Exception) {}
        }
        detachReceiver = null
    }

    private fun findInterruptEndpoint(intf: UsbInterface, direction: Int): UsbEndpoint? {
        for (i in 0 until intf.endpointCount) {
            val ep = intf.getEndpoint(i)
            if (ep.type == UsbConstants.USB_ENDPOINT_XFER_INT && ep.direction == direction) {
                return ep
            }
        }
        return null
    }

    private suspend fun readInputReport(
        path: String,
        interfaceNumber: Int,
        reportLength: Int,
        timeoutMs: Int
    ): ByteArray {
        if (reportLength <= 0) return ByteArray(0)

        val handle = requireOpenHandle(path, interfaceNumber)
        val inEp = findInterruptEndpoint(handle.intf, UsbConstants.USB_DIR_IN)
            ?: throw IllegalStateException("No interrupt IN endpoint for $path#$interfaceNumber")

        val buffer = ByteArray(reportLength)
        val effectiveTimeout = timeoutMs.coerceAtLeast(0)
        val read = handle.mutex.withLock {
            if (handle.closed) throw IllegalStateException("Device closed during read")
            handle.connection.bulkTransfer(inEp, buffer, reportLength, effectiveTimeout)
        }

        if (read < 0) {
            if (handle.closed) throw IllegalStateException("Device closed during read")
            if (timeoutMs > 0) throw TimeoutException("Timed out waiting for input report")
            throw IllegalStateException("Failed to read input report")
        }

        return if (read == buffer.size) buffer else buffer.copyOf(read)
    }

    private suspend fun sendOutputReport(
        path: String,
        interfaceNumber: Int,
        reportId: Int,
        buffer: ByteArray
    ) {
        if (buffer.isEmpty()) {
            throw IllegalArgumentException("Empty output report buffer: first byte must be the Report ID")
        }

        val handle = requireOpenHandle(path, interfaceNumber)
        val outEp = findInterruptEndpoint(handle.intf, UsbConstants.USB_DIR_OUT)

        if (outEp != null) {
            val payload: ByteArray
            val length: Int
            if (reportId == 0) {
                payload = buffer.copyOfRange(1, buffer.size)
                length = buffer.size - 1
            } else {
                payload = buffer
                length = buffer.size
            }
            handle.mutex.withLock {
                if (handle.closed) throw IllegalStateException("Device closed during write")
                val sent = handle.connection.bulkTransfer(
                    outEp, payload, length, DEFAULT_TRANSFER_TIMEOUT_MS
                )
                if (sent < 0) throw IllegalStateException("bulkTransfer failed with code $sent")
                if (sent != length) throw IllegalStateException("Only $sent of $length bytes sent")
            }
            return
        }

        sendControlReport(handle, HID_REPORT_TYPE_OUTPUT, reportId, buffer)
    }

    private suspend fun readFeatureReport(
        path: String,
        interfaceNumber: Int,
        reportId: Int,
        bufferSize: Int
    ): ByteArray {
        val handle = requireOpenHandle(path, interfaceNumber)
        return readControlReport(handle, HID_REPORT_TYPE_FEATURE, reportId, bufferSize.coerceAtLeast(1))
    }

    private suspend fun sendFeatureReport(
        path: String,
        interfaceNumber: Int,
        reportId: Int,
        buffer: ByteArray
    ) {
        val handle = requireOpenHandle(path, interfaceNumber)
        sendControlReport(handle, HID_REPORT_TYPE_FEATURE, reportId, buffer)
    }

    private fun transferOffsetForReport(reportId: Int): Int =
        if (reportId == 0) 1 else 0

    private fun transferLengthForReport(bufferSize: Int, reportId: Int): Int {
        val clamped = bufferSize.coerceAtLeast(0)
        if (clamped == 0) return 0
        return if (reportId == 0) (clamped - 1).coerceAtLeast(0) else clamped
    }

    private suspend fun readControlReport(
        handle: OpenHandle,
        reportType: Int,
        reportId: Int,
        bufferSize: Int
    ): ByteArray {
        if (bufferSize <= 0) return ByteArray(0)

        val buffer = ByteArray(bufferSize)
        buffer[0] = reportId.toByte()
        val offset = transferOffsetForReport(reportId)
        val length = transferLengthForReport(bufferSize, reportId)

        val received = handle.mutex.withLock {
            if (handle.closed) throw IllegalStateException("Device closed during read")
            handle.connection.controlTransfer(
                UsbConstants.USB_DIR_IN or UsbConstants.USB_TYPE_CLASS or USB_RECIPIENT_INTERFACE,
                HID_REQ_GET_REPORT,
                (reportType shl 8) or (reportId and 0xFF),
                handle.intf.id,
                buffer,
                offset,
                length,
                DEFAULT_TRANSFER_TIMEOUT_MS
            )
        }

        if (received < 0) {
            throw IllegalStateException("controlTransfer failed with code $received")
        }

        val total = if (received > 0 && reportId == 0) received + 1 else received
        return buffer.copyOf(total.coerceAtMost(buffer.size))
    }

    private suspend fun sendControlReport(
        handle: OpenHandle,
        reportType: Int,
        reportId: Int,
        buffer: ByteArray
    ) {
        val offset = transferOffsetForReport(reportId)
        val length = transferLengthForReport(buffer.size, reportId)

        val sent = handle.mutex.withLock {
            if (handle.closed) throw IllegalStateException("Device closed during write")
            handle.connection.controlTransfer(
                UsbConstants.USB_DIR_OUT or UsbConstants.USB_TYPE_CLASS or USB_RECIPIENT_INTERFACE,
                HID_REQ_SET_REPORT,
                (reportType shl 8) or (reportId and 0xFF),
                handle.intf.id,
                buffer,
                offset,
                length,
                DEFAULT_TRANSFER_TIMEOUT_MS
            )
        }

        if (sent < 0) {
            throw IllegalStateException("controlTransfer failed with code $sent")
        }
        if (sent != length) {
            throw IllegalStateException("Only $sent of $length bytes sent via controlTransfer")
        }
    }

    private suspend fun readIndexedString(
        path: String,
        interfaceNumber: Int,
        index: Int,
        maxLength: Int
    ): String {
        if (index < 0) throw IllegalArgumentException("String index must be non-negative")
        if (index == 0) return ""

        val handle = requireOpenHandle(path, interfaceNumber)
        val requestedBytes = (maxLength.coerceAtLeast(1) * 2 + 2).coerceAtMost(255)
        val descriptor = ByteArray(requestedBytes)
        val languageId = readPreferredLanguageId(handle)

        val received = handle.mutex.withLock {
            if (handle.closed) throw IllegalStateException("Device closed during read")
            handle.connection.controlTransfer(
                UsbConstants.USB_DIR_IN or UsbConstants.USB_TYPE_STANDARD,
                USB_REQUEST_GET_DESCRIPTOR,
                (USB_DESCRIPTOR_TYPE_STRING shl 8) or (index and 0xFF),
                languageId,
                descriptor,
                requestedBytes,
                DEFAULT_TRANSFER_TIMEOUT_MS
            )
        }

        if (received < 0) {
            throw IllegalStateException("Failed to read string descriptor $index")
        }
        if (received < 2 || (descriptor[1].toInt() and 0xFF) != USB_DESCRIPTOR_TYPE_STRING) {
            return ""
        }

        val descriptorLength = minOf(received, descriptor[0].toInt() and 0xFF)
        val utf16Length = (descriptorLength - 2).coerceAtLeast(0).let { it - (it and 1) }
        if (utf16Length == 0) return ""

        return String(descriptor, 2, utf16Length, Charsets.UTF_16LE)
    }

    private suspend fun readPreferredLanguageId(handle: OpenHandle): Int {
        val buffer = ByteArray(255)
        val received = handle.mutex.withLock {
            if (handle.closed) throw IllegalStateException("Device closed during read")
            handle.connection.controlTransfer(
                UsbConstants.USB_DIR_IN or UsbConstants.USB_TYPE_STANDARD,
                USB_REQUEST_GET_DESCRIPTOR,
                (USB_DESCRIPTOR_TYPE_STRING shl 8),
                0,
                buffer,
                buffer.size,
                DEFAULT_TRANSFER_TIMEOUT_MS
            )
        }

        if (received >= 4 && (buffer[1].toInt() and 0xFF) == USB_DESCRIPTOR_TYPE_STRING) {
            val low = buffer[2].toInt() and 0xFF
            val high = buffer[3].toInt() and 0xFF
            return low or (high shl 8)
        }
        return DEFAULT_USB_LANG_ID
    }
}