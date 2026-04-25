import Foundation

enum FuelType: String, Codable, CaseIterable, Identifiable {
    case gasoline, diesel, hybrid, electric
    var id: String { rawValue }
    var label: String {
        switch self {
        case .gasoline: return "Gasoline"
        case .diesel:   return "Diesel"
        case .hybrid:   return "Hybrid"
        case .electric: return "Electric"
        }
    }
}

enum FuelProduct: String, Codable, CaseIterable, Identifiable {
    case regular
    case midgrade
    case premium
    case diesel
    case electric
    case flexible

    var id: String { rawValue }

    var label: String {
        switch self {
        case .regular: return "Regular"
        case .midgrade: return "Midgrade"
        case .premium: return "Premium"
        case .diesel: return "Diesel"
        case .electric: return "Charge"
        case .flexible: return "Flexible"
        }
    }
}

enum FuelStationPreference: String, Codable, CaseIterable, Identifiable {
    case cheapest
    case balanced
    case premiumQuality
    case promoHunter

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cheapest: return "Cheapest"
        case .balanced: return "Balanced"
        case .premiumQuality: return "Best Quality"
        case .promoHunter: return "Best Promos"
        }
    }
}

struct VehicleProfile: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var make: String
    var model: String
    var year: Int
    var fuelType: FuelType
    var mpg: Double?
    var miPerKwh: Double?
    var brakePadsInstalledAt: Date?
    var currentOdometerMiles: Double?
    var homeArea: String?
    var preferredFuelProduct: FuelProduct = .regular
    var stationPreference: FuelStationPreference = .balanced
    var prioritizePromos: Bool = true
    var weeklyMiles: Double = 140
    var commonRoutes: [String] = []

    // MARK: - Bluetooth Auto-Trigger

    /// UUID string of the paired Bluetooth device (CBPeripheral.identifier).
    var bluetoothDeviceUUID: String?

    /// Human-readable name of the paired device shown in UI.
    var bluetoothDeviceName: String?

    var hasBluetoothPaired: Bool { bluetoothDeviceUUID != nil }

    // MARK: - Auto-Detection Settings

    /// If true, CoreMotion auto-detection is enabled for this vehicle.
    var motionAutoDetectEnabled: Bool = true

    var displayName: String { "\(year) \(make) \(model)" }
    var backendUserId: String { id.uuidString.lowercased() }

    enum CodingKeys: String, CodingKey {
        case id
        case make
        case model
        case year
        case fuelType
        case mpg
        case miPerKwh
        case brakePadsInstalledAt
        case currentOdometerMiles
        case homeArea
        case preferredFuelProduct
        case stationPreference
        case prioritizePromos
        case weeklyMiles
        case commonRoutes
        case bluetoothDeviceUUID
        case bluetoothDeviceName
        case motionAutoDetectEnabled
    }

    init(
        id: UUID = UUID(),
        make: String,
        model: String,
        year: Int,
        fuelType: FuelType,
        mpg: Double? = nil,
        miPerKwh: Double? = nil,
        brakePadsInstalledAt: Date? = nil,
        currentOdometerMiles: Double? = nil,
        homeArea: String? = nil,
        preferredFuelProduct: FuelProduct = .regular,
        stationPreference: FuelStationPreference = .balanced,
        prioritizePromos: Bool = true,
        weeklyMiles: Double = 140,
        commonRoutes: [String] = [],
        bluetoothDeviceUUID: String? = nil,
        bluetoothDeviceName: String? = nil,
        motionAutoDetectEnabled: Bool = true
    ) {
        self.id = id
        self.make = make
        self.model = model
        self.year = year
        self.fuelType = fuelType
        self.mpg = mpg
        self.miPerKwh = miPerKwh
        self.brakePadsInstalledAt = brakePadsInstalledAt
        self.currentOdometerMiles = currentOdometerMiles
        self.homeArea = homeArea
        self.preferredFuelProduct = preferredFuelProduct
        self.stationPreference = stationPreference
        self.prioritizePromos = prioritizePromos
        self.weeklyMiles = weeklyMiles
        self.commonRoutes = commonRoutes
        self.bluetoothDeviceUUID = bluetoothDeviceUUID
        self.bluetoothDeviceName = bluetoothDeviceName
        self.motionAutoDetectEnabled = motionAutoDetectEnabled
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        make = try c.decode(String.self, forKey: .make)
        model = try c.decode(String.self, forKey: .model)
        year = try c.decode(Int.self, forKey: .year)
        fuelType = try c.decode(FuelType.self, forKey: .fuelType)
        mpg = try c.decodeIfPresent(Double.self, forKey: .mpg)
        miPerKwh = try c.decodeIfPresent(Double.self, forKey: .miPerKwh)
        brakePadsInstalledAt = try c.decodeIfPresent(Date.self, forKey: .brakePadsInstalledAt)
        currentOdometerMiles = try c.decodeIfPresent(Double.self, forKey: .currentOdometerMiles)
        homeArea = try c.decodeIfPresent(String.self, forKey: .homeArea)
        preferredFuelProduct = try c.decodeIfPresent(FuelProduct.self, forKey: .preferredFuelProduct) ?? .regular
        stationPreference = try c.decodeIfPresent(FuelStationPreference.self, forKey: .stationPreference) ?? .balanced
        prioritizePromos = try c.decodeIfPresent(Bool.self, forKey: .prioritizePromos) ?? true
        weeklyMiles = try c.decodeIfPresent(Double.self, forKey: .weeklyMiles) ?? 140
        commonRoutes = try c.decodeIfPresent([String].self, forKey: .commonRoutes) ?? []
        bluetoothDeviceUUID = try c.decodeIfPresent(String.self, forKey: .bluetoothDeviceUUID)
        bluetoothDeviceName = try c.decodeIfPresent(String.self, forKey: .bluetoothDeviceName)
        motionAutoDetectEnabled = try c.decodeIfPresent(Bool.self, forKey: .motionAutoDetectEnabled) ?? true
    }
}
