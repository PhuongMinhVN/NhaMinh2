import 'package:lunar/lunar.dart';

class ClanEvent {
  final int id;
  final String title;
  final String? description;
  final DateTime eventDate; // Ngày gốc trong DB
  final bool isLunar;
  final String? location;
  final String type; // 'annual', 'one_time'
  final int notifyBeforeDays;

  // Runtime
  DateTime? upcomingDate; // Ngày dương lịch sắp tới (đã tính toán)
  int? daysUntil;

  ClanEvent({
    required this.id,
    required this.title,
    this.description,
    required this.eventDate,
    this.isLunar = false,
    this.location,
    this.type = 'one_time',
    this.notifyBeforeDays = 3,
  });

  factory ClanEvent.fromJson(Map<String, dynamic> json) {
    return ClanEvent(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      eventDate: DateTime.parse(json['event_date']),
      isLunar: json['is_lunar'] ?? false,
      location: json['location'],
      type: json['type'] ?? 'one_time',
      notifyBeforeDays: json['notify_before_days'] ?? 3,
    );
  }

  /// Tính toán ngày sự kiện sắp tới
  void calculateUpcoming(DateTime now) {
    if (type == 'one_time') {
      // Sự kiện 1 lần: Nếu là lịch âm thì convert sang dương để so sánh
      if (isLunar) {
         final lunar = Lunar.fromDate(eventDate);
         // Logic này hơi phức tạp nếu DB lưu ngày âm dưới dạng DATE (năm giả?). 
         // Giả sử DB lưu đúng ngày lịch âm (ví dụ 2025-01-01 Âm).
         // Ta dùng thư viện convert ngày đó sang Dương để hiển thị.
         final solar = _getSolarFromLunar(eventDate);
         upcomingDate = solar;
      } else {
         upcomingDate = eventDate;
      }
    } else {
      // Sự kiện hàng năm (Annual)
      int targetYear = now.year;
      DateTime? targetSolar;
      
      // Thử tính cho năm nay
      if (isLunar) {
        // Lấy ngày/tháng âm của sự kiện
        // Vì DB lưu dạng Date, ví dụ 2000-03-10 (tức là ngày 10/3 âm)
        // Ta lấy ngày 10, tháng 3, áp vào năm hiện tại
        final lunarDateObj = Lunar.fromYmd(targetYear, eventDate.month, eventDate.day);
        final solarObj = lunarDateObj.getSolar();
        targetSolar = DateTime(solarObj.getYear(), solarObj.getMonth(), solarObj.getDay());
      } else {
        targetSolar = DateTime(targetYear, eventDate.month, eventDate.day);
      }

      // Nếu ngày này trong năm nay đã qua, tính cho năm sau
      // So sánh ngày (bỏ qua giờ)
      final today = DateTime(now.year, now.month, now.day);
      if (targetSolar.isBefore(today)) {
         targetYear++;
         if (isLunar) {
           final lunarDateObj = Lunar.fromYmd(targetYear, eventDate.month, eventDate.day);
           final solarObj = lunarDateObj.getSolar();
           targetSolar = DateTime(solarObj.getYear(), solarObj.getMonth(), solarObj.getDay());
         } else {
           targetSolar = DateTime(targetYear, eventDate.month, eventDate.day);
         }
      }
      
      upcomingDate = targetSolar;
    }

    // Tính số ngày còn lại
    if (upcomingDate != null) {
      final today = DateTime(now.year, now.month, now.day);
      daysUntil = upcomingDate!.difference(today).inDays;
    }
  }

  DateTime _getSolarFromLunar(DateTime date) {
    final lunar = Lunar.fromYmd(date.year, date.month, date.day);
    final solar = lunar.getSolar();
    return DateTime(solar.getYear(), solar.getMonth(), solar.getDay());
  }
}
