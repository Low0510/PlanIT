import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:planit_schedule_manager/utils/smart_date_parser.dart';

class SmartScheduleInput extends StatefulWidget {
  final Function(String title, DateTime? dateTime) onChanged;
  final bool disableDateParsing; // Disable date parsing but keep time parsing
  final DateTime? fixedDate; // Fixed date to use when date parsing is disabled
  
  const SmartScheduleInput({
    Key? key, 
    required this.onChanged,
    this.disableDateParsing = false, // Default to false
    this.fixedDate, // Optional fixed date
  }) : super(key: key);
  
  @override
  State<SmartScheduleInput> createState() => _SmartScheduleInputState();
}

class _SmartScheduleInputState extends State<SmartScheduleInput> {
  final TextEditingController _controller = TextEditingController();
  DateTime? _parsedDateTime;
  List<DateTimeChip> _dateTimeChips = [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final text = _controller.text;
    
    if (!widget.disableDateParsing) {
      // Full parsing - both date and time
      _updateChips(text);
      _parsedDateTime = SmartDateParserService.parseText(text);
      widget.onChanged(text, _parsedDateTime);
    } else {
      // Date parsing disabled, but time parsing enabled
      // Extract only time patterns
      _updateTimeOnlyChips(text);
      
      // If we have a fixed date, combine it with any extracted time
      if (widget.fixedDate != null) {
        final extractedTime = SmartDateParserService.extractTimeOnly(text);
        if (extractedTime != null) {
          // Create a new DateTime with fixed date but parsed time
          _parsedDateTime = DateTime(
            widget.fixedDate!.year,
            widget.fixedDate!.month,
            widget.fixedDate!.day,
            extractedTime.hour,
            extractedTime.minute,
          );
        } else {
          // If no time found, use the fixed date
          _parsedDateTime = widget.fixedDate;
        }
        widget.onChanged(text, _parsedDateTime);
      } else {
        // No fixed date, only extract time
        final timeOnly = SmartDateParserService.extractTimeOnly(text);
        if (timeOnly != null) {
          // Create DateTime for today with the extracted time
          final now = DateTime.now();
          _parsedDateTime = DateTime(
            now.year,
            now.month,
            now.day,
            timeOnly.hour,
            timeOnly.minute,
          );
        } else {
          _parsedDateTime = null;
        }
        widget.onChanged(text, _parsedDateTime);
      }
    }
  }

  
  
  // Method to only extract time chips
  void _updateTimeOnlyChips(String text) {
    final patterns = [
      // Match time expressions only
      RegExp(r'\b(?:\d{1,2}[:\.]\d{2}\s*(?:am|pm)?|\d{1,2}\s*(?:am|pm)|noon|midnight)\b', caseSensitive: false),
    ];

    List<DateTimeChip> newChips = [];
    
    for (var pattern in patterns) {
      for (Match match in pattern.allMatches(text)) {
        final word = text.substring(match.start, match.end);
        
        // Check if this match overlaps with any existing chips
        bool overlaps = false;
        for (var chip in newChips) {
          if (match.start < chip.endIndex && match.end > chip.startIndex) {
            overlaps = true;
            break;
          }
        }
        
        if (!overlaps) {
          newChips.add(DateTimeChip(
            text: word,
            startIndex: match.start,
            endIndex: match.end,
            isTime: true, // Always time chips in this method
          ));
        }
      }
    }

    // Sort chips by their position in the text
    newChips.sort((a, b) => a.startIndex.compareTo(b.startIndex));

    setState(() {
      _dateTimeChips = newChips;
    });
  }

  void _updateChips(String text) {
    // Updated patterns to match complete date/time phrases
    final patterns = [
      // Match compound date expressions
      RegExp(r'\b(?:next\s+(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday))\b', caseSensitive: false),
      RegExp(r'\b(?:day\s+after\s+tomorrow)\b', caseSensitive: false),
      // Match single-word date expressions
      RegExp(r'\b(?:today|tomorrow|monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b', caseSensitive: false),
      // Match relative expressions
      RegExp(r'\b(?:in\s+(?:\d+|a)\s+(?:day|week)s?)\b', caseSensitive: false),
      // Match time expressions
      RegExp(r'\b(?:\d{1,2}[:\.]\d{2}\s*(?:am|pm)?|\d{1,2}\s*(?:am|pm)|noon|midnight)\b', caseSensitive: false),
    ];

    List<DateTimeChip> newChips = [];
    
    for (var pattern in patterns) {
      for (Match match in pattern.allMatches(text)) {
        final word = text.substring(match.start, match.end);
        final isTime = RegExp(r'\d{1,2}[:\.]\d{2}|am|pm|noon|midnight|\d{1,2}\s*(?:am|pm)')
            .hasMatch(word.toLowerCase());
        
        // Check if this match overlaps with any existing chips
        bool overlaps = false;
        for (var chip in newChips) {
          if (match.start < chip.endIndex && match.end > chip.startIndex) {
            overlaps = true;
            break;
          }
        }
        
        if (!overlaps) {
          newChips.add(DateTimeChip(
            text: word,
            startIndex: match.start,
            endIndex: match.end,
            isTime: isTime,
          ));
        }
      }
    }

    // Sort chips by their position in the text
    newChips.sort((a, b) => a.startIndex.compareTo(b.startIndex));

    setState(() {
      _dateTimeChips = newChips;
    });
  }

  void _removeChip(DateTimeChip chip) {
    final text = _controller.text;
    final newText = text.substring(0, chip.startIndex) + 
                    text.substring(chip.endIndex);
    
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: chip.startIndex),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Icon(Icons.edit_calendar, color: Colors.blue[400], size: 24),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLines: null,
                      style: TextStyle(fontSize: 15),
                      decoration: InputDecoration(
                        hintText: widget.disableDateParsing 
                            ? 'Enter task title (+ optional time)' 
                            : 'eg. Meet John tomorrow at 3pm',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                ],
              ),
              if (_dateTimeChips.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(left: 56, right: 16, bottom: 8),
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: _dateTimeChips.map((chip) => _buildChip(chip)).toList(),
                  ),
                ),
            ],
          ),
        ),
        if (_parsedDateTime != null && !widget.disableDateParsing) ...[
          SizedBox(height: 8),
          Text(
            DateFormat('MMM dd, yyyy - HH:mm').format(_parsedDateTime!),
            style: TextStyle(fontSize: 14, color: Colors.blue[400], fontWeight: FontWeight.w500),
          ),
        ],
      ],
    );
  }

  Widget _buildChip(DateTimeChip chip) {
    return RawChip(
      label: Text(
        chip.text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
        ),
      ),
      backgroundColor: chip.isTime ? Colors.green[700] : Colors.blue[700],
      deleteIcon: Icon(Icons.close, size: 14, color: Colors.white70),
      onDeleted: () => _removeChip(chip),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      labelPadding: EdgeInsets.symmetric(horizontal: 4),
      padding: EdgeInsets.symmetric(horizontal: 4),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class DateTimeChip {
  final String text;
  final int startIndex;
  final int endIndex;
  final bool isTime;

  DateTimeChip({
    required this.text,
    required this.startIndex,
    required this.endIndex,
    required this.isTime,
  });
}