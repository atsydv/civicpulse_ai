import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Central in-memory + persisted data store for CivicPulse AI
class AppDataService {
  static AppDataService? _instance;
  static AppDataService get instance => _instance ??= AppDataService._();
  AppDataService._();

  // In-memory state
  List<Map<String, dynamic>> _tickets = [];
  List<Map<String, dynamic>> _users = [];
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final prefs = await SharedPreferences.getInstance();

    // Load tickets
    final ticketsJson = prefs.getString('tickets');
    if (ticketsJson != null) {
      _tickets = List<Map<String, dynamic>>.from(
        (jsonDecode(ticketsJson) as List).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      );
    } else {
      _tickets = _defaultTickets();
      await _saveTickets(prefs);
    }

    // Load users
    final usersJson = prefs.getString('users');
    if (usersJson != null) {
      _users = List<Map<String, dynamic>>.from(
        (jsonDecode(usersJson) as List).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      );
    } else {
      _users = _defaultUsers();
      await _saveUsers(prefs);
    }
  }

  // ─── Users ───────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> get users => List.unmodifiable(_users);

  Map<String, dynamic>? login(String email, String password) {
    try {
      return _users.firstWhere(
        (u) => u['email'] == email && u['password'] == password,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> updateUserKarma(int userId, int delta) async {
    final idx = _users.indexWhere((u) => u['id'] == userId);
    if (idx == -1) return;
    _users[idx] = {
      ..._users[idx],
      'karma': ((_users[idx]['karma'] as int?) ?? 0) + delta,
    };
    final prefs = await SharedPreferences.getInstance();
    await _saveUsers(prefs);
  }

  Map<String, dynamic>? getUserById(int id) {
    try {
      return _users.firstWhere((u) => u['id'] == id);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? getUserByName(String name) {
    try {
      return _users.firstWhere((u) => u['name'] == name);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> createUser(Map<String, dynamic> userData) async {
    final newId = _users.isNotEmpty
        ? (_users
                  .map((u) => u['id'] as int? ?? 0)
                  .reduce((a, b) => a > b ? a : b) +
              1)
        : 100;
    final newUser = {'id': newId, ...userData};
    _users.add(newUser);
    final prefs = await SharedPreferences.getInstance();
    await _saveUsers(prefs);
    return newUser;
  }

  /// Returns all admin users
  List<Map<String, dynamic>> getAdmins() =>
      _users.where((u) => u['role'] == 'ADMIN').toList();

  /// Returns all worker users
  List<Map<String, dynamic>> getWorkers() =>
      _users.where((u) => u['role'] == 'WORKER').toList();

  List<Map<String, dynamic>> getLeaderboard() {
    final citizens = _users.where((u) => u['role'] == 'CITIZEN').toList();
    citizens.sort(
      (a, b) =>
          ((b['karma'] as int?) ?? 0).compareTo((a['karma'] as int?) ?? 0),
    );
    return citizens;
  }

  // ─── Tickets ─────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> get tickets => List.unmodifiable(_tickets);

  List<Map<String, dynamic>> getTicketsByUser(int userId) =>
      _tickets.where((t) => t['userId'] == userId).toList();

  List<Map<String, dynamic>> getTicketsByWorker(String workerName) =>
      _tickets.where((t) => t['assignedTo'] == workerName).toList();

  Future<Map<String, dynamic>> addTicket(Map<String, dynamic> ticket) async {
    final id = 'TKT-${2900 + _tickets.length}';
    final newTicket = {'id': id, ...ticket, 'upvotes': 0, 'status': 'TRIAGED'};
    _tickets.insert(0, newTicket);
    final prefs = await SharedPreferences.getInstance();
    await _saveTickets(prefs);
    return newTicket;
  }

  Future<void> upvoteTicket(String ticketId) async {
    final idx = _tickets.indexWhere((t) => t['id'] == ticketId);
    if (idx == -1) return;
    _tickets[idx] = {
      ..._tickets[idx],
      'upvotes': ((_tickets[idx]['upvotes'] as int?) ?? 0) + 1,
    };
    final prefs = await SharedPreferences.getInstance();
    await _saveTickets(prefs);
  }

  Future<void> assignWorker(String ticketId, String workerName) async {
    final idx = _tickets.indexWhere((t) => t['id'] == ticketId);
    if (idx == -1) return;
    _tickets[idx] = {
      ..._tickets[idx],
      'assignedTo': workerName,
      'status': 'IN_PROGRESS',
      'viewedAt': _tickets[idx]['viewedAt'] ?? DateTime.now().toIso8601String(),
    };
    final prefs = await SharedPreferences.getInstance();
    await _saveTickets(prefs);
  }

  Future<void> closeTicket(String ticketId, {String? afterImageBase64}) async {
    final idx = _tickets.indexWhere((t) => t['id'] == ticketId);
    if (idx == -1) return;
    _tickets[idx] = {
      ..._tickets[idx],
      'status': 'CLOSED',
      'resolvedAt': DateTime.now().toIso8601String(),
      if (afterImageBase64 != null) 'afterImageBase64': afterImageBase64,
    };
    final prefs = await SharedPreferences.getInstance();
    await _saveTickets(prefs);
  }

  Future<void> updateTicket(
    String ticketId,
    Map<String, dynamic> updates,
  ) async {
    final idx = _tickets.indexWhere((t) => t['id'] == ticketId);
    if (idx == -1) return;
    _tickets[idx] = {..._tickets[idx], ...updates};
    final prefs = await SharedPreferences.getInstance();
    await _saveTickets(prefs);
  }

  /// Mark ticket as viewed by admin
  Future<void> markTicketViewed(String ticketId) async {
    final idx = _tickets.indexWhere((t) => t['id'] == ticketId);
    if (idx == -1) return;
    if (_tickets[idx]['viewedAt'] != null) return; // already viewed
    _tickets[idx] = {
      ..._tickets[idx],
      'viewedAt': DateTime.now().toIso8601String(),
    };
    final prefs = await SharedPreferences.getInstance();
    await _saveTickets(prefs);
  }

  // ─── Persistence ─────────────────────────────────────────────────────────

  Future<void> _saveTickets(SharedPreferences prefs) async {
    await prefs.setString('tickets', jsonEncode(_tickets));
  }

  Future<void> _saveUsers(SharedPreferences prefs) async {
    await prefs.setString('users', jsonEncode(_users));
  }

  // ─── Defaults ────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _defaultUsers() => [
    {
      'id': 1,
      'email': 'citizen@civic.local',
      'password': 'demo123',
      'role': 'CITIZEN',
      'name': 'Maya Patel',
      'karma': 145,
    },
    {
      'id': 2,
      'email': 'admin@civic.local',
      'password': 'demo123',
      'role': 'ADMIN',
      'name': 'Commissioner Torres',
      'karma': 0,
    },
    {
      'id': 3,
      'email': 'worker@civic.local',
      'password': 'demo123',
      'role': 'WORKER',
      'name': 'Field Crew Dave',
      'karma': 0,
    },
    // Additional citizens for leaderboard
    {
      'id': 4,
      'email': 'rahul@civic.local',
      'password': 'demo123',
      'role': 'CITIZEN',
      'name': 'Rahul Verma',
      'karma': 320,
    },
    {
      'id': 5,
      'email': 'priya@civic.local',
      'password': 'demo123',
      'role': 'CITIZEN',
      'name': 'Priya Sharma',
      'karma': 275,
    },
    {
      'id': 6,
      'email': 'arjun@civic.local',
      'password': 'demo123',
      'role': 'CITIZEN',
      'name': 'Arjun Singh',
      'karma': 210,
    },
    {
      'id': 7,
      'email': 'neha@civic.local',
      'password': 'demo123',
      'role': 'CITIZEN',
      'name': 'Neha Gupta',
      'karma': 185,
    },
    {
      'id': 8,
      'email': 'amit@civic.local',
      'password': 'demo123',
      'role': 'CITIZEN',
      'name': 'Amit Kumar',
      'karma': 130,
    },
    {
      'id': 9,
      'email': 'sunita@civic.local',
      'password': 'demo123',
      'role': 'CITIZEN',
      'name': 'Sunita Devi',
      'karma': 95,
    },
    {
      'id': 10,
      'email': 'vikram@civic.local',
      'password': 'demo123',
      'role': 'CITIZEN',
      'name': 'Vikram Yadav',
      'karma': 60,
    },
    {
      'id': 11,
      'email': 'kavita@civic.local',
      'password': 'demo123',
      'role': 'CITIZEN',
      'name': 'Kavita Mishra',
      'karma': 40,
    },
    // Additional worker
    {
      'id': 12,
      'email': 'worker2@civic.local',
      'password': 'demo123',
      'role': 'WORKER',
      'name': 'Field Crew Ravi',
      'karma': 0,
    },
  ];

  List<Map<String, dynamic>> _defaultTickets() => [
    {
      'id': 'TKT-2847',
      'category': 'Pothole',
      'severity': 'HIGH',
      'status': 'IN_PROGRESS',
      'address': 'Civil Lines, Prayagraj',
      'latitude': 25.4484,
      'longitude': 81.8322,
      'timestamp': '2026-08-21T08:15:00Z',
      'viewedAt': '2026-08-21T08:30:00Z',
      'upvotes': 12,
      'assignedTo': 'Field Crew Dave',
      'reporter': 'Maya Patel',
      'userId': 1,
      'aiCategory': 'Pothole',
      'aiReason': 'Large structural void in road surface, 40cm diameter.',
      'imageUrl':
          'https://img.rocket.new/generatedImages/rocket_gen_img_16e44b462-1772907441505.png',
      'imageSemanticLabel':
          'Damaged road surface with large pothole on urban street',
      'karmaAwarded': false,
    },
    {
      'id': 'TKT-2846',
      'category': 'Exposed Wires',
      'severity': 'CRITICAL',
      'status': 'TRIAGED',
      'address': 'Allahabad Junction, Prayagraj',
      'latitude': 25.4358,
      'longitude': 81.8463,
      'timestamp': '2026-08-21T07:30:00Z',
      'upvotes': 19,
      'assignedTo': null,
      'reporter': 'Rahul Verma',
      'userId': 4,
      'aiCategory': 'Exposed Wires',
      'aiReason': 'High-voltage wires exposed after utility box damage.',
      'imageUrl':
          'https://images.unsplash.com/photo-1568438591187-1717fdae850f',
      'imageSemanticLabel':
          'Exposed electrical wires hanging from damaged utility box',
      'karmaAwarded': false,
    },
    {
      'id': 'TKT-2845',
      'category': 'Waterlogging',
      'severity': 'CRITICAL',
      'status': 'IN_PROGRESS',
      'address': 'Sangam Road, Prayagraj',
      'latitude': 25.4239,
      'longitude': 81.8847,
      'timestamp': '2026-08-20T22:00:00Z',
      'viewedAt': '2026-08-20T22:30:00Z',
      'upvotes': 28,
      'assignedTo': 'Field Crew Dave',
      'reporter': 'Priya Sharma',
      'userId': 5,
      'aiCategory': 'Waterlogging',
      'aiReason': 'Severe flooding blocking pedestrian and vehicle access.',
      'imageUrl':
          'https://img.rocket.new/generatedImages/rocket_gen_img_1bd221cb9-1772351179052.png',
      'imageSemanticLabel':
          'Flooded urban street with water covering road surface',
      'karmaAwarded': false,
    },
    {
      'id': 'TKT-2831',
      'category': 'Broken Streetlight',
      'severity': 'MEDIUM',
      'status': 'TRIAGED',
      'address': 'MG Marg, Prayagraj',
      'latitude': 25.4506,
      'longitude': 81.8378,
      'timestamp': '2026-08-20T17:45:00Z',
      'upvotes': 7,
      'assignedTo': null,
      'reporter': 'Arjun Singh',
      'userId': 6,
      'aiCategory': 'Broken Streetlight',
      'aiReason': 'Non-functional streetlight creating safety hazard at night.',
      'imageUrl':
          'https://img.rocket.new/generatedImages/rocket_gen_img_1ee6bc6c5-1783768048258.png',
      'imageSemanticLabel': 'Broken streetlight pole on busy city sidewalk',
      'karmaAwarded': false,
    },
    {
      'id': 'TKT-2809',
      'category': 'Garbage Overflow',
      'severity': 'LOW',
      'status': 'CLOSED',
      'address': 'Katra, Prayagraj',
      'latitude': 25.4600,
      'longitude': 81.8400,
      'timestamp': '2026-08-19T11:30:00Z',
      'viewedAt': '2026-08-19T12:00:00Z',
      'resolvedAt': '2026-08-20T09:00:00Z',
      'upvotes': 3,
      'assignedTo': 'Field Crew Dave',
      'reporter': 'Neha Gupta',
      'userId': 7,
      'aiCategory': 'Garbage Overflow',
      'aiReason': 'Public waste bin overflowing, creating hygiene risk.',
      'imageUrl':
          'https://images.unsplash.com/photo-1734656323788-1c43b8db4eff',
      'imageSemanticLabel': 'Overflowing garbage bin on city sidewalk',
      'karmaAwarded': true,
    },
    {
      'id': 'TKT-2820',
      'category': 'Pothole',
      'severity': 'MEDIUM',
      'status': 'TRIAGED',
      'address': 'Lukerganj, Prayagraj',
      'latitude': 25.4550,
      'longitude': 81.8290,
      'timestamp': '2026-08-20T14:20:00Z',
      'upvotes': 5,
      'assignedTo': null,
      'reporter': 'Amit Kumar',
      'userId': 8,
      'aiCategory': 'Pothole',
      'aiReason': 'Multiple potholes on main road causing vehicle damage.',
      'imageUrl':
          'https://img.rocket.new/generatedImages/rocket_gen_img_16e44b462-1772907441505.png',
      'imageSemanticLabel': 'Road with multiple potholes in urban area',
      'karmaAwarded': false,
    },
    {
      'id': 'TKT-2815',
      'category': 'Garbage Overflow',
      'severity': 'MEDIUM',
      'status': 'IN_PROGRESS',
      'address': 'Naini, Prayagraj',
      'latitude': 25.4100,
      'longitude': 81.9000,
      'timestamp': '2026-08-20T10:00:00Z',
      'viewedAt': '2026-08-20T10:30:00Z',
      'upvotes': 9,
      'assignedTo': 'Field Crew Ravi',
      'reporter': 'Sunita Devi',
      'userId': 9,
      'aiCategory': 'Garbage Overflow',
      'aiReason': 'Garbage pile blocking footpath near residential area.',
      'imageUrl':
          'https://images.unsplash.com/photo-1586553734263-7df283d9c928',
      'imageSemanticLabel': 'Large garbage pile on city footpath',
      'karmaAwarded': false,
    },
  ];
}
