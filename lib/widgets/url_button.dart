import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';


class UrlLinkButton extends StatelessWidget {
  final String url;

  const UrlLinkButton({
    super.key,
    required this.url,
  });

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Could not launch $url');
    }
  }

  // Determine the type of URL
  ({String label, IconData icon, Color color}) _getLinkProperties() {
    final uri = Uri.parse(url.toLowerCase());
    
    // Google Meet
    if (url.contains('meet.google.com')) {
      return (
        label: 'Join Meeting',
        icon: Icons.videocam_rounded,
        color: const Color(0xFF00796B),
      );
    }
    
    // Google Maps or location links
    else if (url.contains('goo.gl/maps') || 
             url.contains('google.com/maps') || 
             uri.host == 'maps.app.goo.gl') {
      return (
        label: 'Open Maps',
        icon: Icons.location_on_rounded,
        color: const Color(0xFFD93025),
      );
    }
    
    // Zoom Meeting
    else if (url.contains('zoom.us')) {
      return (
        label: 'Join Zoom',
        icon: Icons.video_camera_front_rounded,
        color: const Color(0xFF2D8CFF),
      );
    }
    
    // Microsoft Teams
    else if (url.contains('teams.microsoft.com')) {
      return (
        label: 'Join Teams',
        icon: Icons.groups_rounded,
        color: const Color(0xFF4B53BC),
      );
    }
    
    // YouTube
    else if (url.contains('youtube.com') || url.contains('youtu.be')) {
      return (
        label: 'Watch Video',
        icon: Icons.play_circle_rounded,
        color: const Color(0xFFFF0000),
      );
    }
    
    // Documents (Google Docs, Sheets, etc.)
    else if (url.contains('docs.google.com')) {
      return (
        label: 'Open Document',
        icon: Icons.description_rounded,
        color: const Color(0xFF1967D2),
      );
    }
    
    // Calendar links
    else if (url.contains('calendar.google.com')) {
      return (
        label: 'View Event',
        icon: Icons.event_rounded,
        color: const Color(0xFF1A73E8),
      );
    }
    
    // Default case
    return (
      label: 'Open Link',
      icon: Icons.open_in_new_rounded,
      color: const Color(0xFF424242),
    );
  }

  @override
  Widget build(BuildContext context) {
    final properties = _getLinkProperties();
    
    return Container(
      margin: const EdgeInsets.only(top: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _launchURL(url),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: properties.color.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  properties.icon,
                  size: 16,
                  color: properties.color,
                ),
                const SizedBox(width: 6),
                Text(
                  properties.label,
                  style: TextStyle(
                    color: properties.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
