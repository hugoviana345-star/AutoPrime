import 'design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

// Troque estas coordenadas pelo endereço real da loja.
const latitudeLoja = -3.1190;
const longitudeLoja = -60.0217;
const nomeLocal = 'Ponto de referência em Manaus';

Future<void> abrirLinkMapa(BuildContext context, Uri url) async {
  try {
    final abriu = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!abriu && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o mapa externo.')));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o mapa externo.')));
    }
  }
}

void abrirRotas(BuildContext context) {
  final url = Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': '$latitudeLoja,$longitudeLoja',
  });
  abrirLinkMapa(context, url);
}

class MapaLoja extends StatelessWidget {
  final bool interativo;
  const MapaLoja({super.key, this.interativo = false});

  @override
  Widget build(BuildContext context) => FlutterMap(
    options: MapOptions(
      initialCenter: const LatLng(latitudeLoja, longitudeLoja),
      initialZoom: 15,
      minZoom: 3,
      maxZoom: 19,
      interactionOptions: InteractionOptions(
        flags: interativo
          ? InteractiveFlag.all & ~InteractiveFlag.rotate
          : InteractiveFlag.none,
      ),
    ),
    children: [
      TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.autoprime.app',
        maxNativeZoom: 19,
      ),
      MarkerLayer(markers: [
        Marker(
          point: const LatLng(latitudeLoja, longitudeLoja),
          width: 64,
          height: 64,
          child: const Tooltip(
            message: nomeLocal,
            child: Icon(Icons.location_on, color: Color(0xffd62828), size: 52),
          ),
        ),
      ]),
      Align(
        alignment: Alignment.bottomRight,
        child: Container(
          color: Colors.white,
          child: TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
            ),
            onPressed: () => abrirLinkMapa(context,
              Uri.parse('https://www.openstreetmap.org/copyright')),
            child: const Text('© OpenStreetMap contributors',
              style: TextStyle(fontSize: 11)),
          ),
        ),
      ),
    ],
  );
}

class LocalizacaoCard extends StatelessWidget {
  const LocalizacaoCard({super.key});

  @override
  Widget build(BuildContext context) => PrimeCard(
    clipBehavior: Clip.antiAlias,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Padding(
        padding: EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Localização',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text(nomeLocal),
        ]),
      ),
      // Altura definida evita erros de layout dentro da lista de Contato.
      const SizedBox(height: 280, child: MapaLoja()),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(spacing: 12, runSpacing: 12, children: [
          OutlinedButton.icon(
            onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const TelaMapa())),
            icon: const Icon(Icons.fullscreen),
            label: const Text('Ampliar mapa'),
          ),
          ElevatedButton.icon(
            onPressed: () => abrirRotas(context),
            icon: const Icon(Icons.directions_outlined),
            label: const Text('Como chegar'),
          ),
        ]),
      ),
    ]),
  );
}

class TelaMapa extends StatelessWidget {
  const TelaMapa({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Localização • AutoPrime')),
    body: const MapaLoja(interativo: true),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton.icon(
          onPressed: () => abrirRotas(context),
          icon: const Icon(Icons.directions_outlined),
          label: const Text('Como chegar'),
        ),
      ),
    ),
  );
}
