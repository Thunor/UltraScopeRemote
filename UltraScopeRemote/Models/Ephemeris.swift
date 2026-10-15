import Foundation

// MARK: - Coordinate Types

/// Equatorial coordinates: right ascension in decimal hours, declination in decimal degrees.
struct Equatorial: Hashable {
    var ra: Double
    var dec: Double
}

/// Horizontal coordinates for an observer: altitude above the horizon and azimuth (from north, eastward), both in degrees.
struct Horizontal: Hashable {
    var alt: Double
    var az: Double

    /// 16-point compass direction for the azimuth, e.g. "SE".
    var compass: String {
        let points = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                      "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        return points[Int((az / 22.5).rounded()) % 16]
    }
}

// MARK: - Ephemeris

/// Low-precision astronomy (accurate to a few arcminutes for the planets and Moon), good enough
/// to put a target in a finder or low-power eyepiece. Planet and Moon positions follow Paul
/// Schlyter's "How to compute planetary positions"; catalog positions are precessed from J2000.
/// All returned equatorial coordinates are referred to the equinox of date (JNow).
enum Ephemeris {

    enum Body: CaseIterable {
        case moon, mercury, venus, mars, jupiter, saturn, uranus, neptune
    }

    struct BodyState {
        let position: Equatorial
        let magnitude: Double
    }

    // MARK: Time and sidereal time

    /// Days since the J2000.0 epoch (JD 2451545.0).
    static func daysSinceJ2000(_ date: Date) -> Double {
        date.timeIntervalSince1970 / 86_400 + 2_440_587.5 - 2_451_545.0
    }

    /// Local sidereal time in degrees.
    static func localSiderealTime(_ date: Date, longitude: Double) -> Double {
        norm(280.46061837 + 360.98564736629 * daysSinceJ2000(date) + longitude)
    }

    // MARK: Transforms

    static func horizontal(_ eq: Equatorial, date: Date, latitude: Double, longitude: Double) -> Horizontal {
        let ha = rad(localSiderealTime(date, longitude: longitude) - eq.ra * 15)
        let dec = rad(eq.dec), phi = rad(latitude)
        let alt = asin(sin(dec) * sin(phi) + cos(dec) * cos(phi) * cos(ha))
        let az = atan2(-cos(dec) * sin(ha), sin(dec) * cos(phi) - cos(dec) * sin(phi) * cos(ha))
        return Horizontal(alt: deg(alt), az: norm(deg(az)))
    }

    /// Rigorous precession from J2000 to the equinox of `date` (Meeus, Astronomical Algorithms, eq. 21.4).
    static func precessFromJ2000(_ eq: Equatorial, to date: Date) -> Equatorial {
        let t = daysSinceJ2000(date) / 36_525
        let zeta  = rad((2306.2181 * t + 0.30188 * t * t + 0.017998 * t * t * t) / 3600)
        let z     = rad((2306.2181 * t + 1.09468 * t * t + 0.018203 * t * t * t) / 3600)
        let theta = rad((2004.3109 * t - 0.42665 * t * t - 0.041833 * t * t * t) / 3600)
        let ra = rad(eq.ra * 15), dec = rad(eq.dec)
        let a = cos(dec) * sin(ra + zeta)
        let b = cos(theta) * cos(dec) * cos(ra + zeta) - sin(theta) * sin(dec)
        let c = sin(theta) * cos(dec) * cos(ra + zeta) + cos(theta) * sin(dec)
        return Equatorial(ra: norm(deg(atan2(a, b) + z)) / 15, dec: deg(asin(c)))
    }

    /// Great-circle angle between two equatorial positions, in degrees.
    static func separation(_ a: Equatorial, _ b: Equatorial) -> Double {
        let d1 = rad(a.dec), d2 = rad(b.dec), dra = rad((a.ra - b.ra) * 15)
        let c = sin(d1) * sin(d2) + cos(d1) * cos(d2) * cos(dra)
        return deg(acos(max(-1, min(1, c))))
    }

    // MARK: Sun

    /// Geocentric position of the Sun. Used only to judge daylight and keep the telescope away from it.
    static func sun(at date: Date) -> Equatorial {
        let s = sunEcliptic(d: schlyterDay(date))
        return toEquatorial(x: s.x, y: s.y, z: 0, d: schlyterDay(date))
    }

    // MARK: Moon and planets

    /// Apparent position and visual magnitude of a solar-system body. Moon positions are
    /// topocentric (corrected for the observer's location), which matters by up to 1°.
    static func state(of body: Body, at date: Date, latitude: Double, longitude: Double) -> BodyState {
        let d = schlyterDay(date)
        let sun = sunEcliptic(d: d)

        if body == .moon {
            var (lon, lat, r) = moonEcliptic(d: d, sun: sun)
            let x = r * cos(rad(lon)) * cos(rad(lat))
            let y = r * sin(rad(lon)) * cos(rad(lat))
            let z = r * sin(rad(lat))
            // Rotate to equatorial (Earth radii), then subtract the observer's position on the globe.
            let ecl = rad(obliquity(d))
            let lst = rad(localSiderealTime(date, longitude: longitude)), phi = rad(latitude)
            let xe = x - cos(phi) * cos(lst)
            let ye = y * cos(ecl) - z * sin(ecl) - cos(phi) * sin(lst)
            let ze = y * sin(ecl) + z * cos(ecl) - sin(phi)
            let pos = Equatorial(ra: norm(deg(atan2(ye, xe))) / 15,
                                 dec: deg(atan2(ze, (xe * xe + ye * ye).squareRoot())))
            // Phase angle ≈ 180° − elongation from the Sun.
            let elong = deg(acos(cos(rad(sun.lon - lon)) * cos(rad(lat))))
            let fv = 180 - elong
            r /= 23_455 // Earth radii → AU
            let mag = 0.23 + 5 * log10(r * sun.r) + 0.026 * fv + 4.0e-9 * pow(fv, 4)
            return BodyState(position: pos, magnitude: mag)
        }

        var (lon, lat, r) = heliocentric(body, d: d)
        perturb(body, d: d, lon: &lon, lat: &lat)
        let xh = r * cos(rad(lon)) * cos(rad(lat))
        let yh = r * sin(rad(lon)) * cos(rad(lat))
        let zh = r * sin(rad(lat))
        let xg = xh + sun.x, yg = yh + sun.y, zg = zh
        let pos = toEquatorial(x: xg, y: yg, z: zg, d: d)

        // Distance from Earth and phase angle drive the brightness.
        let rg = (xg * xg + yg * yg + zg * zg).squareRoot()
        let fv = deg(acos(max(-1, min(1, (r * r + rg * rg - sun.r * sun.r) / (2 * r * rg)))))
        let base = 5 * log10(r * rg)
        let mag: Double
        switch body {
        case .mercury: mag = -0.36 + base + 0.027 * fv + 2.2e-13 * pow(fv, 6)
        case .venus:   mag = -4.34 + base + 0.013 * fv + 4.2e-7 * pow(fv, 3)
        case .mars:    mag = -1.51 + base + 0.016 * fv
        case .jupiter: mag = -9.25 + base + 0.014 * fv
        case .saturn:  mag = -9.00 + base + 0.044 * fv
        case .uranus:  mag = -7.15 + base + 0.001 * fv
        case .neptune: mag = -6.90 + base + 0.001 * fv
        case .moon:    mag = 0
        }
        return BodyState(position: pos, magnitude: mag)
    }

    // MARK: - Internals

    private struct SunEcliptic { let x, y, lon, r, meanAnomaly, meanLongitude: Double }

    /// Schlyter's day number: days since 1999 Dec 31.0 TT.
    private static func schlyterDay(_ date: Date) -> Double { daysSinceJ2000(date) + 1.5 }

    private static func obliquity(_ d: Double) -> Double { 23.4393 - 3.563e-7 * d }

    private static func sunEcliptic(d: Double) -> SunEcliptic {
        let w = 282.9404 + 4.70935e-5 * d
        let e = 0.016709 - 1.151e-9 * d
        let m = norm(356.0470 + 0.9856002585 * d)
        let (v, r) = solveKepler(m: m, e: e, a: 1)
        let lon = norm(v + w)
        return SunEcliptic(x: r * cos(rad(lon)), y: r * sin(rad(lon)), lon: lon, r: r,
                           meanAnomaly: m, meanLongitude: norm(m + w))
    }

    private static func toEquatorial(x: Double, y: Double, z: Double, d: Double) -> Equatorial {
        let ecl = rad(obliquity(d))
        let ye = y * cos(ecl) - z * sin(ecl)
        let ze = y * sin(ecl) + z * cos(ecl)
        return Equatorial(ra: norm(deg(atan2(ye, x))) / 15,
                          dec: deg(atan2(ze, (x * x + ye * ye).squareRoot())))
    }

    /// Orbital elements (N, i, w, a, e, M) for the epoch of date.
    private static func elements(_ body: Body, d: Double) -> (n: Double, i: Double, w: Double, a: Double, e: Double, m: Double) {
        switch body {
        case .mercury: return (48.3313 + 3.24587e-5 * d, 7.0047 + 5.00e-8 * d, 29.1241 + 1.01444e-5 * d,
                               0.387098, 0.205635 + 5.59e-10 * d, 168.6562 + 4.0923344368 * d)
        case .venus:   return (76.6799 + 2.46590e-5 * d, 3.3946 + 2.75e-8 * d, 54.8910 + 1.38374e-5 * d,
                               0.723330, 0.006773 - 1.302e-9 * d, 48.0052 + 1.6021302244 * d)
        case .mars:    return (49.5574 + 2.11081e-5 * d, 1.8497 - 1.78e-8 * d, 286.5016 + 2.92961e-5 * d,
                               1.523688, 0.093405 + 2.516e-9 * d, 18.6021 + 0.5240207766 * d)
        case .jupiter: return (100.4542 + 2.76854e-5 * d, 1.3030 - 1.557e-7 * d, 273.8777 + 1.64505e-5 * d,
                               5.20256, 0.048498 + 4.469e-9 * d, 19.8950 + 0.0830853001 * d)
        case .saturn:  return (113.6634 + 2.38980e-5 * d, 2.4886 - 1.081e-7 * d, 339.3939 + 2.97661e-5 * d,
                               9.55475, 0.055546 - 9.499e-9 * d, 316.9670 + 0.0334442282 * d)
        case .uranus:  return (74.0005 + 1.3978e-5 * d, 0.7733 + 1.9e-8 * d, 96.6612 + 3.0565e-5 * d,
                               19.18171 - 1.55e-8 * d, 0.047318 + 7.45e-9 * d, 142.5905 + 0.011725806 * d)
        case .neptune: return (131.7806 + 3.0173e-5 * d, 1.7700 - 2.55e-7 * d, 272.8461 - 6.027e-6 * d,
                               30.05826 + 3.313e-8 * d, 0.008606 + 2.15e-9 * d, 260.2471 + 0.005995147 * d)
        case .moon:    return (125.1228 - 0.0529538083 * d, 5.1454, 318.0634 + 0.1643573223 * d,
                               60.2666, 0.054900, 115.3654 + 13.0649929509 * d)
        }
    }

    /// Ecliptic longitude/latitude (degrees) and distance from the orbit's central body.
    private static func heliocentric(_ body: Body, d: Double) -> (lon: Double, lat: Double, r: Double) {
        let el = elements(body, d: d)
        let (v, r) = solveKepler(m: norm(el.m), e: el.e, a: el.a)
        let n = rad(el.n), i = rad(el.i), vw = rad(v + el.w)
        let x = r * (cos(n) * cos(vw) - sin(n) * sin(vw) * cos(i))
        let y = r * (sin(n) * cos(vw) + cos(n) * sin(vw) * cos(i))
        let z = r * sin(vw) * sin(i)
        return (norm(deg(atan2(y, x))), deg(atan2(z, (x * x + y * y).squareRoot())), r)
    }

    private static func moonEcliptic(d: Double, sun: SunEcliptic) -> (lon: Double, lat: Double, r: Double) {
        var (lon, lat, r) = heliocentric(.moon, d: d)
        let el = elements(.moon, d: d)
        let mm = rad(norm(el.m)), ms = rad(sun.meanAnomaly)
        let lm = norm(el.m + el.w + el.n)
        let dd = rad(lm - sun.meanLongitude)   // mean elongation
        let f = rad(lm - el.n)                 // argument of latitude
        lon += -1.274 * sin(mm - 2 * dd) + 0.658 * sin(2 * dd) - 0.186 * sin(ms)
             - 0.059 * sin(2 * mm - 2 * dd) - 0.057 * sin(mm - 2 * dd + ms) + 0.053 * sin(mm + 2 * dd)
             + 0.046 * sin(2 * dd - ms) + 0.041 * sin(mm - ms) - 0.035 * sin(dd)
             - 0.031 * sin(mm + ms) - 0.015 * sin(2 * f - 2 * dd) + 0.011 * sin(mm - 4 * dd)
        lat += -0.173 * sin(f - 2 * dd) - 0.055 * sin(mm - f - 2 * dd) - 0.046 * sin(mm + f - 2 * dd)
             + 0.033 * sin(f + 2 * dd) + 0.017 * sin(2 * mm + f)
        r += -0.58 * cos(mm - 2 * dd) - 0.46 * cos(2 * dd)
        return (norm(lon), lat, r)
    }

    /// Mutual perturbations of Jupiter, Saturn and Uranus (each term is in degrees).
    private static func perturb(_ body: Body, d: Double, lon: inout Double, lat: inout Double) {
        let mj = rad(norm(elements(.jupiter, d: d).m))
        let ms = rad(norm(elements(.saturn, d: d).m))
        let mu = rad(norm(elements(.uranus, d: d).m))
        func s(_ x: Double) -> Double { sin(x) }
        func k(_ deg: Double) -> Double { rad(deg) }
        switch body {
        case .jupiter:
            lon += -0.332 * s(2 * mj - 5 * ms - k(67.6)) - 0.056 * s(2 * mj - 2 * ms + k(21))
                 + 0.042 * s(3 * mj - 5 * ms + k(21)) - 0.036 * s(mj - 2 * ms)
                 + 0.022 * cos(mj - ms) + 0.023 * s(2 * mj - 3 * ms + k(52))
                 - 0.016 * s(mj - 5 * ms - k(69))
        case .saturn:
            lon += 0.812 * s(2 * mj - 5 * ms - k(67.6)) - 0.229 * cos(2 * mj - 4 * ms - k(2))
                 + 0.119 * s(mj - 2 * ms - k(3)) + 0.046 * s(2 * mj - 6 * ms - k(69))
                 + 0.014 * s(mj - 3 * ms + k(32))
            lat += -0.020 * cos(2 * mj - 4 * ms - k(2)) + 0.018 * s(2 * mj - 6 * ms - k(49))
        case .uranus:
            lon += 0.040 * s(ms - 2 * mu + k(6)) + 0.035 * s(ms - 3 * mu + k(33))
                 - 0.015 * s(mj - mu + k(20))
        default:
            break
        }
    }

    /// Solves Kepler's equation; returns true anomaly (degrees) and distance (units of `a`).
    private static func solveKepler(m: Double, e: Double, a: Double) -> (v: Double, r: Double) {
        let mr = rad(m)
        var ecc = mr + e * sin(mr) * (1 + e * cos(mr))
        for _ in 0..<8 {
            ecc -= (ecc - e * sin(ecc) - mr) / (1 - e * cos(ecc))
        }
        let xv = a * (cos(ecc) - e)
        let yv = a * (1 - e * e).squareRoot() * sin(ecc)
        return (norm(deg(atan2(yv, xv))), (xv * xv + yv * yv).squareRoot())
    }

    private static func rad(_ d: Double) -> Double { d * .pi / 180 }
    private static func deg(_ r: Double) -> Double { r * 180 / .pi }
    private static func norm(_ x: Double) -> Double {
        let r = x.truncatingRemainder(dividingBy: 360)
        return r < 0 ? r + 360 : r
    }
}
