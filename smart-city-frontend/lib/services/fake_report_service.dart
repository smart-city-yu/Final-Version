import 'dart:async';

class FakeReportService {
  Future<List<Map<String, dynamic>>> getMyReports() async {
    await Future.delayed(const Duration(milliseconds: 800));
    return _fakeReports;
  }

  Future<bool> voteOnReport({
    required String reportId,
    required String voteType,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return true;
  }

  static final List<Map<String, dynamic>> _fakeReports = [
    {
      "reportId": "rpt_001",
      "title": "Pothole",
      "emoji": "🕳️",
      "status": "Accepted",
      "aiAnalysis": "AI detected a deep pothole approximately 30cm wide. Based on 14 community votes confirming the issue, this has been prioritized for urgent repair.",
      "lat": 32.0152,
      "lon": 35.8639,
      "stillThereCount": 14,
      "fixedCount": 2,
      "isVoted": false,
    },
    {
      "reportId": "rpt_004",
      "title": "Damaged Sidewalk",
      "emoji": "🚧",
      "status": "Under Processing",
      "aiAnalysis": "AI identified cracked pavement tiles over a 4-meter stretch, posing a trip hazard.",
      "lat": 32.0200,
      "lon": 35.8700,
      "stillThereCount": 7,
      "fixedCount": 0,
      "isVoted": false,
    },
    {
      "reportId": "rpt_005",
      "title": "Broken Street Light",
      "emoji": "💡",
      "status": "Accepted",
      "aiAnalysis": "AI confirmed the street light has been non-functional for over 72 hours. Repair crew scheduled.",
      "lat": 32.0100,
      "lon": 35.8600,
      "stillThereCount": 6,
      "fixedCount": 3,
      "isVoted": false,
    },
  ];
}
