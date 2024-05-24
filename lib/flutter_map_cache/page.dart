import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:mapbox_map/common/attribution_widget.dart';
import 'package:mapbox_map/flutter_map_cache/cache_store_types.dart';
import 'package:mapbox_map/flutter_map_cache/connectivity_icon.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:open_route_service/open_route_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_compass/flutter_compass.dart';

class FlutterMapCachePage extends StatefulWidget {
  const FlutterMapCachePage({super.key});

  @override
  State<FlutterMapCachePage> createState() => _FlutterMapCachePageState();
}

class _FlutterMapCachePageState extends State<FlutterMapCachePage> {
  CacheStore _cacheStore = MemCacheStore();
  final _dio = Dio();
  LatLng? myPoint;
  bool isLoading = false;
  late MapController mapController;

  Future<void> determineAndSetPosition() async {
    LocationPermission permission;
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw 'Location permission denied';
      }
    }
    final Position position = await Geolocator.getCurrentPosition();
    setState(() {
      myPoint = LatLng(position.latitude, position.longitude);
      print(myPoint);
    });
    mapController.move(
        myPoint!, 10); // Accede a mapController después de inicializarlo
  }


  Widget mapContainer() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Pro'),
        centerTitle: true,
        backgroundColor: Colors.blue,
        actions: const [ConnectivityIcon()],
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              options:  MapOptions(
                initialCenter: myPoint!,
                interactionOptions: InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                maxZoom: 16,
                initialZoom: 8,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  tileProvider: CachedTileProvider(
                    dio: _dio,
                    maxStale: const Duration(days: 30),
                    store: _cacheStore,
                    interceptors: [
                      LogInterceptor(
                        logPrint: (object) => debugPrint(object.toString()),
                        responseHeader: false,
                        requestHeader: false,
                        request: false,
                      ),
                    ],
                  ),
                  userAgentPackageName: 'com.github.josxha/flutter_map_plugins',
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
                const OsmAttributionWidget(),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const Text('Descargando:'),
                if (kIsWeb)
                  DropdownMenu<CacheStoreTypes>(
                    initialSelection: CacheStoreTypes.memCache,
                    onSelected: (value) {
                      if (value == null) return;
                      debugPrint('CacheStore changed to ${value.name}');
                      setState(() {
                        _cacheStore = value.getCacheStoreWeb();
                      });
                    },
                    dropdownMenuEntries: CacheStoreTypes.dropdownList,
                  ),
                if (!kIsWeb)
                  FutureBuilder<Directory>(
                    // ignore: discarded_futures
                    future: getTemporaryDirectory(), // not available on web
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        final dataPath = snapshot.requireData.path;

                      }
                      if (snapshot.hasError) {
                        debugPrint(snapshot.error.toString());
                        debugPrintStack(stackTrace: snapshot.stackTrace);
                        return Expanded(
                          child: Text(snapshot.error.toString()),
                        );
                      }
                      return const Expanded(child: LinearProgressIndicator());
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: myPoint == null
            ? ElevatedButton(
          onPressed: () {
            determineAndSetPosition();
          },
          child: const Text('Activar localización'),
        )
            : mapContainer(),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const SizedBox(height: 10),

        ],
      ),
    );
  }
}
