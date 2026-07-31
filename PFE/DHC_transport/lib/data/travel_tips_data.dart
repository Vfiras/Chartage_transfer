import '../core/services/language_service.dart';

/// Curated highlights lifted from the AVA RAG knowledge base
/// (`backend/app/ai/knowledge/*.txt`) so the Home tab shows real, grounded
/// company information instead of filler.
///
/// Deliberately hardcoded: the knowledge base is a set of static `.txt` files
/// read by the backend's vector store, not an API surface — there is nothing to
/// fetch. Keeping a curated copy here also means the Home tab renders instantly
/// and works offline.
///
/// Long-form copy is stored bilingually **in this file** rather than in
/// `LanguageService._strings`, which holds short UI chrome. Article bodies are
/// content, not labels, and inlining them keeps each tip's EN/FR pair together
/// and reviewable side by side. The section's chrome (title, buttons, category
/// names) does live in `_strings`.
enum TravelTipCategory { faq, destinations, fleet, pricing }

class TravelTip {
  final String id;
  final TravelTipCategory category;
  final String titleEn;
  final String titleFr;
  final String summaryEn;
  final String summaryFr;
  final String bodyEn;
  final String bodyFr;

  /// Pre-filled question sent to AVA when the user taps "Ask AVA" on the tip.
  final String avaQuestionEn;
  final String avaQuestionFr;

  const TravelTip({
    required this.id,
    required this.category,
    required this.titleEn,
    required this.titleFr,
    required this.summaryEn,
    required this.summaryFr,
    required this.bodyEn,
    required this.bodyFr,
    required this.avaQuestionEn,
    required this.avaQuestionFr,
  });

  bool get _fr => LanguageService.instance.current == AppLanguage.french;

  String get title => _fr ? titleFr : titleEn;
  String get summary => _fr ? summaryFr : summaryEn;
  String get body => _fr ? bodyFr : bodyEn;
  String get avaQuestion => _fr ? avaQuestionFr : avaQuestionEn;

  /// Localized category chip label.
  String get categoryLabel {
    switch (category) {
      case TravelTipCategory.faq:
        return LanguageService.instance.t('tip_cat_faq');
      case TravelTipCategory.destinations:
        return LanguageService.instance.t('tip_cat_destinations');
      case TravelTipCategory.fleet:
        return LanguageService.instance.t('tip_cat_fleet');
      case TravelTipCategory.pricing:
        return LanguageService.instance.t('tip_cat_pricing');
    }
  }
}

const kTravelTips = <TravelTip>[
  // ── FAQ (source: ai/knowledge/faq.txt) ────────────────────────────────────
  TravelTip(
    id: 'free-waiting',
    category: TravelTipCategory.faq,
    titleEn: '1 Hour Free Airport Waiting',
    titleFr: '1 heure d attente offerte',
    summaryEn: 'Your driver waits a full hour after landing — free.',
    summaryFr: 'Votre chauffeur attend une heure apres l atterrissage — offert.',
    bodyEn:
        'You have 1 hour of free waiting time after your flight lands. Waiting '
        'time only begins once the flight has actually landed, so delays before '
        'landing are never charged.\n\nEach additional 30 minutes beyond the free '
        'hour is charged at 5 EUR (about 10 EUR per extra hour).',
    bodyFr:
        'Vous disposez d une heure d attente gratuite apres l atterrissage. Le '
        'decompte ne commence qu une fois l avion pose : les retards avant '
        'l atterrissage ne sont jamais factures.\n\nChaque tranche de 30 minutes '
        'supplementaire est facturee 5 EUR (environ 10 EUR par heure).',
    avaQuestionEn: 'How much free waiting time do I get at the airport?',
    avaQuestionFr: 'Combien de temps d attente gratuit ai-je a l aeroport ?',
  ),
  TravelTip(
    id: 'flight-delay',
    category: TravelTipCategory.faq,
    titleEn: 'We Track Your Flight',
    titleFr: 'Nous suivons votre vol',
    summaryEn: 'Delayed or early, your pickup time adjusts automatically.',
    summaryFr: 'Retard ou avance, l heure de prise en charge s ajuste.',
    bodyEn:
        'We continuously monitor flight schedules using the flight number you '
        'provide. If your flight is delayed or arrives early, we adjust your '
        'pickup time accordingly — your driver is ready when you are.',
    bodyFr:
        'Nous surveillons en continu les horaires grace au numero de vol que vous '
        'indiquez. En cas de retard ou d arrivee anticipee, l heure de prise en '
        'charge est ajustee : votre chauffeur est pret quand vous l etes.',
    avaQuestionEn: 'What happens if my flight is delayed?',
    avaQuestionFr: 'Que se passe-t-il si mon vol est retarde ?',
  ),
  TravelTip(
    id: 'free-cancellation',
    category: TravelTipCategory.faq,
    titleEn: 'Free Cancellation (24h)',
    titleFr: 'Annulation gratuite (24h)',
    summaryEn: 'Modify or cancel free of charge up to 24h before pickup.',
    summaryFr: 'Modifiez ou annulez sans frais jusqu a 24h avant.',
    bodyEn:
        'You can modify or cancel your booking up to 24 hours before your '
        'scheduled transfer, free of charge. Cancellations made less than 24 '
        'hours before pickup may be subject to charges.',
    bodyFr:
        'Vous pouvez modifier ou annuler votre reservation jusqu a 24 heures '
        'avant le transfert, sans frais. Les annulations a moins de 24 heures '
        'peuvent etre facturees.',
    avaQuestionEn: 'What is your cancellation policy?',
    avaQuestionFr: 'Quelle est votre politique d annulation ?',
  ),
  TravelTip(
    id: 'meet-driver',
    category: TravelTipCategory.faq,
    titleEn: 'Finding Your Driver',
    titleFr: 'Trouver votre chauffeur',
    summaryEn: 'Look for your name on a sign past baggage claim.',
    summaryFr: 'Cherchez votre nom sur un panneau apres les bagages.',
    bodyEn:
        'After exiting the baggage claim area at Tunis-Carthage International '
        'Airport, head towards the main terminal exit. Your driver will be '
        'waiting outside holding a sign with your name or the Carthage Transfer '
        'logo.',
    bodyFr:
        'Apres la zone de recuperation des bagages a l aeroport Tunis-Carthage, '
        'dirigez-vous vers la sortie principale du terminal. Votre chauffeur '
        'vous attend dehors avec un panneau a votre nom ou au logo Carthage '
        'Transfer.',
    avaQuestionEn: 'Where do I meet my driver at the airport?',
    avaQuestionFr: 'Ou est-ce que je retrouve mon chauffeur a l aeroport ?',
  ),

  // ── Pricing (source: ai/knowledge/pricing_policy.txt) ─────────────────────
  TravelTip(
    id: 'all-inclusive-eur',
    category: TravelTipCategory.pricing,
    titleEn: 'Transparent EUR Pricing',
    titleFr: 'Tarifs transparents en EUR',
    summaryEn: 'Every quote is all-inclusive and shown in euros.',
    summaryFr: 'Chaque devis est tout compris et affiche en euros.',
    bodyEn:
        'All Carthage Transfer prices are quoted in EUR. The price you see at '
        'booking is the price you pay — it already includes the vehicle, the '
        'chauffeur and your free waiting time.\n\nTipping is never included and '
        'is entirely at your discretion.',
    bodyFr:
        'Tous les tarifs Carthage Transfer sont indiques en EUR. Le prix affiche '
        'a la reservation est le prix paye : il inclut le vehicule, le chauffeur '
        'et le temps d attente offert.\n\nLe pourboire n est jamais inclus et '
        'reste a votre entiere discretion.',
    avaQuestionEn: 'What is included in the transfer price?',
    avaQuestionFr: 'Qu est-ce qui est inclus dans le prix du transfert ?',
  ),
  TravelTip(
    id: 'sample-routes',
    category: TravelTipCategory.pricing,
    titleEn: 'Popular Route Fares',
    titleFr: 'Tarifs des trajets populaires',
    summaryEn: 'Tunis airport to Hammamet from 30.95 EUR.',
    summaryFr: 'Aeroport de Tunis vers Hammamet des 30,95 EUR.',
    bodyEn:
        'Starting-from fares out of Tunis-Carthage Airport:\n\n'
        '- Tunis city — from 16.53 EUR\n'
        '- Bizerte — from 29.65 EUR\n'
        '- Hammamet — from 30.95 EUR\n'
        '- Sousse — from 49.21 EUR\n'
        '- Monastir — from 79.07 EUR\n\n'
        'Final fares vary with the vehicle category you choose at booking.',
    bodyFr:
        'Tarifs a partir de l aeroport Tunis-Carthage :\n\n'
        '- Tunis centre — des 16,53 EUR\n'
        '- Bizerte — des 29,65 EUR\n'
        '- Hammamet — des 30,95 EUR\n'
        '- Sousse — des 49,21 EUR\n'
        '- Monastir — des 79,07 EUR\n\n'
        'Le tarif final depend de la categorie de vehicule choisie.',
    avaQuestionEn: 'How much is a transfer from Tunis airport to Hammamet?',
    avaQuestionFr: 'Combien coute un transfert de l aeroport de Tunis a Hammamet ?',
  ),

  // ── Fleet (source: ai/knowledge/vehicles.txt) ─────────────────────────────
  TravelTip(
    id: 's-class',
    category: TravelTipCategory.fleet,
    titleEn: 'Mercedes S-Class',
    titleFr: 'Mercedes Classe S',
    summaryEn: 'The flagship — massage seats and a private rear cabin.',
    summaryFr: 'Le fleuron — sieges massants et cabine arriere privee.',
    bodyEn:
        'The flagship of the fleet. Executive seating with massage function, '
        'state-of-the-art infotainment, a private rear-cabin feel and enhanced '
        'noise isolation.\n\nCapacity: 3 passengers, 6 bags.\nIdeal for VIP '
        'clients, corporate meetings and special events.',
    bodyFr:
        'Le fleuron de la flotte. Sieges executifs avec fonction massage, '
        'systeme multimedia de pointe, ambiance de cabine arriere privee et '
        'isolation phonique renforcee.\n\nCapacite : 3 passagers, 6 bagages.\n'
        'Ideal pour les clients VIP, reunions d affaires et evenements.',
    avaQuestionEn: 'Tell me about the Mercedes S-Class',
    avaQuestionFr: 'Parlez-moi de la Mercedes Classe S',
  ),
  TravelTip(
    id: 'fleet-range',
    category: TravelTipCategory.fleet,
    titleEn: 'From Sedans to Coaches',
    titleFr: 'De la berline au autocar',
    summaryEn: 'A vehicle for every group size and luggage load.',
    summaryFr: 'Un vehicule pour chaque groupe et chaque volume.',
    bodyEn:
        'Our fleet ranges from compact sedans to large coaches — Standard Sedan, '
        'Toyota Yaris, Renault Express, Mercedes E-Class, S-Class and V-Class, '
        'VW Multivan, Toyota Hiace and Coaster.\n\nPick your category at booking '
        'and we will match your group size and luggage needs.',
    bodyFr:
        'Notre flotte va de la berline compacte a l autocar — Berline Standard, '
        'Toyota Yaris, Renault Express, Mercedes Classe E, S et V, VW Multivan, '
        'Toyota Hiace et Coaster.\n\nChoisissez votre categorie a la reservation '
        'et nous adapterons au nombre de passagers et de bagages.',
    avaQuestionEn: 'Which vehicle should I book for 6 people?',
    avaQuestionFr: 'Quel vehicule reserver pour 6 personnes ?',
  ),

  // ── Destinations (source: ai/knowledge/destinations.txt) ──────────────────
  TravelTip(
    id: 'nationwide',
    category: TravelTipCategory.destinations,
    titleEn: 'We Cover All of Tunisia',
    titleFr: 'Toute la Tunisie desservie',
    summaryEn: 'Beyond airports: intercity, tours and corporate travel.',
    summaryFr: 'Au-dela des aeroports : intercite, circuits et affaires.',
    bodyEn:
        'Beyond airport transfers we offer nationwide intercity transportation, '
        'experiential tours, corporate travel, special-event transport, '
        'chauffeur services and bus rentals across Tunisia.\n\nServed from both '
        'Tunis-Carthage and Enfidha airports.',
    bodyFr:
        'Au-dela des transferts aeroport, nous proposons le transport intercite '
        'national, des circuits, les voyages d affaires, le transport '
        'evenementiel, la mise a disposition de chauffeurs et la location '
        'd autocars.\n\nDesservi depuis les aeroports Tunis-Carthage et Enfidha.',
    avaQuestionEn: 'Which cities in Tunisia do you serve?',
    avaQuestionFr: 'Quelles villes de Tunisie desservez-vous ?',
  ),
];
