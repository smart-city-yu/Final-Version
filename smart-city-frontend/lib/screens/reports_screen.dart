import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../core/app_colors.dart';
import '../core/app_localizations.dart';
import '../models/map_issue.dart';
import '../parsers/map_issue_parser.dart';
import '../services/report_service.dart';

// ── Photo strip ──────────────────────────────────────────────────────────────

Widget _buildPhotoStrip(
    BuildContext context, List<String> urls, AppLocalizations l) {
  if (urls.isEmpty) return const SizedBox.shrink();
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 18),
      Text(
        l.photos,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        height: 110,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: urls.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (ctx, i) {
            return GestureDetector(
              onTap: () => _showFullImage(context, urls, i),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  urls[i],
                  width: 110,
                  height: 110,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : Container(
                          width: 110,
                          height: 110,
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                  errorBuilder: (_, __, ___) => Container(
                    width: 110,
                    height: 110,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.broken_image_outlined,
                        color: Colors.grey),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ],
  );
}

void _showFullImage(BuildContext context, List<String> urls, int initial) {
  showDialog(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          PageView.builder(
            controller: PageController(initialPage: initial),
            itemCount: urls.length,
            itemBuilder: (_, i) => InteractiveViewer(
              child: Image.network(
                urls[i],
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : const Center(
                        child:
                            CircularProgressIndicator(color: Colors.white)),
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.close, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ── AI Analysis card ─────────────────────────────────────────────────────────

Widget _buildAiSection(MapIssue issue, AppLocalizations l) {
  final bool analysed = issue.revalidationCount > 0 ||
      (issue.validationReason?.isNotEmpty ?? false);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.info, size: 22),
          const SizedBox(width: 8),
          Text(
            l.aiSmartAnalysis,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.info,
            ),
          ),
          const Spacer(),
          if (analysed)
            Text(
              l.aiRunCount(issue.revalidationCount),
              style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
            ),
        ],
      ),
      const SizedBox(height: 14),
      if (!analysed) ...[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(15),
            border:
                Border.all(color: AppColors.info.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.info),
              ),
              const SizedBox(width: 12),
              Text(
                l.aiInProgress,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textGrey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ] else ...[
        if (issue.priority != null) ...[
          _buildPriorityRow(issue.priority!, issue.prioritySetBy, l),
          const SizedBox(height: 14),
        ],
        _buildConfidenceBar(issue.validationScore, l),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: AppColors.info.withValues(alpha: 0.12)),
          ),
          child: Text(
            issue.validationReason?.isNotEmpty == true
                ? issue.validationReason!
                : l.noReasonProvided,
            style: const TextStyle(
                fontSize: 14, height: 1.6, color: AppColors.textDark),
          ),
        ),
      ],
    ],
  );
}

Widget _buildPriorityRow(
    String priority, String? setBy, AppLocalizations l) {
  final Color color;
  final IconData icon;

  switch (priority.toUpperCase()) {
    case 'CRITICAL':
      color = AppColors.red;
      icon = Icons.emergency_rounded;
      break;
    case 'HIGH':
      color = AppColors.orange;
      icon = Icons.warning_rounded;
      break;
    case 'MEDIUM':
      color = AppColors.info;
      icon = Icons.info_rounded;
      break;
    case 'LOW':
    default:
      color = AppColors.green;
      icon = Icons.check_circle_rounded;
      break;
  }

  final String owner =
      (setBy?.toUpperCase() == 'ADMIN') ? l.setByAdmin : l.setByAi;

  return Row(
    children: [
      Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              l.priorityFull(priority),
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      const SizedBox(width: 10),
      Text(owner,
          style:
              const TextStyle(fontSize: 11, color: AppColors.textGrey)),
    ],
  );
}

Widget _buildConfidenceBar(double score, AppLocalizations l) {
  final pct = (score * 100).round();
  final Color barColor = score >= 0.8
      ? AppColors.green
      : score >= 0.6
          ? AppColors.orange
          : AppColors.red;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l.aiConfidenceLabel,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark)),
          Text('$pct%',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: barColor)),
        ],
      ),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: score.clamp(0.0, 1.0),
          minHeight: 8,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation<Color>(barColor),
        ),
      ),
    ],
  );
}

// ── AI History timeline ──────────────────────────────────────────────────────

Widget _buildAiHistorySection({
  required List<Map<String, dynamic>> aiHistory,
  required bool expanded,
  required VoidCallback onToggle,
  required AppLocalizations l,
}) {
  if (aiHistory.isEmpty) return const SizedBox.shrink();

  final fmt = DateFormat('MMM d, y  HH:mm');

  Color priorityColor(String? p) {
    switch ((p ?? '').toUpperCase()) {
      case 'CRITICAL':
        return AppColors.red;
      case 'HIGH':
        return AppColors.orange;
      case 'MEDIUM':
        return AppColors.info;
      default:
        return AppColors.green;
    }
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.history,
                  color: AppColors.textGrey, size: 18),
              const SizedBox(width: 8),
              Text(
                l.aiHistoryLabel(aiHistory.length),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textGrey),
              ),
              const Spacer(),
              Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                color: AppColors.textGrey,
                size: 20,
              ),
            ],
          ),
        ),
      ),
      if (expanded) ...[
        const SizedBox(height: 12),
        ...aiHistory.asMap().entries.map((e) {
          final i = e.key;
          final run = e.value;
          final isValid = run['valid'] as bool? ?? true;
          final confidence =
              ((run['confidence'] as num?)?.toDouble() ?? 0.0);
          final pct = (confidence * 100).round();
          final reason = run['reason'] as String? ?? '';
          final priority = run['priority'] as String?;
          final rawDate = run['ranAt'] as String? ?? '';
          final trigger = run['trigger'] as String? ?? 'SUBMIT';
          String dateStr = '';
          try {
            dateStr =
                fmt.format(DateTime.parse(rawDate).toLocal());
          } catch (_) {}

          final String triggerLabel;
          final Color triggerColor;
          switch (trigger) {
            case 'VOTE_MILESTONE_3':
              triggerLabel = l.reanalyzed3;
              triggerColor = Colors.orange;
              break;
            case 'VOTE_MILESTONE_5':
              triggerLabel = l.reanalyzed5;
              triggerColor = Colors.deepOrange;
              break;
            default:
              triggerLabel = l.initialAnalysis;
              triggerColor = AppColors.textGrey;
          }

          final runPriorityColor = priorityColor(priority);
          final isLast = i == aiHistory.length - 1;

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  child: Column(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: isValid
                              ? AppColors.green
                              : AppColors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                              width: 2,
                              color: AppColors.border),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding:
                        EdgeInsets.only(bottom: isLast ? 0 : 14),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundLight,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                trigger == 'SUBMIT'
                                    ? Icons.auto_awesome
                                    : Icons.people_alt_outlined,
                                size: 11,
                                color: triggerColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                triggerLabel,
                                style: TextStyle(
                                    fontSize: 10,
                                    color: triggerColor,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: Text(dateStr,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textGrey)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: (isValid
                                          ? AppColors.green
                                          : AppColors.red)
                                      .withValues(alpha: 0.1),
                                  borderRadius:
                                      BorderRadius.circular(20),
                                ),
                                child: Text(
                                  isValid ? l.validLabel : l.invalidLabel,
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isValid
                                          ? AppColors.green
                                          : AppColors.red),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (priority != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: runPriorityColor
                                        .withValues(alpha: 0.1),
                                    borderRadius:
                                        BorderRadius.circular(20),
                                    border: Border.all(
                                        color: runPriorityColor
                                            .withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    l.priorityLabel(priority),
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: runPriorityColor),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                '${l.aiConfidenceLabel}: $pct%',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textGrey),
                              ),
                            ],
                          ),
                          if (reason.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              reason,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textDark,
                                  height: 1.4),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    ],
  );
}

// ── Reports screen ────────────────────────────────────────────────────────────

class ReportsScreen extends StatefulWidget {
  final void Function(LatLng location)? onNavigateToLocation;

  const ReportsScreen({super.key, this.onNavigateToLocation});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  ReportService myService = ReportService();
  List<MapIssue> myReports = [];
  bool loading = true;
  String errorMsg = '';

  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    fetchReports();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchReports() async {
    setState(() {
      loading = true;
      errorMsg = '';
    });

    final result = await myService.getUserReports();
    if (!mounted) return;

    if (result['success'] == true) {
      final list = result['data'] as List<dynamic>? ?? [];
      setState(() {
        myReports = list
            .map((j) =>
                MapIssueParser.fromJson(j as Map<String, dynamic>))
            .toList();
        loading = false;
      });
    } else {
      setState(() {
        errorMsg = result['message'] as String? ??
            AppLocalizations.of(context).somethingWentWrong;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 40),
        Padding(
          padding: const EdgeInsets.only(left: 25),
          child: Text(
            l.myReports,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.green,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Padding(
          padding: const EdgeInsets.only(left: 25, bottom: 20),
          child: Text(
            l.tapToSeeAnalysis,
            style:
                const TextStyle(color: AppColors.textGrey, fontSize: 14),
          ),
        ),
        Expanded(child: buildContent()),
      ],
    );
  }

  Widget buildContent() {
    final l = AppLocalizations.of(context);

    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.green),
      );
    }

    if (errorMsg != '') {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(errorMsg,
                style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: fetchReports,
              child: Text(l.tryAgain),
            ),
          ],
        ),
      );
    }

    if (myReports.isEmpty) {
      return Center(child: Text(l.noReports));
    }

    return RefreshIndicator(
      color: AppColors.green,
      onRefresh: fetchReports,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: myReports.length,
        itemBuilder: (context, index) {
          final item = myReports[index];

          return StreamBuilder<DatabaseEvent>(
            stream: FirebaseDatabase.instance
                .ref('reports/${item.id}')
                .onValue,
            builder: (context, firebaseSnap) {
              final l = AppLocalizations.of(context);
              String liveStatus = item.sub.toUpperCase();
              if (firebaseSnap.hasData &&
                  firebaseSnap.data?.snapshot.value != null) {
                final d = Map<String, dynamic>.from(
                    firebaseSnap.data!.snapshot.value as Map);
                liveStatus = (d['status'] as String?)?.toUpperCase() ??
                    liveStatus;
              }

              Color badgeColor = Colors.orange;
              String badgeText = l.underProcessing;
              if (liveStatus == 'RESOLVED') {
                badgeColor = Colors.green;
                badgeText = l.resolved;
              } else if (liveStatus == 'REJECTED') {
                badgeColor = Colors.red;
                badgeText = l.rejected;
              } else if (liveStatus == 'PENDING') {
                badgeColor = Colors.blue;
                badgeText = l.underReview;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => showDetails(index),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color:
                              AppColors.border.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Text(item.emoji,
                            style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Text(
                            item.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                                color: badgeColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void showDetails(int index) {
    final String capturedId = myReports[index].id;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        final l = AppLocalizations.of(context);
        List<Map<String, dynamic>> aiHistory = [];
        bool historyLoading = true;
        bool historyExpanded = false;

        void refreshReport(StateSetter setSheetState) {
          myService.getReportById(capturedId).then((res) {
            if (!context.mounted) return;
            if (res['success'] == true && res['data'] != null) {
              final updated = MapIssueParser.fromJson(
                  res['data'] as Map<String, dynamic>);
              final idx =
                  myReports.indexWhere((r) => r.id == capturedId);
              if (idx == -1) return;
              setSheetState(() => myReports[idx] = updated);
              setState(() => myReports[idx] = updated);
            }
          });

          myService.getAiHistory(capturedId).then((res) {
            if (!context.mounted) return;
            setSheetState(() {
              if (res['success'] == true) {
                aiHistory =
                    (res['data'] as List<dynamic>? ?? [])
                        .cast<Map<String, dynamic>>();
              }
            });
          });
        }

        return StatefulBuilder(
          builder: (context, setSheetState) {
            if (historyLoading) {
              historyLoading = false;
              refreshReport(setSheetState);

              final currentIdx =
                  myReports.indexWhere((r) => r.id == capturedId);
              if (currentIdx != -1 &&
                  myReports[currentIdx].revalidationCount == 0) {
                _pollingTimer?.cancel();
                _pollingTimer = Timer.periodic(
                  const Duration(seconds: 4),
                  (_) {
                    if (!context.mounted) {
                      _pollingTimer?.cancel();
                      return;
                    }
                    final idx = myReports
                        .indexWhere((r) => r.id == capturedId);
                    if (idx == -1) {
                      _pollingTimer?.cancel();
                      _pollingTimer = null;
                      return;
                    }
                    if (myReports[idx].revalidationCount > 0) {
                      _pollingTimer?.cancel();
                      _pollingTimer = null;
                      return;
                    }
                    refreshReport(setSheetState);
                  },
                );
              }
            }

            final safeIdx =
                myReports.indexWhere((r) => r.id == capturedId);
            final MapIssue issue = safeIdx != -1
                ? myReports[safeIdx]
                : myReports[
                    myReports.length > index ? index : 0];

            Color badgeColor = Colors.orange;
            String badgeText = l.underProcessing;
            final issueStatus = issue.sub.toUpperCase();
            if (issueStatus == 'RESOLVED') {
              badgeColor = Colors.green;
              badgeText = l.resolved;
            } else if (issueStatus == 'REJECTED') {
              badgeColor = Colors.red;
              badgeText = l.rejected;
            } else if (issueStatus == 'PENDING') {
              badgeColor = Colors.blue;
              badgeText = l.underReview;
            }

            return PopScope(
              onPopInvokedWithResult: (didPop, result) {
                _pollingTimer?.cancel();
                _pollingTimer = null;
              },
              child: DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.75,
                minChildSize: 0.4,
                maxChildSize: 0.95,
                builder: (_, scrollController) =>
                    SingleChildScrollView(
                  controller: scrollController,
                  padding:
                      const EdgeInsets.fromLTRB(25, 15, 25, 30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 45,
                          height: 5,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Title + status badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${issue.emoji} ${issue.title}',
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                  color: badgeColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),

                      // Sub-problem chip
                      if (issue.subProblem != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F7EA),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: const Color(0xFFC5DFB0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.label_outline,
                                  size: 14,
                                  color: AppColors.greenDark),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  issue.subProblem!,
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.greenDark,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Location — tappable to navigate map
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          widget.onNavigateToLocation
                              ?.call(issue.position);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppColors.green.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color:
                                    AppColors.green.withOpacity(0.25)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on,
                                  color: AppColors.green, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                '${issue.position.latitude.toStringAsFixed(4)}, '
                                '${issue.position.longitude.toStringAsFixed(4)}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.green,
                                    fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.open_in_new,
                                  size: 13,
                                  color: AppColors.green),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l.tapToViewOnMap,
                        style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textGrey),
                      ),
                      const SizedBox(height: 16),

                      // Community votes (read-only)
                      Row(
                        children: [
                          const Icon(Icons.people_outline,
                              color: AppColors.textGrey, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            l.communityVotes,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textGrey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.orange
                                    .withValues(alpha: 0.07),
                                borderRadius:
                                    BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.orange
                                        .withValues(alpha: 0.25)),
                              ),
                              child: Column(
                                children: [
                                  const Icon(
                                      Icons.warning_amber_rounded,
                                      color: Colors.orange,
                                      size: 22),
                                  const SizedBox(height: 4),
                                  Text('${issue.stillThereCount}',
                                      style: const TextStyle(
                                          color: Colors.orange,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18)),
                                  Text(l.stillThere,
                                      style: const TextStyle(
                                          color: Colors.orange,
                                          fontSize: 11)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.green
                                    .withValues(alpha: 0.07),
                                borderRadius:
                                    BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.green
                                        .withValues(alpha: 0.25)),
                              ),
                              child: Column(
                                children: [
                                  const Icon(
                                      Icons.check_circle_outline,
                                      color: Colors.green,
                                      size: 22),
                                  const SizedBox(height: 4),
                                  Text('${issue.fixedCount}',
                                      style: const TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18)),
                                  Text(l.fixed,
                                      style: const TextStyle(
                                          color: Colors.green,
                                          fontSize: 11)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l.cannotVoteOwn,
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textGrey),
                      ),

                      // Photos
                      _buildPhotoStrip(context, issue.imageUrls, l),
                      const Divider(height: 35),

                      // AI Analysis
                      _buildAiSection(issue, l),
                      const SizedBox(height: 16),

                      // AI History
                      _buildAiHistorySection(
                        aiHistory: aiHistory,
                        expanded: historyExpanded,
                        onToggle: () => setSheetState(
                            () => historyExpanded = !historyExpanded),
                        l: l,
                      ),
                      const SizedBox(height: 25),

                      // Done button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            l.done,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
