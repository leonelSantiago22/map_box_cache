import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng? myPoint;
  bool isLoading = false;
  bool showAdditionalButtons = false;
  TextEditingController searchController = TextEditingController();
  LatLng? searchLocation;
  final MapController mapController = MapController();
  List<LatLng> points = [];
  List<Marker> markers = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Open Street Map',
          style: TextStyle(fontSize: 22, color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white10,
        centerTitle: true,
      ),
      body: Center(
        child: myPoint == null
            ? ElevatedButton(
          onPressed: () {
            determineAndSetPosition();
          },
          child: const Text('Activar localización'),
        )
            : contenidodelmapa(),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const SizedBox(height: 10),
          FloatingActionButton(
            backgroundColor: Colors.blue,
            onPressed: () {
              setState(() {
                showAdditionalButtons = !showAdditionalButtons;
              });
            },
            child: Icon(Icons.map, color: Colors.white),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            backgroundColor: Colors.black,
            onPressed: () {
              mapController.move(mapController.center, mapController.zoom + 1);
            },
            child: const Icon(Icons.add, color: Colors.white),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            backgroundColor: Colors.black,
            onPressed: () {
              mapController.move(mapController.center, mapController.zoom - 1);
            },
            child: const Icon(Icons.remove, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Future<void> determineAndSetPosition() async {
    // Implementar método para determinar la posición de manera offline (por ejemplo, usando una ubicación fija)
    setState(() {
      myPoint = LatLng(37.7749, -122.4194); // Ejemplo: San Francisco, CA
    });
    mapController.move(myPoint!, 10);
  }

  Widget contenidodelmapa() {
    return Stack(
      children: [
        FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialZoom: 16,
            maxZoom: 20,
            minZoom: 1,
            initialCenter: myPoint!,
            onTap: (tapPosition, latLng) => _handleTap2(latLng),
            interactionOptions: const InteractionOptions(flags: ~InteractiveFlag.doubleTapDragZoom),
          ),
          children: [
            TileLayer(
              urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
              userAgentPackageName: 'dev.fleaflet.flutter_map.example',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: myPoint!,
                  width: 60,
                  height: 60,
                  alignment: Alignment.centerLeft,
                  child: const Icon(
                    Icons.person_pin_circle_sharp,
                    size: 60,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: points,
                  color: Colors.black,
                  strokeWidth: 5,
                ),
              ],
            ),
          ],
        ),
        Visibility(
          visible: isLoading,
          child: Container(
            color: Colors.black.withOpacity(0.5),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _handleTap2(LatLng latLng) {
    setState(() {
      if (markers.length < 6) {
        markers.add(
          Marker(
            point: latLng,
            width: 80,
            height: 80,
            child: Icon(Icons.location_on, size: 45, color: Colors.black),
          ),
        );
      }
      if (markers.length == 5) {
        Future.delayed(const Duration(milliseconds: 500), () {
          setState(() {
            isLoading = true;
          });
          _calculateRoute(markers.map((marker) => marker.point).toList());
        });
        LatLngBounds bounds = LatLngBounds.fromPoints(markers.map((marker) => marker.point).toList());
        mapController.fitBounds(bounds);
      }
    });
  }

  Future<void> _calculateRoute(List<LatLng> points) async {
    // Implementa tu propio algoritmo de cálculo de rutas aquí.
    // Por simplicidad, puedes usar un algoritmo de búsqueda voraz o Dijkstra.
    List<LatLng> routePoints = [];
    // Aquí agregamos una implementación simple.
    setState(() {
      this.points = routePoints;
      isLoading = false;
    });
  }
}
