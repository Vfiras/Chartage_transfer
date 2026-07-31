// Template for `maps_config.dart`, which is gitignored because it holds a live
// credential.
//
// Setup:
//   1. Copy this file to `maps_config.dart` in the same directory.
//   2. Replace the placeholder with your Google Maps API key.
//
// The key is used for Places Autocomplete, Places Details, and the Directions
// API, all called directly from the device. Restrict it in the Google Cloud
// console (Android app signing SHA + API restrictions) — an unrestricted key
// shipped in an app binary can be extracted and billed against.
const kMapsApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';
