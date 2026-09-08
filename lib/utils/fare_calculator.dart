/// Centrale plek voor alle prijsberekening, zodat de schatting bij het
/// zoeken, de live meter tijdens de rit, en de uiteindelijke afrekening
/// altijd dezelfde formule gebruiken.
class FareCalculator {
  static const double baseFare = 3.0;
  static const double perKm = 2.0;
  static const double minimumFare = 5.0;

  // Wachttijd: gratis tot [freeWaitMinutes], daarna [perMinuteWaitRate]
  // per minuut. Telt vanaf het moment dat de chauffeur is gearriveerd
  // tot het moment dat de rit daadwerkelijk start.
  static const int freeWaitMinutes = 3;
  static const double perMinuteWaitRate = 3.0;

  /// Schatting op basis van de geplande route-afstand (bij het zoeken/
  /// bestellen, vóór de rit is gestart).
  static double estimateFare(double distanceKm) {
    double price = baseFare + (perKm * distanceKm);
    if (price < minimumFare) price = minimumFare;
    return price;
  }

  /// Live tarief tijdens de rit, op basis van de daadwerkelijk afgelegde
  /// GPS-afstand sinds het starten van de rit.
  static double liveFare(double distanceKm) => estimateFare(distanceKm);

  /// Wachtgeld op basis van hoelang de chauffeur op de passagier heeft
  /// moeten wachten na aankomst. Retourneert 0 binnen de gratis periode.
  static double calculateWaitCost(Duration waitDuration) {
    final waitMinutes = waitDuration.inSeconds / 60.0;
    final chargeableMinutes = waitMinutes - freeWaitMinutes;
    if (chargeableMinutes <= 0) return 0;
    return chargeableMinutes * perMinuteWaitRate;
  }
}
