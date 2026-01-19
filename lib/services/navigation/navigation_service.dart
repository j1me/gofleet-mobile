import 'package:url_launcher/url_launcher.dart';

/// Service for launching external navigation apps
class NavigationService {
  NavigationService._();

  /// Launch Google Maps for turn-by-turn navigation
  static Future<void> navigateToLocation({
    required double lat,
    required double lng,
    String? label,
  }) async {
    // Google Maps navigation URL scheme
    final googleMapsUrl = Uri.parse(
      'google.navigation:q=$lat,$lng&mode=d',
    );

    // Fallback to web URL if app not installed
    final webUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );

    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl);
    } else if (await canLaunchUrl(webUrl)) {
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }
  }

  /// Open location in Google Maps (view only)
  static Future<void> openInMaps({
    required double lat,
    required double lng,
    String? label,
  }) async {
    final query = label != null ? Uri.encodeComponent(label) : '$lat,$lng';
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$query',
    );
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  /// Get Google Maps URL for embedding/preview
  static String getStaticMapUrl({
    required double lat,
    required double lng,
    int zoom = 15,
    int width = 400,
    int height = 200,
    String apiKey = '',
  }) {
    return 'https://maps.googleapis.com/maps/api/staticmap'
        '?center=$lat,$lng'
        '&zoom=$zoom'
        '&size=${width}x$height'
        '&maptype=roadmap'
        '&markers=color:green%7C$lat,$lng'
        '&key=$apiKey';
  }
}
