package com.bitmsg.bitmsg

import android.bluetooth.*
import android.bluetooth.le.*
import android.content.Context
import android.os.ParcelUuid
import android.util.Log
import java.util.UUID

/**
 * Native BLE GATT Server (Peripheral mode).
 *
 * Advertises the bitmsg mesh service UUID and exposes:
 *   - A writable characteristic (other devices write message chunks here)
 *   - A notify characteristic (this device pushes data out to connected centrals)
 */
class BleGattServer(private val context: Context) {
    companion object {
        private const val TAG = "BleGattServer"
        val SERVICE_UUID: UUID = UUID.fromString("6269746d-7367-4000-8000-000000000001")
        val WRITE_CHAR_UUID: UUID = UUID.fromString("6269746d-7367-4000-8000-000000000002")
        val NOTIFY_CHAR_UUID: UUID = UUID.fromString("6269746d-7367-4000-8000-000000000003")
        val CCCD_UUID: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
    }

    private var bluetoothManager: BluetoothManager? = null
    private var gattServer: BluetoothGattServer? = null
    private var advertiser: BluetoothLeAdvertiser? = null
    private var isAdvertising = false

    // Track connected central devices
    private val connectedDevices = mutableMapOf<String, BluetoothDevice>()
    // Track devices subscribed to notifications
    private val subscribedDevices = mutableSetOf<String>()

    // Callbacks to Dart
    var onDataReceived: ((peerId: String, data: ByteArray) -> Unit)? = null
    var onPeerConnected: ((peerId: String) -> Unit)? = null
    var onPeerDisconnected: ((peerId: String) -> Unit)? = null

    private val gattCallback = object : BluetoothGattServerCallback() {
        override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) {
            val peerId = device.address
            when (newState) {
                BluetoothProfile.STATE_CONNECTED -> {
                    Log.d(TAG, "Central connected: $peerId")
                    connectedDevices[peerId] = device
                    onPeerConnected?.invoke(peerId)
                }
                BluetoothProfile.STATE_DISCONNECTED -> {
                    Log.d(TAG, "Central disconnected: $peerId")
                    connectedDevices.remove(peerId)
                    subscribedDevices.remove(peerId)
                    onPeerDisconnected?.invoke(peerId)
                }
            }
        }

        override fun onCharacteristicWriteRequest(
            device: BluetoothDevice,
            requestId: Int,
            characteristic: BluetoothGattCharacteristic,
            preparedWrite: Boolean,
            responseNeeded: Boolean,
            offset: Int,
            value: ByteArray?
        ) {
            if (characteristic.uuid == WRITE_CHAR_UUID && value != null) {
                Log.d(TAG, "Data received from ${device.address}: ${value.size} bytes")
                onDataReceived?.invoke(device.address, value)

                if (responseNeeded) {
                    gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
                }
            } else {
                if (responseNeeded) {
                    gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_FAILURE, 0, null)
                }
            }
        }

        override fun onDescriptorWriteRequest(
            device: BluetoothDevice,
            requestId: Int,
            descriptor: BluetoothGattDescriptor,
            preparedWrite: Boolean,
            responseNeeded: Boolean,
            offset: Int,
            value: ByteArray?
        ) {
            if (descriptor.uuid == CCCD_UUID) {
                val peerId = device.address
                if (value.contentEquals(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)) {
                    subscribedDevices.add(peerId)
                    Log.d(TAG, "Notifications enabled for $peerId")
                } else {
                    subscribedDevices.remove(peerId)
                    Log.d(TAG, "Notifications disabled for $peerId")
                }

                if (responseNeeded) {
                    gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
                }
            }
        }

        override fun onMtuChanged(device: BluetoothDevice?, mtu: Int) {
            Log.d(TAG, "MTU changed to $mtu for ${device?.address}")
        }
    }

    /**
     * Initialize the GATT server and start advertising.
     */
    fun start(): Boolean {
        try {
            bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
            val adapter = bluetoothManager?.adapter ?: return false

            if (!adapter.isEnabled) {
                Log.w(TAG, "Bluetooth is disabled")
                return false
            }

            // Open GATT server
            gattServer = bluetoothManager?.openGattServer(context, gattCallback)
            if (gattServer == null) {
                Log.w(TAG, "Cannot open GATT server")
                return false
            }

        // Build the mesh service with write + notify characteristics
        val service = BluetoothGattService(SERVICE_UUID, BluetoothGattService.SERVICE_TYPE_PRIMARY)

        val writeCharacteristic = BluetoothGattCharacteristic(
            WRITE_CHAR_UUID,
            BluetoothGattCharacteristic.PROPERTY_WRITE or BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE,
            BluetoothGattCharacteristic.PERMISSION_WRITE
        )

        val notifyCharacteristic = BluetoothGattCharacteristic(
            NOTIFY_CHAR_UUID,
            BluetoothGattCharacteristic.PROPERTY_NOTIFY or BluetoothGattCharacteristic.PROPERTY_READ,
            BluetoothGattCharacteristic.PERMISSION_READ
        )
        // Add CCCD descriptor for notification subscription
        val cccd = BluetoothGattDescriptor(
            CCCD_UUID,
            BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE
        )
        notifyCharacteristic.addDescriptor(cccd)

        service.addCharacteristic(writeCharacteristic)
        service.addCharacteristic(notifyCharacteristic)

        gattServer?.addService(service)

        // Start advertising
        advertiser = adapter.bluetoothLeAdvertiser
        startAdvertising()
        return true
        } catch (e: Exception) {
            Log.e(TAG, "Error starting BLE GATT server: ${e.message}")
            return false
        }
    }

    private fun startAdvertising() {
        if (isAdvertising) return

        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
            .setConnectable(true)
            .setTimeout(0) // Advertise indefinitely
            .build()

        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(false) // Must be false so 128-bit UUID fits within 31-byte BLE limit!
            .addServiceUuid(ParcelUuid(SERVICE_UUID))
            .build()

        val scanResponse = AdvertiseData.Builder()
            .setIncludeDeviceName(true) // Include device name in scan response packet
            .setIncludeTxPowerLevel(true)
            .build()

        advertiser?.startAdvertising(settings, data, scanResponse, advertiseCallback)
    }

    private val advertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
            isAdvertising = true
            Log.d(TAG, "BLE advertising started successfully")
        }

        override fun onStartFailure(errorCode: Int) {
            isAdvertising = false
            Log.e(TAG, "BLE advertising failed with error code: $errorCode")
        }
    }

    /**
     * Send data to a specific connected central via notification.
     */
    fun sendData(peerId: String, data: ByteArray): Boolean {
        val device = connectedDevices[peerId] ?: return false
        val service = gattServer?.getService(SERVICE_UUID) ?: return false
        val notifyChar = service.getCharacteristic(NOTIFY_CHAR_UUID) ?: return false

        notifyChar.value = data
        return gattServer?.notifyCharacteristicChanged(device, notifyChar, false) ?: false
    }

    /**
     * Broadcast data to all subscribed centrals.
     */
    fun broadcastData(data: ByteArray) {
        val service = gattServer?.getService(SERVICE_UUID) ?: return
        val notifyChar = service.getCharacteristic(NOTIFY_CHAR_UUID) ?: return

        notifyChar.value = data
        for (peerId in subscribedDevices.toList()) {
            val device = connectedDevices[peerId] ?: continue
            gattServer?.notifyCharacteristicChanged(device, notifyChar, false)
        }
    }

    /**
     * Stop advertising and close the GATT server.
     */
    fun stop() {
        if (isAdvertising) {
            advertiser?.stopAdvertising(advertiseCallback)
            isAdvertising = false
        }
        gattServer?.close()
        gattServer = null
        connectedDevices.clear()
        subscribedDevices.clear()
        Log.d(TAG, "GATT server stopped")
    }
}
