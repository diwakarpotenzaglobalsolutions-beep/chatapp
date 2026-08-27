import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationService {
  Future<bool> checkPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<Position> getCurrentLocation() async {
    final hasPermission = await checkPermission();
    if (!hasPermission) {
      throw Exception('Location permission not granted');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  String getStaticMapUrl(double latitude, double longitude, {String apiKey = 'YOUR_API_KEY'}) {
    // Generate a static maps API URL for displaying in message bubbles if desired
    return 'https://maps.googleapis.com/maps/api/staticmap?center=$latitude,$longitude&zoom=15&size=300x200&markers=color:red%7C$latitude,$longitude&key=$apiKey';
  }

  Future<void> openInGoogleMaps(double latitude, double longitude) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$latitude,$longitude');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Could not open map URL');
    }
  }
}
