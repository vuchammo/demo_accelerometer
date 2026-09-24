import 'package:flutter/material.dart';

import 'algorithm_evaluation_service.dart';
import 'database/recording_database.dart';
import 'recording_detail_screen.dart';

class AlgorithmEvaluationScreen extends StatefulWidget {
  const AlgorithmEvaluationScreen({super.key});

  @override
  State<AlgorithmEvaluationScreen> createState() =>
      _AlgorithmEvaluationScreenState();
}

class _AlgorithmEvaluationScreenState extends State<AlgorithmEvaluationScreen> {
  bool _isLoading = true;
  List<SessionEvaluationResult> _results = [];
  final Map<int, bool?> _manualOverrides = {};
  int _selectedFilterIndex = 0; // 0: Tất cả, 1: Đúng, 2: Sai, 3: Bỏ qua

  @override
  void initState() {
    super.initState();
    _loadAndEvaluate();
  }

  Future<void> _loadAndEvaluate() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final sessions = await RecordingDatabase.instance.getAllSessions();
      final statsMap = await RecordingDatabase.instance
          .getSessionsMagnitudeDistribution();

      final List<SessionEvaluationResult> list = [];

      for (final session in sessions) {
        if (session.id == null) continue;
        final stats = statsMap[session.id!];

        final totalSamples = stats?['total_samples'] ?? session.totalSamples;
        final moderateCount = stats?['moderate_count'] ?? 0;
        final highCount = stats?['high_count'] ?? 0;
        final peakCount = stats?['peak_count'] ?? 0;

        final manualGt = _manualOverrides.containsKey(session.id!)
            ? _manualOverrides[session.id!]
            : null;

        final res = AlgorithmEvaluationService.instance.evaluateCountData(
          session: session,
          totalSamples: totalSamples,
          moderateCount: moderateCount,
          highCount: highCount,
          peakCount: peakCount,
          manualGroundTruth: manualGt,
        );

        list.add(res);
      }

      if (mounted) {
        setState(() {
          _results = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi tải dữ liệu đánh giá: $e')),
        );
      }
    }
  }

  void _setManualGroundTruth(int sessionId, bool? value) {
    setState(() {
      _manualOverrides[sessionId] = value;
      // Cập nhật lại danh sách kết quả tại chỗ
      _results = _results.map((r) {
        if (r.session.id == sessionId) {
          return r.copyWithGroundTruth(value);
        }
        return r;
      }).toList();
    });
  }

  void _showRuleInfoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18.0),
        ),
        title: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Colors.indigo.shade600),
            const SizedBox(width: 8.0),
            const Text(
              'Quy tắc Thuật toán',
              style: TextStyle(fontSize: 17.0, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thuật toán đánh giá phiên ghi là "CÓ DI CHUYỂN" khi thỏa mãn đồng thời cả 2 điều kiện:',
              style: TextStyle(fontSize: 13.5, height: 1.4),
            ),
            const SizedBox(height: 12.0),
            _ruleBullet(
              '1. Gia tốc mức vừa (1.0 – 4.0 m/s²)',
              '> 30.0% tổng số mẫu',
              Colors.teal.shade700,
            ),
            const SizedBox(height: 8.0),
            _ruleBullet(
              '2. Gia tốc cao & cực đại (≥ 4.0 m/s²)',
              '< 5.0% tổng số mẫu',
              Colors.deepOrange.shade700,
            ),
            const SizedBox(height: 12.0),
            Container(
              padding: const EdgeInsets.all(10.0),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10.0),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Text(
                'Nếu không thỏa mãn 1 trong 2 điều kiện trên, phiên ghi sẽ được kết luận là "KHÔNG DI CHUYỂN".',
                style: TextStyle(fontSize: 12.5, color: Colors.amber.shade900),
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  Widget _ruleBullet(String title, String condition, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle_outline, size: 16.0, color: color),
        const SizedBox(width: 6.0),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13.0, color: Colors.black87),
              children: [
                TextSpan(
                  text: '$title: ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(
                  text: condition,
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = AlgorithmEvaluationService.instance.generateReport(_results);

    // Lọc danh sách theo filter tab
    final filteredResults = _results.where((r) {
      if (_selectedFilterIndex == 1) return r.isCorrect == true;
      if (_selectedFilterIndex == 2) return r.isCorrect == false;
      if (_selectedFilterIndex == 3) return r.groundTruthIsMoving == null;
      return true; // Tất cả
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: const Text(
          'Đánh giá Thuật toán',
          style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'Xem quy tắc thuật toán',
            onPressed: _showRuleInfoDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Tính toán lại',
            onPressed: _loadAndEvaluate,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16.0),
                  Text('Đang phân tích các phiên ghi...'),
                ],
              ),
            )
          : _results.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.folder_off_outlined,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16.0),
                    const Text(
                      'Chưa có dữ liệu phiên ghi',
                      style: TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      'Hãy thực hiện các phiên ghi có gắn nhãn (ví dụ: "cầm trên tay, đi chậm" hoặc "không di chuyển") rồi quay lại kiểm tra.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadAndEvaluate,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 24.0),
                children: [
                  // 1. Thẻ Hero KPI hiển thị % độ chính xác
                  _buildAccuracyHeroCard(report),

                  const SizedBox(height: 12.0),

                  // 2. Banner tóm tắt quy tắc
                  _buildRuleSummaryBanner(),

                  const SizedBox(height: 14.0),

                  // 3. Tab Filter
                  _buildFilterChips(report),

                  const SizedBox(height: 12.0),

                  // 4. Danh sách các phiên ghi
                  if (filteredResults.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 40.0),
                      alignment: Alignment.center,
                      child: Text(
                        'Không có phiên ghi nào trong mục này',
                        style: TextStyle(
                          fontSize: 14.0,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    )
                  else
                    ...filteredResults.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: _buildSessionEvaluationCard(item),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  /// Thẻ Hero KPI hiển thị % độ chính xác lớn
  Widget _buildAccuracyHeroCard(EvaluationReport report) {
    final accuracy = report.accuracyPercentage;
    final isGood = accuracy >= 80.0;
    final isMedium = accuracy >= 50.0 && accuracy < 80.0;

    final Color statusColor = isGood
        ? const Color(0xFF10B981) // Emerald Green
        : isMedium
        ? const Color(0xFFF59E0B) // Amber
        : const Color(0xFFEF4444); // Red

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1E2235), const Color(0xFF272D45)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 14.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Vòng tròn tỷ lệ
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 76,
                    height: 76,
                    child: CircularProgressIndicator(
                      value: report.evaluatedCount > 0
                          ? (accuracy / 100.0).clamp(0.0, 1.0)
                          : 0.0,
                      strokeWidth: 8.0,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    ),
                  ),
                  Text(
                    '${accuracy.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 18.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'ĐỘ CHÍNH XÁC',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 3.0,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.6),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            isGood
                                ? 'Rất tốt'
                                : isMedium
                                ? 'Khá'
                                : 'Cần tối ưu',
                            style: TextStyle(
                              fontSize: 11.0,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6.0),
                    Text(
                      '${report.correctCount} / ${report.evaluatedCount} phiên đúng',
                      style: const TextStyle(
                        fontSize: 20.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      report.evaluatedCount > 0
                          ? 'Dựa trên ${report.evaluatedCount} phiên có nhãn đính kèm'
                          : 'Chưa có phiên nào có nhãn hợp lệ',
                      style: TextStyle(
                        fontSize: 12.0,
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          const Divider(color: Colors.white12, height: 1.0),
          const SizedBox(height: 14.0),
          // 3 ô chỉ số con
          Row(
            children: [
              Expanded(
                child: _buildKpiStatItem(
                  icon: Icons.check_circle_rounded,
                  iconColor: const Color(0xFF10B981),
                  label: 'Đoán đúng',
                  value: '${report.correctCount}',
                ),
              ),
              Container(width: 1.0, height: 28.0, color: Colors.white12),
              Expanded(
                child: _buildKpiStatItem(
                  icon: Icons.cancel_rounded,
                  iconColor: const Color(0xFFEF4444),
                  label: 'Đoán sai',
                  value: '${report.incorrectCount}',
                ),
              ),
              Container(width: 1.0, height: 28.0, color: Colors.white12),
              Expanded(
                child: _buildKpiStatItem(
                  icon: Icons.help_rounded,
                  iconColor: Colors.amber.shade300,
                  label: 'Chưa có nhãn',
                  value: '${report.unclassifiedCount}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiStatItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14.0, color: iconColor),
            const SizedBox(width: 4.0),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4.0),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  /// Banner tóm tắt quy tắc điều kiện di chuyển
  Widget _buildRuleSummaryBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6.0),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.tune_rounded,
              size: 16.0,
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(width: 10.0),
          Expanded(
            child: Text(
              'Điều kiện di chuyển: Gia tốc vừa > 30% và Gia tốc cao + cực đại < 5%',
              style: TextStyle(
                fontSize: 12.0,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Thanh Tabs Lọc (Filter Chips)
  Widget _buildFilterChips(EvaluationReport report) {
    final filters = [
      'Tất cả (${_results.length})',
      'Đúng (${report.correctCount})',
      'Sai (${report.incorrectCount})',
      'Chưa nhãn (${report.unclassifiedCount})',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(filters.length, (index) {
          final isSelected = _selectedFilterIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(filters[index]),
              selected: isSelected,
              onSelected: (_) {
                setState(() {
                  _selectedFilterIndex = index;
                });
              },
              selectedColor: Colors.indigo.shade100,
              labelStyle: TextStyle(
                fontSize: 12.0,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? Colors.indigo.shade900
                    : Colors.grey.shade700,
              ),
              side: BorderSide(
                color: isSelected
                    ? Colors.indigo.shade300
                    : Colors.grey.shade300,
              ),
            ),
          );
        }),
      ),
    );
  }

  /// Card chi tiết từng phiên ghi
  Widget _buildSessionEvaluationCard(SessionEvaluationResult result) {
    final session = result.session;
    final isCorrect = result.isCorrect;
    final hasGroundTruth = result.groundTruthIsMoving != null;

    final Color cardBorderColor = !hasGroundTruth
        ? Colors.grey.shade200
        : isCorrect == true
        ? const Color(0xFF10B981).withValues(alpha: 0.4)
        : const Color(0xFFEF4444).withValues(alpha: 0.4);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: cardBorderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dòng 1: Tag nhãn, Thời gian, Badge kết quả
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                                vertical: 3.0,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    session.label != null &&
                                        session.label!.isNotEmpty
                                    ? Colors.indigo.shade50
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8.0),
                                border: Border.all(
                                  color:
                                      session.label != null &&
                                          session.label!.isNotEmpty
                                      ? Colors.indigo.shade200
                                      : Colors.grey.shade300,
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.label,
                                    size: 11.0,
                                    color:
                                        session.label != null &&
                                            session.label!.isNotEmpty
                                        ? Colors.indigo.shade700
                                        : Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4.0),
                                  Flexible(
                                    child: Text(
                                      session.label != null &&
                                              session.label!.isNotEmpty
                                          ? '#${session.label}'
                                          : 'Chưa gắn tag',
                                      style: TextStyle(
                                        fontSize: 12.0,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            session.label != null &&
                                                session.label!.isNotEmpty
                                            ? Colors.indigo.shade800
                                            : Colors.grey.shade600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        session.formattedStartTime,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Badge Kết quả
                _buildStatusBadge(isCorrect, hasGroundTruth),
              ],
            ),

            const SizedBox(height: 12.0),

            // Dòng 2: Chi tiết tỷ lệ % gia tốc
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _buildMetricRow(
                    label: 'Gia tốc vừa (1.0–4.0 m/s²)',
                    percentage: result.moderatePercentage,
                    thresholdText: 'Yêu cầu > 30%',
                    isPassed: result.moderatePercentage > 30.0,
                  ),
                  const SizedBox(height: 8.0),
                  _buildMetricRow(
                    label: 'Gia tốc cao & cực đại (≥ 4.0 m/s²)',
                    percentage: result.highAndPeakPercentage,
                    thresholdText: 'Yêu cầu < 5%',
                    isPassed: result.highAndPeakPercentage < 5.0,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12.0),

            // Dòng 3: Đối chiếu Dự đoán vs Nhãn thực tế
            Row(
              children: [
                // Thuật toán phán đoán
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10.0,
                      vertical: 8.0,
                    ),
                    decoration: BoxDecoration(
                      color: result.predictedIsMoving
                          ? Colors.teal.shade50
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10.0),
                      border: Border.all(
                        color: result.predictedIsMoving
                            ? Colors.teal.shade200
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Thuật toán đoán:',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 2.0),
                        Row(
                          children: [
                            Icon(
                              result.predictedIsMoving
                                  ? Icons.directions_walk_rounded
                                  : Icons.pan_tool_rounded,
                              size: 14.0,
                              color: result.predictedIsMoving
                                  ? Colors.teal.shade800
                                  : Colors.grey.shade800,
                            ),
                            const SizedBox(width: 4.0),
                            Expanded(
                              child: Text(
                                result.predictedIsMoving
                                    ? 'CÓ DI CHUYỂN'
                                    : 'KHÔNG DI CHUYỂN',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: result.predictedIsMoving
                                      ? Colors.teal.shade900
                                      : Colors.grey.shade800,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
                // Nhãn thực tế (Ground Truth) + Nút đổi nhanh
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10.0),
                    onTap: () {
                      _showGroundTruthSelector(result);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10.0,
                        vertical: 8.0,
                      ),
                      decoration: BoxDecoration(
                        color: hasGroundTruth
                            ? (result.groundTruthIsMoving == true
                                  ? Colors.blue.shade50
                                  : Colors.amber.shade50)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(
                          color: hasGroundTruth
                              ? (result.groundTruthIsMoving == true
                                    ? Colors.blue.shade200
                                    : Colors.amber.shade200)
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Thực tế (Nhãn):',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.edit_note_rounded,
                                size: 14.0,
                                color: Colors.grey.shade600,
                              ),
                            ],
                          ),
                          const SizedBox(height: 2.0),
                          Row(
                            children: [
                              Icon(
                                result.groundTruthIsMoving == true
                                    ? Icons.directions_walk_rounded
                                    : (result.groundTruthIsMoving == false
                                          ? Icons.pan_tool_rounded
                                          : Icons.help_outline_rounded),
                                size: 14.0,
                                color: result.groundTruthIsMoving == true
                                    ? Colors.blue.shade800
                                    : (result.groundTruthIsMoving == false
                                          ? Colors.amber.shade900
                                          : Colors.grey.shade600),
                              ),
                              const SizedBox(width: 4.0),
                              Expanded(
                                child: Text(
                                  result.groundTruthIsMoving == true
                                      ? 'CÓ DI CHUYỂN'
                                      : (result.groundTruthIsMoving == false
                                            ? 'KHÔNG DI CHUYỂN'
                                            : 'Chưa xác định'),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: result.groundTruthIsMoving == true
                                        ? Colors.blue.shade900
                                        : (result.groundTruthIsMoving == false
                                              ? Colors.amber.shade900
                                              : Colors.grey.shade600),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Dòng 4: Lý do giải thích nếu Sai
            if (isCorrect == false) ...[
              const SizedBox(height: 10.0),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10.0,
                  vertical: 6.0,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 14.0,
                      color: Colors.red.shade700,
                    ),
                    const SizedBox(width: 6.0),
                    Expanded(
                      child: Text(
                        result.explanation,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.red.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 10.0),

            // Dòng cuối: Nút xem chi tiết biểu đồ
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${session.formattedDuration} | ${result.totalSamples} mẫu',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  ),
                  icon: const Icon(Icons.show_chart_rounded, size: 16.0),
                  label: const Text(
                    'Xem biểu đồ',
                    style: TextStyle(fontSize: 12.0),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RecordingDetailScreen(session: session),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Badge trạng thái (Đúng / Sai / Chưa rõ)
  Widget _buildStatusBadge(bool? isCorrect, bool hasGroundTruth) {
    if (!hasGroundTruth) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.5),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.help_outline, size: 12.0, color: Colors.grey.shade600),
            const SizedBox(width: 4.0),
            Text(
              'Chưa có nhãn',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    if (isCorrect == true) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.5),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: const Color(0xFF10B981).withValues(alpha: 0.6),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_rounded,
              size: 13.0,
              color: Color(0xFF10B981),
            ),
            SizedBox(width: 4.0),
            Text(
              'ĐOÁN ĐÚNG',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF10B981),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.5),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: const Color(0xFFEF4444).withValues(alpha: 0.6),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cancel_rounded, size: 13.0, color: Color(0xFFEF4444)),
            SizedBox(width: 4.0),
            Text(
              'ĐOÁN SAI',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFFEF4444),
              ),
            ),
          ],
        ),
      );
    }
  }

  /// Hàng thanh đo % gia tốc
  Widget _buildMetricRow({
    required String label,
    required double percentage,
    required String thresholdText,
    required bool isPassed,
  }) {
    final statusColor = isPassed
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            Row(
              children: [
                Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 4.0),
                Icon(
                  isPassed ? Icons.check : Icons.close,
                  size: 13.0,
                  color: statusColor,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4.0),
        ClipRRect(
          borderRadius: BorderRadius.circular(4.0),
          child: LinearProgressIndicator(
            value: (percentage / 100.0).clamp(0.0, 1.0),
            minHeight: 5.0,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(statusColor),
          ),
        ),
        const SizedBox(height: 2.0),
        Text(
          thresholdText,
          style: TextStyle(fontSize: 10.0, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  /// Dialog cho phép người dùng đổi Ground Truth nhanh cho một phiên
  void _showGroundTruthSelector(SessionEvaluationResult result) {
    if (result.session.id == null) return;
    final sessionId = result.session.id!;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16.0),
              Text(
                'Chọn Nhãn Thực Tế (Ground Truth)',
                style: const TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6.0),
              Text(
                'Phiên ghi: #${result.session.label ?? "Không có nhãn"} (${result.session.formattedStartTime})',
                style: TextStyle(fontSize: 13.0, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16.0),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.directions_walk_rounded,
                    color: Colors.blue.shade700,
                  ),
                ),
                title: const Text(
                  'Có di chuyển (Moving)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Đi chậm, cầm trên tay, chạy bộ, v.v.'),
                trailing: result.groundTruthIsMoving == true
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  Navigator.of(ctx).pop();
                  _setManualGroundTruth(sessionId, true);
                },
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.pan_tool_rounded,
                    color: Colors.amber.shade700,
                  ),
                ),
                title: const Text(
                  'Không di chuyển (Stationary)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Để trên bàn, đứng yên, tĩnh, v.v.'),
                trailing: result.groundTruthIsMoving == false
                    ? const Icon(Icons.check, color: Colors.amber)
                    : null,
                onTap: () {
                  Navigator.of(ctx).pop();
                  _setManualGroundTruth(sessionId, false);
                },
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.restart_alt_rounded,
                    color: Colors.grey.shade700,
                  ),
                ),
                title: const Text(
                  'Khôi phục tự động theo từ khóa nhãn',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _setManualGroundTruth(
                    sessionId,
                    AlgorithmEvaluationService.instance.determineGroundTruth(
                      result.session.label,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
