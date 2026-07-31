import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/constants/maps_config.dart';
import '../../../core/services/directions_service.dart';
import '../../../core/utils/tn_locations.dart';

/// An interactive Google Map showing optional pickup and/or destination
/// markers, with a real road route drawn between them when both are known.
///
/// The road route is fetched from the Directions API the first time both
/// [pickup] and [destination] are non-null, and cached so rebuilds don't
/// re-fetch. Falls back silently to showing only markers when the API call
/// fails or no driving route exists.
///
/// Pass [height] for a fixed-size widget (e.g. in a scroll column).
/// Omit it (null) when used inside `Positioned.fill` — the widget then
/// expands to fill whatever space the parent gives it.
class RouteMapView extends StatefulWidget {
  final LatLng? pickup;
  final LatLng? destination;
  final String pickupLabel;
  final String destinationLabel;
  final double? height;
  final double borderRadius;

  const RouteMapView({
    super.key,
    this.pickup,
    this.destination,
    this.pickupLabel = 'Pickup',
    this.destinationLabel = 'Destination',
    this.height = 320,
    this.borderRadius = 28,
  });

  /// Convenience: build from free-text place strings via the curated lookup.
  factory RouteMapView.fromStrings({
    Key? key,
    String? pickup,
    String? destination,
    double? height = 320,
    double borderRadius = 28,
  }) {
    return RouteMapView(
      key: key,
      pickup: TnLocations.resolve(pickup),
      destination: TnLocations.resolve(destination),
      pickupLabel:
          (pickup == null || pickup.trim().isEmpty) ? 'Pickup' : pickup,
      destinationLabel: (destination == null || destination.trim().isEmpty)
          ? 'Destination'
          : destination,
      height: height,
      borderRadius: borderRadius,
    );
  }

  @override
  State<RouteMapView> createState() => _RouteMapViewState();
}

class _RouteMapViewState extends State<RouteMapView> {
  static const _directions = DirectionsService(kMapsApiKey);

  GoogleMapController? _controller;
  List<LatLng> _routePoints = [];
  LatLng? _cachedPickup;
  LatLng? _cachedDest;

  @override
  void initState() {
    super.initState();
    _fetchRoute();
  }

  @override
  void didUpdateWidget(RouteMapView old) {
    super.didUpdateWidget(old);
    if (old.pickup != widget.pickup || old.destination != widget.destination) {
      _fetchRoute();
      if (old.pickup != widget.pickup || old.destination != widget.destination) {
        _fitBounds();
      }
    }
  }

  Future<void> _fetchRoute() async {
    final p = widget.pickup, d = widget.destination;
    if (p == null || d == null) {
      if (mounted && _routePoints.isNotEmpty) {
        setState(() => _routePoints = []);
      }
      return;
    }
    if (p == _cachedPickup && d == _cachedDest) return;
    _cachedPickup = p;
    _cachedDest = d;
    final points = await _directions.getRoute(p, d);
    if (mounted) setState(() => _routePoints = points);
  }

  Set<Marker> get _markers {
    final markers = <Marker>{};
    if (widget.pickup != null) {
      markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: widget.pickup!,
        infoWindow: InfoWindow(title: widget.pickupLabel),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ));
    }
    if (widget.destination != null) {
      markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: widget.destination!,
        infoWindow: InfoWindow(title: widget.destinationLabel),
        icon:
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      ));
    }
    return markers;
  }

  Set<Polyline> get _polylines {
    if (_routePoints.isEmpty) return {};
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: _routePoints,
        color: const Color(0xFFC8A96B),
        width: 5,
      ),
    };
  }

  CameraPosition get _initialCamera {
    final p = widget.pickup, d = widget.destination;
    if (p != null && d != null) {
      return CameraPosition(
        target: LatLng(
            (p.latitude + d.latitude) / 2, (p.longitude + d.longitude) / 2),
        zoom: 8,
      );
    }
    final single = p ?? d;
    if (single != null) return CameraPosition(target: single, zoom: 12);
    return const CameraPosition(target: TnLocations.tunisiaCenter, zoom: 6);
  }

  Future<void> _fitBounds() async {
    final p = widget.pickup, d = widget.destination;
    if (_controller == null || p == null || d == null) return;
    final sw = LatLng(
      p.latitude < d.latitude ? p.latitude : d.latitude,
      p.longitude < d.longitude ? p.longitude : d.longitude,
    );
    final ne = LatLng(
      p.latitude > d.latitude ? p.latitude : d.latitude,
      p.longitude > d.longitude ? p.longitude : d.longitude,
    );
    await Future.delayed(const Duration(milliseconds: 350));
    try {
      await _controller!.animateCamera(
        CameraUpdate.newLatLngBounds(
            LatLngBounds(southwest: sw, northeast: ne), 60),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    Widget map = GoogleMap(
      initialCameraPosition: _initialCamera,
      markers: _markers,
      polylines: _polylines,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: true,
      mapToolbarEnabled: false,
      gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
        Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
      },
      onMapCreated: (c) {
        _controller = c;
        _fitBounds();
      },
    );

    if (widget.borderRadius > 0) {
      map = ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: map,
      );
    }

    if (widget.height != null) {
      return SizedBox(height: widget.height, child: map);
    }
    return map; // fills parent — use inside Positioned.fill
  }
}
