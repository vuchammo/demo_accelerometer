import 'package:flutter/material.dart';

import 'algorithm_evaluation_service.dart';
import 'database/recording_database.dart';
import 'database/recording_session.dart';
import 'motion_detector.dart';
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

  bool _isRuleExpanded = false;

  // Config thuật toán (v3)
  double _cvMax = 0.30;
  double _meanMin = 0.30;
  double _peakMin = 0.20;
  double _sessionRatio = 0.50;

  List<RecordingSession> _cachedSessions = [];
  Map<int, ({List<double> times, List<double> magnitudes})> _cachedRawDataMap =
      {};

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
      final rawDataMap = await RecordingDatabase.instance.getSessionsRawData();

      _cachedSessions = sessions;
      _cachedRawDataMap = rawDataMap;

      _recomputeResults();

      if (mounted) {
        setState(() {
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

  List<SessionEvaluationResult> _computeResultsForConfig(MotionConfig config) {
    final List<SessionEvaluationResult> list = [];
    for (final session in _cachedSessions) {
      if (session.id == null) continue;
      final rawData = _cachedRawDataMap[session.id!];

      final manualGt = _manualOverrides.containsKey(session.id!)
          ? _manualOverrides[session.id!]
          : null;

      if (rawData == null || rawData.times.isEmpty) {
        // Phiên không có dữ liệu
        list.add(
          SessionEvaluationResult(
            session: session,
            totalSamples: 0,
            predictedIsMoving: false,
            voteRatio: 0.0,
            totalWindows: 0,
            movingVotes: 0,
            groundTruthIsMoving:
                manualGt ??
                AlgorithmEvaluationService.instance.determineGroundTruth(
                  session.label,
                ),
            groundTruthSource: manualGt != null ? 'manual' : 'auto_keyword',
            config: config,
          ),
        );
        continue;
      }

      final res = AlgorithmEvaluationService.instance.evaluateRawData(
        session: session,
        tSeconds: rawData.times,
        magnitudes: rawData.magnitudes,
        manualGroundTruth: manualGt,
        config: config,
      );

      list.add(res);
    }
    return list;
  }

  void _recomputeResults() {
    final config = MotionConfig(
      cvMax: _cvMax,
      meanMin: _meanMin,
      peakMin: _peakMin,
      sessionRatio: _sessionRatio,
    );
    _results = _computeResultsForConfig(config);
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
              'Thuật toán phát hiện di chuyển (v3) kết hợp đường bao CV và tự tương quan (autocorrelation):',
              style: TextStyle(fontSize: 13.5, height: 1.4),
            ),
            const SizedBox(height: 12.0),
            _ruleBullet(
              '1. Hệ số biến thiên đường bao (CV)',
              '< ${_cvMax.toStringAsFixed(2)} (dao động duy trì = di chuyển)',
              Colors.teal.shade700,
            ),
            const SizedBox(height: 8.0),
            _ruleBullet(
              '2. Trung bình magnitude (Mean)',
              '> ${_meanMin.toStringAsFixed(2)} m/s² (loại nhiễu nền)',
              Colors.indigo.shade700,
            ),
            const SizedBox(height: 8.0),
            _ruleBullet(
              '3. Đỉnh tự tương quan (Peak AC)',
              '> ${_peakMin.toStringAsFixed(2)} (tính chu kỳ, chống nhầm khi chạm/vuốt)',
              Colors.purple.shade700,
            ),
            const SizedBox(height: 8.0),
            _ruleBullet(
              '4. Tỉ lệ cửa sổ di chuyển',
              '≥ ${(_sessionRatio * 100).toStringAsFixed(0)}% tổng cửa sổ',
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
                'Cửa sổ 4.0s (50 mẫu), trượt ~0.48s (6 mẫu), đường bao mượt ~0.8s (10 mẫu). Tự tương quan tách cao tần trễ 0.24-1.44s. Bộ lọc đa số trượt 10 cửa sổ gần nhất.',
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
                  _buildRuleSummaryBanner(report),

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
        ? const Color(0xFF10B981)
        : isMedium
        ? const Color(0xFFF59E0B)
        : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E2235), Color(0xFF272D45)],
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

  /// Khung hiển thị thông minh mô tả điều kiện di chuyển (Interactive Condition Card)
  Widget _buildRuleSummaryBanner(EvaluationReport report) {
    final isCustomConfig =
        _cvMax != 0.30 || _meanMin != 0.30 || _sessionRatio != 0.50;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: isCustomConfig ? Colors.indigo.shade300 : Colors.grey.shade200,
          width: isCustomConfig ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isCustomConfig
                ? Colors.indigo.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10.0,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Bar
          InkWell(
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(16.0),
              bottom: _isRuleExpanded
                  ? Radius.zero
                  : const Radius.circular(16.0),
            ),
            onTap: () {
              setState(() {
                _isRuleExpanded = !_isRuleExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14.0, 12.0, 10.0, 10.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7.0),
                    decoration: BoxDecoration(
                      color: isCustomConfig
                          ? Colors.indigo.shade50
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      size: 16.0,
                      color: isCustomConfig
                          ? Colors.indigo.shade700
                          : Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(width: 10.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Flexible(
                              child: Text(
                                'THUẬT TOÁN CV-BASED',
                                style: TextStyle(
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.4,
                                  color: Color(0xFF1E2235),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isCustomConfig) ...[
                              const SizedBox(width: 6.0),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6.0,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(6.0),
                                ),
                                child: Text(
                                  'Tùy chỉnh',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2.0),
                        Text(
                          _isRuleExpanded
                              ? 'Chạm để thu gọn chi tiết'
                              : 'Chạm để xem chi tiết thuật toán',
                          style: TextStyle(
                            fontSize: 11.0,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Nút mở BottomSheet thử nghiệm config
                  IconButton(
                    icon: Icon(
                      Icons.tune,
                      size: 18.0,
                      color: isCustomConfig
                          ? Colors.indigo.shade700
                          : Colors.grey.shade600,
                    ),
                    tooltip: 'Thử nghiệm tham số',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _showConfigTuningSheet(report),
                  ),
                  Icon(
                    _isRuleExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20.0,
                    color: Colors.grey.shade500,
                  ),
                ],
              ),
            ),
          ),

          // 2. Hai thẻ điều kiện trực quan
          Padding(
            padding: const EdgeInsets.fromLTRB(14.0, 4.0, 14.0, 12.0),
            child: Column(
              children: [
                // Dòng 1: Hệ số biến thiên CV
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 9.0,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDFA),
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: const Color(0xFF99F6E4),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCCFBF1),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: const Icon(
                          Icons.analytics_rounded,
                          size: 15.0,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                      const SizedBox(width: 10.0),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hệ số biến thiên (CV)',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F766E),
                              ),
                            ),
                            SizedBox(height: 1.0),
                            Text(
                              'CV = std / mean trên cửa sổ trượt',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Color(0xFF115E59),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9.0,
                          vertical: 4.0,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(color: const Color(0xFF5EEAD4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'CV ',
                              style: TextStyle(
                                fontSize: 11.0,
                                color: Color(0xFF134E4A),
                              ),
                            ),
                            Text(
                              '< ${_cvMax.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 13.0,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F766E),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Đường liên kết ở giữa với chip VÀ (AND)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 1.0,
                          color: Colors.grey.shade200,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10.0),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 2.0,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2235),
                          borderRadius: BorderRadius.circular(6.0),
                        ),
                        child: const Text(
                          'VÀ',
                          style: TextStyle(
                            fontSize: 10.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 1.0,
                          color: Colors.grey.shade200,
                        ),
                      ),
                    ],
                  ),
                ),

                // Dòng 2: Trung bình magnitude
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 9.0,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF), // Indigo 50
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: const Color(0xFFC7D2FE), // Indigo 200
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0E7FF),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: const Icon(
                          Icons.speed_rounded,
                          size: 15.0,
                          color: Color(0xFF4338CA), // Indigo 700
                        ),
                      ),
                      const SizedBox(width: 10.0),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Trung bình magnitude',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4338CA),
                              ),
                            ),
                            SizedBox(height: 1.0),
                            Text(
                              'Trung bình gia tốc trong cửa sổ',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Color(0xFF3730A3),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9.0,
                          vertical: 4.0,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(color: const Color(0xFFA5B4FC)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Mean ',
                              style: TextStyle(
                                fontSize: 11.0,
                                color: Color(0xFF312E81),
                              ),
                            ),
                            Text(
                              '> ${_meanMin.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 13.0,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4338CA),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Đường liên kết ở giữa với chip VÀ (AND)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 1.0,
                          color: Colors.grey.shade200,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10.0),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 2.0,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2235),
                          borderRadius: BorderRadius.circular(6.0),
                        ),
                        child: const Text(
                          'VÀ',
                          style: TextStyle(
                            fontSize: 10.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 1.0,
                          color: Colors.grey.shade200,
                        ),
                      ),
                    ],
                  ),
                ),

                // Dòng 3: Đỉnh tự tương quan (Peak AC)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 9.0,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF5FF), // Purple 50
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: const Color(0xFFE9D5FF), // Purple 200
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: const Icon(
                          Icons.timeline_rounded,
                          size: 15.0,
                          color: Color(0xFF7E22CE), // Purple 700
                        ),
                      ),
                      const SizedBox(width: 10.0),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Đỉnh tự tương quan (Peak)',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF7E22CE),
                              ),
                            ),
                            SizedBox(height: 1.0),
                            Text(
                              'Tính chu kỳ nhịp đi bộ / cử động',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Color(0xFF6B21A8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9.0,
                          vertical: 4.0,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(color: const Color(0xFFD8B4FE)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Peak ',
                              style: TextStyle(
                                fontSize: 11.0,
                                color: Color(0xFF581C87),
                              ),
                            ),
                            Text(
                              '> ${_peakMin.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 13.0,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF7E22CE),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 3. Dòng kết luận trực quan
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 14.0,
              vertical: 7.0,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(
                bottom: _isRuleExpanded
                    ? Radius.zero
                    : const Radius.circular(16.0),
              ),
              border: Border(
                top: BorderSide(color: Colors.grey.shade200, width: 0.8),
              ),
            ),
            child: Wrap(
              spacing: 4.0,
              runSpacing: 4.0,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Icon(
                  Icons.arrow_right_alt_rounded,
                  size: 16.0,
                  color: Colors.black54,
                ),
                Text(
                  'Tỉ lệ vote ≥ ${(_sessionRatio * 100).toStringAsFixed(0)}%:',
                  style: const TextStyle(fontSize: 11.0, color: Colors.black54),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6.0,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6.0),
                  ),
                  child: const Text(
                    'CÓ DI CHUYỂN',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF047857),
                    ),
                  ),
                ),
                const Text(
                  'Còn lại:',
                  style: TextStyle(fontSize: 11.0, color: Colors.black54),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6.0,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6.0),
                  ),
                  child: Text(
                    'KHÔNG DI CHUYỂN',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 4. Khối Mở rộng chi tiết
          if (_isRuleExpanded)
            Container(
              padding: const EdgeInsets.all(14.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16.0),
                ),
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200, width: 0.8),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'THAM SỐ CỬA SỔ TRƯỢT:',
                    style: TextStyle(
                      fontSize: 11.0,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  _buildConfigInfoRow(
                    'Cửa sổ',
                    '4.0s (50 mẫu)',
                    Colors.teal.shade600,
                  ),
                  const SizedBox(height: 6.0),
                  _buildConfigInfoRow(
                    'Bước trượt',
                    '~0.48s (6 mẫu)',
                    Colors.teal.shade600,
                  ),
                  const SizedBox(height: 6.0),
                  _buildConfigInfoRow(
                    'Đường bao mượt (CV)',
                    '~0.8s (10 mẫu)',
                    Colors.purple.shade600,
                  ),
                  const SizedBox(height: 6.0),
                  _buildConfigInfoRow(
                    'Tự tương quan (hp / lag)',
                    '10 mẫu / lag 3..18 (~0.24-1.44s)',
                    Colors.deepPurple.shade600,
                  ),
                  const SizedBox(height: 6.0),
                  _buildConfigInfoRow(
                    'Bộ lọc đa số trượt',
                    '10 cửa sổ gần nhất (≥ 50%)',
                    Colors.indigo.shade600,
                  ),
                  const SizedBox(height: 6.0),
                  _buildConfigInfoRow(
                    'Bỏ qua đầu phiên',
                    '1.5s',
                    Colors.amber.shade800,
                  ),
                  const SizedBox(height: 12.0),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                      icon: const Icon(Icons.tune_rounded, size: 16.0),
                      label: const Text(
                        'Thử nghiệm thay đổi tham số thuật toán',
                        style: TextStyle(fontSize: 12.0),
                      ),
                      onPressed: () => _showConfigTuningSheet(report),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConfigInfoRow(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.grey.shade200, width: 0.8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5.0),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 8.0),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showConfigTuningSheet(EvaluationReport currentReport) {
    double tempCvMax = _cvMax;
    double tempMeanMin = _meanMin;
    double tempPeakMin = _peakMin;
    double tempSessionRatio = _sessionRatio;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final previewConfig = MotionConfig(
            cvMax: tempCvMax,
            meanMin: tempMeanMin,
            peakMin: tempPeakMin,
            sessionRatio: tempSessionRatio,
          );
          final previewResults = _computeResultsForConfig(previewConfig);
          final previewReport = AlgorithmEvaluationService.instance
              .generateReport(previewResults);
          final isModified =
              tempCvMax != 0.30 ||
              tempMeanMin != 0.30 ||
              tempPeakMin != 0.20 ||
              tempSessionRatio != 0.50;

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
            ),
            padding: EdgeInsets.fromLTRB(
              20.0,
              16.0,
              20.0,
              MediaQuery.of(context).viewInsets.bottom + 24.0,
            ),
            child: SingleChildScrollView(
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        child: Icon(
                          Icons.tune_rounded,
                          color: Colors.indigo.shade700,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10.0),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Thử Nghiệm Tham Số Thuật Toán',
                              style: TextStyle(
                                fontSize: 16.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Kéo thanh trượt để kiểm tra độ chính xác',
                              style: TextStyle(
                                fontSize: 12.0,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isModified)
                        TextButton(
                          onPressed: () {
                            setSheetState(() {
                              tempCvMax = 0.30;
                              tempMeanMin = 0.30;
                              tempPeakMin = 0.20;
                              tempSessionRatio = 0.50;
                            });
                          },
                          child: const Text(
                            'Mặc định',
                            style: TextStyle(fontSize: 12.5),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16.0),

                  // Preview Card
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 12.0,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E2235), Color(0xFF2E3856)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14.0),
                    ),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ĐỘ CHÍNH XÁC MỚI',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.6,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(height: 2.0),
                            Text(
                              '${previewReport.accuracyPercentage.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontSize: 24.0,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF00E5FF),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${previewReport.correctCount}/${previewReport.evaluatedCount} phiên đúng',
                              style: const TextStyle(
                                fontSize: 13.0,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2.0),
                            Text(
                              previewReport.accuracyPercentage >
                                      currentReport.accuracyPercentage
                                  ? '▲ Tăng ${(previewReport.accuracyPercentage - currentReport.accuracyPercentage).toStringAsFixed(1)}%'
                                  : previewReport.accuracyPercentage <
                                        currentReport.accuracyPercentage
                                  ? '▼ Giảm ${(currentReport.accuracyPercentage - previewReport.accuracyPercentage).toStringAsFixed(1)}%'
                                  : 'Không đổi',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color:
                                    previewReport.accuracyPercentage >
                                        currentReport.accuracyPercentage
                                    ? const Color(0xFF10B981)
                                    : previewReport.accuracyPercentage <
                                          currentReport.accuracyPercentage
                                    ? const Color(0xFFEF4444)
                                    : Colors.white60,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18.0),

                  // Slider 1: CV Max
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.analytics_rounded,
                            size: 16.0,
                            color: Colors.teal.shade700,
                          ),
                          const SizedBox(width: 6.0),
                          const Text(
                            'CV max (hệ số biến thiên)',
                            style: TextStyle(
                              fontSize: 13.0,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 2.0,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(6.0),
                          border: Border.all(color: Colors.teal.shade200),
                        ),
                        child: Text(
                          '< ${tempCvMax.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 13.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: tempCvMax,
                    min: 0.05,
                    max: 0.80,
                    divisions: 15,
                    activeColor: const Color(0xFF0F766E),
                    inactiveColor: Colors.teal.shade100,
                    onChanged: (val) {
                      setSheetState(() {
                        tempCvMax = val;
                      });
                    },
                  ),

                  const SizedBox(height: 10.0),

                  // Slider 2: Mean Min
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.speed_rounded,
                            size: 16.0,
                            color: Colors.indigo.shade700,
                          ),
                          const SizedBox(width: 6.0),
                          const Text(
                            'Mean min (trung bình tối thiểu)',
                            style: TextStyle(
                              fontSize: 13.0,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 2.0,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(6.0),
                          border: Border.all(color: Colors.indigo.shade200),
                        ),
                        child: Text(
                          '> ${tempMeanMin.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 13.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: tempMeanMin,
                    min: 0.05,
                    max: 1.50,
                    divisions: 29,
                    activeColor: const Color(0xFF4338CA),
                    inactiveColor: Colors.indigo.shade100,
                    onChanged: (val) {
                      setSheetState(() {
                        tempMeanMin = val;
                      });
                    },
                  ),

                  const SizedBox(height: 10.0),

                  // Slider 3: Peak Min (autocorrelation)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.timeline_rounded,
                            size: 16.0,
                            color: Colors.purple.shade700,
                          ),
                          const SizedBox(width: 6.0),
                          const Text(
                            'Đỉnh tự tương quan (Peak)',
                            style: TextStyle(
                              fontSize: 13.0,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 2.0,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(6.0),
                          border: Border.all(color: Colors.purple.shade200),
                        ),
                        child: Text(
                          '> ${tempPeakMin.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 13.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: tempPeakMin,
                    min: 0.05,
                    max: 0.50,
                    divisions: 18,
                    activeColor: Colors.purple.shade700,
                    inactiveColor: Colors.purple.shade100,
                    onChanged: (val) {
                      setSheetState(() {
                        tempPeakMin = val;
                      });
                    },
                  ),

                  const SizedBox(height: 10.0),

                  // Slider 4: Session Ratio
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.pie_chart_rounded,
                            size: 16.0,
                            color: Colors.deepOrange.shade700,
                          ),
                          const SizedBox(width: 6.0),
                          const Text(
                            'Tỉ lệ cửa sổ di chuyển',
                            style: TextStyle(
                              fontSize: 13.0,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 2.0,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.deepOrange.shade50,
                          borderRadius: BorderRadius.circular(6.0),
                          border: Border.all(color: Colors.deepOrange.shade200),
                        ),
                        child: Text(
                          '≥ ${(tempSessionRatio * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 13.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepOrange.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: tempSessionRatio,
                    min: 0.10,
                    max: 0.90,
                    divisions: 16,
                    activeColor: const Color(0xFFC2410C),
                    inactiveColor: Colors.deepOrange.shade100,
                    onChanged: (val) {
                      setSheetState(() {
                        tempSessionRatio = val;
                      });
                    },
                  ),

                  const SizedBox(height: 16.0),

                  // Nút Áp dụng
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Đóng'),
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1E2235),
                          ),
                          icon: const Icon(Icons.check_rounded, size: 18.0),
                          label: const Text('Áp dụng tham số'),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            setState(() {
                              _cvMax = tempCvMax;
                              _meanMin = tempMeanMin;
                              _peakMin = tempPeakMin;
                              _sessionRatio = tempSessionRatio;
                              _recomputeResults();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
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

            // Dòng 2: Chi tiết tỉ lệ vote (CV-based)
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
                    label: 'Tỉ lệ cửa sổ di chuyển',
                    percentage: result.voteRatio * 100,
                    thresholdText:
                        'Yêu cầu ≥ ${(result.config.sessionRatio * 100).toStringAsFixed(0)}%',
                    isPassed: result.voteRatio >= result.config.sessionRatio,
                  ),
                  const SizedBox(height: 6.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${result.movingVotes}/${result.totalWindows} cửa sổ vote di chuyển',
                        style: TextStyle(
                          fontSize: 11.0,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        '${result.totalSamples} mẫu',
                        style: TextStyle(
                          fontSize: 11.0,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
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

  /// Hàng thanh đo % vote ratio
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
              const Text(
                'Chọn Nhãn Thực Tế (Ground Truth)',
                style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
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
