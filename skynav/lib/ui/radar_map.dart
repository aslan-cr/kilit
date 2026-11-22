import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../services/weather_repository.dart';
import 'theme.dart';

/// RainViewer yağış radarı + gerçek taban harita (OSM) / NASA GIBS uydu görüntüsü. Karolar önbelleklenir; tek kare, hafif.
class RadarMapCard extends StatefulWidget {
  const RadarMapCard({super.key});
  @override
  State<RadarMapCard> createState() => _RadarMapCardState();
}

class _RadarMapCardState extends State<RadarMapCard> {
  bool _open = false; bool _sat = false;
  String? _radarUrl;
  String? _err;

  Future<void> _load() async {
    try {
      final r = await http.get(Uri.parse('https://api.rainviewer.com/public/weather-maps.json')).timeout(const Duration(seconds: 10));
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final host = j['host'] as String;
      final past = (j['radar']['past'] as List);
      final path = past.last['path'] as String;
      setState(() => _radarUrl = '$host$path/256/{z}/{x}/{y}/2/1_1.png');
    } catch (_) { setState(() => _err = 'Radar şu an alınamadı.'); }
  }

  @override
  Widget build(BuildContext context) {
    final p = WeatherController.I.confirmed?.place;
    final ctr = LatLng(p?.lat ?? 39.0, p?.lon ?? 35.0);
    return Glass(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (!_open) Row(children: [
        const IconBadge(Icons.radar_rounded, size: 46), const SizedBox(width: 14),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Canlı yağış radarı', style: T.h2),
          Text('RainViewer radarı + NASA uydu görüntüsü', style: T.small),
        ])),
        FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(82, 46)), onPressed: () { setState(() => _open = true); _load(); }, child: const Text('Aç')),
      ])
      else ...[
        Row(children: [
          ChoiceChip(label: const Text('Harita'), selected: !_sat, onSelected: (_) => setState(() => _sat = false)),
          const SizedBox(width: 8),
          ChoiceChip(label: const Text('NASA uydu'), selected: _sat, onSelected: (_) => setState(() => _sat = true)),
          const Spacer(),
          IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _open = false)),
        ]),
        SizedBox(height: 280, child: ClipRRect(borderRadius: BorderRadius.circular(16), child: FlutterMap(
          options: MapOptions(initialCenter: ctr, initialZoom: 6, maxZoom: 9, minZoom: 2),
          children: [
            TileLayer(
              urlTemplate: _sat
                  ? 'https://gibs.earthdata.nasa.gov/wmts/epsg3857/best/MODIS_Terra_CorrectedReflectance_TrueColor/default/GoogleMapsCompatible_Level9/{z}/{y}/{x}.jpg'
                  : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.skynav.app',
            ),
            if (_radarUrl != null) Opacity(opacity: .7, child: TileLayer(urlTemplate: _radarUrl!, userAgentPackageName: 'com.skynav.app')),
            MarkerLayer(markers: [Marker(point: ctr, width: 22, height: 22, child: const Icon(Icons.circle, color: kAccent, size: 18))]),
          ],
        ))),
        if (_err != null) Text(_err!, style: const TextStyle(fontSize: 12)),
        const Padding(padding: EdgeInsets.only(top: 8), child: Text('Mavi/yeşil: yağış (RainViewer). Uydu: NASA GIBS (MODIS).', style: T.small)),
      ],
    ]));
  }
}
