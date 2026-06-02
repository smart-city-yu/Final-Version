import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/app_colors.dart';
import '../../core/app_localizations.dart';
import '../../data/sub_problems.dart';
import '../../models/app_category.dart';
import '../sheet_handle.dart';

void showReportFormSheet({
  required BuildContext context,
  required AppCategory category,
  required void Function(
    String? subProblem,
    String? description,
    String? note,
    List<XFile> images,
  ) onSubmit,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _ReportFormSheet(category: category, onSubmit: onSubmit),
  );
}

class _ReportFormSheet extends StatefulWidget {
  final AppCategory category;
  final void Function(String?, String?, String?, List<XFile>) onSubmit;

  const _ReportFormSheet({required this.category, required this.onSubmit});

  @override
  State<_ReportFormSheet> createState() => _ReportFormSheetState();
}

class _ReportFormSheetState extends State<_ReportFormSheet> {
  String? _selectedSubProblem;

  final _descController = TextEditingController();
  final _noteController = TextEditingController();
  final List<XFile> _selectedImages = [];
  final List<Uint8List> _selectedBytes = [];
  final ImagePicker _picker = ImagePicker();

  String? _errorMessage;

  bool get _isOtherCategory => widget.category.backendValue == 'other';
  bool get _isOtherPath =>
      _isOtherCategory || _selectedSubProblem == 'other';
  List<String> get _options =>
      subProblems[widget.category.backendValue] ?? [];

  @override
  void dispose() {
    _descController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final photo = await _picker.pickImage(
        source: ImageSource.camera, imageQuality: 75);
    if (photo == null || !mounted) return;
    final bytes = await photo.readAsBytes();
    if (!mounted) return;
    setState(() {
      if (_selectedImages.length < 5) {
        _selectedImages.add(photo);
        _selectedBytes.add(bytes);
        _clearError();
      }
    });
  }

  void _submit() {
    final l = AppLocalizations.of(context);
    if (!_isOtherCategory && _selectedSubProblem == null) {
      _setError(l.pleaseSelectIssue);
      return;
    }
    if (_isOtherPath && _descController.text.trim().isEmpty) {
      _setError(l.pleaseDescribe);
      return;
    }
    if (_selectedImages.isEmpty) {
      _setError(l.atLeastOnePhoto);
      return;
    }

    Navigator.pop(context);
    widget.onSubmit(
      _isOtherPath ? null : _selectedSubProblem,
      _isOtherPath ? _descController.text.trim() : null,
      (!_isOtherPath && _noteController.text.trim().isNotEmpty)
          ? _noteController.text.trim()
          : null,
      List.from(_selectedImages),
    );
  }

  void _setError(String msg) => setState(() => _errorMessage = msg);
  void _clearError() => setState(() => _errorMessage = null);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 24),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          12,
          18,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(),
              const SizedBox(height: 14),

              // Header row
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${widget.category.emoji}  ${l.catDisplayName(widget.category)}',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.black),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle),
                      child: const Icon(Icons.close,
                          size: 20, color: Colors.black54),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (_isOtherCategory) ...[
                _sectionLabel(l.describeIssue),
                const SizedBox(height: 8),
                _descriptionField(l),
              ] else ...[
                _sectionLabel(l.whatsSpecificIssue),
                const SizedBox(height: 8),
                _subProblemList(l),
              ],

              if (!_isOtherCategory && _selectedSubProblem != null) ...[
                const SizedBox(height: 20),
                if (_isOtherPath) ...[
                  _sectionLabel(l.describeIssue),
                  const SizedBox(height: 8),
                  _descriptionField(l),
                ] else ...[
                  _sectionLabel(l.noteForStaff),
                  const SizedBox(height: 4),
                  Text(
                    l.notReviewedByAi,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 8),
                  _noteField(l),
                ],
              ],

              const SizedBox(height: 20),

              _sectionLabel(l.photosRequired),
              const SizedBox(height: 8),
              if (_selectedImages.length < 5)
                _cameraButton(l)
              else
                _photoLimitBanner(l),
              if (_selectedImages.isNotEmpty) ...[
                const SizedBox(height: 12),
                _thumbnailStrip(),
                const SizedBox(height: 4),
                Text(
                  l.photosSelected(_selectedImages.length),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textGrey),
                ),
              ],

              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.location_on,
                      size: 16, color: AppColors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.reportPinnedHint,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textGrey),
                    ),
                  ),
                ],
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0F0),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: const Color(0xFFFFCDD2), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Color(0xFFC62828), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFFC62828),
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                      GestureDetector(
                        onTap: _clearError,
                        child: const Icon(Icons.close,
                            size: 16, color: Color(0xFFC62828)),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    elevation: 0,
                  ),
                  child: Text(
                    l.submitReport,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800),
      );

  Widget _subProblemList(AppLocalizations l) {
    return Container(
      decoration: BoxDecoration(
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          ..._options.asMap().entries.map((entry) {
            final i = entry.key;
            final option = entry.value;
            return Column(
              children: [
                _radioTile(label: option, value: option),
                if (i < _options.length - 1)
                  const Divider(
                      height: 1, indent: 44, color: Colors.black12),
              ],
            );
          }),
          const Divider(height: 1, color: Colors.black12),
          _radioTile(
              label: l.otherNotInList, value: 'other', isOther: true),
        ],
      ),
    );
  }

  Widget _radioTile({
    required String label,
    required String value,
    bool isOther = false,
  }) {
    final isSelected = _selectedSubProblem == value;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        setState(() {
          _selectedSubProblem = value;
          if (!isOther) _descController.clear();
          _clearError();
        });
      },
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 20,
              color: isSelected ? AppColors.green : Colors.grey,
            ),
            const SizedBox(width: 10),
            if (isOther) ...[
              Icon(Icons.help_outline,
                  size: 16, color: Colors.grey.shade500),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  color:
                      isOther ? Colors.grey.shade600 : Colors.black87,
                  fontStyle: isOther
                      ? FontStyle.italic
                      : FontStyle.normal,
                  fontWeight: isSelected
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _descriptionField(AppLocalizations l) => TextField(
        controller: _descController,
        maxLines: 4,
        onChanged: (_) => _clearError(),
        decoration: InputDecoration(
          hintText: l.describeInDetail,
          hintStyle: const TextStyle(
              fontSize: 14, color: AppColors.textGrey),
          filled: true,
          fillColor: AppColors.white,
          contentPadding: const EdgeInsets.all(16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                const BorderSide(color: Colors.black26, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                const BorderSide(color: Colors.black26, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                const BorderSide(color: AppColors.green, width: 2),
          ),
        ),
      );

  Widget _noteField(AppLocalizations l) => TextField(
        controller: _noteController,
        maxLines: 3,
        decoration: InputDecoration(
          hintText: l.extraContext,
          hintStyle: const TextStyle(
              fontSize: 13, color: AppColors.textGrey),
          filled: true,
          fillColor: const Color(0xFFFBF8EC),
          contentPadding: const EdgeInsets.all(16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
                color: Color(0xFFD4C890), width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
                color: Color(0xFFD4C890), width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
                color: Color(0xFF9E8C2C), width: 2),
          ),
        ),
      );

  Widget _cameraButton(AppLocalizations l) => SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _takePhoto,
          icon: const Icon(Icons.camera_alt_outlined, size: 18),
          label: Text(l.takePhoto,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            foregroundColor: AppColors.greenDark,
            side: const BorderSide(
                color: Color(0xFFC8E6B0), width: 2),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            backgroundColor: const Color(0xFFF8FDF5),
          ),
        ),
      );

  Widget _photoLimitBanner(AppLocalizations l) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline,
                size: 18, color: Colors.grey.shade600),
            const SizedBox(width: 10),
            Text(
              l.maxPhotos,
              style: TextStyle(
                  fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      );

  Widget _thumbnailStrip() => SizedBox(
        height: 80,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _selectedImages.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) => Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(_selectedBytes[i],
                    width: 80, height: 80, fit: BoxFit.cover),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: GestureDetector(
                  onTap: () => setState(() {
                    _selectedImages.removeAt(i);
                    _selectedBytes.removeAt(i);
                  }),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle),
                    child: const Icon(Icons.close,
                        size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
