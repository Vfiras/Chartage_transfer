abstract final class DemoConversationRepository {
  static const _rules = <_Rule>[
    _Rule(
      keywords: ['hello', 'hi', 'hey', 'bonjour', 'salut', 'good morning', 'good afternoon', 'good evening'],
      response:
          "Good to hear from you! I'm AVA, your personal Carthage Transfer concierge. I can assist with bookings, airport transfers, vehicle selection, pricing, and anything else related to your executive journey. How may I assist you today?",
    ),
    _Rule(
      keywords: ['modify', 'change', 'update', 'reschedule', 'edit booking', 'adjust'],
      response:
          "Bookings can be modified up to 24 hours before the scheduled departure. To modify yours, go to the Trips section and tap 'Modify Booking'. You can update your pickup location, destination, date, time, and passenger count. If you need help with a specific booking, just share the reference number.",
    ),
    _Rule(
      keywords: ['cancel', 'cancellation', 'refund', 'reimburse'],
      response:
          "Of course — here's a clear breakdown of how cancellations and refunds work at Carthage Transfer:\n\n• Free cancellation — Cancel more than 24 hours before departure and you receive a full 100% refund, no questions asked.\n• Late cancellation — Within 24 hours of departure, a cancellation fee may apply based on the rules set by the administrator.\n• Refund method — Approved refunds return to your original payment method; card refunds typically settle within 5–7 business days.\n• How to cancel — Open the booking in the Trips section and tap 'Cancel Booking'. You'll receive an instant confirmation notification.\n\nWould you like me to check the cancellation window for one of your bookings?",
    ),
    _Rule(
      keywords: ['price', 'pricing', 'cost', 'fare', 'how much', 'tarif', 'rate'],
      response:
          "Our pricing is calculated based on distance, vehicle class, and time of day. Standard vehicles start at 45 TND for city transfers, while premium fleet options such as the Mercedes S-Class start at 120 TND. Night transfers and last-minute bookings may include a dynamic surcharge. Would you like a quote for a specific route?",
    ),
    _Rule(
      keywords: ['airport', 'transfer', 'pickup', 'arrival', 'flight', 'terminal', 'tun', 'monastir', 'sfax'],
      response:
          "Our airport transfer service includes real-time flight monitoring, so your chauffeur adjusts arrival time based on your actual landing. We offer meet-and-greet service inside the arrivals hall with a name card. Luggage assistance is included. Which airport and date were you considering?",
    ),
    _Rule(
      keywords: ['vehicle', 'car', 'fleet', 'mercedes', 'sedan', 'van', 'suv', 'class'],
      response:
          "We offer three vehicle classes:\n\n• Executive Sedan (Mercedes E-Class, BMW 5 Series) — up to 3 passengers\n• Premium SUV (Mercedes GLE, Range Rover) — up to 5 passengers\n• Business Van (Mercedes V-Class) — up to 7 passengers + luggage\n\nAll vehicles are less than 3 years old and professionally maintained. Which suits your needs?",
    ),
    _Rule(
      keywords: ['luggage', 'bag', 'baggage', 'suitcase', 'bagages'],
      response:
          "Each vehicle has a specified luggage capacity:\n\n• Executive Sedan — 2 large suitcases\n• Premium SUV — 4 large suitcases\n• Business Van — 7+ suitcases\n\nIf you have oversized items such as sports equipment or extra bags, I recommend booking a Business Van to ensure a comfortable ride.",
    ),
    _Rule(
      keywords: ['driver', 'chauffeur', 'who', 'professional'],
      response:
          "All Carthage Transfer chauffeurs are professionally trained, background-checked, and hold a valid commercial transport license. They are fluent in Arabic, French, and English. Your chauffeur profile, including name, photo, and vehicle plate, will be visible in the app 30 minutes before pickup.",
    ),
    _Rule(
      keywords: ['destination', 'where', 'city', 'hammamet', 'sousse', 'tunis', 'nabeul', 'marsa', 'guide'],
      response:
          "We operate transfers to all major destinations across Tunisia, including Tunis, La Marsa, Sidi Bou Said, Hammamet, Nabeul, Sousse, Monastir, Sfax, Tozeur, and more. Our Destination Guide section features curated recommendations for hotels, restaurants, and experiences at each location.",
    ),
    _Rule(
      keywords: ['round trip', 'return', 'round-trip', 'aller retour', 'back'],
      response:
          "Yes, we offer round-trip bookings with a 5% discount automatically applied. When creating a booking, toggle the 'Round Trip' option and enter your return date and time. The discount is reflected in the final price at checkout.",
    ),
    _Rule(
      keywords: ['promo', 'discount', 'code', 'voucher', 'coupon', 'reduction'],
      response:
          "Promo codes can be applied on the Checkout screen under 'Promo Code'. If you're a Gold or Platinum member, exclusive codes are sent directly to your registered email. If you have a code that isn't working, I can verify its validity — just share it with me.",
    ),
    _Rule(
      keywords: ['group', 'passenger', 'team', 'family', 'people', 'several'],
      response:
          "For groups of 4 or more passengers, I recommend our Business Van (Mercedes V-Class, capacity 7). It offers ample space for both passengers and luggage. For larger delegations, we can coordinate multiple vehicles under a single booking reference — useful for corporate events or VIP arrivals.",
    ),
    _Rule(
      keywords: ['track', 'location', 'where is', 'my ride', 'gps', 'live', 'map'],
      response:
          "You can track your chauffeur in real-time from the Trips section of the app. Tracking activates 30 minutes before your scheduled pickup. You'll see the driver's current position, vehicle details, and an estimated arrival time updated every 30 seconds.",
    ),
    _Rule(
      keywords: ['payment', 'pay', 'card', 'cash', 'bank', 'paiement'],
      response:
          "We accept the following payment methods:\n\n• Visa / Mastercard (secure Stripe processing)\n• Cash on delivery (must be selected during booking)\n• Bank transfer (for corporate accounts)\n\nAll card transactions are encrypted and PCI-DSS compliant. Would you like to set up a preferred payment method?",
    ),
    _Rule(
      keywords: ['review', 'rating', 'feedback', 'experience', 'satisfaction'],
      response:
          "After each completed transfer, you'll receive a prompt to rate your experience from 1 to 5 stars and leave an optional comment. Your feedback is reviewed by our quality team within 48 hours. Consistently high-rated chauffeurs are awarded our 'Elite Chauffeur' status.",
    ),
    _Rule(
      keywords: ['status', 'confirmed', 'pending', 'on route', 'completed'],
      response:
          "Booking statuses follow this lifecycle:\n\n• Pending — received and awaiting confirmation\n• Confirmed — chauffeur assigned and verified\n• On Route — chauffeur is en route to pickup\n• Completed — transfer finished\n\nYou'll receive a push notification for each status change. Is there a specific booking you'd like me to check?",
    ),
    _Rule(
      keywords: ['help', 'support', 'problem', 'issue', 'contact', 'assistance'],
      response:
          "I'm here to help! For urgent issues, you can also reach our team directly:\n\n• Phone: +216 71 000 000\n• WhatsApp: Instant response\n• Email: support@carthagetransfer.com\n\nOur support team is available daily from 05:00 AM to midnight. What can I help you resolve?",
    ),
  ];

  static String getResponse(String input) {
    final lower = input.toLowerCase().trim();
    for (final rule in _rules) {
      for (final kw in rule.keywords) {
        if (lower.contains(kw)) return rule.response;
      }
    }
    return "I'm here to assist with your executive travel needs. I can answer questions about bookings, airport transfers, vehicle selection, pricing, destinations, and customer support. What would you like to know?";
  }
}

class _Rule {
  final List<String> keywords;
  final String response;
  const _Rule({required this.keywords, required this.response});
}
