import Foundation

// MARK: - Catalog Entry

/// A GOTO target. The Sun is deliberately absent from the catalog so it can never be suggested or slewed to.
struct CelestialObject: Identifiable, Hashable {
    enum Kind: String {
        case moon = "Moon", planet = "Planet", star = "Star", deepSky = "Deep Sky"

        var icon: String {
            switch self {
            case .moon:    "moon.fill"
            case .planet:  "circle.circle"
            case .star:    "star.fill"
            case .deepSky: "sparkles"
            }
        }
    }

    enum Source: Hashable {
        /// Fixed J2000 position with a catalog visual magnitude.
        case fixed(Equatorial, magnitude: Double)
        /// Position and brightness computed for the current time.
        case body(Ephemeris.Body)
    }

    let name: String
    let detail: String
    let kind: Kind
    let source: Source

    var id: String { name }
}

// MARK: - Position for an Observer

/// Where a catalog object is right now for a given observer.
struct SkyPosition: Identifiable {
    let object: CelestialObject
    /// Equatorial coordinates of date (JNow); these are what get sent to the telescope.
    let equatorial: Equatorial
    let horizontal: Horizontal
    let magnitude: Double
    /// Angular distance from the Sun, in degrees.
    let sunSeparation: Double

    var id: String { object.id }

    /// Minimum distance from the Sun for any GOTO, to keep the optics well clear of it.
    static let minimumSunSeparation: Double = 15

    var isAboveHorizon: Bool { horizontal.alt > 0 }
    var isTooCloseToSun: Bool { sunSeparation < Self.minimumSunSeparation }
    var canSlew: Bool { isAboveHorizon && !isTooCloseToSun }
}

// MARK: - Sky

enum Sky {

    struct Snapshot {
        let positions: [SkyPosition]
        let sunAltitude: Double

        /// Faintest magnitude that can be seen given the sky brightness (Sun up / twilight / dark).
        var limitingMagnitude: Double {
            switch sunAltitude {
            case 0...:       -2.0
            case -6..<0:     1.0
            case -12 ..< -6: 3.5
            default:         .infinity
            }
        }

        /// Brightest objects comfortably above the horizon (≥ 10°), clear of the Sun, and bright enough to see now.
        func brightestVisible(limit: Int = 5) -> [SkyPosition] {
            positions
                .filter { $0.canSlew && $0.horizontal.alt >= 10 && $0.magnitude <= limitingMagnitude }
                .sorted { $0.magnitude < $1.magnitude }
                .prefix(limit)
                .map { $0 }
        }
    }

    static func snapshot(at date: Date, latitude: Double, longitude: Double) -> Snapshot {
        let sun = Ephemeris.sun(at: date)
        let sunAlt = Ephemeris.horizontal(sun, date: date, latitude: latitude, longitude: longitude).alt

        let positions = catalog.map { object -> SkyPosition in
            let eq: Equatorial
            let mag: Double
            switch object.source {
            case let .fixed(j2000, magnitude):
                eq = Ephemeris.precessFromJ2000(j2000, to: date)
                mag = magnitude
            case let .body(body):
                let state = Ephemeris.state(of: body, at: date, latitude: latitude, longitude: longitude)
                eq = state.position
                mag = state.magnitude
            }
            return SkyPosition(
                object: object,
                equatorial: eq,
                horizontal: Ephemeris.horizontal(eq, date: date, latitude: latitude, longitude: longitude),
                magnitude: mag,
                sunSeparation: Ephemeris.separation(eq, sun)
            )
        }
        return Snapshot(positions: positions, sunAltitude: sunAlt)
    }

    // MARK: Catalog

    private static func star(_ name: String, _ detail: String, _ ra: Double, _ dec: Double, _ mag: Double) -> CelestialObject {
        CelestialObject(name: name, detail: detail, kind: .star, source: .fixed(Equatorial(ra: ra, dec: dec), magnitude: mag))
    }

    private static func dso(_ name: String, _ detail: String, _ ra: Double, _ dec: Double, _ mag: Double) -> CelestialObject {
        CelestialObject(name: name, detail: detail, kind: .deepSky, source: .fixed(Equatorial(ra: ra, dec: dec), magnitude: mag))
    }

    /// Moon, planets, the brightest stars, and showpiece deep-sky objects. J2000 RA (hours) / Dec (degrees).
    static let catalog: [CelestialObject] = [
        CelestialObject(name: "Moon", detail: "Earth's Moon", kind: .moon, source: .body(.moon)),
        CelestialObject(name: "Mercury", detail: "Planet", kind: .planet, source: .body(.mercury)),
        CelestialObject(name: "Venus", detail: "Planet", kind: .planet, source: .body(.venus)),
        CelestialObject(name: "Mars", detail: "Planet", kind: .planet, source: .body(.mars)),
        CelestialObject(name: "Jupiter", detail: "Planet", kind: .planet, source: .body(.jupiter)),
        CelestialObject(name: "Saturn", detail: "Planet", kind: .planet, source: .body(.saturn)),
        CelestialObject(name: "Uranus", detail: "Planet", kind: .planet, source: .body(.uranus)),
        CelestialObject(name: "Neptune", detail: "Planet", kind: .planet, source: .body(.neptune)),

        star("Sirius", "Canis Major", 6.7525, -16.7161, -1.46),
        star("Canopus", "Carina", 6.3992, -52.6957, -0.74),
        star("Rigil Kentaurus", "Centaurus", 14.6600, -60.8340, -0.27),
        star("Arcturus", "Boötes", 14.2610, 19.1824, -0.05),
        star("Vega", "Lyra", 18.6156, 38.7837, 0.03),
        star("Capella", "Auriga", 5.2782, 45.9980, 0.08),
        star("Rigel", "Orion", 5.2423, -8.2016, 0.13),
        star("Procyon", "Canis Minor", 7.6550, 5.2250, 0.34),
        star("Achernar", "Eridanus", 1.6286, -57.2368, 0.46),
        star("Betelgeuse", "Orion", 5.9195, 7.4071, 0.50),
        star("Hadar", "Centaurus", 14.0637, -60.3730, 0.61),
        star("Altair", "Aquila", 19.8464, 8.8683, 0.77),
        star("Acrux", "Crux", 12.4433, -63.0991, 0.77),
        star("Aldebaran", "Taurus", 4.5987, 16.5093, 0.85),
        star("Antares", "Scorpius", 16.4901, -26.4320, 0.96),
        star("Spica", "Virgo", 13.4199, -11.1613, 0.97),
        star("Pollux", "Gemini", 7.7553, 28.0262, 1.14),
        star("Fomalhaut", "Piscis Austrinus", 22.9608, -29.6222, 1.16),
        star("Deneb", "Cygnus", 20.6905, 45.2803, 1.25),
        star("Mimosa", "Crux", 12.7954, -59.6888, 1.25),
        star("Regulus", "Leo", 10.1395, 11.9672, 1.35),
        star("Adhara", "Canis Major", 6.9771, -28.9721, 1.50),
        star("Castor", "Gemini", 7.5767, 31.8883, 1.58),
        star("Shaula", "Scorpius", 17.5601, -37.1038, 1.62),
        star("Gacrux", "Crux", 12.5194, -57.1132, 1.63),
        star("Bellatrix", "Orion", 5.4189, 6.3497, 1.64),
        star("Elnath", "Taurus", 5.4382, 28.6074, 1.65),
        star("Miaplacidus", "Carina", 9.2200, -69.7172, 1.67),
        star("Alnilam", "Orion", 5.6036, -1.2019, 1.69),
        star("Alnair", "Grus", 22.1372, -46.9610, 1.74),
        star("Alioth", "Ursa Major", 12.9005, 55.9598, 1.77),
        star("Dubhe", "Ursa Major", 11.0621, 61.7510, 1.79),
        star("Mirfak", "Perseus", 3.4054, 49.8612, 1.79),
        star("Kaus Australis", "Sagittarius", 18.4029, -34.3846, 1.85),
        star("Alkaid", "Ursa Major", 13.7923, 49.3133, 1.86),
        star("Menkalinan", "Auriga", 5.9921, 44.9474, 1.90),
        star("Alhena", "Gemini", 6.6285, 16.3993, 1.92),
        star("Peacock", "Pavo", 20.4275, -56.7351, 1.94),
        star("Polaris", "Ursa Minor", 2.5303, 89.2641, 1.98),
        star("Mirzam", "Canis Major", 6.3783, -17.9559, 1.98),
        star("Alphard", "Hydra", 9.4598, -8.6586, 1.98),
        star("Hamal", "Aries", 2.1196, 23.4624, 2.00),
        star("Nunki", "Sagittarius", 18.9211, -26.2967, 2.05),
        star("Alpheratz", "Andromeda", 0.1398, 29.0904, 2.06),
        star("Rasalhague", "Ophiuchus", 17.5822, 12.5600, 2.07),
        star("Kochab", "Ursa Minor", 14.8451, 74.1555, 2.08),
        star("Algol", "Perseus", 3.1361, 40.9556, 2.12),
        star("Denebola", "Leo", 11.8177, 14.5721, 2.13),
        star("Mizar", "Ursa Major", 13.3988, 54.9254, 2.23),
        star("Albireo", "Cygnus", 19.5121, 27.9597, 3.05),

        dso("Pleiades", "M45 · Open cluster", 3.7833, 24.1167, 1.6),
        dso("Ptolemy Cluster", "M7 · Open cluster", 17.8975, -34.7922, 3.3),
        dso("Andromeda Galaxy", "M31 · Galaxy", 0.7123, 41.2692, 3.4),
        dso("Beehive Cluster", "M44 · Open cluster", 8.6700, 19.6667, 3.7),
        dso("Double Cluster", "NGC 869/884 · Open clusters", 2.3150, 57.1333, 3.7),
        dso("Omega Centauri", "NGC 5139 · Globular cluster", 13.4466, -47.4794, 3.9),
        dso("Orion Nebula", "M42 · Nebula", 5.5881, -5.3911, 4.0),
        dso("47 Tucanae", "NGC 104 · Globular cluster", 0.4014, -72.0809, 4.1),
        dso("Sagittarius Cluster", "M22 · Globular cluster", 18.6066, -23.9048, 5.1),
        dso("Triangulum Galaxy", "M33 · Galaxy", 1.5641, 30.6602, 5.7),
        dso("Hercules Cluster", "M13 · Globular cluster", 16.6949, 36.4613, 5.8),
        dso("Lagoon Nebula", "M8 · Nebula", 18.0603, -24.3833, 6.0),
        dso("Bode's Galaxy", "M81 · Galaxy", 9.9259, 69.0653, 6.9),
        dso("Dumbbell Nebula", "M27 · Planetary nebula", 19.9934, 22.7212, 7.5),
        dso("Whirlpool Galaxy", "M51 · Galaxy", 13.4979, 47.1953, 8.4),
        dso("Ring Nebula", "M57 · Planetary nebula", 18.8933, 33.0292, 8.8),
    ]
}
