import 'dart:convert';

import 'package:http/http.dart' as http;

const _urls = <String>[
  'https://overpass-api.de/api/interpreter',
  'https://lz4.overpass-api.de/api/interpreter',
  'https://z.overpass-api.de/api/interpreter',
];

Future<http.Response?> postOverpass(String query) async {
  for (final url in _urls) {
    try {
      final res = await http
          .post(
            Uri.parse(url),
            headers: const {
              'Accept': 'application/json',
              'User-Agent': 'SafeHer/1.0 (support: arzu@safeherapp.com)',
            },
            body: {'data': query},
          )
          .timeout(const Duration(seconds: 45));
      print('$url -> ${res.statusCode}');
      if (res.statusCode == 200) return res;
    } catch (e) {
      print('$url -> $e');
    }
  }
  return null;
}

Future<int> count(String label, String query) async {
  final res = await postOverpass(query);
  if (res == null) {
    print('$label: NO RESPONSE');
    return 0;
  }
  final body = jsonDecode(res.body) as Map<String, dynamic>;
  final elements = body['elements'] as List<dynamic>? ?? const [];
  print('$label: ${elements.length}');
  for (final e in elements.take(5)) {
    final tags = (e as Map<String, dynamic>)['tags'] as Map<String, dynamic>? ?? {};
    print('  - ${tags['name'] ?? tags['ref'] ?? tags['route_ref'] ?? '(no name)'}');
  }
  return elements.length;
}

Future<void> main() async {
  const lat = 38.3735;
  const lng = 27.2000;

  await count('bus stops', '''
[out:json][timeout:20];
(
  node["highway"="bus_stop"](around:2500,$lat,$lng);
  way["highway"="bus_stop"](around:2500,$lat,$lng);
  relation["highway"="bus_stop"](around:2500,$lat,$lng);
  node["public_transport"="platform"](around:2500,$lat,$lng);
  way["public_transport"="platform"](around:2500,$lat,$lng);
  relation["public_transport"="platform"](around:2500,$lat,$lng);
  node["amenity"="bus_station"](around:3500,$lat,$lng);
  way["amenity"="bus_station"](around:3500,$lat,$lng);
  relation["amenity"="bus_station"](around:3500,$lat,$lng);
  node["public_transport"="stop_position"](around:2500,$lat,$lng);
);
out center 80;
''');

  await count('health', '''
[out:json][timeout:25];
(
  node["amenity"="hospital"](around:50000,$lat,$lng);
  node["amenity"="clinic"](around:50000,$lat,$lng);
  node["healthcare"="hospital"](around:50000,$lat,$lng);
  node["healthcare"="clinic"](around:50000,$lat,$lng);
);
out center 40;
''');

  await count('pharmacy', '''
[out:json][timeout:25];
(
  node["amenity"="pharmacy"](around:40000,$lat,$lng);
  way["amenity"="pharmacy"](around:40000,$lat,$lng);
  relation["amenity"="pharmacy"](around:40000,$lat,$lng);
);
out center 40;
''');
}
