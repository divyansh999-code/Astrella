class Anomaly {
  final String id;
  final String name;
  final String rarity;
  final String description;
  final String imagePath;

  const Anomaly({
    required this.id,
    required this.name,
    required this.rarity,
    required this.description,
    required this.imagePath,
  });
}

const List<Anomaly> allAnomalies = [
  // LEGENDARY
  Anomaly(
    id: 'black_hole',
    name: 'BLACK HOLE',
    rarity: 'LEGENDARY',
    description: 'A singularity where spacetime collapses — nothing escapes',
    imagePath: 'assets/anomalies/black_hole.jpg',
  ),
  Anomaly(
    id: 'dyson_sphere',
    name: 'DYSON SPHERE',
    rarity: 'LEGENDARY',
    description: 'A megastructure encasing a star — evidence of Type II civilization',
    imagePath: 'assets/anomalies/dyson_sphere.jpg',
  ),
  Anomaly(
    id: 'alien_signal',
    name: 'ALIEN SIGNAL',
    rarity: 'LEGENDARY',
    description: 'An unidentified repeating signal of non-stellar origin',
    imagePath: 'assets/anomalies/alien_signal.jpg',
  ),

  // RARE
  Anomaly(
    id: 'pulsar',
    name: 'PULSAR',
    rarity: 'RARE',
    description: 'A rapidly rotating neutron star emitting precise radio beams',
    imagePath: 'assets/anomalies/pulsar.jpg',
  ),
  Anomaly(
    id: 'binary_system',
    name: 'BINARY STAR SYSTEM',
    rarity: 'RARE',
    description: 'Two stars locked in gravitational orbit around each other',
    imagePath: 'assets/anomalies/binary_system.jpg',
  ),
  Anomaly(
    id: 'magnetar',
    name: 'MAGNETAR',
    rarity: 'RARE',
    description: 'Neutron star with the most powerful magnetic field in existence',
    imagePath: 'assets/anomalies/magnetar.jpg',
  ),
  Anomaly(
    id: 'wormhole',
    name: 'WORMHOLE',
    rarity: 'RARE',
    description: 'A theoretical fold in spacetime — destination unknown',
    imagePath: 'assets/anomalies/wormhole.jpg',
  ),
  Anomaly(
    id: 'quasar',
    name: 'QUASAR',
    rarity: 'RARE',
    description: 'An ancient galactic nucleus burning brighter than a trillion suns',
    imagePath: 'assets/anomalies/quasar.jpg',
  ),

  // COMMON
  Anomaly(
    id: 'red_dwarf',
    name: 'RED DWARF',
    rarity: 'COMMON',
    description: 'A small, cool stellar remnant burning for trillions of years',
    imagePath: 'assets/anomalies/red_dwarf.jpg',
  ),
  Anomaly(
    id: 'asteroid_field',
    name: 'ASTEROID FIELD',
    rarity: 'COMMON',
    description: 'Dense cluster of rocky debris from a shattered planetoid',
    imagePath: 'assets/anomalies/asteroid_field.jpg',
  ),
  Anomaly(
    id: 'nebula_cloud',
    name: 'NEBULA CLOUD',
    rarity: 'COMMON',
    description: 'Vast interstellar gas cloud — a stellar nursery',
    imagePath: 'assets/anomalies/nebula_cloud.jpg',
  ),
  Anomaly(
    id: 'rogue_planet',
    name: 'ROGUE PLANET',
    rarity: 'COMMON',
    description: 'A planet ejected from its solar system, drifting alone',
    imagePath: 'assets/anomalies/rogue_planet.jpg',
  ),
  Anomaly(
    id: 'white_dwarf',
    name: 'WHITE DWARF',
    rarity: 'COMMON',
    description: 'The cooling core of a collapsed sun',
    imagePath: 'assets/anomalies/white_dwarf.jpg',
  ),
  Anomaly(
    id: 'comet_trail',
    name: 'COMET TRAIL',
    rarity: 'COMMON',
    description: 'Ancient ice and dust streaming through deep space',
    imagePath: 'assets/anomalies/comet_trail.jpg',
  ),
  Anomaly(
    id: 'solar_flare',
    name: 'SOLAR FLARE',
    rarity: 'COMMON',
    description: 'Massive electromagnetic burst from an unstable star',
    imagePath: 'assets/anomalies/solar_flare.jpg',
  ),
  Anomaly(
    id: 'dark_matter_void',
    name: 'DARK MATTER VOID',
    rarity: 'COMMON',
    description: 'A region of space unusually devoid of visible matter',
    imagePath: 'assets/anomalies/dark_matter_void.jpg',
  ),
];
