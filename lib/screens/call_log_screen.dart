import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:call_log/call_log.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:url_launcher/url_launcher.dart'; // To call back

class CallLogScreen extends StatefulWidget {
  const CallLogScreen({super.key});

  @override
  State<CallLogScreen> createState() => _CallLogScreenState();
}

class _CallLogScreenState extends State<CallLogScreen> {
  Iterable<CallLogEntry> _callLogEntries = [];
  bool _permissionDenied = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCallLogs();
  }

  Future<void> _fetchCallLogs() async {
    setState(() {
      _isLoading = true;
      _permissionDenied = false;
    });

    PermissionStatus status = await Permission.phone.request(); // Request phone permission (includes call log)

    if (status.isGranted) {
      try {
        Iterable<CallLogEntry> entries = await CallLog.get();
        setState(() {
          _callLogEntries = entries;
          _isLoading = false;
        });
      } catch (e) {
        print('Error fetching call logs: $e');
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la récupération du journal d\appels.')),
        );
      }
    } else {
      setState(() {
        _permissionDenied = true;
        _isLoading = false;
      });
    }
  }

  // Helper function to get icon based on call type
  Icon _getCallTypeIcon(CallType callType) {
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

  // Helper function to format duration
  String _formatDuration(int durationSeconds) {
    final duration = Duration(seconds: durationSeconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  // Helper function to format date/time
  String _formatDateTime(int timestampMillis) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestampMillis);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);

    if (dateTime.isAfter(today)) {
      return DateFormat.Hm().format(dateTime); // Just time for today
    } else if (dateTime.isAfter(yesterday)) {
      return 'Hier, ${DateFormat.Hm().format(dateTime)}'; // Yesterday + time
    } else {
      return DateFormat.yMd().add_Hm().format(dateTime); // Full date and time
    }
  }

  // Helper function to launch URL (call)
  Future<void> _launchCall(String? number) async {
    if (number == null || number.isEmpty) return;
    final Uri url = Uri(scheme: 'tel', path: number);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }
    } catch (e) {
      print('Could not launch $url: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de lancer l\appel vers $number')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(title: Text('Journal d'appels')), // Removed to integrate
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchCallLogs,
        tooltip: 'Rafraîchir le journal',
        child: const Icon(Icons.refresh),
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
              const Text(
                'Permission d\accès au journal d\appels refusée.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: openAppSettings,
                child: const Text('Ouvrir les paramètres'),
              ),
              ElevatedButton(
                onPressed: _fetchCallLogs,
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    if (_callLogEntries.isEmpty) {
      return const Center(child: Text('Journal d\appels vide.'));
    }

    return ListView.builder(
      itemCount: _callLogEntries.length,
      itemBuilder: (context, index) {
        final entry = _callLogEntries.elementAt(index);
        final callTypeIcon = _getCallTypeIcon(entry.callType ?? CallType.unknown);
        final formattedDuration = _formatDuration(entry.duration ?? 0);
        final formattedDateTime = _formatDateTime(entry.timestamp ?? 0);

        return ListTile(
          leading: callTypeIcon,
          title: Text(entry.name ?? entry.number ?? 'Numéro inconnu'),
          subtitle: Text('${entry.number ?? ''} • $formattedDuration'),
          trailing: Text(formattedDateTime),
          onTap: () => _launchCall(entry.number), // Call back on tap
        );
      },
    );
  }
}

