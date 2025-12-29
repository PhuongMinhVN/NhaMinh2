import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import '../models/family_member.dart';

class GraphTreeView extends StatefulWidget {
  final List<FamilyMember> members;
  final Function(FamilyMember) onMemberTap;

  const GraphTreeView({
    super.key,
    required this.members,
    required this.onMemberTap,
  });

  @override
  State<GraphTreeView> createState() => _GraphTreeViewState();
}

class _GraphTreeViewState extends State<GraphTreeView> {
  final Graph _graph = Graph()..isTree = true;
  late BuchheimWalkerConfiguration _builder;
  
  // Map ID -> Member for quick lookup
  final Map<int, FamilyMember> _memberMap = {};

  @override
  void initState() {
    super.initState();
    _memberMap.addEntries(widget.members.map((m) => MapEntry(m.id, m)));
    
    // BUILD GRAPH
    for (var member in widget.members) {
      // Create Node
      final node = Node.Id(member.id);
      
      // Create Edges (Parent -> Child)
      if (member.fatherId != null && _memberMap.containsKey(member.fatherId)) {
         _graph.addEdge(Node.Id(member.fatherId!), node);
      } else if (member.motherId != null && _memberMap.containsKey(member.motherId)) {
        // If no father recorded (rare in patrolinial), use mother as edge source
        _graph.addEdge(Node.Id(member.motherId!), node);
      }
    }

    _builder = BuchheimWalkerConfiguration()
      ..siblingSeparation = (100)
      ..levelSeparation = (100)
      ..subtreeSeparation = (150)
      ..orientation = (BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.members.isEmpty) {
      return const Center(child: Text('Chưa có dữ liệu cây gia phả'));
    }

    return InteractiveViewer(
      constrained: false,
      boundaryMargin: const EdgeInsets.all(100),
      minScale: 0.01,
      maxScale: 5.6,
      child: GraphView(
        graph: _graph,
        algorithm: BuchheimWalkerAlgorithm(_builder, TreeEdgeRenderer(_builder)),
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
    // Determine Color
    Color bgColor;
    Color borderColor;

    // Logic for styling
    if (member.isMaternal) {
      bgColor = Colors.purple.shade50;
      borderColor = Colors.purple.shade300;
    } else {
      // Internal (Patrilineal)
      if (member.gender == 'male') {
         bgColor = Colors.blue.shade50;
         borderColor = Colors.blue.shade300;
      } else {
         bgColor = Colors.pink.shade50;
         borderColor = Colors.pink.shade300;
      }
    }

    // Is Spose? (For now, spouses are drawn as separate nodes if they exist in the member list)
    // Refinement: Ideally Spouses are grouped. 
    // MVP: Draw everyone as node.

    return InkWell(
      onTap: () => widget.onMemberTap(member),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: [
             BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: borderColor.withOpacity(0.2),
              backgroundImage: (member.avatarUrl != null && member.avatarUrl!.isNotEmpty) 
                  ? NetworkImage(member.avatarUrl!) 
                  : null,
              child: (member.avatarUrl == null || member.avatarUrl!.isEmpty)
                  ? Icon(member.gender == 'male' ? Icons.face : Icons.face_3, color: borderColor)
                  : null,
            ),
            const SizedBox(height: 8),
            Text(
              member.fullName,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            if (member.title != null)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                color: Colors.amber.withOpacity(0.2),
                child: Text(member.title!, style: const TextStyle(fontSize: 8)),
              ),
            if (member.isMaternal) 
               const Text('(Ngoại)', style: TextStyle(fontSize: 8, color: Colors.purple, fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }
}
