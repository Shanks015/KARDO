import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_entity_extraction/google_mlkit_entity_extraction.dart';

class SpatialLine {
  final String text;
  final Rect boundingBox;
  final double confidence;
  
  SpatialLine(this.text, this.boundingBox, this.confidence);
}

class LocalTransformerService {
  static const double MIN_CONFIDENCE_THRESHOLD = 50.0;

  static final List<String> _companySuffixes = [
    "ltd", "limited", "inc", "incorporated", "llc", "llp", "plc",
    "corp", "corporation", "pvt", "pte", "gmbh", "srl",
    "company", "companies", "group", "holdings", "ventures", "enterprises", "industries",
    "solutions", "technologies", "technology", "tech", "systems", "services", 
    "consulting", "consultancy", "consultants", "advisors", "advisory", "agency", "agencies",
    "studio", "studios", "labs", "laboratory", "laboratories",
    "innovations", "innovation", "software", "hardware", 
    "manufacturing", "construction", "engineering",
    "logistics", "exports", "imports", "trading", "traders",
    "retail", "wholesale", "pharma", "pharmaceutical",
    "university", "college", "school", "academy", 
    "institute", "institution", "iit", "iim", "nit", "bits",
    "foundation", "trust", "ngo", "charity", "association", 
    "federation", "hospital", "clinic", "healthcare", "bank"
  ];

  static final List<String> _titleKeywords = [
    "ceo", "cto", "cfo", "coo", "cmo", "cso", "chro",
    "founder", "co-founder", "cofounder",
    "director", "managing director", "md",
    "manager", "general manager", "assistant manager", "deputy manager",
    "engineer", "senior engineer", "junior engineer", "principal engineer",
    "associate", "senior associate", "junior associate",
    "professor", "asst. professor", "assistant professor", "associate professor",
    "lecturer", "senior lecturer",
    "executive", "senior executive",
    "developer", "software developer", "web developer",
    "consultant", "senior consultant",
    "head", "head of",
    "president", "vice president", "vp",
    "specialist", "senior specialist",
    "scientist", "research scientist",
    "designer", "graphic designer", "ux designer",
    "architect", "solution architect",
    "partner", "managing partner",
    "officer", "chief officer",
    "analyst", "business analyst", "financial analyst",
    "representative", "sales representative",
    "coordinator", "project coordinator",
    "administrator", "admin",
    "supervisor", "team lead", "tech lead",
    "intern", "trainee", "apprentice",
    "researcher", "postdoc",
    "chairman", "chairperson", "vice chairman",
    "trustee", "secretary", "lead", "associate", "account",
    "advisor", "diplomat", "ambassador", "editor", "dean"
  ];

  static final List<String> _taglineKeywords = [
    "thinking", "mindset", "solutions", "future", "global", "globally", "minded", 
    "excellence", "innovation", "since 19", "since 20", "vision", "mission", 
    "empowering", "delivering", "capital", "creating", "building", "world", "change", "ideas", "transforming"
  ];

  static final List<String> _addressKeywords = [
    "street", "st", "road", "rd", "floor", "fl", "suite", "ste", "building", "bldg",
    "avenue", "ave", "block", "blk", "tower", "lane", "ln", "nagar", "marg", "phase",
    "sector", "plot", "area", "estate", "park", "city", "town", "district", "state"
  ];

  static final List<String> _multilingualBlocklist = [
    "te kunenga", "ki pūrehuroa", "purehuroa", "mai te ho", "te pa"
  ];

  static final List<String> _honorifics = [
    'dr.', 'dr ', 'mr.', 'mr ', 'mrs.', 'mrs ', 'ms.', 'ms ',
    'prof.', 'prof ', 'professor ', 'professor',
    'ca.', 'ca ', 'er.', 'er '
  ];

  static Future<Map<String, dynamic>> extractCard(dynamic imageFile) async {
    final bool isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    final bool isMobile = !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
    if (isTest || !isMobile) return _getMockData();

    try {
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      String email = "Not Found";
      String phone = "Not Found";
      String url = "Not Found";
      String name = "Not Found";
      String title = "Not Found";
      String company = "Not Found";
      String address = "Not Found";

      if (recognizedText.text.trim().isEmpty) {
        debugPrint('OCR text is empty');
        return _emptyResult();
      }

      double maxWidth = 0.0;
      double cardMinY = 999999.0;
      double cardMaxY = 0.0;

      List<SpatialLine> lines = [];
      for (final block in recognizedText.blocks) {
        // Try to merge the block if it looks like a multi-line company name
        final blockLines = block.lines.toList();
        if (blockLines.length > 1) {
           final blockText = blockLines.map((l) => l.text.trim()).join(' ');
           final blockLower = blockText.toLowerCase();
           if (_companySuffixes.any((kw) => blockLower.contains(kw))) {
             double avgConfidence = blockLines.map((l) => l.confidence ?? 1.0).reduce((a, b) => a + b) / blockLines.length;
             if (avgConfidence <= 0.0) avgConfidence = 1.0;
             lines.add(SpatialLine(blockText, block.boundingBox, avgConfidence));
           }
        }

        for (final line in block.lines) {
          final trimmed = line.text.trim();
          if (trimmed.isEmpty) continue;
          
          final w = line.boundingBox.width;
          if (w > maxWidth) maxWidth = w;
          if (line.boundingBox.top < cardMinY) cardMinY = line.boundingBox.top;
          if (line.boundingBox.bottom > cardMaxY) cardMaxY = line.boundingBox.bottom;
          
          double conf = line.confidence ?? 1.0;
          if (conf <= 0.0) conf = 1.0;
          lines.add(SpatialLine(trimmed, line.boundingBox, conf));
        }
      }

      final cardHeight = cardMaxY - cardMinY;

      // Phase 1: Hard Regex Extraction & Claim
      email = _cleanUrlOrEmail(_findEmailRegex(recognizedText.text) ?? "Not Found");
      phone = _findPhoneRegex(recognizedText.text) ?? "Not Found";

      // Extract URL per-line BEFORE stripping, so we don't lose URL lines
      for (final line in lines) {
        final lower = line.text.toLowerCase();
        if (lower.contains('www.') || lower.contains('http') || lower.contains('.com') || lower.contains('.org') || lower.contains('.edu') || lower.contains('.in') || lower.contains('.au')) {
          final found = _findUrlRegex(line.text);
          if (found != null && url == "Not Found") url = _cleanUrlOrEmail(found);
        }
      }
      if (url == "Not Found") url = _cleanUrlOrEmail(_findUrlRegex(recognizedText.text) ?? "Not Found");
      
      // Fallback: Infer URL from email domain if no website URL is printed
      if (url == "Not Found" && email != "Not Found" && email.contains("@")) {
        final domain = email.split("@")[1].trim().toLowerCase();
        if (domain.isNotEmpty && domain.contains(".")) {
          url = "www.$domain";
        }
      }

      lines.removeWhere((l) {
        final lower = l.text.toLowerCase();
        if (email != "Not Found" && lower.contains(email.toLowerCase())) return true;
        if (phone != "Not Found" && _cleanDigits(lower).contains(_cleanDigits(phone))) return true;
        if (url != "Not Found" && lower.contains(url.toLowerCase())) return true;
        if (lower.contains("@")) return true;
        if (url != "Not Found" && (lower.contains("www.") || lower.contains("http"))) return true;
        if (RegExp(r'\d{7,}').hasMatch(lower) && _hasMatch(lower, _addressKeywords)) return false;
        return false;
      });

      // Phase 2: Multilingual Guard
      lines.removeWhere((l) {
        final lower = l.text.toLowerCase();
        return _multilingualBlocklist.any((blocked) => lower.contains(blocked));
      });

      // Phase 3: Multi-Signal Scoring
      double bestNameScore = -999, bestTitleScore = -999, bestCompanyScore = -999;
      SpatialLine? bestNameLine, bestTitleLine, bestCompanyLine;

      for (final line in lines) {
        final nScore = _computeNameScore(line, maxWidth, cardMinY, cardHeight, email);
        final cScore = _computeCompanyScore(line, maxWidth, email, url);

        if (nScore > bestNameScore) { bestNameScore = nScore; bestNameLine = line; }
        if (cScore > bestCompanyScore) { bestCompanyScore = cScore; bestCompanyLine = line; }
      }

      if (bestNameLine != null && bestNameLine == bestCompanyLine) {
         if (bestNameScore > bestCompanyScore) {
             bestCompanyLine = null; bestCompanyScore = -999;
         } else {
             bestNameLine = null; bestNameScore = -999;
         }
      }

      for (final line in lines) {
         if (line == bestNameLine || line == bestCompanyLine) continue;
         if (bestNameLine == null) {
            final nScore = _computeNameScore(line, maxWidth, cardMinY, cardHeight, email);
            if (nScore > bestNameScore) { bestNameScore = nScore; bestNameLine = line; }
         }
         if (bestCompanyLine == null) {
            final cScore = _computeCompanyScore(line, maxWidth, email, url);
            if (cScore > bestCompanyScore) { bestCompanyScore = cScore; bestCompanyLine = line; }
         }
      }

      for (final line in lines) {
        if (line == bestNameLine || line == bestCompanyLine) continue;
        final tScore = _computeTitleScore(line, bestNameLine?.boundingBox);
        if (tScore > bestTitleScore) { bestTitleScore = tScore; bestTitleLine = line; }
      }

      // Phase 4: Confidence Gating
      if (bestNameLine != null && bestNameScore >= 20.0) {
        name = bestNameLine.text;
        lines.remove(bestNameLine);
      }
      if (bestTitleLine != null && bestTitleScore >= 20.0) {
        title = bestTitleLine.text;
        lines.remove(bestTitleLine);
      }
      if (bestCompanyLine != null && bestCompanyScore >= 15.0) {
        company = bestCompanyLine.text;
        lines.remove(bestCompanyLine);
        if (company.length <= 4) company = company.toUpperCase();
      }

      // Fallbacks
      if (name == "Not Found" && email != "Not Found") {
         name = _extractNameFromEmail(email) ?? "Not Found";
      }

      if (company == "Not Found") {
         String domain = "";
         if (email != "Not Found" && email.contains("@")) {
            domain = email.split("@")[1];
         } else if (url != "Not Found") {
            domain = url;
         }
         if (domain.isNotEmpty) {
             String coreDomain = domain.toLowerCase().replaceAll(RegExp(r'https?:\/\/'), '').replaceAll('www.', '').split('.')[0];
             if (coreDomain.length > 2) {
                 company = coreDomain[0].toUpperCase() + coreDomain.substring(1);
             }
         }
      }

      // Phase 5: Address Assembly
      List<SpatialLine> addressLines = [];
      for (final line in lines) {
        if (line.text.length < 5) continue;
        final lower = line.text.toLowerCase();
        if (_hasMatch(lower, _titleKeywords) && !_hasMatch(lower, _addressKeywords)) continue;
        if (_honorifics.any((h) => lower.startsWith(h))) continue;
        addressLines.add(line);
      }

      addressLines.sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));
      String assembledAddress = "";
      if (addressLines.isNotEmpty) {
        List<String> validAddrParts = [];
        for (final al in addressLines) {
           final lower = al.text.toLowerCase();
           bool hasDigit = RegExp(r'\d').hasMatch(lower);
           bool hasAddrKw = _hasMatch(lower, _addressKeywords);
           if (hasDigit || hasAddrKw || validAddrParts.isNotEmpty) {
              validAddrParts.add(al.text);
           }
        }
        if (validAddrParts.isNotEmpty) {
           assembledAddress = validAddrParts.join(", ");
           if (assembledAddress.length > 150) assembledAddress = assembledAddress.substring(0, 150) + "...";
           
           final lowerAssembled = assembledAddress.toLowerCase();
           bool hasDigit = RegExp(r'\d').hasMatch(lowerAssembled);
           bool hasAddrKw = _hasMatch(lowerAssembled, _addressKeywords);
           if (hasDigit || hasAddrKw) address = assembledAddress;
        }
      }

      final result = {
        'point_person': name,
        'department': title,
        'organization_name': company,
        'organization_type': _inferOrganizationType(company, title, recognizedText.text),
        'location': address,
        'contact_number': _formatPhone(phone),
        'contact_email': email,
        'url': url,
        '_debug_scores': {
          'name_score': bestNameScore,
          'title_score': bestTitleScore,
          'company_score': bestCompanyScore,
        }
      };
      
      debugPrint('OCR extraction complete');
      
      return result;

    } catch (e) {
      debugPrint("Error in local extraction service: $e");
      return _emptyResult();
    }
  }

  static String _cleanUrlOrEmail(String text) {
    if (text == "Not Found") return text;
    var cleaned = text.trim();
    cleaned = cleaned.replaceAll(RegExp(r'^[:•\-|\s]+'), '');
    cleaned = cleaned.replaceAll(RegExp(r'^(web|url|site|email|e-mail|mail)\s*[:•\-]?\s*', caseSensitive: false), '');
    return cleaned.trim();
  }

  static String _inferOrganizationType(String company, String title, String fullText) {
    final combined = '$company $title $fullText'.toLowerCase();
    if (_hasMatch(combined, ['university', 'college', 'school', 'academy', 'institute', 'dsu', 'iit', 'iim', 'nit'])) {
      return 'UNIVERSITY';
    }
    if (_hasMatch(combined, ['hospital', 'clinic', 'healthcare', 'pharma', 'medical', 'doctor', 'health'])) {
      return 'HEALTHCARE';
    }
    if (_hasMatch(combined, ['tech', 'technologies', 'technology', 'software', 'systems', 'digital', 'labs', 'solutions', 'ai', 'cyber'])) {
      return 'TECHNOLOGY';
    }
    if (_hasMatch(combined, ['startup', 'ventures', 'innovations', 'labs', 'studio'])) {
      return 'STARTUP';
    }
    if (_hasMatch(combined, ['govt', 'government', 'ministry', 'department', 'bhavan', 'embassy', 'police'])) {
      return 'GOVERNMENT';
    }
    return 'BUSINESS';
  }

  static bool _hasMatch(String text, List<String> keywords) {
    final lower = text.toLowerCase();
    for (final kw in keywords) {
      if (RegExp(r'\b' + RegExp.escape(kw) + r'\b').hasMatch(lower)) return true;
    }
    return false;
  }

  static int _countMatches(String text, List<String> keywords) {
    final lower = text.toLowerCase();
    int count = 0;
    for (final kw in keywords) {
      if (RegExp(r'\b' + RegExp.escape(kw) + r'\b').hasMatch(lower)) count++;
    }
    return count;
  }

  static double _computeNameScore(SpatialLine line, double maxWidth, double minY, double cardHeight, String email) {
    double score = (line.confidence * 40.0);

    final text = line.text;
    final words = text.split(RegExp(r'\s+'));
    final lower = text.toLowerCase();

    if (line.boundingBox.height > 18) score += 25;
    if (_honorifics.any((h) => lower.startsWith(h))) score += 40;

    // Penalize conjunctions/prepositions in names
    if (_hasMatch(lower, ['and', 'of', 'the', 'for', 'in', '&', 'at'])) score -= 40;

    final isAllCaps = text == text.toUpperCase() && text.length > 3;
    final isTitleCase = words.every((w) => w.isEmpty || w[0] == w[0].toUpperCase());
    if (isAllCaps && words.length >= 2 && words.length <= 3) {
      score += 20;
    } else if (isTitleCase && !isAllCaps) {
      score += 20;
    }
    
    if (words.length >= 2 && words.length <= 4) score += 20;
    if (words.length == 1) score -= 25;
    if (words.length > 5) score -= 40;

    if (text.contains(',')) score -= 30;
    if (text.contains('.') && !_honorifics.any((h) => lower.startsWith(h))) {
      final nonInitialDots = RegExp(r'[a-z]{3,}\.');
      if (nonInitialDots.hasMatch(lower)) score -= 30;
    }
    if (RegExp(r'\d').hasMatch(text)) score -= 50;
    if (text.contains('(') || text.contains(')')) score -= 60;
    if (text.contains(':')) score -= 40;

    final nameBlocklist = [
      'university', 'college', 'school', 'institute', 'institut', 'academy',
      'headquarters', 'department', 'faculty', 'office', 'regional',
      'india', 'bangalore', 'bengaluru', 'new delhi', 'mumbai', 'chennai',
      'hyderabad', 'australia', 'adelaide', 'singapore', 'london',
      'education', 'hotel', 'hospital', 'embassy', 'republic',
      'degrees', 'global', 'initiatives', 'mueller', 'bhavan',
      'consulting', 'solutions', 'technologies', 'services',
      'let\'s', 'better', 'group', 'media', 'ventures',
      'business', 'development', 'management', 'marketing', 'sales',
      'finance', 'operations', 'administration', 'support',
      'applications', 'computer', 'science', 'information', 'technology',
      'recruitment', 'admissions', 'affairs', 'international'
    ];
    if (_hasMatch(lower, nameBlocklist)) score -= 60;
    if (_hasMatch(lower, _addressKeywords)) score -= 60;
    if (_hasMatch(lower, _companySuffixes)) score -= 60;

    int titleKeywordHits = _countMatches(lower, _titleKeywords);
    score -= titleKeywordHits * 50;

    final relativeSize = line.boundingBox.width / (maxWidth == 0 ? 1 : maxWidth);
    if (relativeSize > 0.4) score += 15;

    if (RegExp(r'^[a-zA-Z\s]+$').hasMatch(text) && words.length >= 2) score += 10;

    // Email match boost: if candidate line contains part of email localName
    if (email != "Not Found" && email.contains('@')) {
      final localName = email.split('@')[0].toLowerCase();
      if (words.any((w) => w.length > 2 && localName.contains(w.toLowerCase()))) {
        score += 35;
      }
    }

    return score;
  }

  static double _computeTitleScore(SpatialLine line, Rect? nameBox) {
    double score = (line.confidence * 40.0);

    final lower = line.text.toLowerCase();
    if (_hasMatch(lower, _titleKeywords)) score += 50;

    if (nameBox != null) {
      final yDiff = (line.boundingBox.top - nameBox.bottom).abs();
      if (yDiff < 80) score += 30;
    }

    if (line.text.length > 80) score -= 40;
    if (RegExp(r'\d').hasMatch(line.text)) score -= 60;
    if (_hasMatch(lower, _addressKeywords)) score -= 60;

    return score;
  }

  static double _computeCompanyScore(SpatialLine line, double maxWidth, String email, String url) {
    double score = (line.confidence * 30.0);

    final lower = line.text.toLowerCase();
    
    if (line.boundingBox.height > 20) score += 30;

    String domain = "";
    if (email != "Not Found" && email.contains("@")) {
        domain = email.split("@")[1];
    } else if (url != "Not Found") {
        domain = url;
    }
    if (domain.isNotEmpty) {
        domain = domain.toLowerCase().replaceAll(RegExp(r'https?:\/\/'), '').replaceAll('www.', '');
        String coreDomain = domain.split('.')[0];
        
        bool isAcronymMatch = false;
        if (coreDomain.length <= 4 && coreDomain.length > 1) {
            final lineWords = line.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
            String lineAcronym = lineWords
                .where((w) => !['of', 'the', 'and', '&', 'for'].contains(w.toLowerCase()))
                .map((w) => w[0].toLowerCase())
                .join('');
            if (lineAcronym == coreDomain || lineAcronym.startsWith(coreDomain)) {
                isAcronymMatch = true;
            }
        }

        String noSpaceLine = lower.replaceAll(RegExp(r'\s+'), '');

        if (isAcronymMatch) {
            score += 120;
        } else if (coreDomain.length > 2 && (lower.contains(coreDomain) || noSpaceLine.contains(coreDomain))) {
            score += 80;
        }
    }

    if (_hasMatch(lower, _companySuffixes)) score += 45;
    if (_hasMatch(lower, _taglineKeywords)) score -= 80;
    if (_hasMatch(lower, _addressKeywords)) score -= 60;
    score -= _countMatches(lower, _titleKeywords) * 40;

    if (line.text == line.text.toUpperCase() && line.text.length > 3 && line.text.split(' ').length < 4) score += 20;

    final relativeSize = line.boundingBox.width / (maxWidth == 0 ? 1 : maxWidth);
    if (relativeSize > 0.6) score += 30;

    final words = line.text.split(RegExp(r'\s+'));
    int capsWords = words.where((w) => w.isNotEmpty && w[0] == w[0].toUpperCase()).length;
    if (line.text.contains('.') && capsWords > 2) score -= 30;

    return score;
  }

  static String? _findEmailRegex(String text) {
    final RegExp emailRegex = RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}');
    final match = emailRegex.firstMatch(text);
    if (match != null) return match.group(0);

    final cleanText = text.replaceAll(' @', '@').replaceAll('@ ', '@').replaceAll('E-mail :', '').replaceAll('Email:', '');
    final match2 = emailRegex.firstMatch(cleanText);
    if (match2 != null) return match2.group(0);

    final RegExp domainRepair = RegExp(r'([a-zA-Z0-9._%+-]+)(vectus|gmail|hp|outlook|yahoo|dsu|iit|iim)\.(in|com|edu|org|net)');
    final match3 = domainRepair.firstMatch(text);
    if (match3 != null && !match3.group(0)!.contains('@')) {
      return '${match3.group(1)}@${match3.group(2)}.${match3.group(3)}';
    }

    return null;
  }

  static String? _findPhoneRegex(String text) {
    final lines = text.split('\n');
    for (final l in lines) {
      final lower = l.toLowerCase();
      // Skip lines that look like addresses or postal zip codes
      if (_hasMatch(lower, ['street', 'road', 'st', 'rd', 'ave', 'suite', 'box', 'fl', 'floor', 'blvd', 'drive', 'dr', 'zip'])) continue;

      if (lower.contains('m:') || lower.contains('tel:') || lower.contains('mob') || lower.contains('cell') || lower.contains('+91') || RegExp(r'\d{8,}').hasMatch(l)) {
        String repaired = l
            .replaceAll(RegExp(r'(?<=\d)[Oo](?=\d)'), '0')
            .replaceAll(RegExp(r'(?<=\d)[Il](?=\d)'), '1');
        final RegExp phoneRegex = RegExp(r'(\+?\d{1,3}[-.\s]?)?(\(?\d{3}\)?[-.\s]?)?[\d\s.-]{7,15}');
        final match = phoneRegex.firstMatch(repaired);
        if (match != null) {
          final digits = match.group(0)!.replaceAll(RegExp(r'\D'), '');
          if (digits.length >= 8 && digits.length <= 15) return match.group(0)!.trim();
        }
      }
    }
    return null;
  }

  static String? _findUrlRegex(String text) {
    final RegExp urlRegex = RegExp(r'(https?:\/\/)?(www\.)?[-a-zA-Z0-9@:%._\+~#=]{2,256}\.[a-z]{2,6}\b([-a-zA-Z0-9@:%_\+.~#?&//=]*)', caseSensitive: false);
    final match = urlRegex.firstMatch(text);
    if (match != null) {
      final url = match.group(0)!;
      if (!url.contains('@')) return url;
    }
    return null;
  }

  static String? _extractNameFromEmail(String email) {
    final localPart = email.split('@')[0];
    final parts = localPart.split(RegExp(r'[._]'));
    if (parts.length >= 2) {
      String first = parts[0];
      String last = parts[1];
      first = first.replaceAll(RegExp(r'\d'), '');
      last = last.replaceAll(RegExp(r'\d'), '');
      if (first.length > 1 && last.length > 1) {
        return "${first[0].toUpperCase()}${first.substring(1).toLowerCase()} ${last[0].toUpperCase()}${last.substring(1).toLowerCase()}";
      }
    }
    return null;
  }

  static String _cleanDigits(String s) => s.replaceAll(RegExp(r'\D'), '');

  static String _formatPhone(String phone) {
    if (phone == "Not Found") return phone;
    String digitsOnly = phone.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length == 12 && digitsOnly.startsWith('91')) return '+91 ${digitsOnly.substring(2)}';
    return phone;
  }

  static Map<String, dynamic> _emptyResult() {
    return {
      'point_person': 'Not Found',
      'department': 'Not Found',
      'organization_name': 'Not Found',
      'organization_type': 'BUSINESS',
      'location': 'Not Found',
      'contact_number': 'Not Found',
      'contact_email': 'Not Found',
      'url': 'Not Found',
      '_debug_scores': {'name_score': 0, 'title_score': 0, 'company_score': 0}
    };
  }

  static Map<String, dynamic> _getMockData() {
    return {
      'point_person': 'Alex Morgan',
      'department': 'VP of Business Development',
      'organization_name': 'Aetheria Innovations Inc',
      'organization_type': 'TECHNOLOGY',
      'location': '100 Silicon Way, Suite 400, San Francisco, CA 94107',
      'contact_number': '+1 (415) 890-1234',
      'contact_email': 'alex.morgan@aetheria.io',
      'url': 'https://aetheria.io',
      '_debug_scores': {'name_score': 100, 'title_score': 100, 'company_score': 100}
    };
  }
}
