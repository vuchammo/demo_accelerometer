import 'package:flutter/material.dart';

import 'database/recording_database.dart';
import 'database/recording_session.dart';
import 'recording_detail_screen.dart';

class RecordingHistoryScreen extends StatefulWidget {
  const RecordingHistoryScreen({super.key});

  @override
  State<RecordingHistoryScreen> createState() => _RecordingHistoryScreenState();
}

class _RecordingHistoryScreenState extends State<RecordingHistoryScreen> {
  late Future<List<RecordingSession>> _sessionsFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _sessionsFuture = RecordingDatabase.instance.getAllSessions();
    });
  }

  Future<void> _confirmDeleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa tất cả lịch sử?'),
        content: const Text(
          'Toàn bộ các phiên ghi sẽ bị xóa vĩnh viễn và không thể khôi phục.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xóa tất cả'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await RecordingDatabase.instance.deleteAllSessions();
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa tất cả phiên ghi')),
        );
      }
    }
  }

  Future<void> _deleteSession(RecordingSession session) async {
    if (session.id != null) {
      await RecordingDatabase.instance.deleteSession(session.id!);
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa phiên ghi')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: const Text(
          'Lịch sử ghi nhận',
          style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Xóa tất cả',
            onPressed: _confirmDeleteAll,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _refresh();
        },
        child: FutureBuilder<List<RecordingSession>>(
          future: _sessionsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final sessions = snapshot.data ?? [];

            if (sessions.isEmpty) {
              return Center(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.history_toggle_off_rounded,
                            size: 40,
                            color: Colors.blue.shade400,
                          ),
                        ),
                        const SizedBox(height: 18.0),
                        const Text(
                          'Chưa có phiên ghi nào',
                          style: TextStyle(
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        Text(
                          'Nhấn nút "Bắt đầu ghi" ở màn hình chính để thu thập và lưu dữ liệu bước chân vào lịch sử.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14.0,
                            color: Colors.grey.shade600,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16.0),
              itemCount: sessions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12.0),
              itemBuilder: (context, index) {
                final session = sessions[index];
                return _buildSessionCard(session);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildSessionCard(RecordingSession session) {
    return Dismissible(
      key: ValueKey(session.id ?? session.startTime.toIso8601String()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      onDismissed: (_) => _deleteSession(session),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        elevation: 1.0,
        shadowColor: Colors.black12,
        child: InkWell(
          borderRadius: BorderRadius.circular(16.0),
          onTap: () async {
            final result = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => RecordingDetailScreen(session: session),
              ),
            );
            if (result == true) {
              _refresh();
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: thời gian + icon chi tiết
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 15.0,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 8.0),
                        Text(
                          session.formattedStartTime,
                          style: TextStyle(
                            fontSize: 14.0,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade900,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.grey.shade400,
                      size: 22.0,
                    ),
                  ],
                ),
                const SizedBox(height: 14.0),
                // Stats row
                Row(
                  children: [
                    Expanded(
                      child: _infoChip(
                        Icons.timer_outlined,
                        session.formattedDuration,
                        'Thời lượng',
                      ),
                    ),
                    Expanded(
                      child: _infoChip(
                        Icons.data_usage,
                        session.totalSamples.toString(),
                        'Số mẫu',
                      ),
                    ),
                    Expanded(
                      child: _infoChip(
                        Icons.speed,
                        session.avgMagnitude.toStringAsFixed(2),
                        'Avg (m/s²)',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String value, String unit) {
    return Row(
      children: [
        Icon(icon, size: 15.0, color: Colors.grey.shade500),
        const SizedBox(width: 4.0),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 13.0,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              unit,
              style: TextStyle(fontSize: 10.0, color: Colors.grey.shade500),
            ),
          ],
        ),
      ],
    );
  }
}
