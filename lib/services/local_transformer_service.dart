import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_entity_extraction/google_mlkit_entity_extraction.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'offline_transformer_service.dart';

class LocalTransformerService {
  /// Extracts structured data from the visiting card image entirely on-device
  static Future<Map<String, dynamic>> extractCard(dynamic imageFile) async {
    // 1. Check Platform Compatibility: Google ML Kit is supported only on Android and iOS.
    // Return mock developer fallback data on other platforms or during unit tests to prevent crashes.
    final bool isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    final bool isMobile = !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
    if (isTest || !isMobile) {
      return _getMockData();
    }

    try {
      final String filePath = imageFile.path;

      // 2. Perform OCR via Google ML Kit Text Recognition
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final inputImage = InputImage.fromFilePath(filePath);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      final String fullText = recognizedText.text;
      if (fullText.trim().isEmpty) {
        return {
          "organization_name": "Not Found",
          "point_person": "Not Found",
          "department": "Not Found",
          "location": "Not Found",
          "contact_number": "Not Found",
          "contact_email": "Not Found",
          "organization_type": "BUSINESS",
        };
      }

      // Collect and sort all lines visually/spatially (Top-to-Bottom, Left-to-Right)
      final List<SpatialLine> spatialLines = [];
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          final trimmed = line.text.trim();
          if (trimmed.isNotEmpty) {
            spatialLines.add(SpatialLine(trimmed, line.boundingBox));
          }
        }
      }

      // Sort lines primarily by top vertical coordinate (within 15px is considered same row),
      // and secondarily by left horizontal coordinate.
      spatialLines.sort((a, b) {
        final double yDiff = (a.boundingBox.top - b.boundingBox.top).abs();
        if (yDiff < 15.0) {
          return a.boundingBox.left.compareTo(b.boundingBox.left);
        }
        return a.boundingBox.top.compareTo(b.boundingBox.top);
      });

      // Populate allLines
      final List<String> allLines = [];

      final List<String> companyKeywords = [
        // Legal suffixes
        "ltd", "limited", "inc", "incorporated", "llc", "llp", "plc",
        "corp", "corporation", "pvt", "pvt.", "pte", "gmbh", "srl",
        // Clear business entity types
        "company", "companies", "group", "holdings", "ventures", "enterprises", "industries",
        // Tech/Service companies
        "solutions", "technologies", "technology", "tech", "systems", "services", 
        "consulting", "consultancy", "consultants", "advisors", "advisory", "agency", "agencies",
        "studio", "studios", "labs", "laboratory", "laboratories",
        "innovations", "innovation", "software", "hardware", 
        "manufacturing", "construction", "engineering",
        "logistics", "exports", "imports", "trading", "traders",
        "retail", "wholesale", "pharma", "pharmaceutical",
        // Education/Institutions
        "university", "universit", "college", "school", "academy", 
        "institute", "institution", "iit", "iim", "nit", "bits",
        // Non-profit/Gov
        "foundation", "trust", "ngo", "charity", "association", 
        "federation", "hospital", "clinic", "healthcare",
        // Indian specific patterns
        "pvt. ltd", "pvt ltd", "& co.", "& sons", "and sons",
      ];


      // Add merged multi-line company name blocks if any block matches company keywords
      for (final block in recognizedText.blocks) {
        // Sort lines within the block spatially to prevent backwards merging on rotated images
        final sortedLines = block.lines.toList();
        sortedLines.sort((a, b) {
           final double yDiff = (a.boundingBox.top - b.boundingBox.top).abs();
           if (yDiff < 10.0) return a.boundingBox.left.compareTo(b.boundingBox.left);
           return a.boundingBox.top.compareTo(b.boundingBox.top);
        });
        
        final blockText = sortedLines.map((l) => l.text.trim()).join(' ').trim();
        final lowerBlockText = blockText.toLowerCase();
        
        if (block.lines.length > 1 && companyKeywords.any((kw) => lowerBlockText.contains(kw))) {
          // Add the properly ordered merged block to spatialLines so font-size sorting sees it as a massive entity
          spatialLines.add(SpatialLine(blockText, block.boundingBox));
        }
      }

      // Add spatially sorted lines
      for (final sl in spatialLines) {
        allLines.add(sl.text);
      }

      // 3. Extract Entities via Google ML Kit Entity Extraction
      final entityExtractor = EntityExtractor(language: EntityExtractorLanguage.english);
      final List<EntityAnnotation> annotations = await entityExtractor.annotateText(fullText);
      await entityExtractor.close();

      String? extractedEmail;
      String? extractedPhone;
      String? extractedUrl;
      final List<String> locationLines = [];

      for (final annotation in annotations) {
        for (final entity in annotation.entities) {
          if (entity.type == EntityType.email) {
            extractedEmail ??= annotation.text;
          } else if (entity.type == EntityType.phone) {
            final digitCount = annotation.text.replaceAll(RegExp(r'\D'), '').length;
            if (digitCount >= 7) {
              extractedPhone ??= annotation.text;
            }
          } else if (entity.type == EntityType.url) {
            extractedUrl ??= annotation.text;
          } else if (entity.type == EntityType.address) {
            final clean = annotation.text.trim();
            if (clean.isNotEmpty && !locationLines.contains(clean)) {
              locationLines.add(clean);
            }
          }
        }
      }

      // 4. Regex & Heuristic Fallbacks (in case ML Kit misses them due to heavy OCR noise)
      extractedEmail ??= _findEmailRegex(fullText);
      extractedPhone ??= _findPhoneRegex(fullText);
      extractedUrl ??= _findUrlRegex(fullText);

      debugPrint('--- RAW ML KIT LINES ---');
      for (final sl in spatialLines) {
        debugPrint('LINE: "${sl.text}" SIZE: ${sl.boundingBox.width}x${sl.boundingBox.height} POS: ${sl.boundingBox.left},${sl.boundingBox.top}');
      }
      debugPrint('------------------------');

      // 4. Extract entities using Regex (Email, Phone, URL)
      String email = (extractedEmail ?? "Not Found").toLowerCase();
      String phone = extractedPhone ?? "Not Found";
      String url = extractedUrl ?? "Not Found";

      // Reconstruct location using allLines to preserve natural top-to-bottom order
      final List<String> orderedLocationLines = [];
      for (final line in allLines) {
        if (_isLocationLine(line) || locationLines.any((ll) => ll.contains(line) || line.contains(ll))) {
          final clean = line.endsWith(",") ? line.substring(0, line.length - 1).trim() : line;
          if (clean.isNotEmpty && !orderedLocationLines.contains(clean)) {
            orderedLocationLines.add(clean);
          }
        }
      }
      
      // If we completely missed something ML Kit found, add it at the end
      for (final loc in locationLines) {
         if (!orderedLocationLines.any((ol) => ol.contains(loc) || loc.contains(ol))) {
             orderedLocationLines.add(loc);
         }
      }
      
      locationLines.clear();
      locationLines.addAll(orderedLocationLines);

      String location = locationLines.isNotEmpty ? locationLines.join(", ") : "Not Found";

      // 5. Categorize Organization Type
      final String organizationType = _determineOrgType(fullText);

      // 6. Prepare name/organization detection with improved heuristics
      // Filter out lines that match email, phone, website, or location to isolate name/org/designation candidates
      final List<SpatialLine> remainingSpatialLines = spatialLines.where((sl) {
        final line = sl.text;
        final l = line.toLowerCase();
        if (email != "Not Found" && l.contains(email.toLowerCase())) return false;
        if (phone != "Not Found" && _cleanDigits(l).contains(_cleanDigits(phone))) return false;
        if (url != "Not Found" && l.contains(url.toLowerCase())) return false;

        // Filter out if this line is in our locationLines pool
        final isLocLine = locationLines.any((ll) {
          final cleanLL = ll.toLowerCase();
          return cleanLL == l || l.contains(cleanLL) || cleanLL.contains(l);
        });
        
        if (isLocLine) {
           // Wait! If the line also contains a company keyword, it might be a fused company + address line!
           // We must preserve it for company extraction.
           final hasCompanyKeyword = companyKeywords.any((kw) => l.contains(kw));
           if (!hasCompanyKeyword) {
             return false;
           }
        }

        // Remove obvious phone/email patterns
        if (l.contains("@") || l.contains("www.") || l.contains("http")) return false;
        if (RegExp(r'\d{7,}').hasMatch(l)) return false;

        return true;
      }).toList();
      
      // Sort remaining lines by true font size (largest first)
      // On rotated images, the bounding box might have width and height swapped.
      // The short side of a text line's bounding box represents the true font size.
      remainingSpatialLines.sort((a, b) {
        final aFontSize = a.boundingBox.width < a.boundingBox.height ? a.boundingBox.width : a.boundingBox.height;
        final bFontSize = b.boundingBox.width < b.boundingBox.height ? b.boundingBox.width : b.boundingBox.height;
        return bFontSize.compareTo(aFontSize);
      });
      
      final List<String> remainingLines = remainingSpatialLines.map((sl) => sl.text).toList();


      String department = "Not Found";

      // Identify Designation/Department - expanded keyword list
      final List<String> designationKeywords = [
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
        "trustee", "secretary"
      ];

      for (final line in remainingLines) {
        final lowerLine = line.toLowerCase();
        final isDesignation = designationKeywords.any((kw) => lowerLine.contains(kw));
        if (isDesignation) {
          department = line;
          break;
        }
      }

      // Remove department from candidates
      if (department != "Not Found") {
        remainingLines.remove(department);
      }

      // Try to extract person and organization using offline NER model
      String? nerPerson;
      String? nerOrg;
      try {
        final nerResult = await OfflineTransformerService.extractEntities(fullText);
        nerPerson = nerResult['person'];
        nerOrg = nerResult['organization'];

        final bool hasValidNerPerson = nerPerson != null &&
            nerPerson.isNotEmpty &&
            !nerPerson.contains('Not Found') &&
            !nerPerson.startsWith('Token_');

        final bool hasValidNerOrg = nerOrg != null &&
            nerOrg.isNotEmpty &&
            !nerOrg.contains('Not Found') &&
            !nerOrg.startsWith('Token_');

        if (!hasValidNerPerson) nerPerson = null;
        if (!hasValidNerOrg) nerOrg = null;

      } catch (e) {
        debugPrint('NER failed: $e');
      }
String finalPerson = nerPerson ?? "Not Found";
      String finalOrg = nerOrg ?? "Not Found";

      // ── PASS 1: Unified Company Detection (Keywords + Domain Matching) ────────
      if (finalOrg == "Not Found") {
        String? domain = _extractDomain(url);
        domain ??= _extractDomain(email);
        final domainRegex = (domain != null && domain.length >= 3) 
            ? RegExp(r'\b' + RegExp.escape(domain) + r'\b', caseSensitive: false) 
            : null;

        int maxBaseScore = -1;
        double maxAreaForBestScore = -1;
        String bestOrg = "Not Found";

        for (final sl in remainingSpatialLines) {
          final line = sl.text;
          if (line == department || line == finalPerson) continue;

          int baseScore = 0;
          if (_looksLikeCompanyName(line, companyKeywords)) {
            baseScore += 50;
          }
          if (domainRegex != null && domainRegex.hasMatch(line) && line.split(' ').length <= 6) {
            baseScore += 50;
          }

          if (baseScore > 0) {
            final area = sl.boundingBox.width * sl.boundingBox.height;
            if (baseScore > maxBaseScore || (baseScore == maxBaseScore && area > maxAreaForBestScore)) {
              maxBaseScore = baseScore;
              maxAreaForBestScore = area;
              bestOrg = line;
            }
          }
        }

        if (bestOrg != "Not Found") {
          finalOrg = bestOrg;
        } else if (domain != null && domain.length >= 3) {
          // Fallback: Use the capitalized domain itself
          finalOrg = domain[0].toUpperCase() + domain.substring(1);
        }
      }

      // ── PASS 2: Honorific-based person detection ─────────────────────────────
      // Lines starting with Dr./Mr./Prof. etc. are definitely people.
      if (finalPerson == "Not Found") {
        for (final line in remainingLines) {
          if (line == finalOrg) continue;
          if (_startsWithHonorific(line)) {
            finalPerson = line;
            break;
          }
        }
      }

      // ── PASS 3: Dictionary-based person detection ────────────────────────────
      if (finalPerson == "Not Found") {
        for (final line in remainingLines) {
          if (line == finalOrg) continue;
          final words = line.split(RegExp(r'\s+'));
          if (_looksLikePersonName(line, words, _firstNames, _lastNames)) {
            finalPerson = line;
            break;
          }
        }
      }

      // ── PASS 4: ALL CAPS line that is short = company logo text ──────────────
      // e.g. "GOOGLE", "MIT", "TCS" — common on business cards
      if (finalOrg == "Not Found") {
        for (final line in remainingLines) {
          if (line == finalPerson || line == department) continue;
          final words = line.split(RegExp(r'\s+'));
          final isAllCaps = line == line.toUpperCase() &&
              line.length > 2 &&
              RegExp(r'[A-Z]').hasMatch(line) &&
              !RegExp(r'\d').hasMatch(line);
          // If all-caps AND not a 2-word person name in our dictionary
          if (isAllCaps && words.length <= 6) {
            finalOrg = line;
            break;
          }
        }
      }

      // ── PASS 5: Largest-font remaining line = company (business card convention)
      // After person/dept removed, the biggest text is usually the company name.
      if (finalOrg == "Not Found") {
        for (final sl in remainingSpatialLines) {
          final line = sl.text;
          if (line == finalPerson || line == department) continue;
          if (!line.contains('@') && !_isLocationLine(line) && !RegExp(r'\d{5,}').hasMatch(line)) {
            finalOrg = line;
            break;
          }
        }
      }

      // ── PASS 6: Generic 2-4 word Title-Case fallback for person name ──────────
      if (finalPerson == "Not Found") {
        for (final line in remainingLines) {
          if (line == finalOrg || line == department) continue;
          final words = line.split(RegExp(r'\s+'));
          final hasWeirdPunctuation = line.contains(',') || line.contains('!') ||
              line.contains('?') || line.contains(':') || line.contains(';');
          final isTitleCase = words.every((w) =>
              w.isEmpty || w[0] == w[0].toUpperCase());
          // Must be 2-4 words, title case, no digits, no org keywords
          if (words.length >= 2 && words.length <= 4 &&
              !RegExp(r'\d').hasMatch(line) &&
              !line.contains('@') &&
              !hasWeirdPunctuation &&
              isTitleCase &&
              !_looksLikeCompanyName(line, companyKeywords)) {
            finalPerson = line;
            break;
          }
        }
      }

      // ── POST-PASS FIXES ─────────────────────────────────────────────────────

      // FIX 1: Tagline/Slogan as Company → reject it and reset to Not Found
      if (finalOrg != "Not Found" && _looksLikeTagline(finalOrg)) {
        // Try next candidate that isn't a tagline
        finalOrg = "Not Found";
        for (final line in remainingLines) {
          if (line == finalPerson || line == department) continue;
          if (!_looksLikeTagline(line) && !line.contains('@') &&
              !_isLocationLine(line) && !RegExp(r'\d{5,}').hasMatch(line) &&
              line.split(' ').length <= 6) {
            finalOrg = line;
            break;
          }
        }
      }

      // FIX 2: Company field contains a title/designation → swap to title
      if (finalOrg != "Not Found") {
        final lowerOrg = finalOrg.toLowerCase();
        final orgHasDesignation = designationKeywords.any((kw) => lowerOrg.contains(kw));
        final orgHasCompanyKw = _looksLikeCompanyName(finalOrg, companyKeywords);
        if (orgHasDesignation && !orgHasCompanyKw) {
          // This is a title, not a company
          if (department == "Not Found") department = finalOrg;
          finalOrg = "Not Found";
          // Try to find a real company in remaining lines
          for (final line in remainingLines) {
            if (line == finalPerson || line == department) continue;
            if (_looksLikeCompanyName(line, companyKeywords) ||
                (!_looksLikeTagline(line) && !line.contains('@') &&
                 !_isLocationLine(line) && !RegExp(r'\d{5,}').hasMatch(line))) {
              finalOrg = line;
              break;
            }
          }
        }
      }

      // FIX 3: Name repeated in Title field → strip name prefix from title
      if (finalPerson != "Not Found" && department != "Not Found") {
        final deptLower = department.toLowerCase().trim();
        final personLower = finalPerson.toLowerCase().trim();
        if (deptLower.startsWith(personLower)) {
          department = department.substring(finalPerson.length).trim();
          if (department.startsWith(',') || department.startsWith('-') ||
              department.startsWith(' ')) {
            department = department.substring(1).trim();
          }
          if (department.isEmpty) department = "Not Found";
        }
      }

      // FIX 4: Email → Name recovery (ONLY when name is truly Not Found)
      // Parse email like disha.raj@dsti.school → "Disha Raj"
      // This NEVER overrides a name that was already successfully found.
      if (finalPerson == "Not Found" && email != "Not Found" && email.contains('@')) {
        final recovered = _extractNameFromEmail(email);
        if (recovered != null) finalPerson = recovered;
      }

      // FIX 5: Partial name completion → only when email STARTS WITH the same name
      // e.g. detected "Rachael" + email "rachael.mundie@x.com" → "Rachael Mundie"
      // But if email is "rmundiei@x.com" (doesn't match "rachael"), DON'T override.
      if (finalPerson != "Not Found" && !finalPerson.contains(' ') &&
          email != "Not Found" && email.contains('@')) {
        final localPart = email.split('@')[0].toLowerCase();
        final personLower = finalPerson.toLowerCase();
        // Only complete if the email local part starts with the found first name
        if (localPart.startsWith(personLower) && localPart.contains('.')) {
          final recovered = _extractNameFromEmail(email);
          if (recovered != null) finalPerson = recovered;
        }
      }

      // FIX 6: ALL CAPS person name guard
      // If finalPerson is ALL CAPS multi-word AND not in our name dictionaries,
      // it is likely a company logo or slogan (e.g. "LEAP GEEBEE", "TE KUNENGA").
      // Valid ALL CAPS person names like "FARZAD IRANI" ARE in the dictionary
      // and will be protected.
      if (finalPerson != "Not Found" && finalPerson == finalPerson.toUpperCase() &&
          finalPerson.split(' ').length > 1 && finalPerson.length > 6) {
        final words = finalPerson.split(' ');
        final lowerWords = words.map((w) => w.toLowerCase()).toList();
        // Check if at least one word is a known name — if yes, keep it as person
        final isKnownName = lowerWords.any((w) =>
            _firstNames.contains(w) || _lastNames.contains(w));
        if (!isKnownName) {
          // Not a known name → treat as company logo text
          if (finalOrg == "Not Found") finalOrg = finalPerson;
          // Try email recovery for the actual person name
          if (email != "Not Found" && email.contains('@')) {
            final recovered = _extractNameFromEmail(email);
            finalPerson = recovered ?? "Not Found";
          } else {
            finalPerson = "Not Found";
          }
        }
      }

      // 7. Final Formatting
      String extractedAddressResidue = "";
      if (finalOrg.toLowerCase().contains("limited")) {
         final index = finalOrg.toLowerCase().indexOf("limited");
         extractedAddressResidue = finalOrg.substring(index + 7).trim();
         finalOrg = finalOrg.substring(0, index + 7).trim();
      } else if (finalOrg.toLowerCase().contains("ltd")) {
         final index = finalOrg.toLowerCase().indexOf("ltd");
         extractedAddressResidue = finalOrg.substring(index + 3).trim();
         finalOrg = finalOrg.substring(0, index + 3).trim();
      }
      
      // If OCR fused the address with the company name, append it to location
      if (extractedAddressResidue.isNotEmpty) {
         if (location == "Not Found") {
           location = extractedAddressResidue;
         } else if (!location.contains(extractedAddressResidue)) {
           location = "$extractedAddressResidue, $location";
         }
      }

      // Name formatting (e.g. SVenkatesh -> S Venkatesh)
      if (finalPerson != "Not Found" && finalPerson.length > 2) {
         if (finalPerson[0] == finalPerson[0].toUpperCase() && 
             finalPerson[1] == finalPerson[1].toUpperCase() &&
             finalPerson[2] != finalPerson[2].toUpperCase()) {
            finalPerson = '${finalPerson[0]} ${finalPerson.substring(1)}';
         }
      }

      // Email formatting (recover invisible OCR dot in emails like svenkatesh1 -> s.venkatesh1)
      if (email != "Not Found" && finalPerson != "Not Found") {
         final nameParts = finalPerson.toLowerCase().split(RegExp(r'\s+'));
         if (nameParts.length >= 2) {
            final firstInitial = nameParts[0][0];
            final lastName = nameParts[1];
            if (email.startsWith('$firstInitial$lastName')) {
               email = email.replaceFirst('$firstInitial$lastName', '$firstInitial.$lastName');
            }
         }
      }
      
      String formattedPhone = phone;
      if (formattedPhone != "Not Found") {
        String digitsOnly = formattedPhone.replaceAll(RegExp(r'\D'), '');
        if (digitsOnly.length == 12 && digitsOnly.startsWith('91')) {
          formattedPhone = '+91 ${digitsOnly.substring(2)}';
        } else if (digitsOnly.length > 10 && formattedPhone.startsWith('+')) {
           final ccLength = digitsOnly.length - 10;
           final cc = digitsOnly.substring(0, ccLength);
           final rest = digitsOnly.substring(ccLength);
           formattedPhone = '+$cc $rest';
        }
      }

      return {
        "organization_name": finalOrg,
        "point_person": finalPerson,
        "department": department,
        "location": _cleanAddressField(location, phone, email, url),
        "contact_number": formattedPhone,
        "contact_email": email,
        "organization_type": organizationType,
        "url": url,
      };
    } catch (e) {
      debugPrint("Error in local extraction service: $e");
      rethrow;
    }
  }

  /// Returns true if line starts with an honorific prefix (Dr., Mr., Prof. etc.)
  static bool _startsWithHonorific(String line) {
    final lower = line.toLowerCase().trim();
    const honorifics = [
      'dr.', 'dr ', 'mr.', 'mr ', 'mrs.', 'mrs ', 'ms.', 'ms ',
      'prof.', 'prof ', 'professor ', 'rev.', 'rev ', 'eng.', 'eng ',
      'phd', 'ph.d', 'sir ', 'hon.', 'hon ',
    ];
    return honorifics.any((h) => lower.startsWith(h));
  }

  /// Detects marketing taglines/slogans that should never be a company name
  static bool _looksLikeTagline(String line) {
    final l = line.toLowerCase();
    // Specific promotional/motivational words common on university/corporate cards
    final taglineWords = [
      'thinking', 'globally', 'minded', 'driven by', 'powered by',
      'inspired by', 'excellence', 'innovation for', 'building tomorrow',
      'your future', 'we are', 'mai te', 'ki p',
      'education driven', 'knowledge driven', 'capital thinking',
      'globally minded', 'te herenga', 'te kunenga',
    ];
    if (taglineWords.any((w) => l.contains(w))) return true;
    // Multiple sentence-ending periods in a short line = slogan
    final dotCount = '.'.allMatches(line).length;
    if (dotCount >= 2 && line.length < 80 && !line.contains('@')) return true;
    // ALL CAPS line with | is usually Maori university branding or logo text
    if (line.contains('|') && line.toUpperCase() == line) return true;
    // ALL CAPS with > 4 words and no company keyword = likely slogan/logo
    final words = line.trim().split(RegExp(r'\s+'));
    if (line == line.toUpperCase() && words.length > 4 &&
        !line.contains('UNIVERSITY') && !line.contains('COLLEGE') &&
        !line.contains('INSTITUTE') && !line.contains('LTD') &&
        !line.contains('INC') && !line.contains('SCHOOL')) {
      return true;
    }
    return false;
  }

  /// Extract a person name from an email address
  /// e.g. disha.raj@domain.com → "Disha Raj"
  ///      sebastien.corniglion@domain.com → "Sebastien Corniglion"
  ///      rmundiei@domain.com → "R Mundie"
  static String? _extractNameFromEmail(String email) {
    if (!email.contains('@')) return null;
    final localPart = email.split('@')[0].toLowerCase()
        .replaceAll(RegExp(r'[._\-+0-9]+$'), ''); // strip trailing digits/dots

    // Pattern 1: firstname.lastname (most common)
    if (localPart.contains('.')) {
      final parts = localPart.split('.').where((p) =>
          p.length > 0 && !RegExp(r'^\d+$').hasMatch(p)).toList();
      if (parts.length >= 2) {
        return parts.map(_capitalizeWord).join(' ');
      }
      if (parts.length == 1) {
        return _capitalizeWord(parts[0]);
      }
    }

    // Pattern 2: Match known first name prefix, remainder = last name
    for (final firstName in _firstNames) {
      if (localPart.startsWith(firstName)) {
        final lastPart = localPart.substring(firstName.length)
            .replaceAll(RegExp(r'\d+'), '');
        if (lastPart.length > 0) {
          return '${_capitalizeWord(firstName)} ${_capitalizeWord(lastPart)}';
        }
      }
    }

    // Pattern 3: Single initial + last name (e.g. rmundiei → R Mundie)
    if (localPart.length > 1) {
      final initial = localPart[0].toUpperCase();
      final rest = localPart.substring(1).replaceAll(RegExp(r'\d+'), '');
      if (rest.length > 0 && RegExp(r'^[a-z]+$').hasMatch(rest)) {
        return '$initial ${_capitalizeWord(rest)}';
      }
    }

    return null;
  }

  static String _capitalizeWord(String word) {
    if (word.isEmpty) return word;
    return word[0].toUpperCase() + word.substring(1);
  }

  /// Clean the address field: remove phone numbers, emails, and URLs that got fused in
  static String _cleanAddressField(String address, String phone, String email, String url) {
    if (address == "Not Found") return address;
    final segments = address.split(RegExp(r',\s*'));
    final cleaned = segments.where((seg) {
      final s = seg.trim();
      if (s.isEmpty) return false;
      // Remove if it contains @ (email)
      if (s.contains('@')) return false;
      // Remove if it starts with www or http
      if (s.toLowerCase().startsWith('www.') || s.toLowerCase().startsWith('http')) return false;
      // Remove if it's purely a phone number (many digits)
      if (RegExp(r'^[\+\d\s\-()]{7,}$').hasMatch(s)) return false;
      // Remove if it's a very long digit string
      if (RegExp(r'\d{7,}').hasMatch(s) && s.replaceAll(RegExp(r'\D'), '').length > 6) return false;
      // Remove if this segment matches the URL field value
      if (url != "Not Found" && s.toLowerCase().contains(url.toLowerCase())) return false;
      return true;
    }).toList();
    // Deduplicate adjacent identical segments
    final deduped = <String>[];
    for (final seg in cleaned) {
      if (deduped.isEmpty || deduped.last != seg) deduped.add(seg);
    }
    return deduped.isEmpty ? "Not Found" : deduped.join(', ');
  }

  /// Extracts the main domain name from a URL or Email, ignoring generic providers.
  static String? _extractDomain(String urlOrEmail) {
    if (urlOrEmail == "Not Found" || urlOrEmail.trim().isEmpty) return null;
    String host = urlOrEmail.toLowerCase();
    
    // If it's an email, take the part after @
    if (host.contains('@')) {
      host = host.split('@').last;
    }
    
    // Clean up url prefixes
    host = host.replaceAll(RegExp(r'^https?://'), '');
    host = host.replaceAll(RegExp(r'^www\.'), '');
    
    // Split by dot and grab the primary domain part
    final parts = host.split('.');
    if (parts.isNotEmpty) {
      final domain = parts[0];
      // Ignore common generic domains
      if (!['gmail', 'yahoo', 'hotmail', 'outlook', 'icloud', 'aol', 'mail', 'not found'].contains(domain)) {
        return domain;
      }
    }
    return null;
  }

  /// Returns true if a line looks like a company/org name
  static bool _looksLikeCompanyName(String line, List<String> companyKeywords) {
    final lower = line.toLowerCase();
    // Check regex-based keywords
    for (final kw in companyKeywords) {
      if (kw.startsWith(r'\b')) {
        if (RegExp(kw).hasMatch(lower)) return true;
      } else {
        if (lower.contains(kw)) return true;
      }
    }
    // Has & between two words (e.g. "Smith & Co", "Arts & Crafts Ltd")
    // Reject: "Level 1 & 2", "Unit 3 & 4" (& between numbers)
    if (line.contains('&')) {
      final ampMatch = RegExp(r'[A-Za-z]+\s*&\s*[A-Za-z]+').hasMatch(line);
      if (ampMatch) return true;
    }
    // Ends with common legal abbreviations as a whole word
    final endsWithLegal = RegExp(
        r'\b(ltd\.?|inc\.?|llc\.?|corp\.?|plc\.?|pvt\.?)\s*$',
        caseSensitive: false).hasMatch(line);
    if (endsWithLegal) return true;
    return false;
  }

  /// Heuristic to decide if a line looks like a person name
  static bool _looksLikePersonName(String line, List<String> words,
      List<String> firstNames, List<String> lastNames) {
    if (words.length < 1 || words.length > 5) return false;
    // Single word name only valid if it's a known first name + starts upper case
    if (words.length == 1) {
      final w = words[0].toLowerCase();
      return firstNames.contains(w) && line[0] == line[0].toUpperCase();
    }
    final List<String> lowerWords = words.map((w) =>
        w.replaceAll(RegExp(r'[^a-z]'), '')).where((w) => w.isNotEmpty).toList();
    // Count how many words are in name dictionaries
    int knownCount = 0;
    for (final w in lowerWords) {
      if (firstNames.contains(w) || lastNames.contains(w)) knownCount++;
    }
    // At least one word must be a known name
    if (knownCount == 0) return false;
    // Has digits = not a name
    if (RegExp(r'\d').hasMatch(line)) return false;
    // Has email/url patterns = not a name
    if (line.contains('@') || line.contains('www.') || line.contains('.com')) return false;
    return true;
  }

  // Regex Helpers for fallback matching
  static String? _findEmailRegex(String text) {
    final match = RegExp(r'[a-zA-Z0-9._%+-]+\s*@\s*[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}').firstMatch(text);
    if (match != null) {
      return match.group(0)?.replaceAll(RegExp(r'\s+'), '');
    }
    // Extreme fallback: find the line with @
    final lines = text.split(RegExp(r'[\r\n]+'));
    for (final line in lines) {
      if (line.contains('@')) {
         final words = line.split(RegExp(r'\s+'));
         for (final word in words) {
           if (word.contains('@')) return word.trim();
         }
      }
    }
    return null;
  }

  static String? _findPhoneRegex(String text) {
    // Looks for phone formats: e.g. +91 99999-99999 or (123) 456-7890
    final matches = RegExp(r'\+?[0-9\s\-()]{8,18}').allMatches(text);
    for (final m in matches) {
      final matchedStr = m.group(0)!.trim();
      final digitCount = matchedStr.replaceAll(RegExp(r'\D'), '').length;
      if (digitCount >= 7 && digitCount <= 15) {
        return matchedStr;
      }
    }
    return null;
  }

  static String? _findUrlRegex(String text) {
    // Only match standalone strings with known TLDs, or explicit http/www links
    final match = RegExp(r'(https?:\/\/)[^\s]+|(www\.)[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}|[a-zA-Z0-9.-]+\.(com|edu|org|net|co|ac|in|uk|us|gov|io|biz|info)\b', caseSensitive: false).firstMatch(text);
    return match?.group(0);
  }

  static bool _isLocationLine(String line) {
    final l = line.toLowerCase().trim();
    if (l.isEmpty) return false;

    // Zip/postal code matching (5 or 6 digits, or alphanumeric postal codes)
    final hasZip = RegExp(r'\b\d{5,6}\b').hasMatch(l);
    if (hasZip) return true;

    // Common address/location keywords
    final List<String> locationKeywords = [
      "street", "road", " avenue", " lane", " highway", " court", " drive",
      " st.", " rd.", " ave.", " ln.", " hwy.", " ct.", " dr.",
      "suite", "ste.", "ste ", "room", " rm.", " rm ", "building", "bldg",
      "floor", " fl.", " fl ", " fl,", "plaza", "p.o. box", "po box", "parkway", "pkwy",
      "valley", "mount", "mountain", "block", "sector", "district", "zone",
      "city", "state", "country", "india", "usa", "uk", "germany", "japan",
      "san francisco", "california", "new york", "london", "post office",
      "cross", "main", "phase", "layout", "nagar", "industrial", "estate", "arena", "tower", "marg", "complex"
    ];

    if (locationKeywords.any((kw) => l.contains(kw))) return true;

    // Check for US State abbreviation pattern at the end of a line, e.g. ", CA" or ", NY"
    final hasStateAbbrev = RegExp(r',\s*[a-zA-Z]{2}\b').hasMatch(l);
    if (hasStateAbbrev) return true;

    return false;
  }

  static String _determineOrgType(String text) {
    final l = text.toLowerCase();
    if (l.contains("university") || l.contains("college") || l.contains("school") || l.contains("academy") || l.contains("institute")) {
      return "UNIVERSITY";
    }
    if (l.contains("ngo") || l.contains("foundation") || l.contains("charity") || l.contains("trust") || l.contains("nonprofit") || l.contains("association")) {
      return "NGO";
    }
    if (l.contains("consultancy") || l.contains("consulting") || l.contains("advisor")) {
      return "CONSULTANCY";
    }
    if (l.contains("startup") || l.contains("labs") || l.contains("hub")) {
      return "STARTUP";
    }
    if (l.contains("government") || l.contains("ministry") || l.contains("dept of") || l.contains("national") || l.contains("federal")) {
      return "GOVERNMENT";
    }
    return "BUSINESS";
  }

  static String _cleanDigits(String text) {
    return text.replaceAll(RegExp(r'\D'), '');
  }

  /// Returns mock business card data for local testing on Web and Desktop environments
  static Map<String, dynamic> _getMockData() {
    return {
      "organization_name": "Google LLC",
      "point_person": "Sundar Pichai",
      "department": "Chief Executive Officer",
      "location": "Mountain View, CA",
      "contact_number": "+1 (650) 253-0000",
      "contact_email": "sundar@google.com",
      "organization_type": "BUSINESS",
      "url": "www.google.com"
    };
  }
}

// Define name/organization detection helpers
const List<String> _firstNames = [
  // Western / European
  "john", "jane", "michael", "emily", "william", "olivia", "james", "sophia",
  "robert", "isabella", "david", "mia", "joseph", "charlotte", "charles", "amelia",
  "thomas", "harper", "christopher", "evelyn", "daniel", "abigail", "matthew",
  "anthony", "elizabeth", "mark", "donald", "ella", "steven", "avery",
  "paul", "sofia", "andrew", "camila", "joshua", "aria", "kenneth", "scarlett",
  "ken", "laura", "kevin", "sarah", "brian", "kimberly", "george", "deborah",
  "timothy", "dorothy", "ronald", "lisa", "jason", "nancy", "edward", "samantha",
  "stephen", "katherine", "christine", "larry", "catherine", "justin",
  "emma", "brandon", "benjamin", "alex", "rachael", "jessica", "ashley",
  "amanda", "stephanie", "melissa", "nicole", "jennifer", "heather", "amber",
  "adam", "ryan", "jacob", "tyler", "jordan", "ethan", "noah", "liam",
  "mason", "logan", "lucas", "oliver", "elijah", "aiden", "jackson",
  "peter", "henry", "patrick", "richard", "alan", "albert", "alfred",
  "jacqueline", "paulo", "sebastien", "hans", "pierre", "marie", "claire",
  // Indian first names (North + South + Bengali)
  "amit", "rahul", "neha", "priya", "rohit", "vikas", "sanjay", "deepak",
  "anil", "sunil", "pooja", "arjun", "ankit", "ashish", "riddhi", "aakash",
  "priyal", "vaseem", "harjinder", "urvashi", "abhilash", "farzad", "disha",
  "archana", "mini", "joice", "karthik",
  "aarav", "aditi", "akash", "alok", "aman", "anand", "anjali", "ankur",
  "anupam", "anurag", "arun", "arvind", "ashu", "ayesha", "bhavna", "chetan",
  "chitra", "deepa", "devika", "dhruv", "divya", "ganesh", "gaurav", "gayatri",
  "girish", "gopal", "harish", "hemant", "hina", "isha", "ishaan", "jagdish",
  "jatin", "jitendra", "kalpana", "kamal", "kartik", "kavita", "kishore",
  "krishna", "kunal", "lata", "lalit", "madhuri", "mahesh", "manish", "manjari",
  "meena", "meenakshi", "mihir", "minal", "mohan", "mukesh", "munna", "nalini",
  "namita", "nandita", "narendra", "naresh", "naveen", "nidhi", "nikhil", "nitin",
  "parag", "pankaj", "parth", "pawan", "piyush", "prakash", "pranav", "prasad",
  "preeti", "priyanka", "purvi", "radha", "rajesh", "rajiv", "rakesh", "ram",
  "ramesh", "rani", "ravi", "rekha", "renu", "ritesh", "ritu", "riya",
  "rohan", "sachin", "samir", "sandeep", "sandesh", "sangeetha", "sanjana",
  "santosh", "sapna", "shailesh", "shekhar", "shivam", "shilpa", "shreya",
  "shruti", "shubham", "siddharth", "smita", "sneha", "sonam", "subhash",
  "sumit", "sunita", "suresh", "swati", "tanvi", "tarun", "uday", "umesh",
  "vandana", "varun", "vijay", "vijaya", "vikram", "vinay", "vineet", "vishal",
  "vishwas", "yogesh", "yashwant", "zara", "zoya",
  // South Indian
  "aravind", "balaji", "bharat", "chandrasekhar", "geetha", "hariharan",
  "indira", "jayalakshmi", "kamala", "krishnamurthy", "lakshmi", "lalitha",
  "madhavan", "malathi", "murugan", "nandakumar", "padma", "palaniswamy",
  "raghunathan", "rajagopalan", "rajalakshmi", "rajan", "rajani", "ramachandran",
  "saravanan", "sathish", "selvi", "senthil", "shanthi", "sivaraj", "subramanian",
  "sundaram", "suresh", "suryanarayana", "usha", "vasanth", "venkatesh", "vignesh",
  // East Asian / Arabic (common on intl biz cards)
  "ahmed", "ali", "fatima", "hassan", "ibrahim", "khalid", "muhammad", "omar",
  "sara", "yusuf", "zhang", "wei", "li", "yang", "liu", "chen", "wang",
  "akira", "haruto", "yuki", "kenji", "sakura", "hana",
];
const List<String> _lastNames = [
  // Western
  "smith", "johnson", "williams", "brown", "jones", "garcia", "miller", "davis",
  "rodriguez", "martinez", "hernandez", "lopez", "gonzalez", "wilson", "anderson",
  "thomas", "taylor", "moore", "jackson", "martin", "lee", "perez", "thompson",
  "white", "harris", "sanchez", "clark", "ramirez", "lewis", "robinson", "walker",
  "young", "allen", "king", "wright", "scott", "torres", "nguyen", "hill",
  "flores", "green", "adams", "nelson", "baker", "hall", "rivera", "campbell",
  "mitchell", "carter", "roberts", "turner", "phillips", "parker", "evans",
  "edwards", "collins", "stewart", "morris", "reed", "cook", "bell", "gray",
  "james", "watson", "brooks", "kelly", "sanders", "price", "bennett", "wood",
  "ross", "murphy", "bailey", "cooper", "cox", "ward",
  // Indian last names (common across regions)
  "shah", "sadra", "walia", "kaparthi", "irani", "madival", "raj",
  "corniglion", "kahupapa", "suri", "khurana", "mehta", "priego",
  "mora", "menon", "malhotra", "kumar", "sharma", "singh", "patel",
  "gupta", "reddy", "rao", "das", "bablani", "mundie",
  "agarwal", "aggarwal", "agrawal", "arora", "bajaj", "bose", "bhatnagar",
  "bhatt", "chakraborty", "chatterjee", "chaudhary", "chaurasia", "chopra",
  "desai", "deshpande", "dube", "dubey", "dutta", "gandhi", "ghosh",
  "goswami", "goyal", "goel", "jain", "jaiswal", "joshi", "kapoor",
  "kaur", "khanna", "kulkarni", "lal", "lamba", "mahajan", "mishra",
  "mittal", "mukerjee", "mukherjee", "nair", "naik", "narayanan", "pandey",
  "pandit", "pillai", "prasad", "rana", "rathore", "rastogi", "saxena",
  "sehgal", "sen", "seth", "shukla", "sinha", "srivastava", "tiwari",
  "trivedi", "thakur", "varma", "verma", "yadav",
  // South Indian surnames
  "ayer", "iyer", "iyengar", "krishnan", "murthy", "naidu", "nambiar",
  "pillai", "rajan", "ramachandran", "subramaniam", "venkataraman",
];
const List<String> _honorifics = [
  "mr.", "mrs.", "ms.", "miss", "dr.", "prof.", "rev.", "hon.", "sir", "madam",
  "dr.", "ph.d.", "md", "do", "dds", "dvm", "esq.", "jr.", "sr.", "ii", "iii"
];
const List<String> _orgPrefixes = [
  "the", "a", "an"
];

class SpatialLine {
  final String text;
  final Rect boundingBox;

  SpatialLine(this.text, this.boundingBox);
}