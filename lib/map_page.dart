import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'emergency_contacts_page.dart';
import 'stats_page.dart';
import 'sos_history_page.dart';

class MapPage extends StatefulWidget {
  final double? focusLat;
  final double? focusLng;

  const MapPage({
    super.key,
    this.focusLat,
    this.focusLng,
  });

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();

  final List<String> safeTags = [
    "Aydınlık",
    "Kalabalık",
    "Kamera var",
    "Polis noktası var",
    "Merkezi konum",
  ];

  final List<String> unsafeTags = [
    "Tenha",
    "Sokak lambası yok",
    "Tedirgin edici insanlar",
    "Kamera yok",
    "Issız",
  ];

  String _getBadge(int markerCount) {
    if (markerCount >= 100) return "🏆 SafeHer Elçisi";
    if (markerCount >= 50) return "🥇 Güven Lideri";
    if (markerCount >= 20) return "🥈 Güven Destekçisi";
    if (markerCount >= 5) return "🥉 Topluluk Katkıcısı";
    return "👤 Yeni Üye";
  }

  String _getScoreLabel(int score) {
    if (score <= 0) return "Zayıf";
    if (score <= 5) return "Orta";
    return "Güçlü";
  }

  Color _getScoreColor(int score) {
    if (score <= 0) return Colors.red;
    if (score <= 5) return Colors.orange;
    return Colors.green;
  }

  Future<int> _getUserMarkerCount(String userId) async {

    if (userId.isEmpty) return 0;

    final snapshot = await _firestore
        .collection("locations")
        .where("userId", isEqualTo: userId)
        .get();

    return snapshot.docs.length;
  }

  void _showMarkerDetail(String docId, Map<String, dynamic> data) {

    String userId = data["userId"] ?? "";
    List tags = data["tags"] ?? [];
    int upVotes = data["upVotes"] ?? 0;
    int downVotes = data["downVotes"] ?? 0;

    showModalBottomSheet(

      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),

      builder: (_) {

        return FutureBuilder<int>(
          future: _getUserMarkerCount(userId),

          builder: (context, snapshot) {

            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            int score = upVotes - downVotes;

            bool isOwner =
                userId == _auth.currentUser?.uid;

            return Padding(

              padding:
                  const EdgeInsets.fromLTRB(16, 16, 16, 40),

              child: Column(

                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  ListTile(
                    leading: const Icon(
                      Icons.workspace_premium,
                      color: Colors.amber,
                    ),
                    title: const Text("Kullanıcı Rozeti"),
                    subtitle: Text(
                        _getBadge(snapshot.data!)),
                  ),

                  const Divider(),

                  Text(
                    data["type"] == "safe"
                        ? "🟢 Güvenli Bölge"
                        : "🔴 Güvensiz Bölge",
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 10),

                  Wrap(
                    spacing: 6,
                    children: tags
                        .map<Widget>((tag) =>
                            Chip(label: Text(tag)))
                        .toList(),
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [

                      IconButton(
                        icon: const Icon(
                          Icons.thumb_up,
                          color: Colors.green,
                        ),
                        onPressed: () {

                          _firestore
                              .collection("locations")
                              .doc(docId)
                              .update({
                            "upVotes":
                                FieldValue.increment(1),
                          });

                        },
                      ),

                      Text("$upVotes"),

                      const SizedBox(width: 20),

                      IconButton(
                        icon: const Icon(
                          Icons.thumb_down,
                          color: Colors.red,
                        ),
                        onPressed: () {

                          _firestore
                              .collection("locations")
                              .doc(docId)
                              .update({
                            "downVotes":
                                FieldValue.increment(1),
                          });

                        },
                      ),

                      Text("$downVotes"),

                    ],
                  ),

                  const SizedBox(height: 10),

                  Text(
                    "Güven Skoru: $score",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getScoreColor(score)),
                  ),

                  Text(
                    "Topluluk Değerlendirmesi: ${_getScoreLabel(score)}",
                    style: TextStyle(
                        color: _getScoreColor(score)),
                  ),

                  const SizedBox(height: 10),

                  if (isOwner)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red),
                      onPressed: () async {

                        await _firestore
                            .collection("locations")
                            .doc(docId)
                            .delete();

                        Navigator.pop(context);
                      },
                      child: const Text("Sil"),
                    )
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _selectTags(LatLng position, String type) {

    List<String> selectedTags = [];
    List<String> tags =
        type == "safe" ? safeTags : unsafeTags;

    showDialog(

      context: context,

      builder: (dialogContext) {

        return StatefulBuilder(

          builder: (context, setState) {

            return AlertDialog(

              title: const Text("Etiket Seç"),

              content: SizedBox(

                width: double.maxFinite,

                child: ListView(

                  shrinkWrap: true,

                  children: tags.map((tag) {

                    return CheckboxListTile(

                      title: Text(tag),

                      value:
                          selectedTags.contains(tag),

                      onChanged: (val) {

                        setState(() {

                          if (val == true) {
                            selectedTags.add(tag);
                          } else {
                            selectedTags.remove(tag);
                          }

                        });

                      },
                    );

                  }).toList(),
                ),
              ),

              actions: [

                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text("İptal"),
                ),

                ElevatedButton(

                  onPressed: () async {

                    final user =
                        _auth.currentUser;

                    if (user == null) return;

                    await _firestore
                        .collection("locations")
                        .add({

                      "lat": position.latitude,
                      "lng": position.longitude,
                      "type": type,
                      "tags": selectedTags,
                      "userId": user.uid,
                      "createdAt": Timestamp.now(),
                      "upVotes": 0,
                      "downVotes": 0,
                      "votedUserIds": [],

                    });

                    Navigator.pop(dialogContext);

                  },

                  child: const Text("Kaydet"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _onLongPress(LatLng position) {

    showModalBottomSheet(

      context: context,

      builder: (_) {

        return Padding(

          padding: const EdgeInsets.all(20),

          child: Row(

            children: [

              Expanded(
                child: ElevatedButton(

                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green),

                  onPressed: () {

                    Navigator.pop(context);

                    _selectTags(position, "safe");

                  },

                  child: const Text("GÜVENLİ"),
                ),
              ),

              const SizedBox(width: 20),

              Expanded(
                child: ElevatedButton(

                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red),

                  onPressed: () {

                    Navigator.pop(context);

                    _selectTags(position, "unsafe");

                  },

                  child: const Text("GÜVENSİZ"),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _searchLocation() async {

    String address =
        _searchController.text.trim();

    if (address.isEmpty) return;

    List<Location> locations =
        await locationFromAddress(address);

    final loc = locations.first;

    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(loc.latitude, loc.longitude),
        15,
      ),
    );
  }

  Future<void> _goToCurrentLocation() async {

    LocationPermission permission =
        await Geolocator.requestPermission();

    Position position =
        await Geolocator.getCurrentPosition();

    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(position.latitude,
            position.longitude),
        15,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("SafeHer"),
        actions: [

          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () {

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const EmergencyContactsPage(),
                ),
              );

            },
          ),

          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () {

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StatsPage(),
                ),
              );

            },
          ),

          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const SosHistoryPage(),
                ),
              );

            },
          ),

        ],
      ),

      body: Stack(

        children: [

          StreamBuilder<QuerySnapshot>(

            stream: _firestore
                .collection("locations")
                .snapshots(),

            builder: (context, snapshot) {

              if (!snapshot.hasData) {
                return const Center(
                  child:
                      CircularProgressIndicator(),
                );
              }

              Set<Marker> markers = {};

              for (var doc in snapshot.data!.docs) {

                final data =
                    doc.data()
                        as Map<String, dynamic>;

                if (data["lat"] == null ||
                    data["lng"] == null) continue;

                markers.add(

                  Marker(

                    markerId: MarkerId(doc.id),

                    position: LatLng(
                      data["lat"],
                      data["lng"],
                    ),

                    icon: BitmapDescriptor
                        .defaultMarkerWithHue(
                      data["type"] == "safe"
                          ? BitmapDescriptor
                              .hueGreen
                          : BitmapDescriptor
                              .hueRed,
                    ),

                    onTap: () =>
                        _showMarkerDetail(
                            doc.id, data),

                  ),
                );
              }

              return GoogleMap(

                initialCameraPosition:
                    const CameraPosition(
                  target: LatLng(
                      41.0082, 28.9784),
                  zoom: 12,
                ),

                markers: markers,

                onLongPress: _onLongPress,

                onMapCreated: (controller) {
                  _mapController = controller;
                },
              );
            },
          ),

          Positioned(

            top: 10,
            left: 15,
            right: 15,

            child: Card(

              child: Row(

                children: [

                  Expanded(
                    child: TextField(

                      controller:
                          _searchController,

                      decoration:
                          const InputDecoration(
                        hintText: "Adres ara...",
                        border:
                            InputBorder.none,
                        contentPadding:
                            EdgeInsets.all(10),
                      ),

                      onSubmitted: (_) =>
                          _searchLocation(),
                    ),
                  ),

                  IconButton(
                    icon:
                        const Icon(Icons.search),
                    onPressed:
                        _searchLocation,
                  )
                ],
              ),
            ),
          ),

          Positioned(

            bottom: 20,
            right: 15,

            child: FloatingActionButton(
              onPressed: _goToCurrentLocation,
              child:
                  const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}