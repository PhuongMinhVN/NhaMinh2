import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import '../models/family_member.dart';

class GraphTreeView extends StatefulWidget {
  final List<FamilyMember> members;
  final Function(FamilyMember) onMemberTap;
  final bool isClan; // Standard VN Logic toggle

  const GraphTreeView({
    super.key,
    required this.members,
    required this.onMemberTap,
    this.isClan = false,
  });

  @override
  State<GraphTreeView> createState() => _GraphTreeViewState();
}

class _GraphTreeViewState extends State<GraphTreeView> {
  final Graph _graph = Graph()..isTree = false;
  late SugiyamaConfiguration _builder;
  final Map<int, FamilyMember> _memberMap = {};

  // Custom Paint for Dotted Border (optional, or just use simpler styling)
  
  @override
  void initState() {
    super.initState();
    _memberMap.addEntries(widget.members.map((m) => MapEntry(m.id, m)));
    
    // BUILD GRAPH
    for (var member in widget.members) {
      final node = Node.Id(member.id);
      
      // 1. Parent -> Child
      if (member.fatherId != null && _memberMap.containsKey(member.fatherId)) {
         _graph.addEdge(Node.Id(member.fatherId!), node, paint: Paint()..color = Colors.grey..strokeWidth = 1.5..style = PaintingStyle.stroke);
      } 
      if (member.motherId != null && _memberMap.containsKey(member.motherId)) {
         _graph.addEdge(Node.Id(member.motherId!), node, paint: Paint()..color = Colors.grey..strokeWidth = 1.5..style = PaintingStyle.stroke);
      }

      // 2. Spouse
      if (member.spouseId != null && _memberMap.containsKey(member.spouseId)) {
        if (member.id < member.spouseId!) {
           _graph.addEdge(
             Node.Id(member.id), 
             Node.Id(member.spouseId!), 
             paint: Paint()..color = Colors.pinkAccent..strokeWidth = 2..style = PaintingStyle.stroke
           );
        }
      }
    }

    _builder = SugiyamaConfiguration()
      ..nodeSeparation = 30
      ..levelSeparation = 80
      ..orientation = SugiyamaConfiguration.ORIENTATION_TOP_BOTTOM;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.members.isEmpty) {
      return const Center(child: Text('Chưa có dữ liệu cây gia phả'));
    }

    return InteractiveViewer(
      constrained: false,
      boundaryMargin: const EdgeInsets.all(100),
      minScale: 0.1,
      maxScale: 5.0,
      child: GraphView(
        graph: _graph,
        algorithm: SugiyamaAlgorithm(_builder),
        paint: Paint()
          ..color = Colors.grey.shade400
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
        builder: (Node node) {
          final id = node.key?.value as int;
          final member = _memberMap[id];
          if (member == null) return const SizedBox();

          return _buildNodeWidget(member);
        },
      ),
    );
  }

  Widget _buildNodeWidget(FamilyMember member) {
    Color bgColor;
    Color borderColor;
    bool isRe = false; // Son-in-law
    bool isTruong = false; // Eldest Son

    // 1. Determine Logic based on isClan
    if (widget.isClan) {
      // VN Clan Logic
      final hasParents = (member.fatherId != null && _memberMap.containsKey(member.fatherId)) || 
                         (member.motherId != null && _memberMap.containsKey(member.motherId));
      
      // A. Son-in-law (Rể): Male, No Parents in List, Has Spouse in List (who likely has parents/isRoot)
      if (member.gender == 'male' && !hasParents && member.spouseId != null) {
         isRe = true;
      }

      // B. Eldest Son (Trưởng): Male, Has Parents (Blood), BirthOrder == 1
      // Note: 'isRoot' members are also effectively "Heads", but let's stick to children for "Chi Trưởng"
      if (member.gender == 'male' && hasParents && member.birthOrder == 1) {
         isTruong = true;
      }
    }

    // 2. Styling
    if (member.isMaternal) {
      bgColor = Colors.purple.shade50;
      borderColor = Colors.purple.shade300;
    } else {
      if (member.gender == 'male') {
         bgColor = Colors.blue.shade50;
         borderColor = Colors.blue.shade300;
      } else {
         bgColor = Colors.pink.shade50;
         borderColor = Colors.pink.shade300;
      }
    }

    // Apply "Re" styling (Override)
    if (isRe) {
       bgColor = Colors.grey.shade100;
       borderColor = Colors.grey.shade400; // Less prominent
    }

    return InkWell(
      onTap: () => widget.onMemberTap(member),
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: isRe 
             // Dashed border simulator (Solid for now, but Grey)
             ? Border.all(color: borderColor, width: 1, style: BorderStyle.solid) 
             : Border.all(color: borderColor, width: isTruong ? 3 : 2), // Bold for Truong
          boxShadow: [
             BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: borderColor.withOpacity(0.2),
                  backgroundImage: (member.avatarUrl != null && member.avatarUrl!.isNotEmpty) 
                      ? NetworkImage(member.avatarUrl!) 
                      : null,
                  child: (member.avatarUrl == null || member.avatarUrl!.isEmpty)
                      ? Icon(member.gender == 'male' ? Icons.face : Icons.face_3, size: 20, color: borderColor)
                      : null,
                ),
                if (isTruong)
                  Positioned(
                    right: -2, bottom: -2,
                    child: Icon(Icons.star, color: Colors.orange, size: 12),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              member.fullName,
              style: TextStyle(
                fontSize: 10, 
                fontWeight: isTruong ? FontWeight.w900 : FontWeight.bold,
                color: isRe ? Colors.grey.shade700 : null,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (member.title != null)
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                color: Colors.white.withOpacity(0.5),
                child: Text(
                  member.title!, 
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.brown.shade800)
                ),
              ),
             if (isRe)
              const Text('(Rể)', style: TextStyle(fontSize: 8, fontStyle: FontStyle.italic, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
