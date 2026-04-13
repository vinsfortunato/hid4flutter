package com.github.vinsfortunato.hid4flutter

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import android.hardware.usb.UsbDeviceConnection
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeoutException
import java.util.concurrent.TimeUnit

/** Hid4flutterPlugin */
class Hid4flutterPlugin : FlutterPlugin, MethodCallHandler {
    companion object {
        private const val DEFAULT_TRANSFER_TIMEOUT_MS = 1000
        private const val USB_REQUEST_GET_DESCRIPTOR = 0x06
        private const val USB_DESCRIPTOR_TYPE_STRING = 0x03
        private const val DEFAULT_USB_LANG_ID = 0x0409
        private const val USB_RECIPIENT_INTERFACE = 0x01
    }

    private lateinit var channel: MethodChannel
    private lateinit var applicationContext: Context

    private val ACTION_USB_PERMISSION by lazy { "${applicationContext.packageName}.USB_PERMISSION" }

    private data class OpenHandle(
        val connection: UsbDeviceConnection,
        val intf: UsbInterface
    )

    private val openHandles = HashMap<String, OpenHandle>()

    private fun keyFor(path: String, interfaceNumber: Int): String =
        "$" + path + "#" + interfaceNumber

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "hid4flutter")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getDevices" -> {
                val vendorId = call.argument<Int>("vendorId")
                val productId = call.argument<Int>("productId")
                val devices = listHidDevices(vendorId, productId)
                result.success(devices)
            }

            "openDevice" -> {
                val path = call.argument<String>("path")
                val interfaceNumber = call.argument<Int>("interfaceNumber")
                if (path == null || interfaceNumber == null) {
                    result.error("ARGUMENT_ERROR", "Missing 'path' or 'interfaceNumber'", null)
                    return
                }
                try {
                    openHidDevice(path, interfaceNumber)
                    result.success(null)
                } catch (se: SecurityException) {
                    result.error("PERMISSION_DENIED", se.message ?: "USB permission denied", null)
                } catch (e: Exception) {
                    result.error("OPEN_FAILED", e.message ?: "Failed to open HID device", null)
                }
            }

            "closeDevice" -> {
                val path = call.argument<String>("path")
                val interfaceNumber = call.argument<Int>("interfaceNumber")
                if (path == null || interfaceNumber == null) {
                    result.error("ARGUMENT_ERROR", "Missing 'path' or 'interfaceNumber'", null)
                    return
                }
                try {
                    closeHidDevice(path, interfaceNumber)
                    result.success(null)
                } catch (e: Exception) {
                    result.error("CLOSE_FAILED", e.message ?: "Failed to close HID device", null)
                }
            }

            "sendReport" -> {
                val path = call.argument<String>("path")
                val interfaceNumber = call.argument<Int>("interfaceNumber")
                val reportId = call.argument<Int>("reportId") ?: 0
                if (path == null || interfaceNumber == null) {
                    result.error("ARGUMENT_ERROR", "Missing 'path' or 'interfaceNumber'", null)
                    return
                }
                try {
                    val raw: ByteArray? = call.argument<ByteArray>("data")
                    val payload: ByteArray = raw ?: ByteArray(0)

                    // Build buffer: first byte is reportId, followed by data bytes
                    val buffer = ByteArray(1 + payload.size)
                    buffer[0] = reportId.toByte()
                    System.arraycopy(payload, 0, buffer, 1, payload.size)

                    sendOutputReport(path, interfaceNumber, buffer)
                    result.success(null)
                } catch (e: IllegalStateException) {
                    result.error("NOT_OPEN", e.message ?: "Device/interface is not open", null)
                } catch (e: Exception) {
                    result.error("SEND_FAILED", e.message ?: "Failed to send HID report", null)
                }
            }

            "receiveReport" -> {
                val path = call.argument<String>("path")
                val interfaceNumber = call.argument<Int>("interfaceNumber")
                val reportLength = call.argument<Int>("reportLength")
                val timeoutMs = call.argument<Int>("timeoutMs") ?: 0
                if (path == null || interfaceNumber == null || reportLength == null) {
                    result.error(
                        "ARGUMENT_ERROR",
                        "Missing 'path', 'interfaceNumber', or 'reportLength'",
                        null
                    )
                    return
                }
                try {
                    result.success(readInputReport(path, interfaceNumber, reportLength, timeoutMs))
                } catch (e: TimeoutException) {
                    result.error("TIMEOUT", e.message ?: "Timed out waiting for input report", null)
                } catch (e: IllegalStateException) {
                    result.error("NOT_OPEN", e.message ?: "Device/interface is not open", null)
                } catch (e: Exception) {
                    result.error("RECEIVE_FAILED", e.message ?: "Failed to receive HID report", null)
                }
            }

            "receiveFeatureReport" -> {
                val path = call.argument<String>("path")
                val interfaceNumber = call.argument<Int>("interfaceNumber")
                val reportId = call.argument<Int>("reportId") ?: 0
                val bufferSize = call.argument<Int>("bufferSize") ?: 1024
                if (path == null || interfaceNumber == null) {
                    result.error("ARGUMENT_ERROR", "Missing 'path' or 'interfaceNumber'", null)
                    return
                }
                try {
                    result.success(readFeatureReport(path, interfaceNumber, reportId, bufferSize))
                } catch (e: IllegalStateException) {
                    result.error("NOT_OPEN", e.message ?: "Device/interface is not open", null)
                } catch (e: Exception) {
                    result.error(
                        "RECEIVE_FEATURE_FAILED",
                        e.message ?: "Failed to receive feature report",
                        null
                    )
                }
            }

            "sendFeatureReport" -> {
                val path = call.argument<String>("path")
                val interfaceNumber = call.argument<Int>("interfaceNumber")
                val reportId = call.argument<Int>("reportId") ?: 0
                if (path == null || interfaceNumber == null) {
                    result.error("ARGUMENT_ERROR", "Missing 'path' or 'interfaceNumber'", null)
                    return
                }
                try {
                    val raw: ByteArray? = call.argument<ByteArray>("data")
                    val payload: ByteArray = raw ?: ByteArray(0)
                    val buffer = ByteArray(1 + payload.size)
                    buffer[0] = reportId.toByte()
                    System.arraycopy(payload, 0, buffer, 1, payload.size)

                    sendFeatureReport(path, interfaceNumber, reportId, buffer)
                    result.success(null)
                } catch (e: IllegalStateException) {
                    result.error("NOT_OPEN", e.message ?: "Device/interface is not open", null)
                } catch (e: Exception) {
                    result.error(
                        "SEND_FEATURE_FAILED",
                        e.message ?: "Failed to send feature report",
                        null
                    )
                }
            }

            "getIndexedString" -> {
                val path = call.argument<String>("path")
                val interfaceNumber = call.argument<Int>("interfaceNumber")
                val index = call.argument<Int>("index")
                val maxLength = call.argument<Int>("maxLength") ?: 256
                if (path == null || interfaceNumber == null || index == null) {
                    result.error(
                        "ARGUMENT_ERROR",
                        "Missing 'path', 'interfaceNumber', or 'index'",
                        null
                    )
                    return
                }
                try {
                    result.success(readIndexedString(path, interfaceNumber, index, maxLength))
                } catch (e: IllegalStateException) {
                    result.error("NOT_OPEN", e.message ?: "Device/interface is not open", null)
                } catch (e: Exception) {
                    result.error(
                        "GET_STRING_FAILED",
                        e.message ?: "Failed to read indexed string",
                        null
                    )
                }
            }

            else -> result.notImplemented()
        }
    }

    private fun usbManager(): UsbManager =
        applicationContext.getSystemService(Context.USB_SERVICE) as UsbManager

    private fun listHidDevices(vendorId: Int?, productId: Int?): List<Map<String, Any>> {
        val usbManager = usbManager()
        val deviceList = usbManager.deviceList.values
        val devices = mutableListOf<Map<String, Any>>()
        for (device in deviceList) {
            val interfaceCount = device.interfaceCount
            for (i in 0 until interfaceCount) {
                val intf: UsbInterface = device.getInterface(i)
                if (intf.interfaceClass == UsbConstants.USB_CLASS_HID) {
                    if (vendorId != null && device.vendorId != vendorId) continue
                    if (productId != null && device.productId != productId) continue
                    devices.add(buildDeviceMap(device, intf, i))
                }
            }
        }
        return devices
    }

    private fun buildDeviceMap(
        device: UsbDevice,
        intf: UsbInterface,
        interfaceIndex: Int
    ): Map<String, Any> {
        val id = "${device.deviceName}#${interfaceIndex}"
        val manufacturer = try {
            device.manufacturerName ?: ""
        } catch (e: Exception) {
            ""
        }
        val serialNumber = try {
            device.serialNumber ?: ""
        } catch (e: Exception) {
            ""
        }
        val productName = device.productName ?: (device.deviceName ?: "")
        val releaseNumber = try {
            val v = device.version
            if (v != null) {
                val parts = v.split('.')
                val major = parts.getOrNull(0)?.toIntOrNull() ?: 0
                val minorStr = parts.getOrNull(1) ?: "0"
                val minor = minorStr.padEnd(2, '0').take(2).toIntOrNull() ?: 0
                major * 256 + minor
            } else 0
        } catch (e: Exception) {
            0
        }

        return hashMapOf(
            "id" to id,
            "path" to device.deviceName,
            "vendorId" to device.vendorId,
            "productId" to device.productId,
            "serialNumber" to serialNumber,
            "releaseNumber" to releaseNumber,
            "manufacturer" to manufacturer,
            "productName" to productName,
            "usagePage" to 0,
            "usage" to 0,
            "interfaceNumber" to intf.id,
            "busType" to 1
        )
    }

    private fun findDeviceByPath(path: String): UsbDevice? {
        val manager = usbManager()
        return manager.deviceList.values.firstOrNull { it.deviceName == path }
    }

    private fun requestUsbPermission(device: UsbDevice): Boolean {
        val manager = usbManager()
        if (manager.hasPermission(device)) return true

        val latch = CountDownLatch(1)
        var granted = false

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == ACTION_USB_PERMISSION) {
                    val d: UsbDevice? = intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                    if (d != null && d.deviceId == device.deviceId) {
                        granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
                        try {
                            applicationContext.unregisterReceiver(this)
                        } catch (_: Exception) {
                        }
                        latch.countDown()
                    }
                }
            }
        }

        val filter = IntentFilter(ACTION_USB_PERMISSION)
        val receiverFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            // Receiver should not be exported; we only need app/system broadcasts
            Context.RECEIVER_NOT_EXPORTED
        } else {
            0
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            applicationContext.registerReceiver(receiver, filter, receiverFlags)
        } else {
            @Suppress("DEPRECATION")
            applicationContext.registerReceiver(receiver, filter)
        }

        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        val intent = Intent(ACTION_USB_PERMISSION).setPackage(applicationContext.packageName)
        val permissionIntent = PendingIntent.getBroadcast(
            applicationContext,
            0,
            intent,
            flags
        )

        manager.requestPermission(device, permissionIntent)

        // Wait up to 5 seconds for user response
        latch.await(5, TimeUnit.SECONDS)
        return granted || manager.hasPermission(device)
    }

    private fun openHidDevice(path: String, interfaceNumber: Int) {
        val key = keyFor(path, interfaceNumber)
        if (openHandles.containsKey(key)) {
            return
        }

        val manager = usbManager()
        val device = findDeviceByPath(path)
            ?: throw IllegalArgumentException("Device not found: $path")

        if (!manager.hasPermission(device)) {
            val ok = requestUsbPermission(device)
            if (!ok) {
                throw SecurityException("Missing USB permission for device: $path")
            }
        }

        val intf = (0 until device.interfaceCount)
            .map { device.getInterface(it) }
            .firstOrNull { it.id == interfaceNumber }
            ?: throw IllegalArgumentException("Interface not found: $interfaceNumber")

        val connection = manager.openDevice(device)
            ?: throw IllegalStateException("Failed to open device: $path")

        val claimed = connection.claimInterface(intf, true)
        if (!claimed) {
            connection.close()
            throw IllegalStateException("Failed to claim interface: $interfaceNumber")
        }

        openHandles[key] = OpenHandle(connection, intf)
    }

    private fun closeHidDevice(path: String, interfaceNumber: Int) {
        val key = keyFor(path, interfaceNumber)
        val handle = openHandles.remove(key) ?: return
        try {
            handle.connection.releaseInterface(handle.intf)
        } catch (_: Exception) {
        }
        try {
            handle.connection.close()
        } catch (_: Exception) {
        }
    }

    private fun requireOpenHandle(path: String, interfaceNumber: Int): OpenHandle {
        val key = keyFor(path, interfaceNumber)
        return openHandles[key]
            ?: throw IllegalStateException("Device/interface not open: $path#$interfaceNumber")
    }

    private fun findInterruptInEndpoint(intf: UsbInterface): UsbEndpoint? {
        for (i in 0 until intf.endpointCount) {
            val ep = intf.getEndpoint(i)
            if (ep.type == UsbConstants.USB_ENDPOINT_XFER_INT &&
                ep.direction == UsbConstants.USB_DIR_IN
            ) {
                return ep
            }
        }
        return null
    }

    private fun findInterruptOutEndpoint(intf: UsbInterface): UsbEndpoint? {
        for (i in 0 until intf.endpointCount) {
            val ep = intf.getEndpoint(i)
            if (ep.type == UsbConstants.USB_ENDPOINT_XFER_INT && ep.direction == UsbConstants.USB_DIR_OUT) {
                return ep
            }
        }
        return null
    }

    private fun readInputReport(
        path: String,
        interfaceNumber: Int,
        reportLength: Int,
        timeoutMs: Int
    ): ByteArray {
        if (reportLength <= 0) {
            return ByteArray(0)
        }

        val handle = requireOpenHandle(path, interfaceNumber)
        val inEp = findInterruptInEndpoint(handle.intf)
            ?: throw IllegalStateException("No interrupt IN endpoint for $path#$interfaceNumber")
        val buffer = ByteArray(reportLength)
        val read = handle.connection.bulkTransfer(
            inEp,
            buffer,
            reportLength,
            timeoutMs.coerceAtLeast(0)
        )

        if (read < 0 || (read == 0 && timeoutMs > 0)) {
            if (timeoutMs > 0) {
                throw TimeoutException("Timed out waiting for input report")
            }
            throw IllegalStateException("Failed to read input report")
        }

        return if (read == buffer.size) buffer else buffer.copyOf(read)
    }

    private fun transferLengthForReport(bufferSize: Int, reportId: Int): Int {
        val clampedBufferSize = bufferSize.coerceAtLeast(0)
        if (clampedBufferSize == 0) {
            return 0
        }
        return if (reportId == 0) {
            (clampedBufferSize - 1).coerceAtLeast(0)
        } else {
            clampedBufferSize
        }
    }

    private fun transferOffsetForReport(reportId: Int): Int =
        if (reportId == 0) 1 else 0

    private fun readControlReport(
        handle: OpenHandle,
        reportType: Int,
        reportId: Int,
        bufferSize: Int
    ): ByteArray {
        if (bufferSize <= 0) {
            return ByteArray(0)
        }

        val buffer = ByteArray(bufferSize)
        buffer[0] = reportId.toByte()
        val offset = transferOffsetForReport(reportId)
        val length = transferLengthForReport(bufferSize, reportId)
        val received = handle.connection.controlTransfer(
            UsbConstants.USB_DIR_IN or UsbConstants.USB_TYPE_CLASS or USB_RECIPIENT_INTERFACE,
            0x01,
            (reportType shl 8) or (reportId and 0xFF),
            handle.intf.id,
            buffer,
            offset,
            length,
            DEFAULT_TRANSFER_TIMEOUT_MS
        )

        if (received < 0) {
            throw IllegalStateException("controlTransfer failed with code $received")
        }

        val total = if (received > 0 && reportId == 0) received + 1 else received
        return buffer.copyOf(total.coerceAtMost(buffer.size))
    }

    private fun sendControlReport(
        handle: OpenHandle,
        reportType: Int,
        reportId: Int,
        buffer: ByteArray
    ) {
        val offset = transferOffsetForReport(reportId)
        val length = transferLengthForReport(buffer.size, reportId)
        val sent = handle.connection.controlTransfer(
            UsbConstants.USB_DIR_OUT or UsbConstants.USB_TYPE_CLASS or USB_RECIPIENT_INTERFACE,
            0x09,
            (reportType shl 8) or (reportId and 0xFF),
            handle.intf.id,
            buffer,
            offset,
            length,
            DEFAULT_TRANSFER_TIMEOUT_MS
        )

        if (sent < 0) {
            throw IllegalStateException("controlTransfer failed with code $sent")
        }
        if (sent != length) {
            throw IllegalStateException("Only $sent of $length bytes sent via controlTransfer")
        }
    }

    private fun readFeatureReport(
        path: String,
        interfaceNumber: Int,
        reportId: Int,
        bufferSize: Int
    ): ByteArray {
        val handle = requireOpenHandle(path, interfaceNumber)
        return readControlReport(handle, 0x03, reportId, bufferSize.coerceAtLeast(1))
    }

    private fun sendFeatureReport(
        path: String,
        interfaceNumber: Int,
        reportId: Int,
        buffer: ByteArray
    ) {
        val handle = requireOpenHandle(path, interfaceNumber)
        sendControlReport(handle, 0x03, reportId, buffer)
    }

    private fun readIndexedString(
        path: String,
        interfaceNumber: Int,
        index: Int,
        maxLength: Int
    ): String {
        if (index < 0) {
            throw IllegalArgumentException("String index must be non-negative")
        }

        val handle = requireOpenHandle(path, interfaceNumber)
        val requestedBytes = (maxLength.coerceAtLeast(1) * 2 + 2).coerceAtMost(255)
        val descriptor = ByteArray(requestedBytes)
        val languageId = readPreferredLanguageId(handle.connection)
        val received = handle.connection.controlTransfer(
            UsbConstants.USB_DIR_IN or UsbConstants.USB_TYPE_STANDARD,
            USB_REQUEST_GET_DESCRIPTOR,
            (USB_DESCRIPTOR_TYPE_STRING shl 8) or (index and 0xFF),
            languageId,
            descriptor,
            requestedBytes,
            DEFAULT_TRANSFER_TIMEOUT_MS
        )

        if (received < 0) {
            throw IllegalStateException("Failed to read string descriptor $index")
        }
        if (received < 2 || descriptor[1].toInt() and 0xFF != USB_DESCRIPTOR_TYPE_STRING) {
            return ""
        }

        val descriptorLength = minOf(received, descriptor[0].toInt() and 0xFF)
        val utf16Length = (descriptorLength - 2).coerceAtLeast(0) and 0xFE
        if (utf16Length == 0) {
            return ""
        }

        return String(descriptor, 2, utf16Length, Charsets.UTF_16LE)
    }

    private fun readPreferredLanguageId(connection: UsbDeviceConnection): Int {
        val buffer = ByteArray(255)
        val received = connection.controlTransfer(
            UsbConstants.USB_DIR_IN or UsbConstants.USB_TYPE_STANDARD,
            USB_REQUEST_GET_DESCRIPTOR,
            (USB_DESCRIPTOR_TYPE_STRING shl 8),
            0,
            buffer,
            buffer.size,
            DEFAULT_TRANSFER_TIMEOUT_MS
        )

        if (received >= 4 && buffer[1].toInt() and 0xFF == USB_DESCRIPTOR_TYPE_STRING) {
            val low = buffer[2].toInt() and 0xFF
            val high = buffer[3].toInt() and 0xFF
            return low or (high shl 8)
        }

        return DEFAULT_USB_LANG_ID
    }

    private fun sendOutputReport(path: String, interfaceNumber: Int, buffer: ByteArray) {
        val handle = requireOpenHandle(path, interfaceNumber)
        val timeoutMs = DEFAULT_TRANSFER_TIMEOUT_MS

        if (buffer.isEmpty()) {
            throw IllegalArgumentException("Empty output report buffer: first byte must be the Report ID")
        }

        val reportId = buffer[0].toInt() and 0xFF
        val offset = transferOffsetForReport(reportId)
        val length = transferLengthForReport(buffer.size, reportId)

        // Send over out endpoint if available
        val outEp = findInterruptOutEndpoint(handle.intf)
        if (outEp != null) {
            val sent = handle.connection.bulkTransfer(outEp, buffer, offset, length, timeoutMs)
            if (sent < 0) {
                throw IllegalStateException("bulkTransfer failed with code $sent")
            }
            if (sent != length) {
                throw IllegalStateException("Only $sent of $length bytes sent")
            }
            return
        }

        sendControlReport(handle, 0x02, reportId, buffer)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        openHandles.values.forEach { handle ->
            try {
                handle.connection.releaseInterface(handle.intf)
            } catch (_: Exception) {
            }
            try {
                handle.connection.close()
            } catch (_: Exception) {
            }
        }
        openHandles.clear()
        channel.setMethodCallHandler(null)
    }
}
