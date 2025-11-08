import 'package:flutter/material.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:planit_schedule_manager/const.dart';
// You might need url_launcher to open the map link
import 'package:url_launcher/url_launcher.dart';

const String GOOGLE_API_KEY = GOOGLE_API;

class LocationInputWidget extends StatefulWidget {
  // Optional: Callback to pass selected place details back to the parent widget
  final Function(String? placeId, String? description)? onPlaceSelected;

  const LocationInputWidget({Key? key, this.onPlaceSelected}) : super(key: key);

  @override
  _LocationInputWidgetState createState() => _LocationInputWidgetState();
}

class _LocationInputWidgetState extends State<LocationInputWidget> {
  final TextEditingController _placeController = TextEditingController();
  final FocusNode _locationFocusNode = FocusNode();

  String? _selectedPlaceId;
  String? _selectedPlaceDescription;
  String? _googleMapsUrl; // To store the generated URL

  @override
  void initState() {
    super.initState();
    // Add a listener to handle clearing the text field
    _placeController.addListener(_handleTextChange);
  }

  @override
  void dispose() {
    _placeController.removeListener(_handleTextChange);
    _placeController.dispose();
    _locationFocusNode.dispose();
    super.dispose();
  }

  void _handleTextChange() {
    // If text is cleared (manually or via clear button), reset selection
    if (_placeController.text.isEmpty && _selectedPlaceId != null) {
      if (mounted) { // Ensure the widget is still in the tree
         setState(() {
          _selectedPlaceId = null;
          _selectedPlaceDescription = null;
          _googleMapsUrl = null;
          print("Place selection cleared.");
           // Optionally notify parent
          widget.onPlaceSelected?.call(null, null);
        });
      }
    }
  }

  // Function to attempt opening the generated Google Maps URL
  Future<void> _launchMapsUrl() async {
    if (_googleMapsUrl != null) {
      final Uri uri = Uri.parse(_googleMapsUrl!);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
         print('Could not launch $_googleMapsUrl');
         // Show error to user (e.g., using a SnackBar)
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Could not open map.')),
         );
      }
    } else {
       print('No map URL available to launch.');
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Please select a location first.')),
         );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Location',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 8),
        // Container for better background/border styling if needed
        Container(
           decoration: BoxDecoration(
             color: Colors.grey[100], // Example background
             borderRadius: BorderRadius.circular(8.0),
             // border: Border.all(color: Colors.grey[300]!) // Optional border
           ),
          child: GooglePlaceAutoCompleteTextField(
            textEditingController: _placeController,
            focusNode: _locationFocusNode,
            googleAPIKey: GOOGLE_API_KEY,
            inputDecoration: InputDecoration(
              hintText: 'Search Place (e.g., Petronas Towers)',
              hintStyle: TextStyle(color: Colors.grey[500]),
              prefixIcon: Icon(Icons.location_on_outlined, color: Colors.grey[500]),
              // Use suffixIcon to potentially add a map launch button if needed
              // suffixIcon: _googleMapsUrl != null
              //     ? IconButton(
              //         icon: Icon(Icons.map_outlined, color: Theme.of(context).primaryColor),
              //         tooltip: 'Open in Maps',
              //         onPressed: _launchMapsUrl,
              //       )
              //     : null, // Only show if a URL is available
              border: InputBorder.none, // Remove default border if using Container decoration
              filled: true, // Use fill color from Container or specify here
              fillColor: Colors.transparent, // Make transparent if Container handles background
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            debounceTime: 600, // Adjust debounce time as needed
            countries: ["my"], // Malaysia
            isLatLngRequired: true, // Request LatLng, useful for Place Details later
            getPlaceDetailWithLatLng: (Prediction prediction) {
               // This callback provides more details but requires an extra API call ($)
               // Usually called *after* itemClick. Good for getting coordinates directly.
               print("Place Details: ${prediction.lat} ${prediction.lng}");
               // You could store lat/lng here if needed immediately
            },
            itemClick: (Prediction prediction) {
              if (prediction.description != null && prediction.placeId != null) {
                 // 1. Update state
                 setState(() {
                   _selectedPlaceDescription = prediction.description!;
                   _selectedPlaceId = prediction.placeId!;

                   // Update the TextField
                   _placeController.text = _selectedPlaceDescription!;
                   _placeController.selection = TextSelection.fromPosition(
                      TextPosition(offset: _selectedPlaceDescription!.length),
                   );

                   // 2. Generate the *specific* Google Maps URL using Place ID
                   // This format tells Google Maps exactly which place you mean.
                   String placeIdEncoded = Uri.encodeComponent(_selectedPlaceId!);
                   // Include query for better display text in Maps, but place_id is key
                   String queryEncoded = Uri.encodeComponent(_selectedPlaceDescription!);
                   _googleMapsUrl = "https://www.google.com/maps/search/?api=1&query=$queryEncoded&query_place_id=$placeIdEncoded";

                   print("Selected Place: $_selectedPlaceDescription (ID: $_selectedPlaceId)");
                   print("Generated Google Maps URL: $_googleMapsUrl");

                   // 3. Hide keyboard and remove focus
                   _locationFocusNode.unfocus();

                   // 4. Notify parent widget (if callback provided)
                   widget.onPlaceSelected?.call(_selectedPlaceId, _selectedPlaceDescription);
                 });
              } else {
                 print("Error: Prediction data is incomplete.");
                 // Handle error (e.g., show message)
              }
            },
            itemBuilder: (context, index, Prediction prediction) {
              // Nice formatted dropdown item
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.location_on, size: 20.0, color: Colors.blueGrey),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        prediction.description ?? "",
                        style: TextStyle(fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
            seperatedBuilder: Divider(height: 1, thickness: 0.5),
            isCrossBtnShown: true, // Show the clear button
            containerHorizontalPadding: 0, // Let the InputDecoration handle padding
          ),
        ),

        // Optional: Add a button to explicitly launch the map link
         if (_googleMapsUrl != null) ...[
            SizedBox(height: 10),
            TextButton.icon(
              icon: Icon(Icons.map_outlined, size: 18),
              label: Text('Open in Google Maps'),
              onPressed: _launchMapsUrl,
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).primaryColor,
              ),
            ),
         ]

      ],
    );
  }
}