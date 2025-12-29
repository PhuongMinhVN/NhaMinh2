import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/event_model.dart';
import '../services/event_service.dart';
import '../pages/events/event_detail_page.dart';

class EventListWidget extends StatefulWidget {
  const EventListWidget({super.key});

  @override
  State<EventListWidget> createState() => _EventListWidgetState();
}

class _EventListWidgetState extends State<EventListWidget> {
  final _eventService = EventService();
  late Future<List<Event>> _eventsFuture;

  @override
  void initState() {
    super.initState();
    _eventsFuture = _eventService.getEvents();
  }
  
  void refresh() {
    setState(() {
      _eventsFuture = _eventService.getEvents();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sự Kiện Sắp Tới',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: refresh,
              ),
            ],
          ),
        ),
        FutureBuilder<List<Event>>(
          future: _eventsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Lỗi: ${snapshot.error}'));
            }
            
            final events = snapshot.data ?? [];
            if (events.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: Text(
                    'Chưa có sự kiện nào sắp tới.',
                    style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                  ),
                ),
              );
            }

            // Split events
            final importantEvents = events.where((e) => e.isImportant).toList();
            final otherEvents = events.where((e) => !e.isImportant).toList();

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Important Events (Big Cards)
                if (importantEvents.isNotEmpty)
                  SizedBox(
                    height: 230, 
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: importantEvents.length,
                      itemBuilder: (context, index) {
                        return _buildEventCard(context, importantEvents[index]);
                      },
                    ),
                  ),

                // 2. Other Events (Simple Links)
                if (otherEvents.isNotEmpty) ...[
                   if (importantEvents.isNotEmpty) const SizedBox(height: 16),
                   Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 16.0),
                     child: Text(
                       'Sự kiện khác:', 
                       style: TextStyle(
                         fontSize: 14, 
                         fontWeight: FontWeight.bold, 
                         color: Colors.grey.shade700
                       )
                     ),
                   ),
                   const SizedBox(height: 8),
                   ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: otherEvents.length,
                      separatorBuilder: (c, i) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        return _buildSimpleEventItem(context, otherEvents[index]);
                      },
                   ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildSimpleEventItem(BuildContext context, Event event) {
    final date = event.nextOccurrenceSolar ?? DateTime.now();
    final dateStr = DateFormat('dd/MM').format(date);
    
    return InkWell(
      onTap: () {
         Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EventDetailPage(event: event),
          ),
        ).then((_) => refresh());
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            Container(
               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
               decoration: BoxDecoration(
                 color: Colors.grey.shade200,
                 borderRadius: BorderRadius.circular(4)
               ),
               child: Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                event.title, 
                style: const TextStyle(
                  color: Colors.blue, 
                  decoration: TextDecoration.underline,
                  fontSize: 15,
                )
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, Event event) {
    // Format Date
    // If nextOccurrence is available, use it.
    final date = event.nextOccurrenceSolar ?? DateTime.now(); // Fallback
    final dateStr = DateFormat('dd/MM').format(date);
    final yearStr = DateFormat('yyyy').format(date);
    
    // Calculate days remaining
    final diff = date.difference(DateTime.now()).inDays;
    String timeStatus;
    Color statusColor;
    
    if (diff == 0) {
      timeStatus = 'Hôm nay';
      statusColor = Colors.red;
    } else if (diff > 0) {
      timeStatus = 'Còn $diff ngày';
      statusColor = Colors.orange;
    } else {
      timeStatus = 'Đã qua';
      statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
             Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EventDetailPage(event: event),
              ),
            ).then((_) => refresh()); // Refresh on return
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 160,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
                // Badge: Family vs Clan
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: event.scope == EventScope.FAMILY 
                        ? Colors.blue.withOpacity(0.1) 
                        : Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: event.scope == EventScope.FAMILY 
                          ? Colors.blue.withOpacity(0.5) 
                          : Colors.purple.withOpacity(0.5),
                    ),
                  ),
                  child: Text(
                    event.scope == EventScope.FAMILY ? 'Gia Đình' : 'Dòng Họ',
                    style: TextStyle(
                      fontSize: 10, 
                      fontWeight: FontWeight.bold,
                      color: event.scope == EventScope.FAMILY ? Colors.blue : Colors.purple,
                    ),
                  ),
                ),
                Text(
                  event.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_month, size: 16, color: statusColor),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '$dateStr/$yearStr',
                            style: TextStyle(color: statusColor, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeStatus,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    )
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
