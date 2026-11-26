import SwiftUI
import CoreBluetooth

@main struct HKWatchApp: App {
    @StateObject private var bluetooth = BluetoothManager()
    var body: some Scene { WindowGroup { ContentView().environmentObject(bluetooth) } }
}

struct Device: Identifiable {
    let id: UUID
    let name: String
    let rssi: Int
    let peripheral: CBPeripheral
}

final class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var status = "در حال بررسی بلوتوث…"
    @Published var devices: [Device] = []
    @Published var services: [String] = []
    @Published var scanning = false
    private var central: CBCentralManager!
    private var connected: CBPeripheral?
    override init() { super.init(); central = CBCentralManager(delegate: self, queue: .main) }
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn: status = "بلوتوث آماده است."
        case .poweredOff: status = "بلوتوث را روشن کنید."
        case .unauthorized: status = "اجازهٔ بلوتوث را در تنظیمات فعال کنید."
        default: status = "بلوتوث آماده نیست."
        }
    }
    func scan() {
        guard central.state == .poweredOn else { return }
        devices = []; services = []; scanning = true
        central.scanForPeripherals(withServices: nil)
        status = "در حال جست‌وجو…"
    }
    func stop() { central.stopScan(); scanning = false; status = "جست‌وجو متوقف شد." }
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name ?? "بدون نام"
        let item = Device(id: peripheral.identifier, name: name, rssi: RSSI.intValue, peripheral: peripheral)
        if let index = devices.firstIndex(where: { $0.id == item.id }) { devices[index] = item } else { devices.append(item) }
    }
    func connect(_ device: Device) {
        if scanning { stop() }
        if let previous = connected { central.cancelPeripheralConnection(previous) }
        connected = device.peripheral; services = []; device.peripheral.delegate = self
        status = "در حال اتصال به \(device.name)…"; central.connect(device.peripheral)
    }
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        status = "متصل شد؛ در حال دریافت سرویس‌ها…"; peripheral.discoverServices(nil)
    }
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        status = "اتصال ناموفق: \(error?.localizedDescription ?? "خطای نامشخص")"
    }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if connected?.identifier == peripheral.identifier { connected = nil; status = "اتصال قطع شد." }
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error { status = "خطا: \(error.localizedDescription)"; return }
        services = (peripheral.services ?? []).map { $0.uuid.uuidString }
        status = "متصل؛ \(services.count) سرویس پیدا شد."
    }
}

struct ContentView: View {
    @EnvironmentObject var bluetooth: BluetoothManager
    var body: some View {
        TabView {
            NavigationStack {
                List {
                    Section("وضعیت") {
                        Text(bluetooth.status)
                        Button(bluetooth.scanning ? "توقف جست‌وجو" : "جست‌وجو") {
                            if bluetooth.scanning { bluetooth.stop() } else { bluetooth.scan() }
                        }
                    }
                    Section("دستگاه‌ها") {
                        ForEach(bluetooth.devices) { device in
                            Button { bluetooth.connect(device) } label: {
                                VStack(alignment: .leading) {
                                    Text(device.name)
                                    Text("سیگنال: \(device.rssi) dBm").font(.caption)
                                }
                            }
                        }
                    }
                    Section("شناسه سرویس‌ها") {
                        if bluetooth.services.isEmpty { Text("هنوز سرویسی دریافت نشده است.") }
                        ForEach(bluetooth.services, id: \.self) { Text($0).font(.caption).textSelection(.enabled) }
                    }
                }.navigationTitle("اتصال ساعت")
            }.tabItem { Label("اتصال", systemImage: "applewatch") }
            NavigationStack {
                List {
                    Section("اطلاعات واردشده توسط کاربر") {
                        LabeledContent("محصول", value: "HK ONE")
                        LabeledContent("نسخه سیستم", value: "2.09")
                        LabeledContent("Kernel", value: "TG0733-2 / WF_V6")
                        LabeledContent("Firmware", value: "FW_V2.0.3")
                        LabeledContent("Bluetooth", value: "BT2.24.1")
                    }
                    Section("مدیریت سیستم") { Text("به‌روزرسانی و تغییر فریم‌ور در این نسخه فعال نیست.") }
                }.navigationTitle("سیستم ساعت")
            }.tabItem { Label("سیستم", systemImage: "gearshape") }
        }.environment(\.layoutDirection, .rightToLeft)
    }
}
