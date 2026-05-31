import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { english, french }

class LanguageService {
  LanguageService._();

  static final LanguageService instance = LanguageService._();

  static const _key = 'app_language';

  final ValueNotifier<AppLanguage> language =
      ValueNotifier(AppLanguage.english);

  AppLanguage get current => language.value;
  bool get isFrench => current == AppLanguage.french;
  String get code => isFrench ? 'fr' : 'en';
  String get localeName => isFrench ? 'fr_FR' : 'en_US';

  Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key);
    language.value = code == 'fr' ? AppLanguage.french : AppLanguage.english;
    Intl.defaultLocale = localeName;
  }

  Future<void> setLanguage(AppLanguage value) async {
    language.value = value;
    Intl.defaultLocale = localeName;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, value == AppLanguage.french ? 'fr' : 'en');
  }

  String languageName(AppLanguage value) {
    if (isFrench) {
      return value == AppLanguage.french ? 'Francais' : 'Anglais';
    }
    return value == AppLanguage.french ? 'French' : 'English';
  }

  AppLanguage languageFromName(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'french' || normalized == 'francais') {
      return AppLanguage.french;
    }
    return AppLanguage.english;
  }

  String t(String key, {Map<String, Object>? args}) {
    var value = (_strings[code]?[key] ?? _strings['en']?[key] ?? key);
    if (args != null) {
      for (final entry in args.entries) {
        value = value.replaceAll('{${entry.key}}', entry.value.toString());
      }
    }
    return value;
  }
}

const _strings = {
  'en': {
    'add_favorite': 'Add Favorite',
    'add_new_location': 'Add New Location',
    'address': 'Address',
    'alerts': 'Alerts',
    'alerts_empty': 'No alerts yet. Booking updates will appear here.',
    'alerts_subtitle': 'Booking updates and offers',
    'airport': 'Airport',
    'airport_service_desc': 'Meet and greet transfers',
    'available_promo_codes': 'Available Promo Codes',
    'booking_cancel_note':
        'This will mark the reservation as cancelled. Your booking history will keep the record.',
    'booking_modify_limit':
        'Modification is only allowed {hours} hours before departure.',
    'booking_minimum':
        'Bookings must be made at least {hours} hours before departure.',
    'booking_cancel_limit':
        'Cancellation is only allowed {hours} hours before departure.',
    'booking_pickup_destination_required':
        'Add pickup and destination locations.',
    'booking_return_required': 'Choose return date and time.',
    'booking_time_required': 'Choose departure date and time.',
    'bookings': 'Bookings',
    'book_transfer': 'Book your transfer',
    'business': 'Business',
    'business_service_desc': 'Executive city rides',
    'call_support': 'Call support',
    'cancel': 'Cancel',
    'canceled': 'Canceled',
    'confirm_cancellation': 'Confirm Cancellation',
    'date': 'Date',
    'custom': 'Custom',
    'departure': 'Departure',
    'destination': 'Destination',
    'destination_hint': 'Hotel, city, or address',
    'display_preferences': 'Language and display preferences',
    'done': 'DONE',
    'drivers': 'Drivers',
    'earn': 'EARN',
    'edit_profile': 'Edit Profile',
    'favorites': 'Favorites',
    'favorite_label_hint': 'Home, Work, Airport',
    'favorites_subtitle': 'Home, work, airport, and custom locations',
    'fixed': 'Fixed',
    'good_morning': 'Good morning',
    'group': 'Group',
    'group_service_desc': 'Van and family transfers',
    'guest': 'Guest',
    'guest_browsing': 'Guest browsing',
    'guest_profile': 'Guest Profile',
    'history': 'History',
    'home': 'Home',
    'instant_response': 'Instant response',
    'just_now': 'Just now',
    'label': 'Label',
    'language': 'Language',
    'licensed': 'Licensed',
    'light_mode': 'Light mode',
    'light_mode_desc': 'Bright ivory interface with gold accents',
    'login': 'Login',
    'login_or_register': 'Login or Register',
    'login_required_favorites': 'Login to save personal locations',
    'login_to_reserve': 'Login to reserve rides',
    'logout': 'Logout',
    'luggage': 'Luggage',
    'mark_all_read': 'Mark all read',
    'modify': 'Modify',
    'modify_booking': 'Modify Booking',
    'modify_booking_subtitle': 'Allowed until {hours} hours before pickup',
    'my_bookings': 'My Bookings',
    'my_bookings_desc': 'Modify, cancel, or review reservations',
    'my_rides': 'My Rides',
    'my_rides_subtitle': 'Upcoming transfers and ride history',
    'no_canceled_rides': 'No canceled rides yet.',
    'no_history_rides': 'No history rides yet.',
    'no_upcoming_rides': 'No upcoming rides yet.',
    'passengers': 'Passengers',
    'pickup': 'Pickup',
    'pickup_hint': 'Pickup location',
    'pickup_location': 'Pickup location',
    'popular_destinations': 'Popular destinations',
    'popular_destinations_subtitle': 'Airport transfers and fixed routes',
    'preferences': 'Preferences',
    'premium_rides': 'Premium rides, trusted drivers',
    'profile': 'Profile',
    'profile_subtitle': 'Account, settings, and support',
    'promo_code': 'Promo code',
    'pricing': 'Pricing',
    'reservation_update': 'Reservation update',
    'return': 'Return',
    'return_time': 'Return time',
    'rewards': 'Rewards',
    'rewards_desc': 'Promo codes and ride milestones',
    'rewards_subtitle': 'Travel more, earn more',
    'rides': 'Rides',
    'routes': 'Routes',
    'round_trip': 'Round Trip',
    'safe': 'Safe',
    'save_changes': 'Save Changes',
    'save_location': 'Save Location',
    'saved_location': 'Saved location',
    'street_hint': 'Street, area, or landmark',
    'search_book': 'Search & Book',
    'secure': 'Secure',
    'select': 'Select',
    'services': 'Services',
    'services_subtitle': 'Premium transfer options for travelers',
    'settings': 'Settings',
    'support': 'Support',
    'support_available': 'Available 24/7',
    'support_desc': '24/7 transfer assistance',
    'time': 'Time',
    'to': 'to',
    'trip_status_changed': 'Your booking status changed.',
    'upcoming': 'Upcoming',
    'vehicle_categories': 'Vehicle categories',
    'vehicle_categories_subtitle': 'Browse the fleet before booking',
    'view_all': 'View all',
    'work': 'Work',
    'your_rewards': 'Your Rewards',
    'dark_mode': 'Dark mode',
    'dark_mode_desc': 'Premium black and gold interface',
    'already_have_account': 'Already have an account? ',
    'confirm_password': 'Confirm Password',
    'continue_with': 'Or continue with',
    'create_account': 'Create Account',
    'email_or_phone': 'Email or Phone Number',
    'every_time': 'Every time.',
    'forgot_password': 'Forgot Password?',
    'full_name': 'Full Name',
    'login_subtitle': 'Login to your account',
    'no_account': "Don't have an account? ",
    'password': 'Password',
    'reset_password': 'Reset Password',
    'reset_password_body':
        'Enter your account email. The operations team will queue reset instructions.',
    'reset_password_sent':
        'Reset instructions have been queued for the admin team.',
    'send_reset_link': 'Send Reset Link',
    'signup': 'Sign Up',
    'signup_subtitle': 'Sign up to get started',
    'social_login_soon': '{provider} sign-in is coming soon.',
    'social_signup_soon': '{provider} sign-up is coming soon.',
    'terms_accept': 'I agree to the Terms & Conditions',
    'terms_required': 'Please accept the terms to continue.',
    'welcome_back': 'Welcome Back',
    'one_way': 'One Way',
    // Notifications
    'alerts_hero_subtitle':
        'Stay updated on your executive journeys and rewards.',
    'today': 'TODAY',
    'yesterday': 'YESTERDAY',
    'earlier': 'EARLIER',
    'all_clear': 'All Clear',
    'alerts_empty_subtitle':
        'No alerts at the moment.\nYour executive journeys are running smoothly.',
    'selected_count': '{count} Selected',
    'select_all': 'Select All',
    'deselect_all': 'Deselect All',
    'mark_read': 'Mark read',
    'delete_selected': 'Delete selected',
    'notification_deleted': 'Notification deleted',
    'undo': 'Undo',
    'delete': 'DELETE',
    'notification': 'Notification',
    'no_details': 'No details available.',
    'time_now': 'now',
    'time_just_now': 'Just now',
    'time_minutes_ago': '{n}m ago',
    'time_hours_ago': '{n}h ago',
    'time_yesterday': 'Yesterday',
    'time_days_ago': '{n}d ago',
    // Trips (My Rides)
    'rides_hero_subtitle':
        'Track upcoming transfers and review your ride history.',
    'no_rides_empty_action': 'Book a transfer',
    'ride_modify': 'Modify',
    'ride_cancel': 'Cancel',
    'ride_details': 'Details',
    'status_upcoming': 'Upcoming',
    'status_completed': 'Completed',
    'status_cancelled': 'Cancelled',
    'status_in_progress': 'In progress',
    // Saved (Favorites)
    'saved_hero_subtitle':
        'Quick-pick your home, work, airport, and frequent stops.',
    'no_saved_locations': 'No saved locations yet.',
    'add_first_location': 'Add your first location',
    'edit': 'Edit',
    'delete_location': 'Delete location',
    'delete_location_confirm':
        'Remove this saved location? You can always add it again.',
    'remove': 'Remove',
  },
  'fr': {
    'add_favorite': 'Ajouter un favori',
    'add_new_location': 'Ajouter une adresse',
    'address': 'Adresse',
    'alerts': 'Alertes',
    'alerts_empty':
        'Aucune alerte pour le moment. Les mises a jour apparaitront ici.',
    'alerts_subtitle': 'Mises a jour de reservation et offres',
    'airport': 'Aeroport',
    'airport_service_desc': 'Accueil et transferts aeroport',
    'available_promo_codes': 'Codes promo disponibles',
    'booking_cancel_note':
        'Cette action marquera la reservation comme annulee. Votre historique conservera cette course.',
    'booking_modify_limit':
        'La modification est possible jusqu a {hours} heures avant le depart.',
    'booking_minimum':
        'Les reservations doivent etre faites au moins {hours} heures avant le depart.',
    'booking_cancel_limit':
        'L annulation est possible jusqu a {hours} heures avant le depart.',
    'booking_pickup_destination_required':
        'Ajoutez le lieu de prise en charge et la destination.',
    'booking_return_required': 'Choisissez la date et l heure de retour.',
    'booking_time_required': 'Choisissez la date et l heure de depart.',
    'bookings': 'Reservations',
    'book_transfer': 'Reserver votre transfert',
    'business': 'Business',
    'business_service_desc': 'Trajets executifs en ville',
    'call_support': 'Appeler le support',
    'cancel': 'Annuler',
    'canceled': 'Annulees',
    'confirm_cancellation': 'Confirmer l annulation',
    'date': 'Date',
    'custom': 'Perso',
    'departure': 'Depart',
    'destination': 'Destination',
    'destination_hint': 'Hotel, ville ou adresse',
    'display_preferences': 'Langue et mode d affichage',
    'done': 'TERMINE',
    'drivers': 'pro',
    'earn': 'GAGNER',
    'edit_profile': 'Modifier le profil',
    'favorites': 'Favoris',
    'favorite_label_hint': 'Maison, Travail, Aeroport',
    'favorites_subtitle': 'Maison, travail, aeroport et adresses perso',
    'fixed': 'Prix',
    'good_morning': 'Bonjour',
    'group': 'Groupe',
    'group_service_desc': 'Vans et transferts famille',
    'guest': 'Invite',
    'guest_browsing': 'Navigation invite',
    'guest_profile': 'Profil invite',
    'history': 'Historique',
    'home': 'Accueil',
    'instant_response': 'Reponse instantanee',
    'just_now': 'A l instant',
    'label': 'Libelle',
    'language': 'Langue',
    'licensed': 'Chauffeurs',
    'light_mode': 'Mode clair',
    'light_mode_desc': 'Interface ivoire lumineuse avec accents or',
    'login': 'Connexion',
    'login_or_register': 'Connexion ou inscription',
    'login_required_favorites': 'Connectez-vous pour enregistrer vos adresses',
    'login_to_reserve': 'Connectez-vous pour reserver',
    'logout': 'Deconnexion',
    'luggage': 'Bagages',
    'mark_all_read': 'Tout marquer comme lu',
    'modify': 'Modifier',
    'modify_booking': 'Modifier la reservation',
    'modify_booking_subtitle':
        'Autorise jusqu a {hours} heures avant la prise en charge',
    'my_bookings': 'Mes reservations',
    'my_bookings_desc': 'Modifier, annuler ou consulter vos reservations',
    'my_rides': 'Mes courses',
    'my_rides_subtitle': 'Transferts a venir et historique',
    'no_canceled_rides': 'Aucune course annulee.',
    'no_history_rides': 'Aucun historique de course.',
    'no_upcoming_rides': 'Aucune course a venir.',
    'passengers': 'Passagers',
    'pickup': 'Prise en charge',
    'pickup_hint': 'Lieu de prise en charge',
    'pickup_location': 'Lieu de prise en charge',
    'popular_destinations': 'Destinations populaires',
    'popular_destinations_subtitle': 'Transferts aeroport et routes fixes',
    'preferences': 'Preferences',
    'premium_rides': 'Trajets premium, chauffeurs de confiance',
    'profile': 'Profil',
    'profile_subtitle': 'Compte, parametres et support',
    'promo_code': 'Code promo',
    'pricing': 'fixes',
    'reservation_update': 'Mise a jour de reservation',
    'return': 'Retour',
    'return_time': 'Heure retour',
    'rewards': 'Recompenses',
    'rewards_desc': 'Codes promo et objectifs de trajet',
    'rewards_subtitle': 'Voyagez plus, gagnez plus',
    'rides': 'courses',
    'routes': 'Routes',
    'round_trip': 'Aller-retour',
    'safe': 'Securise',
    'save_changes': 'Enregistrer',
    'save_location': 'Enregistrer l adresse',
    'saved_location': 'Adresse enregistree',
    'street_hint': 'Rue, zone ou point de repere',
    'search_book': 'Rechercher et reserver',
    'secure': 'premium',
    'select': 'Choisir',
    'services': 'Services',
    'services_subtitle': 'Options de transfert premium',
    'settings': 'Parametres',
    'support': 'Support',
    'support_available': 'Disponible 24/7',
    'support_desc': 'Assistance transfert 24/7',
    'time': 'Heure',
    'to': 'vers',
    'trip_status_changed': 'Le statut de votre reservation a change.',
    'upcoming': 'A venir',
    'vehicle_categories': 'Categories de vehicules',
    'vehicle_categories_subtitle': 'Parcourez la flotte avant de reserver',
    'view_all': 'Voir tout',
    'work': 'Travail',
    'your_rewards': 'Vos recompenses',
    'dark_mode': 'Mode sombre',
    'dark_mode_desc': 'Interface noire premium avec accents or',
    'already_have_account': 'Vous avez deja un compte ? ',
    'confirm_password': 'Confirmer le mot de passe',
    'continue_with': 'Ou continuer avec',
    'create_account': 'Creer un compte',
    'email_or_phone': 'Email ou numero de telephone',
    'every_time': 'A chaque trajet.',
    'forgot_password': 'Mot de passe oublie ?',
    'full_name': 'Nom complet',
    'login_subtitle': 'Connectez-vous a votre compte',
    'no_account': 'Vous n avez pas de compte ? ',
    'password': 'Mot de passe',
    'reset_password': 'Reinitialiser le mot de passe',
    'reset_password_body':
        'Entrez l email de votre compte. L equipe operations preparera les instructions.',
    'reset_password_sent':
        'Les instructions de reinitialisation ont ete transmises a l equipe admin.',
    'send_reset_link': 'Envoyer le lien',
    'signup': 'Inscription',
    'signup_subtitle': 'Inscrivez-vous pour commencer',
    'social_login_soon': 'La connexion {provider} arrive bientot.',
    'social_signup_soon': 'L inscription {provider} arrive bientot.',
    'terms_accept': 'J accepte les conditions generales',
    'terms_required': 'Veuillez accepter les conditions pour continuer.',
    'welcome_back': 'Bon retour',
    'one_way': 'Aller simple',
    // Notifications
    'alerts_hero_subtitle':
        'Suivez vos courses executives et vos recompenses.',
    'today': 'AUJOURD HUI',
    'yesterday': 'HIER',
    'earlier': 'PLUS TOT',
    'all_clear': 'Tout est calme',
    'alerts_empty_subtitle':
        'Aucune alerte pour le moment.\nVos courses executives se deroulent normalement.',
    'selected_count': '{count} selectionnee(s)',
    'select_all': 'Tout selectionner',
    'deselect_all': 'Tout deselectionner',
    'mark_read': 'Marquer lu',
    'delete_selected': 'Supprimer la selection',
    'notification_deleted': 'Notification supprimee',
    'undo': 'Annuler',
    'delete': 'SUPPRIMER',
    'notification': 'Notification',
    'no_details': 'Aucun detail disponible.',
    'time_now': 'maintenant',
    'time_just_now': 'A l instant',
    'time_minutes_ago': 'il y a {n} min',
    'time_hours_ago': 'il y a {n} h',
    'time_yesterday': 'Hier',
    'time_days_ago': 'il y a {n} j',
    // Trips (My Rides)
    'rides_hero_subtitle':
        'Suivez vos transferts a venir et consultez votre historique.',
    'no_rides_empty_action': 'Reserver un transfert',
    'ride_modify': 'Modifier',
    'ride_cancel': 'Annuler',
    'ride_details': 'Details',
    'status_upcoming': 'A venir',
    'status_completed': 'Terminee',
    'status_cancelled': 'Annulee',
    'status_in_progress': 'En cours',
    // Saved (Favorites)
    'saved_hero_subtitle':
        'Acces rapide a votre domicile, bureau, aeroport et arrets frequents.',
    'no_saved_locations': 'Aucune adresse enregistree.',
    'add_first_location': 'Ajouter votre premiere adresse',
    'edit': 'Modifier',
    'delete_location': 'Supprimer l adresse',
    'delete_location_confirm':
        'Supprimer cette adresse enregistree ? Vous pourrez toujours l ajouter a nouveau.',
    'remove': 'Supprimer',
  },
};
