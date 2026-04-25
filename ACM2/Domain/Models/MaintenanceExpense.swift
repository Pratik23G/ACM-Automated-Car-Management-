import Foundation

struct MaintenanceExpense: Identifiable, Codable, Equatable {
    enum Category: String, Codable, CaseIterable, Identifiable {
        case oil
        case tires
        case brakes
        case battery
        case filters
        case fluids
        case parts
        case other

        var id: String { rawValue }

        var label: String {
            switch self {
            case .oil:
                return "Oil"
            case .tires:
                return "Tires"
            case .brakes:
                return "Brakes"
            case .battery:
                return "Battery"
            case .filters:
                return "Filters"
            case .fluids:
                return "Fluids"
            case .parts:
                return "Parts"
            case .other:
                return "Other"
            }
        }

        var icon: String {
            switch self {
            case .oil:
                return "drop.fill"
            case .tires:
                return "circle.hexagongrid.fill"
            case .brakes:
                return "exclamationmark.octagon.fill"
            case .battery:
                return "battery.75"
            case .filters:
                return "line.3.horizontal.decrease.circle.fill"
            case .fluids:
                return "waterbottle.fill"
            case .parts:
                return "shippingbox.fill"
            case .other:
                return "wrench.adjustable.fill"
            }
        }
    }

    var id: UUID = UUID()
    var purchasedAt: Date = Date()
    var category: Category
    var itemName: String
    var purchaseLocation: String
    var totalCost: Double
    var notes: String?
}
