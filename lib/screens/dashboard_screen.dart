import 'package:flutter/material.dart';
import 'package:call_log/call_log.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart'; // For date formatting

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Iterable<CallLogEntry> _callLogEntries = [];
  bool _isLoading = true;
  bool _permissionDenied = false;
  final DateFormat _formatter = DateFormat('dd/MM/yyyy HH:mm'); // Date formatter

  // Stats holders
  Map<String, int> _callCounts = {};
  Map<String, int> _callDurations = {};

  @override
  void initState() {
    super.initState();
    _fetchCallLogs();
  }

  Future<void> _fetchCallLogs() async {
    setState(() {
      _isLoading = true;
      _permissionDenied = false;
      _callCounts = {}; // Reset stats
      _callDurations = {};
    });

    PermissionStatus status = await Permission.phone.request();

    if (status.isGranted) {
      try {
        Iterable<CallLogEntry> entries = await CallLog.get();
        _calculateStats(entries); // Calculate stats after fetching

        if (mounted) {
          setState(() {
            _callLogEntries = entries;
            _isLoading = false;
          });
        }
      } catch (e) {
        print('Error fetching call logs: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _permissionDenied = true;
          _isLoading = false;
        });
      }
    }
  }

  void _calculateStats(Iterable<CallLogEntry> entries) {
    Map<String, int> counts = {};
    Map<String, int> durations = {};

    for (var entry in entries) {
      // Use 'Unknown SIM' if simDisplayName is null or empty
      String simKey = (entry.simDisplayName?.isNotEmpty ?? false) ? entry.simDisplayName! : 'Unknown SIM';

      // Increment call count for the SIM
      counts[simKey] = (counts[simKey] ?? 0) + 1;

      // Add duration (only for connected calls, typically outgoing/incoming)
      // We consider duration > 0 to avoid counting missed/rejected calls in total time
      if (entry.duration != null && entry.duration! > 0) {
         durations[simKey] = (durations[simKey] ?? 0) + entry.duration!;
      }
    }

    // Update state variables for stats
    _callCounts = counts;
    _callDurations = durations;
  }


  Icon _getCallTypeIcon(CallType? callType) {
    switch (callType) {
      case CallType.incoming:
        return const Icon(Icons.call_received, color: Colors.green);
      case CallType.outgoing:
        return const Icon(Icons.call_made, color: Colors.blue);
      case CallType.missed:
        return const Icon(Icons.call_missed, color: Colors.red);
      case CallType.rejected:
        return const Icon(Icons.call_end, color: Colors.orange);
      case CallType.blocked:
        return const Icon(Icons.block, color: Colors.grey);
      default:
        return const Icon(Icons.help_outline, color: Colors.grey);
    }
  }

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return '00:00'; // Return 00:00 for null or zero duration
    Duration duration = Duration(seconds: seconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard d\'utilisation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Rafraîchir',
            onPressed: _fetchCallLogs,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildStatsCard(String simName, int callCount, int totalDurationSeconds) {
     return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              simName, // Display SIM name (e.g., 'SIM 1', 'Unknown SIM')
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Nombre d\'appels:'),
                Text('$callCount', style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Durée totale:'),
                Text(_formatDuration(totalDurationSeconds), style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_permissionDenied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.phone_disabled_outlined, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Permission d\'accès au journal d\'appels refusée.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.settings_outlined),
                onPressed: openAppSettings,
                label: const Text('Ouvrir les paramètres'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh_outlined),
                onPressed: _fetchCallLogs,
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    if (_callLogEntries.isEmpty) {
      return const Center(child: Text('Aucun historique d\'appels trouvé.'));
    }

    // Build list of stat cards
    List<Widget> statCards = [];
    _callCounts.forEach((simName, count) {
      int duration = _callDurations[simName] ?? 0;
      statCards.add(_buildStatsCard(simName, count, duration));
    });

    return Column(
      children: [
        // Display Stat Cards
        if (statCards.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0), // Add some padding above the cards
            child: Column(children: statCards),
          ),
        if (statCards.isEmpty && !_isLoading) // Show message if no stats calculated but logs exist
           const Padding(
             padding: EdgeInsets.all(16.0),
             child: Text('Impossible de calculer les statistiques par SIM (informations SIM manquantes dans le journal d\'appels).'),
           ),

        // Separator
        const Divider(height: 20, thickness: 1, indent: 16, endIndent: 16),

        // Title for the log list
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Historique détaillé des appels', 
            style: Theme.of(context).textTheme.titleMedium
          ),
        ),

        // Call Log List
        Expanded(
          child: ListView.builder(
            itemCount: _callLogEntries.length,
            itemBuilder: (context, index) {
              final entry = _callLogEntries.elementAt(index);
              final callTime = entry.timestamp != null
                  ? DateTime.fromMillisecondsSinceEpoch(entry.timestamp!)
                  : null;

              return ListTile(
                leading: _getCallTypeIcon(entry.callType),
                title: Text(entry.name ?? entry.formattedNumber ?? entry.number ?? 'Inconnu'),
                subtitle: Text(
                  '${entry.number ?? 'N/A'} - ${_formatDuration(entry.duration)}'
                  '${callTime != null ? '\n${_formatter.format(callTime)}' : ''}'
                  '${entry.simDisplayName != null ? ' - SIM: ${entry.simDisplayName}' : ''}'
                ),
                isThreeLine: callTime != null,
              );
            },
          ),
        ),
      ],
    );
  }
}

