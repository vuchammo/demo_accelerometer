import 'package:flutter/material.dart';

import 'algorithm_evaluation_screen.dart';
import 'database/recording_database.dart';
import 'database/recording_session.dart';
import 'recording_detail_screen.dart';
import 'web_server/web_share_sheet.dart';

class RecordingHistoryScreen extends StatefulWidget {
  const RecordingHistoryScreen({super.key});

  @override
  State<RecordingHistoryScreen> createState() => _RecordingHistoryScreenState();
}

class _RecordingHistoryScreenState extends State<RecordingHistoryScreen> {
  late Future<List<RecordingSession>> _sessionsFuture;
  final TextEditingController _searchController = TextEditingController();
  String? _selectedTag;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã xóa phiên ghi')));
      }
    }
  }

  Future<void> _showEditTagDialog(RecordingSession session) async {
    final controller = TextEditingController(text: session.label ?? '');
    final savedTags = await RecordingDatabase.instance.getSavedTags();
    if (!mounted) return;

    final newTag = await showDialog<String?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.label_outline, color: Colors.indigo.shade700),
                const SizedBox(width: 8.0),
                const Text('Gắn tag cho phiên'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Tên tag',
                    hintText: 'Nhập tên tag...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    suffixIcon: controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              controller.clear();
                              setDialogState(() {});
                            },
                          )
                        : null,
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                if (savedTags.isNotEmpty) ...[
                  const SizedBox(height: 12.0),
                  Text(
                    'Tag đã dùng trước đó:',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 6.0),
                  Wrap(
                    spacing: 6.0,
                    runSpacing: 6.0,
                    children: savedTags.map((s) {
                      final isSelected =
                          controller.text.trim().toLowerCase() == s.toLowerCase();
                      return ActionChip(
                        visualDensity: VisualDensity.compact,
                        label: Text(
                          '#$s',
                          style: const TextStyle(fontSize: 11.5),
                        ),
                        backgroundColor: isSelected
                            ? Colors.indigo.shade100
                            : Colors.grey.shade100,
                        onPressed: () {
                          controller.text = isSelected ? '' : s;
                          setDialogState(() {});
                        },
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
            actions: [
              if (session.label != null && session.label!.isNotEmpty)
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: () => Navigator.of(ctx).pop(''),
                  child: const Text('Xóa tag'),
                ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
                child: const Text('Lưu'),
              ),
            ],
          );
        },
      ),
    );

    if (newTag != null && mounted && session.id != null) {
      await RecordingDatabase.instance.updateSessionLabel(
        session.id!,
        newTag.isEmpty ? null : newTag,
      );
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newTag.isEmpty ? 'Đã xóa tag' : 'Đã gắn tag "#$newTag"',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _openAlgorithmEvaluation() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AlgorithmEvaluationScreen(),
      ),
    );
    _refresh();
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
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'Đánh giá thuật toán',
            onPressed: _openAlgorithmEvaluation,
          ),
          IconButton(
            icon: const Icon(Icons.laptop_chromebook),
            tooltip: 'Xem trên máy tính (Wi-Fi)',
            onPressed: () => WebShareSheet.show(context),
          ),
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

            final allSessions = snapshot.data ?? [];

            if (allSessions.isEmpty) {
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

            // Danh sách unique tags
            final uniqueTags =
                allSessions
                    .map((s) => s.label?.trim())
                    .where((l) => l != null && l.isNotEmpty)
                    .cast<String>()
                    .toSet()
                    .toList()
                  ..sort();

            // Lọc danh sách theo tag và search query
            final query = _searchController.text.trim().toLowerCase();
            final filteredSessions = allSessions.where((s) {
              if (_selectedTag != null && _selectedTag!.isNotEmpty) {
                if (s.label?.trim().toLowerCase() !=
                    _selectedTag!.toLowerCase()) {
                  return false;
                }
              }
              if (query.isNotEmpty) {
                final labelMatch =
                    s.label?.toLowerCase().contains(query) ?? false;
                final dateMatch = s.formattedStartTime.toLowerCase().contains(
                  query,
                );
                final idMatch = s.id?.toString() == query;
                if (!labelMatch && !dateMatch && !idMatch) {
                  return false;
                }
              }
              return true;
            }).toList();

            return Column(
              children: [
                // Banner đánh giá độ chính xác thuật toán
                _buildEvaluationBanner(allSessions),

                // Khung tìm kiếm theo tag hoặc ngày giờ
                _buildSearchBar(),

                // Dải filter tags nếu có ít nhất 1 tag
                if (uniqueTags.isNotEmpty) _buildTagChips(uniqueTags),

                // Danh sách kết quả
                Expanded(
                  child: filteredSessions.isEmpty
                      ? Center(
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search_off_rounded,
                                    size: 48,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 12.0),
                                  Text(
                                    'Không tìm thấy phiên ghi phù hợp',
                                    style: TextStyle(
                                      fontSize: 16.0,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                  const SizedBox(height: 6.0),
                                  Text(
                                    _selectedTag != null
                                        ? 'Không có kết quả cho tag "#$_selectedTag"'
                                        : 'Thử tìm với từ khóa khác',
                                    style: TextStyle(
                                      fontSize: 13.0,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 16.0),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.clear_all, size: 18),
                                    label: const Text('Xóa bộ lọc'),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _selectedTag = null;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                            16.0,
                            4.0,
                            16.0,
                            16.0,
                          ),
                          itemCount: filteredSessions.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12.0),
                          itemBuilder: (context, index) {
                            final session = filteredSessions[index];
                            return _buildSessionCard(session);
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEvaluationBanner(List<RecordingSession> allSessions) {
    final taggedCount = allSessions
        .where((s) => s.label != null && s.label!.trim().isNotEmpty)
        .length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 2.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E2235),
            const Color(0xFF2E3856),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10.0,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16.0),
          onTap: _openAlgorithmEvaluation,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 14.0,
              vertical: 12.0,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: const Icon(
                    Icons.fact_check_outlined,
                    color: Color(0xFF00E5FF),
                    size: 22.0,
                  ),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Đánh giá độ chính xác thuật toán',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2.0),
                      Text(
                        'Kiểm thử $taggedCount/${allSessions.length} phiên có nhãn theo tiêu chí di chuyển',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10.0,
                    vertical: 5.0,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Kiểm tra',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(width: 2.0),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 15.0,
                        color: Color(0xFF0F172A),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8.0,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Tìm theo tag, ngày giờ...',
          hintStyle: TextStyle(fontSize: 13.5, color: Colors.grey.shade400),
          prefixIcon: Icon(
            Icons.search,
            size: 20.0,
            color: Colors.grey.shade600,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 18.0),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14.0,
            vertical: 11.0,
          ),
        ),
        style: const TextStyle(fontSize: 13.5),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildTagChips(List<String> tags) {
    return Container(
      height: 38.0,
      margin: const EdgeInsets.only(bottom: 8.0),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        itemCount: tags.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8.0),
        itemBuilder: (context, index) {
          if (index == 0) {
            final isSelected = _selectedTag == null;
            return ChoiceChip(
              label: const Text('Tất cả'),
              selected: isSelected,
              onSelected: (_) {
                setState(() {
                  _selectedTag = null;
                });
              },
              selectedColor: Colors.blue.shade100,
              labelStyle: TextStyle(
                fontSize: 12.0,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.blue.shade900 : Colors.grey.shade700,
              ),
              side: BorderSide(
                color: isSelected ? Colors.blue.shade400 : Colors.grey.shade300,
              ),
            );
          }

          final tag = tags[index - 1];
          final isSelected = _selectedTag?.toLowerCase() == tag.toLowerCase();
          return ChoiceChip(
            avatar: Icon(
              Icons.label_outline,
              size: 13.0,
              color: isSelected ? Colors.indigo.shade800 : Colors.grey.shade600,
            ),
            label: Text('#$tag'),
            selected: isSelected,
            onSelected: (_) {
              setState(() {
                _selectedTag = isSelected ? null : tag;
              });
            },
            selectedColor: Colors.indigo.shade100,
            labelStyle: TextStyle(
              fontSize: 12.0,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.indigo.shade900 : Colors.grey.shade700,
            ),
            side: BorderSide(
              color: isSelected ? Colors.indigo.shade400 : Colors.grey.shade300,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSessionCard(RecordingSession session) {
    final hasTag = session.label != null && session.label!.isNotEmpty;

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
                // Top row: tag, thời gian + nút đổi tag + chevron
                Row(
                  children: [
                    if (hasTag) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 3.0,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(
                            color: Colors.indigo.shade200,
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.label,
                              size: 11.0,
                              color: Colors.indigo.shade700,
                            ),
                            const SizedBox(width: 4.0),
                            Text(
                              '#${session.label}',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8.0),
                    ],
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 13.0,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 5.0),
                    Expanded(
                      child: Text(
                        session.formattedStartTime,
                        style: TextStyle(
                          fontSize: 13.0,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        hasTag ? Icons.edit_outlined : Icons.new_label_outlined,
                        size: 17.0,
                        color: hasTag
                            ? Colors.indigo.shade400
                            : Colors.grey.shade400,
                      ),
                      tooltip: hasTag ? 'Đổi tag' : 'Thêm tag',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _showEditTagDialog(session),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.grey.shade400,
                      size: 20.0,
                    ),
                  ],
                ),
                const SizedBox(height: 12.0),
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
