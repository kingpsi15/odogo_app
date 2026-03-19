class DropoffLocation {
  const DropoffLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.aliases = const <String>[],
  });

  final String name;
  final double latitude;
  final double longitude;
  final List<String> aliases;

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;

    if (name.toLowerCase().contains(normalized)) {
      return true;
    }

    for (final alias in aliases) {
      if (alias.toLowerCase().contains(normalized)) {
        return true;
      }
    }
    return false;
  }

  static DropoffLocation? fromName(String searchName) {
    final normalized = searchName.trim().toLowerCase();

    for (final loc in iitkDropoffLocations) {
      // 1. Check if it matches the primary name
      if (loc.name.toLowerCase() == normalized) {
        return loc;
      }
      
      // 2. Check if it matches any alias
      for (final alias in loc.aliases) {
        if (alias.toLowerCase() == normalized) {
          return loc;
        }
      }
    }
    
    // Returns null if the location name/alias isn't in your local list
    return null; 
  }
}

const List<DropoffLocation> iitkDropoffLocations = <DropoffLocation>[
  DropoffLocation(name: 'Main Gate', latitude: 26.5108, longitude: 80.2466, aliases: <String>['gate', 'main', 'icici', 'parking']),
  DropoffLocation(name: 'Academic Area Gate 1', latitude: 26.5131, longitude: 80.2353, aliases: <String>['cc', 'rm', 'kd', 'hr kadim', 'cse', 'dosa', 'office', 'faculty building', 'computer',  'centre', 'center']),
  DropoffLocation(name: 'Academic Area Gate 2', latitude: 26.5105, longitude: 80.2345, aliases: <String>['subway', 'ccd', 'library', 'starbucks']),
  DropoffLocation(name: 'Academic Area Gate 3', latitude: 26.5105, longitude: 80.2320, aliases: <String>['aa gate 3', 'academic', 'lhc', 'library', 'lecture hall complex', 'tutorial', 'tb', 'block']),
  DropoffLocation(name: 'Outreach Auditorium', latitude: 26.5091, longitude: 80.2346, aliases: <String>['oat', 'auditorium', 'clothes']),
  DropoffLocation(name: 'Visitors Hostel 1', latitude: 26.5073, longitude: 80.2345, aliases: <String>['vh1']),
  DropoffLocation(name: 'Visitors Hostel 2', latitude: 26.5116, longitude: 80.2259, aliases: <String>['vh2']),
  DropoffLocation(name: 'Hall 1', latitude: 26.5093, longitude: 80.2307, aliases: <String>['h1', 'tennis']),
  DropoffLocation(name: 'Hall 2', latitude: 26.5105, longitude: 80.2307, aliases: <String>['h2']),
  DropoffLocation(name: 'Hall 3', latitude: 26.5083, longitude: 80.2306, aliases: <String>['h3']),
  DropoffLocation(name: 'Hall 4', latitude: 26.5071, longitude: 80.2307, aliases: <String>['h4']),
  DropoffLocation(name: 'Hall 5', latitude: 26.5096, longitude: 80.2290, aliases: <String>['h5', 'tennis']),
  DropoffLocation(name: 'Hall 6', latitude: 26.5045, longitude: 80.2349, aliases: <String>['h6']),
  DropoffLocation(name: 'Hall 7', latitude: 26.5065, longitude: 80.2288, aliases: <String>['h7']),
  DropoffLocation(name: 'Hall 8', latitude: 26.5049, longitude: 80.2289, aliases: <String>['h8']),
  DropoffLocation(name: 'Hall 9', latitude: 26.5080, longitude: 80.2272, aliases: <String>['h9']),
  DropoffLocation(name: 'Hall 10', latitude: 26.5062, longitude: 80.2272, aliases: <String>['h10']),
  DropoffLocation(name: 'Hall 11', latitude: 26.5052, longitude: 80.2272, aliases: <String>['h11']),
  DropoffLocation(name: 'Hall 12', latitude: 26.5117, longitude: 80.2282, aliases: <String>['h12']),
  DropoffLocation(name: 'Hall 13', latitude: 26.5087, longitude: 80.2269, aliases: <String>['h13']),
  DropoffLocation(name: 'Hall 14', latitude: 26.5118, longitude: 80.2253, aliases: <String>['h14']),
  DropoffLocation(name: 'Open Air Theatre', latitude: 26.5053, longitude: 80.2298, aliases: <String>['oat', 'new sac', 'dominos', 'burger', 'stage', 'yoga', 'mpr', 'new shopping complex']),
  DropoffLocation(name: 'Health Centre', latitude: 26.5052, longitude: 80.2339, aliases: <String>['hospital', 'medical', 'hc', '1mg', 'tata', 'pharmacy']),
  DropoffLocation(name: 'New Shopping Complex', latitude: 26.5044, longitude: 80.2314, aliases: <String>['eshop', 'zing', 'ashiyana', 'amul', 'dry cleaner', 'clothes']),
  DropoffLocation(name: 'Kendriya Vidyalaya', latitude: 26.5088, longitude: 80.2364, aliases: <String>['kv']),
  DropoffLocation(name: 'DOAA Canteen', latitude: 26.5145, longitude: 80.2317, aliases: <String>['canteen', 'doaa', 'doaa canteen']),
  DropoffLocation(name: 'MT', latitude: 26.5122, longitude: 80.2306, aliases: <String>['mt']),
  DropoffLocation(name: 'Type 2 Community Center', latitude: 26.5104, longitude: 80.2413, aliases: <String>['type 2', 'community', 'temple', 'police', 'mahadev', 'chowki']),
  DropoffLocation(name: 'Petrol Pump', latitude: 26.5109, longitude: 80.2393, aliases: <String>['indian oil', 'petrol', 'pump']),
  DropoffLocation(name: 'Gurudwara', latitude: 26.5078, longitude: 80.2426, aliases: <String>['gurudwara', 'temple']),
  DropoffLocation(name: 'Park 67', latitude: 26.5105, longitude: 80.2381, aliases: <String>['park', '67']),
  DropoffLocation(name: 'Old Shopping Complex', latitude: 26.5114, longitude: 80.2364, aliases: <String>['old', 'shop', 'restaurant', 'sbi', 'd shop', 'tarun bookstore', 'dry cleaner', 'divyam', 'tadka', 'campus restaurant']),
  DropoffLocation(name: 'Post Office', latitude: 26.5120, longitude: 80.2365, aliases: <String>['psot office', 'post', 'office']),
  DropoffLocation(name: 'Main Auditorium', latitude: 26.5131, longitude: 80.2359, aliases: <String>['audi', 'auditorium', 'main audi', 'main auditorium', 'church']),
  DropoffLocation(name: 'Institute Nursery', latitude: 26.5152, longitude: 80.2352 , aliases: <String>['nursery', 'garden', 'flowers']),
  DropoffLocation(name: 'Swimming Pool', latitude: 26.5052, longitude: 80.2312, aliases: <String>['swimming', 'pool']),
  DropoffLocation(name: 'Old Sports Complex', latitude: 26.5085, longitude: 80.2313, aliases: <String>['sports', 'complex', 'old sports complex']),
  DropoffLocation(name: 'Shivli Gate', latitude: 26.5041, longitude: 80.2251, aliases: <String>['shivli', 'gate']),
  DropoffLocation(name: 'Mama Mio, Hall 10', latitude: 26.5062, longitude: 80.2272, aliases: <String>['mama', 'mio']),
  DropoffLocation(name: 'Mama Mio, Old Shopping Complex', latitude: 26.5114, longitude: 80.2364, aliases: <String>['mama', 'mio']),
  DropoffLocation(name: 'SBRA', latitude: 26.5041, longitude: 80.2351, aliases: <String>['sbra']),
];
