
import '../models/family_member.dart';

enum RelativeTitle {
  // Direct Ancestors
  caoTo, tangTo, noiTo, cha, me,
  
  // Direct Descendants
  con, chau, chat, chut,
  
  // Collateral (Same Gen)
  anhTrai, chiGai, emTrai, emGai,
  anhHo, chiHo, emHo,
  
  // Collateral (Parents Gen)
  bac, chu, co, cau, di,
  
  // Collateral (Children Gen)
  chauTrai, chauGai,
  
  // Unrelated/Unknown
  unknown,
}

class RelationshipCalculator {
  
  /// Calculates the title of [target] FROM THE PERSPECTIVE of [viewer].
  /// Example: If A is father of B. 
  /// call(A, B) -> Title of A to B (Dad).
  /// call(B, A) -> Title of B to A (Son).
  static String getTitle(FamilyMember target, FamilyMember viewer, List<FamilyMember> allMembers) {
    // 1. Check Direct Blood Relationship
    final bloodTitle = getBloodTitle(target, viewer, allMembers);
    if (!bloodTitle.startsWith('Người trong họ') && !bloodTitle.startsWith('Unknown')) {
       return bloodTitle;
    }

    // 2. Check In-Law Relationship (Target is Spouse of Blood Relative)
    // Find who is the Spouse of Target?
    try {
      // Case A: Target has 'spouseId' pointing to a blood relative
      // Case B: A blood relative has 'spouseId' pointing to Target
      // Simplified: Find any member in allMembers who is Spouse of Target AND is blood related to Viewer
      
      FamilyMember? spouse;
      // Check if Target's spouse is defined
      if (target.spouseId != null) {
         spouse = allMembers.firstWhere((m) => m.id == target.spouseId, orElse: () => FamilyMember(id: -1, fullName: '', isAlive: true));
      } 
      
      // Double check: Look for anyone pointing TO target
      if (spouse == null || spouse.id == -1) {
         spouse = allMembers.firstWhere((m) => m.spouseId == target.id, orElse: () => FamilyMember(id: -1, fullName: '', isAlive: true));
      }

      if (spouse != null && spouse.id != -1) {
         // Is Spouse blood related?
         final spouseTitle = getBloodTitle(spouse, viewer, allMembers);
         if (!spouseTitle.startsWith('Người trong họ') && !spouseTitle.startsWith('Unknown')) {
             return _getInLawTitle(spouseTitle, target.gender ?? 'female'); // Infer in-law title
         }
      }
    } catch (e) {
      // ignore
    }

    return bloodTitle; // Fallback to generic
  }

  static String getBloodTitle(FamilyMember target, FamilyMember viewer, List<FamilyMember> allMembers) {
    if (target.id == viewer.id) return 'Bản thân';

    // 1. Build Map for fast lookup
    final memberMap = {for (var m in allMembers) m.id: m};

    // 2. Calculate Generations and Find LCA
    final pathViewer = _getPathToRoot(viewer, memberMap);
    final pathTarget = _getPathToRoot(target, memberMap);
    
    // Find Common Ancestor
    FamilyMember? lca;
    int indexViewer = -1;
    int indexTarget = -1;

    for (int i = 0; i < pathViewer.length; i++) {
      for (int j = 0; j < pathTarget.length; j++) {
        if (pathViewer[i].id == pathTarget[j].id) {
          lca = pathViewer[i];
          indexViewer = i; // Distance from Viewer to LCA
          indexTarget = j; // Distance from Target to LCA
          break;
        }
      }
      if (lca != null) break;
    }

    if (lca == null) return 'Người trong họ (Chưa rõ chi)';

    // 3. Determine Generation Difference
    // path[0] is self, path[1] is father, etc.
    // index is basically "generations up".
    // Generation(Viewer) = 0. Generation(Target) = indexViewer - indexTarget.
    // Ex: Viewer->Dad->LCA (index=2). Target->LCA (index=1). 
    // Target is 1 gen higher than Viewer.
    final genDiff = indexViewer - indexTarget; 
    
    // 4. Resolve Title based on Gen Diff and Branch Rank
    
    // --- SAME LINE (Direct Descendant/Ancestor) ---
    if (indexViewer == 0) {
      // Viewer is LCA -> Target is descendant
      return _getDescendantTitle(genDiff, target.gender ?? 'male');
    }
    if (indexTarget == 0) {
      // Target is LCA -> Target is ancestor
      return _getAncestorTitle(genDiff, target.gender ?? 'male');
    }

    // --- COLLATERAL (Sibling/Cousin branches) ---
    
    // Identify the Roots of the sub-branches
    // immediate ancestor of Viewer who is child of LCA = pathViewer[indexViewer - 1]
    // immediate ancestor of Target who is child of LCA = pathTarget[indexTarget - 1]
    
    final rootViewer = pathViewer[indexViewer - 1];
    final rootTarget = pathTarget[indexTarget - 1];
    
    // Compare Rank of these two roots to determine "Seniority of Branch"
    // Using Date of Birth (dob) as proxy for "Order". older = higher rank (Bác branch).
    // In real app, explicit 'birth_order' field is safer.
    final bool isViewerBranchSenior = _compareSeniority(rootViewer, rootTarget);
    
    // 4a. Same Generation (genDiff = 0)
    if (genDiff == 0) {
      // Check for Real Siblings (Same Father OR Mother)
      bool isSibling = false;
      if (viewer.fatherId != null && target.fatherId != null && viewer.fatherId == target.fatherId) isSibling = true;
      if (viewer.motherId != null && target.motherId != null && viewer.motherId == target.motherId) isSibling = true;
      
      if (isSibling) {
          // Compare seniority directly
          final isTargetSenior = _compareSeniority(target, viewer);
          if (isTargetSenior) {
             return target.gender == 'male' ? 'Anh trai' : 'Chị gái';
          } else {
             return target.gender == 'male' ? 'Em trai' : 'Em gái';
          }
      }

      // If Target is in Senior Branch -> Anh/Chị
      // If Target is in Junior Branch -> Em
      // NOTE: Traditional logic: "Con chú con bác". 
      // Child of Older Bro (Bác) is always "Anh/Chị" to Child of Younger Bro (Chú), regardless of physical age.
      
      bool isTargetSenior = !isViewerBranchSenior;
      if (rootViewer.id == rootTarget.id) {
          // Same Branch Root but not direct sibling? (e.g. Half-siblings logic if not caught above, or edge case)
          // Should be caught by isSibling check above, but fallback to direct compare
          isTargetSenior = _compareSeniority(target, viewer);
      }

      
      // Cousins
      if (isTargetSenior) {
        return target.gender == 'male' ? 'Anh họ' : 'Chị họ';
      } else {
        return 'Em họ';
      }
    }
    
    // 4b. Target is Parent Generation (genDiff = 1) -> (Chú/Bác/Cô...)
    if (genDiff == 1) {
       // Target is sibling of Viewer's Parent
       // Determine if Target's Branch is Senior to Viewer's Parent?
       // Actually, we just checked rootTarget vs rootViewer (who is Viewer's Parent or ancestor).
       // If indexViewer=1 (Viewer's parent is LCA child), then indexTarget=0 (impossible as covered in direct).
       
       // Correct logic:
       // Viewer -> Parent (LCA child)
       // Target (LCA child)
       // Compare Target vs Parent.
       
       // If Viewer is gen Z. Target is gen Z-1.
       // Check relation of Target to Viewer's Parent.
       // Since they are children of LCA (indexTarget=0 relative to LCA?? No, indexTarget=0 means Target IS LCA).
       
       // Let's rely on genDiff.
       // Case: Viewer (Gen 0) -> Parent (Gen 1). Target (Gen 1). 
       // Start from Viewer, go up 1 step to Parent. 
       // Target is sibling of Parent.
       
       // Compare Target vs Parent
       // If Target Older -> Bác (Male), Bác/Dì (Female? No, dad side: Bác/Cô).
       
       // Assumption: Patrilineal (Dad side).
       final parent = pathViewer[1]; // Viewer's parent
       bool isTargetolderThanParent = _compareSeniority(target, parent);
       
       if (target.gender == 'male') {
         return isTargetolderThanParent ? 'Bác' : 'Chú';
       } else {
         // Female: Older than Dad? usually 'Bác' or 'O/Cô' (Central), 'Cô' (North usually younger, but older is Bác too).
         // Simplified: Parent's Sister is Cô. 
         // But strict "Vai vế": If older than dad -> Bác? 
         // Let's stick to: Sister of Dad = Cô (regardless of age usually in some regions, but "Bác" if older is respectful).
         // User Prompt: "người thuộc vai trên (ví dụ chú, bác) dù ít tuổi hơn vẫn là bề trên".
         // Let's use: Older male = Bác, Younger male = Chú. Female = Cô.
         return isTargetolderThanParent ? 'Bác (Gái)' : 'Cô';
       }
    }
    
    // 4c. Target is Lower Generation (genDiff = -1) -> (Cháu)
    if (genDiff == -1) {
      return target.gender == 'male' ? 'Cháu trai' : 'Cháu gái';
    }

    // 4d. Other gaps
    if (genDiff > 1) {
       return 'Ông/Bà họ (Đời trên)';
    }
    if (genDiff < -1) {
       return 'Cháu/Chắt (Đời dưới)';
    }

    return 'Họ hàng';
  }

  static String _getAncestorTitle(int genDiff, String gender) {
     // genDiff is positive (generations UP)
     // 1: Parent
     // 2: Grand
     // 3: Great-Grand
     // 4: Great-Great-Grand
     switch (genDiff) {
       case 1: return gender == 'male' ? 'Cha' : 'Mẹ';
       case 2: return gender == 'male' ? 'Ông nội' : 'Bà nội'; // Assuming patrilineal default
       case 3: return 'Cụ (Ông/Bà cố)'; // Tằng tổ
       case 4: return 'Kỵ (Ông/Bà sơ)'; // Cao tổ
       default: return 'Viễn Tổ';
     }
  }

  static String _getDescendantTitle(int genDiff, String gender) {
    // genDiff is negative (generations DOWN)
    // -1: Child
    // -2: Grandchild
    switch (genDiff) {
      case -1: return 'Con';
      case -2: return 'Cháu';
      case -3: return 'Chắt (Tằng tôn)';
      case -4: return 'Chút (Huyền tôn)';
      default: return 'Hậu duệ';
    }
  }

  static List<FamilyMember> _getPathToRoot(FamilyMember start, Map<int, FamilyMember> map) {
    final path = <FamilyMember>[];
    FamilyMember? curr = start;
    while (curr != null) {
      path.add(curr);
      if (curr.fatherId != null) {
        curr = map[curr.fatherId];
      } else {
        curr = null;
      }
    }
    return path;
  }
  
  // Returns true if A is "Senior" to B (Older / Higher Rank)
  // Returns true if A is "Senior" to B (Older / Higher Rank)
  // Returns true if A is "Senior" to B (Older / Higher Rank)
  static bool _compareSeniority(FamilyMember a, FamilyMember b) {
    // 1. Strict Hierarchy Ranking (Vai vế - Title based)
    int rankA = getRank(a.title);
    int rankB = getRank(b.title);

    if (rankA < rankB) return true; 
    if (rankA > rankB) return false;

    // 2. Birth Order (Specific for siblings or branch roots)
    // If they have explicit birth order, Lower is Senior (1st > 2nd)
    if (a.birthOrder != null && b.birthOrder != null) {
      if (a.birthOrder! < b.birthOrder!) return true;
      if (a.birthOrder! > b.birthOrder!) return false;
    }

    // 3. Date of Birth (Older is Senior)
    if (a.birthDate != null && b.birthDate != null) {
      return a.birthDate!.isBefore(b.birthDate!); 
    }
    
    // 4. Fallback: ID
    return a.id < b.id;
  }



  static int getRank(String? title) {
    if (title == null) return 99;
    final t = title.toLowerCase().trim();
    
    // Level 0: Supreme
    if (t.contains('trưởng họ') || t.contains('tộc trưởng')) return 0;
    
    // Level 1: Heir Apparent
    if (t.contains('đích tôn')) return 1;

    // Level 2: Branch Heads
    if (t.contains('chi trưởng') || t.contains('trưởng nhà') || t.contains('trưởng chi')) return 2;
    if (t.contains('con cả') || t.contains('con trưởng')) return 2; // Eldest child (generic)

    // Level 3: Deputies
    if (t.contains('phó họ') || t.contains('phó chi')) return 3;

    // Level 4: Eldest Son Hierarchy
    if (t.contains('con thứ 2')) return 12;
    if (t.contains('con thứ 3')) return 13;
    // ... can expand

    // Default for others
    return 99;
  }

  static String _getInLawTitle(String bloodTitle, String targetGender) {
    final t = bloodTitle.toLowerCase();
    final isMaleTarget = targetGender == 'male';

    if (t.contains('con gái')) return 'Con rể';
    if (t.contains('con trai')) return 'Con dâu';
    
    if (t.contains('chị gái') || t.contains('chị họ')) return 'Anh rể';
    if (t.contains('em gái') || t.contains('em họ')) return 'Em rể';
    
    if (t.contains('anh trai') || t.contains('anh họ')) return 'Chị đâu';
    if (t.contains('em trai') || t.contains('em họ')) return 'Em dâu';

    if (t.contains('bác')) return isMaleTarget ? 'Bác trai (Dượng)' : 'Bác gái';
    if (t.contains('chú')) return 'Thím';
    if (t.contains('cô')) return 'Chú (Dượng)';
    if (t.contains('dì')) return 'Chú (Dượng)';
    if (t.contains('cậu')) return 'Mợ';

    return 'Họ hàng (Dâu/Rể)';
  }
}
