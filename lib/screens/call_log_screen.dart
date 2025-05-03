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

    // Request phone state permission (includes call log access on older Android)
    // On newer Android, READ_CALL_LOG is separate but often grouped.
    PermissionStatus status = await Permission.phone.request();

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
        if (mounted) { // Check if the widget is still in the tree
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erreur lors de la récupération du journal d\appels.')),
          );
        }
      }
    } else {
      setState(() {
        _permissionDenied = true;
        _isLoading = false;
      });
    }
  }

  // Helper function to get icon based on call type
  Widget _getCallTypeIcon(CallType callType, BuildContext context) {
    IconData iconData;
    Color iconColor;
    final colors = Theme.of(context).colorScheme;

    switch (callType) {
      case CallType.incoming:
        iconData = Icons.call_received_outlined;
        iconColor = Colors.green; // Consider using theme colors like colors.tertiary
        break;
      case CallType.outgoing:
        iconData = Icons.call_made_outlined;
        iconColor = colors.primary; // Use theme primary color
        break;
      case CallType.missed:
        iconData = Icons.call_missed_outlined;
        iconColor = colors.error; // Use theme error color
        break;
      case CallType.rejected:
        iconData = Icons.call_end_outlined;
        iconColor = Colors.orange; // Consider using theme colors like colors.secondary
        break;
      case CallType.blocked:
        iconData = Icons.block_outlined;
        iconColor = colors.onSurfaceVariant; // Use a neutral theme color
        break;
      default:
        iconData = Icons.help_outline;
        iconColor = colors.onSurfaceVariant;
        break;
    }
    return Icon(iconData, color: iconColor);
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
      // Use locale-aware date format
      return DateFormat.yMd(Localizations.localeOf(context).languageCode).add_Hm().format(dateTime);
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible de lancer l\appel vers $number')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(title: Text('Journal d'appels')), // Integrated into HomeScreen
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchCallLogs,
        tooltip: 'Rafraîchir le journal',
        child: const Icon(Icons.refresh_outlined), // Modernized icon
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
              const Icon(Icons.phone_disabled_outlined, size: 64), // Modernized icon
              const SizedBox(height: 16),
              const Text(
                'Permission d\accès au journal d\appels refusée.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.settings_outlined), // Modernized icon
                onPressed: openAppSettings,
                label: const Text('Ouvrir les paramètres'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh_outlined), // Modernized icon
                onPressed: _fetchCallLogs,
                label: const Text('Réessayer'),
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
        final callTypeIcon = _getCallTypeIcon(entry.callType ?? CallType.unknown, context);
        final formattedDuration = _formatDuration(entry.duration ?? 0);
        final formattedDateTime = _formatDateTime(entry.timestamp ?? 0);

        return ListTile(
          leading: callTypeIcon,
          title: Text(entry.name ?? entry.number ?? 'Numéro inconnu'),
          subtitle: Text('${entry.number ?? ''} • $formattedDuration'),
          trailing: Text(formattedDateTime, style: Theme.of(context).textTheme.bodySmall),
          onTap: () => _launchCall(entry.number), // Call back on tap
        );
      },
    );
  }
}

