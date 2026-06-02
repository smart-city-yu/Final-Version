import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_localizations.dart';
import '../../models/map_issue.dart';
import '../app_widgets.dart';
import '../sheet_handle.dart';

// ── Priority chip ────────────────────────────────────────────────────────────

Widget _buildPriorityChip(String priority, AppLocalizations l) {
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

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 5),
        Text(
          l.priorityFull(priority),
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

// ── Photo strip ──────────────────────────────────────────────────────────────

Widget _buildPhotoStrip(List<String> urls, AppLocalizations l) {
  if (urls.isEmpty) return const SizedBox.shrink();
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 18),
      Text(
        l.photos,
        style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
      ),
      const SizedBox(height: 8),
      SizedBox(
        height: 110,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: urls.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
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
                              child: CircularProgressIndicator(strokeWidth: 2)),
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
                    color: Colors.black54, shape: BoxShape.circle),
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

/// Vote callbacks return null on success or an error string on failure.
void showIssueDetailsSheet({
  required BuildContext context,
  required MapIssue issue,
  required bool alreadyVoted,
  bool isOwnReport = false,
  required Future<String?> Function() onVoteStillThere,
  required Future<String?> Function() onVoteFixed,
}) {
  final l = AppLocalizations.of(context);
  bool submitted = false;
  bool voting = false;
  String selectedVote = '';
  String? voteError;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            builder: (_, scrollController) => Container(
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
                child: StreamBuilder<DatabaseEvent>(
                  stream: FirebaseDatabase.instance
                      .ref('reports/${issue.id}')
                      .onValue,
                  builder: (context, firebaseSnap) {
                    int liveStill = issue.stillThereCount;
                    int liveFixed = issue.fixedCount;

                    if (firebaseSnap.hasData &&
                        firebaseSnap.data?.snapshot.value != null) {
                      final d = Map<String, dynamic>.from(
                          firebaseSnap.data!.snapshot.value as Map);
                      liveStill =
                          (d['stillVotes'] as num?)?.toInt() ?? liveStill;
                      liveFixed =
                          (d['fixedVotes'] as num?)?.toInt() ?? liveFixed;
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SheetHandle(),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.topRight,
                          child: InkWell(
                            onTap: () => Navigator.pop(context),
                            child: const Icon(Icons.close,
                                color: Colors.grey, size: 28),
                          ),
                        ),
                        if (!submitted) ...[
                          Container(
                            width: double.infinity,
                            height: 120,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF4E9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Center(
                                child: Text(issue.emoji,
                                    style:
                                        const TextStyle(fontSize: 38))),
                          ),
                          const SizedBox(height: 18),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(issue.title,
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black)),
                          ),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(issue.sub,
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textGrey)),
                          ),
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
                                    child: Text(issue.subProblem!,
                                        style: const TextStyle(
                                            fontSize: 12.5,
                                            color: AppColors.greenDark,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (issue.priority != null) ...[
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: _buildPriorityChip(
                                  issue.priority!, l),
                            ),
                          ],
                          if (issue.validationScore > 0) ...[
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                l.aiConfidenceNote((issue.validationScore * 100).round()),
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textGrey),
                              ),
                            ),
                          ],
                          if (issue.desc.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(issue.desc,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF555555),
                                      height: 1.5)),
                            ),
                          ],
                          _buildPhotoStrip(issue.imageUrls, l),
                          const SizedBox(height: 22),

                          // Own report → read-only counters
                          if (isOwnReport) ...[
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(l.communityVotes,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black)),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _voteCounter(
                                    count: liveStill,
                                    label: l.stillThere,
                                    color: Colors.orange,
                                    icon: Icons.warning_amber_rounded,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: _voteCounter(
                                    count: liveFixed,
                                    label: l.fixed,
                                    color: Colors.green,
                                    icon: Icons.check_circle_outline,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(l.cannotVoteOwn,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textGrey)),
                          ],

                          // Other's report → vote buttons
                          if (!isOwnReport) ...[
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(l.isIssueStillThere,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black)),
                            ),
                            const SizedBox(height: 14),
                            if (alreadyVoted)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF8E1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: const Color(0xFFE6C95A),
                                      width: 2),
                                ),
                                child: Text(l.alreadyVotedMsg,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                              ),
                            if (!alreadyVoted || true) ...[
                              if (alreadyVoted)
                                const SizedBox(height: 10),
                              voting
                                  ? const Center(
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                            vertical: 12),
                                        child: CircularProgressIndicator(),
                                      ),
                                    )
                                  : Row(
                                      children: [
                                        Expanded(
                                          child: _voteButton(
                                            context: context,
                                            label: alreadyVoted
                                                ? '↺ ${l.stillThere}'
                                                : '✓ ${l.stillThere}',
                                            count: liveStill,
                                            color: AppColors.green,
                                            borderColor: AppColors.green,
                                            confirmTitle: l.confirmVote,
                                            confirmContent:
                                                l.confirmVoteStillThere(
                                                    alreadyVoted),
                                            cancelLabel: l.cancel,
                                            confirmLabel: l.confirm,
                                            confirmButtonColor:
                                                AppColors.green,
                                            onConfirmed: () async {
                                              setSheetState(() {
                                                voting = true;
                                                voteError = null;
                                              });
                                              final errMsg =
                                                  await onVoteStillThere();
                                              if (errMsg == null) {
                                                selectedVote = 'still_there';
                                                setSheetState(() {
                                                  voting = false;
                                                  submitted = true;
                                                });
                                              } else {
                                                setSheetState(() {
                                                  voting = false;
                                                  voteError = errMsg;
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: _voteButton(
                                            context: context,
                                            label: alreadyVoted
                                                ? '↺ ${l.fixed}'
                                                : '✗ ${l.fixed}',
                                            count: liveFixed,
                                            color:
                                                const Color(0xFFC43C34),
                                            borderColor:
                                                const Color(0xFFC43C34),
                                            confirmTitle: l.confirmVote,
                                            confirmContent:
                                                l.confirmVoteFixed(
                                                    alreadyVoted),
                                            cancelLabel: l.cancel,
                                            confirmLabel: l.confirm,
                                            confirmButtonColor:
                                                const Color(0xFFC43C34),
                                            onConfirmed: () async {
                                              setSheetState(() {
                                                voting = true;
                                                voteError = null;
                                              });
                                              final errMsg =
                                                  await onVoteFixed();
                                              if (errMsg == null) {
                                                selectedVote = 'fixed';
                                                setSheetState(() {
                                                  voting = false;
                                                  submitted = true;
                                                });
                                              } else {
                                                setSheetState(() {
                                                  voting = false;
                                                  voteError = errMsg;
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                              if (voteError != null) ...[
                                const SizedBox(height: 14),
                                AppErrorBanner(
                                  message: voteError!,
                                  onDismiss: () =>
                                      setSheetState(() => voteError = null),
                                ),
                              ],
                            ],
                          ],
                        ] else ...[
                          const SizedBox(height: 24),
                          Container(
                            width: 82,
                            height: 82,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE8F5E1),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                                child: Text('✅',
                                    style: TextStyle(fontSize: 40))),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            l.successfullySubmitted,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.greenDark),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            selectedVote == 'still_there'
                                ? l.voteSubmittedStillThere
                                : l.voteSubmittedFixed,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textGrey,
                                height: 1.4),
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
                            width: 140,
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.green,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(18)),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14),
                              ),
                              child: Text(l.done,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

// ── Small helpers ─────────────────────────────────────────────────────────────

Widget _voteCounter({
  required int count,
  required String label,
  required Color color,
  required IconData icon,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text('$count',
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        Text(label, style: TextStyle(color: color, fontSize: 11)),
      ],
    ),
  );
}

Widget _voteButton({
  required BuildContext context,
  required String label,
  required int count,
  required Color color,
  required Color borderColor,
  required String confirmTitle,
  required String confirmContent,
  required String cancelLabel,
  required String confirmLabel,
  required Color confirmButtonColor,
  required Future<void> Function() onConfirmed,
}) {
  return OutlinedButton(
    onPressed: () async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: Text(confirmTitle),
          content: Text(confirmContent),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(cancelLabel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: confirmButtonColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      );
      if (confirmed == true) await onConfirmed();
    },
    style: OutlinedButton.styleFrom(
      side: BorderSide(color: borderColor, width: 2.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      padding: const EdgeInsets.symmetric(vertical: 12),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 14)),
        const SizedBox(height: 2),
        Text('$count',
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
      ],
    ),
  );
}
