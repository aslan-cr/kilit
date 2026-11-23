import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:skynav/services/geocode_service.dart';

void main() {
  const omAgri = {
    'results': [
      {'name': 'Ağrı', 'latitude': 39.71944, 'longitude': 43.05139, 'elevation': 1640.0, 'country': 'Türkiye', 'admin1': 'Ağrı'},
      {'name': 'Doğubayazıt', 'latitude': 39.54694, 'longitude': 44.08417, 'elevation': 1625.0, 'country': 'Türkiye', 'admin1': 'Ağrı', 'admin2': 'Doğubayazıt'},
    ],
  };
  const photonAgri = {
    'features': [
      {'geometry': {'coordinates': [43.0510, 39.7190]}, 'properties': {'name': 'Ağrı', 'state': 'Ağrı', 'country': 'Türkiye'}}, // aynı yer (yinelenen)
      {'geometry': {'coordinates': [43.3, 39.9]}, 'properties': {'name': 'Taşlıçay', 'county': 'Taşlıçay', 'state': 'Ağrı', 'country': 'Türkiye'}},
    ],
  };

  test('Ağrı: Türkçe adlar, rakım, iki kaynak birleşir, yinelenen atılır', () async {
    final c = MockClient((r) async => http.Response(jsonEncode(r.url.host.contains('open-meteo') ? omAgri : photonAgri), 200,
        headers: {'content-type': 'application/json; charset=utf-8'}));
    final r = await GeocodeService(client: c).search('Ağrı');
    expect(r.map((p) => p.name).toList(), ['Ağrı', 'Doğubayazıt, Ağrı', 'Taşlıçay, Ağrı']);
    expect(r.first.elevation, 1640);
  });

  test('Türkçe harfle sonuç yoksa düz harfle yeniden dener', () async {
    final asked = <String>[];
    final c = MockClient((r) async {
      final q = r.url.queryParameters['name'] ?? r.url.queryParameters['q'] ?? '';
      asked.add(q);
      final empty = r.url.host.contains('open-meteo') ? <String, dynamic>{} : {'features': []};
      final hit = q == 'Agri' && r.url.host.contains('open-meteo');
      return http.Response(jsonEncode(hit ? omAgri : empty), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    });
    final r = await GeocodeService(client: c).search('Ağrı');
    expect(asked, containsAll(['Ağrı', 'Agri']));
    expect(r, isNotEmpty);
  });

  test('iki servise de ulaşılamazsa bağlantı yok', () async {
    final c = MockClient((r) async => throw http.ClientException('yok'));
    expect(() => GeocodeService(client: c).search('Ağrı'), throwsA(isA<GeocodeOffline>()));
  });

  test('düzleştirme', () {
    expect(GeocodeService.fold('Ağrı Doğubayazıt Şırnak Iğdır Çorum Ödemiş Üsküdar'), 'Agri Dogubayazit Sirnak Igdir Corum Odemis Uskudar');
  });
}
