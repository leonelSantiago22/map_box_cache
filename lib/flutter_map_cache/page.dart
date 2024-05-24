import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:open_route_service/open_route_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
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
class FlutterMapCachePage extends StatefulWidget {
  const FlutterMapCachePage({super.key});

  @override
  State<FlutterMapCachePage> createState() => _MapScreenState();
}
class Node {
  final LatLng point;
  double g; // Cost from start to current node
  double h; // Heuristic cost to end
  double get f => g + h; // Total cost
  Node? parent; // For path reconstruction

  Node(this.point, {this.g = 0, this.h = 0, this.parent});
}

class DraggableMarker extends StatelessWidget {
  final LatLng point;
  final Function(LatLng) onDragEnd;
  DraggableMarker({required this.point, required this.onDragEnd});
  @override
  Widget build(BuildContext context) {
    return Draggable(
      feedback: IconButton(
        onPressed: () {},
        icon: const Icon(Icons.location_on),
        color: Colors.black,
        iconSize: 45,
      ),
      onDragEnd: (details) {
        onDragEnd(LatLng(details.offset.dy, details.offset.dx));
      },
      child: IconButton(
        onPressed: () {},
        icon: const Icon(Icons.location_on),
        color: Colors.black,
        iconSize: 45,
      ),
    );
  }
}
List<LatLng> aStar(LatLng start, LatLng end, List<LatLng> waypoints) {
  Node startNode = Node(start);
  Node endNode = Node(end);

  List<Node> openList = [];
  List<Node> closedList = [];

  openList.add(startNode);

  Node? currentNode;

  while (openList.isNotEmpty) {
    openList.sort((a, b) => a.f.compareTo(b.f));
    currentNode = openList.removeAt(0);
    closedList.add(currentNode);

    if (currentNode.point == endNode.point) {
      List<LatLng> path = [];
      while (currentNode != null) {
        path.add(currentNode.point);
        currentNode = currentNode.parent;
      }
      return path.reversed.toList();
    }

    for (LatLng point in waypoints) {
      Node neighbor = Node(point, parent: currentNode);
      if (closedList.any((node) => node.point == neighbor.point)) {
        continue;
      }

      neighbor.g = currentNode.g + _distance(currentNode.point, neighbor.point);
      neighbor.h = _distance(neighbor.point, endNode.point);

      if (openList.any((node) => node.point == neighbor.point && node.f < neighbor.f)) {
        continue;
      }

      openList.add(neighbor);
    }
  }

  return [];
}

double _distance(LatLng a, LatLng b) {
  final double dx = a.latitude - b.latitude;
  final double dy = a.longitude - b.longitude;
  return dx * dx + dy * dy;
}

class _MapScreenState extends State<FlutterMapCachePage> {
  CacheStore _cacheStore = MemCacheStore();
  final _dio = Dio();
  LatLng? myPoint; // Tipo de dato LatLng
  bool isLoading = false;
  bool showAdditionalButtons = false;
  TextEditingController searchController = TextEditingController();
  LatLng? searchLocation;
  final MapController mapController = MapController();
  bool useAStar = true;

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
    });
    mapController.move(myPoint!, 10);
  }

  Future<void> searchAndMoveToPlace(String query) async {
    List<Location> locations = await locationFromAddress(query);
    if (locations.isNotEmpty) {
      final LatLng newLocation = LatLng(locations[0].latitude, locations[0].longitude);
      setState(() {
        searchLocation = newLocation;
      });
      mapController.move(newLocation, 10);
    } else {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Error'),
            content: Text('No se encontró ningún lugar con esta búsqueda.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  List<LatLng> points = [];
  List<Marker> markers = [];

  Future<void> getCoordinates(LatLng lat1, LatLng lat2) async {
    setState(() {
      isLoading = true;
    });

    final OpenRouteService client = OpenRouteService(
      apiKey: '5b3ce3597851110001cf62481d15c38eda2742818d1b9ff0e510ca77',
    );

    final List<ORSCoordinate> routeCoordinates =
    await client.directionsRouteCoordsGet(
      startCoordinate:
      ORSCoordinate(latitude: lat1.latitude, longitude: lat1.longitude),
      endCoordinate:
      ORSCoordinate(latitude: lat2.latitude, longitude: lat2.longitude),
    );

    final List<LatLng> routePoints = routeCoordinates
        .map((coordinate) => LatLng(coordinate.latitude, coordinate.longitude))
        .toList();

    setState(() {
      points = routePoints;
      isLoading = false;
    });
  }

  void _handleTap2(LatLng latLng) {
    setState(() {
      if (markers.length < 10) {
        markers.add(
          Marker(
            point: latLng,
            width: 80,
            height: 80,
            child: Builder(
              builder: (BuildContext context) {
                return DraggableMarker(
                  point: latLng,
                  onDragEnd: (newLatLng) {
                    setState(() {
                      int markerIndex =
                      markers.indexWhere((marker) => marker.point == latLng);
                      markers[markerIndex] = Marker(
                        point: newLatLng,
                        width: 80,
                        height: 80,
                        child: Builder(
                          builder: (BuildContext context) {
                            return DraggableMarker(
                              point: newLatLng,
                              onDragEnd: (details) {
                                setState(() {
                                  print(
                                      "Latitude: ${newLatLng.latitude}, Longitude: ${newLatLng.longitude}");
                                });
                              },
                            );
                          },
                        ),
                      );
                    });
                  },
                );
              },
            ),
          ),
        );
      }

      if (markers.length == 10) {
        Future.delayed(const Duration(milliseconds: 500), () {
          setState(() {
            isLoading = true;
          });

          if (useAStar) {
            List<LatLng> waypoints = markers.map((marker) => marker.point).toList();
            LatLng start = waypoints.removeAt(0);
            LatLng end = waypoints.removeLast();
            List<LatLng> route = aStar(start, end, waypoints);
            setState(() {
              points = route;
              isLoading = false;
            });
          } else {
            _greedySearch(markers.map((marker) => marker.point).toList());
          }
        });

        LatLngBounds bounds = LatLngBounds.fromPoints(
            markers.map((marker) => marker.point).toList());
        mapController.fitBounds(bounds);
      }
    });
  }

  Future<void> _greedySearch(List<LatLng> points) async {
    List<LatLng> allRoutePoints = [];
    List<LatLng> unvisited = List.from(points); // Puntos no visitados
    LatLng currentPoint = unvisited.removeAt(0); // Empezamos con el primer punto
    LatLng startPoint = currentPoint; // Guardamos el punto inicial

    while (unvisited.isNotEmpty) {
      LatLng closestPoint = unvisited[0];
      double closestDistance = distance(currentPoint, closestPoint);

      for (LatLng point in unvisited) {
        double distanceToPoint = distance(currentPoint, point);
        if (distanceToPoint < closestDistance) {
          closestDistance = distanceToPoint;
          closestPoint = point;
        }
      }

      List<LatLng> segmentPoints = await _getSegmentRoute(currentPoint, closestPoint);
      allRoutePoints.addAll(segmentPoints);
      currentPoint = closestPoint;
      unvisited.remove(currentPoint);
    }

    // Para cerrar el ciclo, añadir la ruta de vuelta al punto inicial (opcional)
    List<LatLng> closingSegment = await _getSegmentRoute(currentPoint, startPoint);
    allRoutePoints.addAll(closingSegment);

    setState(() {
      this.points = allRoutePoints;
      isLoading = false;
    });
  }

// Función para calcular la distancia entre dos puntos
  double distance(LatLng a, LatLng b) {
    final double dx = a.latitude - b.latitude;
    final double dy = a.longitude - b.longitude;
    return dx * dx + dy * dy; // Distancia euclidiana al cuadrado para evitar raíces cuadradas
  }


  Future<List<LatLng>> _getSegmentRoute(LatLng start, LatLng end) async {
    final OpenRouteService client = OpenRouteService(
      apiKey: '5b3ce3597851110001cf62481d15c38eda2742818d1b9ff0e510ca77',
    );

    final List<ORSCoordinate> routeCoordinates =
    await client.directionsRouteCoordsGet(
      startCoordinate:
      ORSCoordinate(latitude: start.latitude, longitude: start.longitude),
      endCoordinate:
      ORSCoordinate(latitude: end.latitude, longitude: end.longitude),
    );

    return routeCoordinates
        .map((coordinate) => LatLng(coordinate.latitude, coordinate.longitude))
        .toList();
  }

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
            child: const Icon(
              Icons.add,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            backgroundColor: Colors.black,
            onPressed: () {
              mapController.move(mapController.center, mapController.zoom - 1);
            },
            child: const Icon(
              Icons.remove,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
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
            interactionOptions: const InteractionOptions(
                flags: ~InteractiveFlag.doubleTapDragZoom),
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
            const OsmAttributionWidget(),
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
              ] + markers,
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
        Positioned(
          top: MediaQuery.of(context).padding.top + 20.0,
          left: MediaQuery.of(context).size.width / 2 - 110,
          child: Align(
            child: TextButton(
              onPressed: () {
                if (markers.isEmpty) {
                  print('Marcar puntos en el mapa');
                } else {
                  setState(() {
                    markers = [];
                    points = [];
                  });
                }
              },
              child: Container(
                width: 200,
                height: 50,
                decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(10)),
                child: Center(
                  child: Text(
                    markers.isEmpty ? "Marcar ruta del mapa" : "Limpar ruta",
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
              ),
            ),
          ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const Text('CacheStore Type'),
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
                      return DropdownMenu<CacheStoreTypes>(
                        initialSelection: CacheStoreTypes.memCache,
                        onSelected: (value) {
                          if (value == null) return;
                          debugPrint('CacheStore changed to ${value.name}');
                          setState(() {
                            _cacheStore = value.getCacheStore(dataPath);
                          });
                        },
                        dropdownMenuEntries: CacheStoreTypes.dropdownList,
                      );
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
        if (showAdditionalButtons)
          Positioned(
            bottom: 230,
            right: 16,
            child: Column(
              children: [
                FloatingActionButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Text('Buscar ubicación'),
                          content: TextField(
                            controller: searchController,
                            decoration: InputDecoration(
                              hintText: 'Ingrese la ubicación',
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                searchAndMoveToPlace(searchController.text);
                                Navigator.of(context).pop();
                              },
                              child: Text('Buscar'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  child: Icon(Icons.search),
                ),
                SizedBox(height: 16),
                FloatingActionButton(
                  onPressed: () {
                    determineAndSetPosition();
                  },
                  child: Icon(Icons.location_pin),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
