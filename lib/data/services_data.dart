import '../models/service_item.dart';

class ServicesData {
  static const items = [
    ServiceItem(
      id: 'airport',
      label: 'Airport Transfers',
      desc: 'Seamless door-to-airport pickups with real-time flight tracking and fixed pricing.',
      tags: ['Flight tracking', 'Meet & greet', 'Fixed price'],
      popular: true,
    ),
    ServiceItem(
      id: 'chauffeur',
      label: 'Premium Chauffeur',
      desc: 'Personal, discreet chauffeur service for any special occasion or VIP event.',
      tags: ['Hourly hire', 'VIP treatment', 'Privacy'],
      popular: false,
    ),
    ServiceItem(
      id: 'group',
      label: 'Group Transport',
      desc: 'Comfortable vans and minibuses for groups, events, and team transfers.',
      tags: ['Up to 8 pax', 'Event ready', 'Child seats'],
      popular: false,
    ),
    ServiceItem(
      id: 'business',
      label: 'Business Travel',
      desc: 'Punctual, professional service for corporate clients and executives.',
      tags: ['Corporate billing', 'WiFi', 'Quiet ride'],
      popular: false,
    ),
    ServiceItem(
      id: 'tours',
      label: 'Tours & Events',
      desc: 'Explore Tunisia highlights in private comfort.',
      tags: ['Hammamet', 'Carthage', 'Custom routes'],
      popular: false,
    ),
    ServiceItem(
      id: 'access',
      label: 'Accessibility',
      desc: 'Adapted transfers for passengers with reduced mobility. Comfort is our priority.',
      tags: ['Wheelchair access', 'Assistance', 'Care priority'],
      popular: false,
    ),
  ];
}