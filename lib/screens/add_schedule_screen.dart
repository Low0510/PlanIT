import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:intl/intl.dart';
import 'package:planit_schedule_manager/const.dart';
import 'package:planit_schedule_manager/models/task.dart';
import 'package:planit_schedule_manager/services/schedule_service.dart';
import 'package:planit_schedule_manager/utils/text_cleaner.dart';
import 'package:planit_schedule_manager/widgets/highlighted_title_input.dart';
import 'package:planit_schedule_manager/widgets/repeat_task_widget.dart';
import 'package:planit_schedule_manager/widgets/time_conflict_manager.dart';
import 'package:planit_schedule_manager/widgets/toast.dart';

class AddSchedulePanel extends StatefulWidget {
  final Function(
    String title,
    String category,
    String url,
    String placeURL,
    DateTime time,
    List<String> subtasks,
    String priority,
    bool isRepeated,
    String repeatInterval,
    int repeatedIntervalTime,
    List<File> selectedFiles,
  ) onAddSchedule;

  final DateTime? initialDate;

  const AddSchedulePanel(
      {super.key, required this.onAddSchedule, this.initialDate});

  @override
  State<AddSchedulePanel> createState() => _AddSchedulePanelState();

  static void show(
      BuildContext context,
      Function(
        String title,
        String category,
        String url,
        String placeURL,
        DateTime time,
        List<String> subtasks,
        String priority,
        bool isRepeated,
        String repeatInterval,
        int repeatedIntervalTime,
        List<File> selectedFiles,
      ) onAddSchedule,
      {DateTime? initialDate}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      builder: (context) => AddSchedulePanel(
        onAddSchedule: onAddSchedule,
        initialDate: initialDate,
      ),
    );
  }
}

class _AddSchedulePanelState extends State<AddSchedulePanel> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _placeURLController = TextEditingController();

  final List<TextEditingController> _subtasksControllers = [];
  final List<FocusNode> _subtasksFocusNodes = [];

  final FocusNode _locationFocusNode = FocusNode();
  final FocusNode _intervalSelectorFocusNode = FocusNode();

  String _selectedCategory = 'Other';
  DateTime? _selectedDateTime;
  String _selectedPriority = 'Medium';
  bool _isRepeatEnabled = false;
  String _selectedRepeatInterval = 'Daily';
  int _repeatedIntervalTime = 0;
  final Set<int> _selectedWeekdays = {};
  final List<File> _selectedFiles = [];

  String googleMapsUrl = '';

  @override
  void initState() {
    super.initState();

    if (widget.initialDate != null) {
      bool hasCustomTime =
          widget.initialDate!.hour != 0 || widget.initialDate!.minute != 0;
      _selectedDateTime = hasCustomTime
          ? widget.initialDate
          : widget.initialDate!.copyWith(hour: 23, minute: 59);
    } else {
      _selectedDateTime = DateTime.now().copyWith(hour: 23, minute: 59);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    _placeURLController.dispose();
    _locationFocusNode.dispose();
    for (var controller in _subtasksControllers) {
      controller.dispose();
    }
    for (var node in _subtasksFocusNodes) {
      node.dispose();
    }
    _intervalSelectorFocusNode.dispose();
    super.dispose();
  }

  InputDecoration _styledInputDecoration({
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    EdgeInsetsGeometry? contentPadding,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
      prefixIcon: prefixIcon != null
          ? Padding(
              padding: const EdgeInsets.only(left: 14, right: 10),
              child: IconTheme(
                  data: IconThemeData(color: Colors.grey[500], size: 20),
                  child: prefixIcon),
            )
          : null,
      suffixIcon: suffixIcon != null
          ? Padding(padding: const EdgeInsets.only(right: 8), child: suffixIcon)
          : null,
      filled: true,
      fillColor: Colors.white.withOpacity(0.9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(color: Colors.grey[300]!, width: 1.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(color: Colors.grey[300]!, width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(color: Colors.blue[400]!, width: 1.5),
      ),
      contentPadding: contentPadding ??
          const EdgeInsets.symmetric(vertical: 15.0, horizontal: 16.0),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  Future<void> _pickDateTime(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue[400]!,
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime:
            TimeOfDay.fromDateTime(_selectedDateTime ?? DateTime.now()),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: Colors.blue[400]!,
                onPrimary: Colors.white,
                surface: Colors.white,
              ),
              dialogBackgroundColor: Colors.white,
            ),
            child: child!,
          );
        },
      );
      if (pickedTime != null) {
        setState(() {
          _selectedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<bool> _showConflictSuggestionDialog(BuildContext context,
      DateTime conflictTime, List<Task> conflictTasks) async {
    final TimeConflictManager conflictManager =
        TimeConflictManager(ScheduleService());
    final alternatives = conflictManager.getAlternativeTimes(conflictTime);
    final completer = Completer<bool>();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter dialogSetState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
            backgroundColor: Colors.white,
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Colors.orange[600], size: 26),
                      const SizedBox(width: 10),
                      Text(
                        'Time Conflict Detected',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[850],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Text(
                    'You already have ${conflictTasks.length} task${conflictTasks.length > 1 ? "s" : ""} scheduled at ${DateFormat('MMM dd, yyyy - HH:mm').format(conflictTime)}:',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[100]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: conflictTasks
                          .map((task) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  children: [
                                    Icon(Icons.event_note_outlined,
                                        color: Colors.blue[500], size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        task.title,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 15),
                                      ),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Suggested alternatives:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 150, // Adjusted height
                    child: ListView.builder(
                      itemCount: alternatives.length,
                      itemBuilder: (context, index) {
                        return InkWell(
                          onTap: () {
                            setState(() {
                              // This setState is for the main panel
                              _selectedDateTime = alternatives[index];
                            });
                            dialogSetState(
                                () {}); // Rebuild dialog if needed, or just pop
                            Navigator.pop(context);
                            completer.complete(
                                true); // Indicate a selection was made
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.schedule_outlined,
                                        color: Colors.green[500], size: 20),
                                    const SizedBox(width: 12),
                                    Text(
                                      DateFormat('HH:mm')
                                          .format(alternatives[index]),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  index < 2 ? 'Earlier' : 'Later',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<DateTime?>(
                    future: conflictManager.findNextAvailableSlot(conflictTime),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator(strokeWidth: 2));
                      }
                      if (snapshot.hasData && snapshot.data != null) {
                        return InkWell(
                          onTap: () {
                            setState(() {
                              // This setState is for the main panel
                              _selectedDateTime = snapshot.data;
                            });
                            Navigator.pop(context);
                            completer.complete(true);
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.auto_awesome_outlined,
                                    color: Colors.blue[500], size: 20),
                                const SizedBox(width: 12),
                                Text(
                                  'Next available: ${DateFormat('HH:mm').format(snapshot.data!)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          completer.complete(false);
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          foregroundColor: Colors.grey[700],
                        ),
                        child: const Text('Cancel',
                            style: TextStyle(fontSize: 15)),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () {
                          // No need to change _selectedDateTime here, it's already conflictTime
                          // setState is for the main panel to ensure it reflects the chosen time if needed,
                          // though in this specific "Use anyway" case, it's already set.
                          // setState(() { _selectedDateTime = conflictTime; });
                          Navigator.pop(context);
                          completer.complete(true); // Proceed with current time
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[400],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Use anyway',
                            style: TextStyle(fontSize: 15)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
    return completer.future;
  }

  void _showPriorityInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        const boldStyle =
            TextStyle(fontWeight: FontWeight.bold, color: Colors.black87);
        const normalStyle = TextStyle(color: Colors.black54, height: 1.4);

        return AlertDialog(
          title: const Text('Priority Levels Explained'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                RichText(
                  text: TextSpan(
                    style: normalStyle,
                    children: const <TextSpan>[
                      TextSpan(
                          text: 'High (15mins before): ', style: boldStyle),
                      TextSpan(
                          text:
                              'For urgent tasks. Shows as a full-screen alarm, plays a loud sound, and cannot be easily dismissed.'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                RichText(
                  text: TextSpan(
                    style: normalStyle,
                    children: const <TextSpan>[
                      TextSpan(
                          text: 'Medium (10mins before): ', style: boldStyle),
                      TextSpan(
                          text:
                              'For important reminders. Appears as a standard notification with sound and vibration.'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                RichText(
                  text: TextSpan(
                    style: normalStyle,
                    children: const <TextSpan>[
                      TextSpan(text: 'Low (5mins before): ', style: boldStyle),
                      TextSpan(
                          text:
                              'For regular tasks. Appears as a standard notification with sound but no vibration.'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                RichText(
                  text: TextSpan(
                    style: normalStyle,
                    children: const <TextSpan>[
                      TextSpan(text: 'None: ', style: boldStyle),
                      TextSpan(
                          text:
                              'For silent reminders. The notification will appear quietly without any sound or vibration.'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Got it'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (BuildContext context, StateSetter setModalState) {
        return Stack(children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/background.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.white.withOpacity(0.8), // Slightly more opaque
            ),
          ),
          Column(
            // Use Column for handle and content
            children: [
              // Handle bar at the top
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                // Allows SingleChildScrollView to take remaining space
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                    left: 20,
                    right: 20,
                    top: 10, // Reduced top padding as handle is separate
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add New Schedule',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[900],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Create a new schedule item',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: () {
                              _titleController.clear();
                              _urlController.clear();
                              _subtasksControllers
                                  .forEach((controller) => controller.clear());
                              _subtasksFocusNodes.clear();
                              _placeURLController.clear();
                              _selectedWeekdays.clear();
                              _selectedFiles.clear();

                              setModalState(() {
                                _selectedCategory = 'Other';
                                _selectedDateTime = DateTime.now()
                                    .copyWith(hour: 23, minute: 59);
                                _selectedPriority = 'Medium';
                                _isRepeatEnabled = false;
                                _selectedRepeatInterval = 'Daily';
                                _repeatedIntervalTime = 0;
                                while (_subtasksControllers.length > 0) {
                                  _subtasksControllers.last.dispose();
                                  _subtasksControllers.removeLast();
                                }
                              });
                              Navigator.pop(context);
                            },
                            icon: Icon(Icons.close,
                                color: Colors.grey[600], size: 26),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Title Input
                      _buildInputLabel('Title'),
                      SmartScheduleInput(
                        onChanged: (title, dateTime) {
                          setModalState(() {
                            // Use setModalState for UI updates within modal
                            _titleController.text = title;
                            if (dateTime != null) {
                              if (widget.initialDate != null &&
                                  _selectedDateTime != null) {
                                _selectedDateTime = DateTime(
                                  _selectedDateTime!.year,
                                  _selectedDateTime!.month,
                                  _selectedDateTime!.day,
                                  dateTime.hour,
                                  dateTime.minute,
                                );
                              } else {
                                _selectedDateTime = dateTime;
                              }
                            }
                          });
                        },
                        disableDateParsing: widget.initialDate != null,
                        fixedDate: widget.initialDate != null
                            ? _selectedDateTime
                            : null,
                      ),
                      const SizedBox(height: 20),

                      // Subtasks
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildInputLabel('Subtasks'),
                          IconButton(
                            iconSize: 24,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              setModalState(() {
                                _subtasksControllers
                                    .add(TextEditingController());
                                _subtasksFocusNodes.add(FocusNode());
                              });
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                FocusScope.of(context)
                                    .requestFocus(_subtasksFocusNodes.last);
                              });
                            },
                            icon: Icon(Icons.add_circle_outline_rounded,
                                color: Colors.blue[400]),
                          ),
                        ],
                      ),
                      if (_subtasksControllers.isNotEmpty)
                        ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _subtasksControllers.length,
                          onReorder: (oldIndex, newIndex) {
                            setModalState(() {
                              if (newIndex > oldIndex) newIndex -= 1;
                              final controller =
                                  _subtasksControllers.removeAt(oldIndex);
                              final focusNode =
                                  _subtasksFocusNodes.removeAt(oldIndex);
                              _subtasksControllers.insert(newIndex, controller);
                              _subtasksFocusNodes.insert(newIndex, focusNode);
                            });
                          },
                          itemBuilder: (context, index) {
                            return Container(
                              key: ValueKey(_subtasksControllers[index]),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(12.0),
                                border: Border.all(
                                    color: Colors.grey[300]!, width: 1.0),
                              ),
                              child: Row(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(left: 12.0),
                                    child: Icon(Icons.drag_handle_rounded,
                                        color: Colors.grey[400], size: 20),
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: _subtasksControllers[index],
                                      focusNode: _subtasksFocusNodes[index],
                                      style: const TextStyle(fontSize: 15),
                                      decoration: InputDecoration(
                                        hintText: 'Enter subtask',
                                        hintStyle: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 15),
                                        border: InputBorder.none,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 14),
                                      ),
                                      onSubmitted: (value) {
                                        if (index <
                                            _subtasksControllers.length - 1) {
                                          FocusScope.of(context).requestFocus(
                                              _subtasksFocusNodes[index + 1]);
                                        } else if (value.isNotEmpty) {
                                          // Only add new if current is not empty
                                          setModalState(() {
                                            _subtasksControllers
                                                .add(TextEditingController());
                                            _subtasksFocusNodes
                                                .add(FocusNode());
                                          });
                                          WidgetsBinding.instance
                                              .addPostFrameCallback((_) {
                                            FocusScope.of(context).requestFocus(
                                                _subtasksFocusNodes.last);
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                        Icons.remove_circle_outline_rounded,
                                        color: Colors.red[300],
                                        size: 20),
                                    onPressed: () {
                                      setModalState(() {
                                        _subtasksControllers[index].dispose();
                                        _subtasksFocusNodes[index].dispose();
                                        _subtasksControllers.removeAt(index);
                                        _subtasksFocusNodes.removeAt(index);
                                      });
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      if (_subtasksControllers.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text("No subtasks added.",
                                style: TextStyle(color: Colors.grey[500])),
                          ),
                        ),
                      const SizedBox(height: 20),

                      // Priority Dropdown
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Label and Help Icon Row
                          Row(
                            children: [
                              Text(
                                'Priority',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              // const SizedBox(width: 2),
                              IconButton(
                                icon: Icon(Icons.help_outline_rounded,
                                    color: Colors.grey[500], size: 13),
                                onPressed: () {
                                  // This function (defined below) will show the help dialog
                                  _showPriorityInfoDialog(context);
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'What do the priorities mean?',
                              ),
                            ],
                          ),

                          // Your Original Dropdown Container (no changes inside)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal:
                                    0), // Let DropdownButton handle padding
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(12.0),
                              border: Border.all(
                                  color: Colors.grey[300]!, width: 1.0),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedPriority,
                                isExpanded: true,
                                icon: Padding(
                                  padding: const EdgeInsets.only(right: 12.0),
                                  child: Icon(Icons.arrow_drop_down_rounded,
                                      color: Colors.grey[600]),
                                ),
                                borderRadius: BorderRadius.circular(12.0),
                                items: ['High', 'Medium', 'Low', 'None']
                                    .map((String value) {
                                  Color priorityColor = value == 'High'
                                      ? Colors.red[400]!
                                      : value == 'Medium'
                                          ? Colors.orange[400]!
                                          : value == 'Low'
                                              ? Colors.green[400]!
                                              : Colors.grey[400]!;
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                          left:
                                              16.0), // Match TextField prefix padding
                                      child: Row(
                                        children: [
                                          Icon(Icons.flag_rounded,
                                              color: priorityColor, size: 20),
                                          const SizedBox(width: 12),
                                          Text(
                                            value,
                                            style: TextStyle(
                                                color: Colors.grey[800],
                                                fontSize: 15),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  // Assuming this is inside a StatefulWidget and you have access to setState
                                  // Or setModalState if you are in a modal bottom sheet.
                                  setState(() {
                                    // Or your setModalState
                                    _selectedPriority = newValue!;
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Date and Time Picker
                      _buildInputLabel('Date & Time'),
                      InkWell(
                        onTap: () => _pickDateTime(context),
                        borderRadius: BorderRadius.circular(12.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 15),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(12.0),
                            border: Border.all(
                                color: Colors.grey[300]!, width: 1.0),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_rounded,
                                  color: Colors.blue[400], size: 20),
                              const SizedBox(width: 12),
                              Text(
                                _selectedDateTime == null
                                    ? 'Select date and time'
                                    : DateFormat('MMM dd, yyyy - HH:mm')
                                        .format(_selectedDateTime!),
                                style: TextStyle(
                                  fontSize: 15,
                                  color: _selectedDateTime == null
                                      ? Colors.grey[400]
                                      : Colors.grey[900],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Repeat Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildInputLabel('Repeat Task'),
                          Transform.scale(
                            scale: 0.85,
                            alignment: Alignment.centerRight,
                            child: Switch(
                              value: _isRepeatEnabled,
                              onChanged: (bool value) {
                                setModalState(() {
                                  _isRepeatEnabled = value;
                                  if (!value) {
                                    _repeatedIntervalTime = 0;
                                  } else {
                                    _repeatedIntervalTime =
                                        1; // Default to 1 when enabled
                                  }
                                });
                              },
                              activeColor: Colors.blue[400],
                              inactiveTrackColor: Colors.grey[300],
                            ),
                          ),
                        ],
                      ),
                      if (_isRepeatEnabled) ...[
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  focusNode: _intervalSelectorFocusNode,
                                  borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(12),
                                      topRight: Radius.circular(12)),
                                  onTap: () async {
                                    _intervalSelectorFocusNode.requestFocus();
                                    final result =
                                        await showModalBottomSheet<String>(
                                      context: context,
                                      backgroundColor: Colors.transparent,
                                      builder: (context) =>
                                          _buildIntervalPicker(),
                                    );
                                    if (result != null) {
                                      setModalState(() =>
                                          _selectedRepeatInterval = result);
                                    }
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.blue[50],
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Icon(
                                              _getIntervalIcon(
                                                  _selectedRepeatInterval),
                                              color: Colors.blue[400],
                                              size: 22),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text('Repeat Interval',
                                                  style: TextStyle(
                                                      color: Colors.grey[600],
                                                      fontSize: 13)),
                                              const SizedBox(height: 2),
                                              Text(_selectedRepeatInterval,
                                                  style: const TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w500)),
                                            ],
                                          ),
                                        ),
                                        Icon(Icons.chevron_right_rounded,
                                            color: Colors.grey[400]),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              if (_selectedRepeatInterval == 'Weekly') ...[
                                Divider(height: 1, color: Colors.grey[200]),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.blue[50],
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Icon(
                                                Icons
                                                    .calendar_view_week_rounded,
                                                color: Colors.blue[400],
                                                size: 22),
                                          ),
                                          const SizedBox(width: 16),
                                          Text('Repeat on',
                                              style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 13)),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: List.generate(
                                              7,
                                              (i) => Padding(
                                                    padding: EdgeInsets.only(
                                                        right: i < 6 ? 6.0 : 0),
                                                    child: WeekdayButton(
                                                      day: i,
                                                      isSelected:
                                                          _selectedWeekdays
                                                              .contains(i),
                                                      onToggle: (selected) {
                                                        setModalState(() {
                                                          if (selected)
                                                            _selectedWeekdays
                                                                .add(i);
                                                          else
                                                            _selectedWeekdays
                                                                .remove(i);
                                                        });
                                                      },
                                                    ),
                                                  )),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              Divider(height: 1, color: Colors.grey[200]),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[50],
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(Icons.repeat_rounded,
                                          color: Colors.blue[400], size: 22),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('Number of Times',
                                              style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 13)),
                                          const SizedBox(height: 2),
                                          Text(
                                            '$_repeatedIntervalTime time${_repeatedIntervalTime == 1 ? '' : 's'}',
                                            style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        NumberButton(
                                          icon: Icons.remove_rounded,
                                          onPressed: _repeatedIntervalTime >
                                                  (_selectedRepeatInterval ==
                                                              'Weekly' &&
                                                          _selectedWeekdays
                                                              .isEmpty
                                                      ? 0
                                                      : 1) // Allow 0 if weekly and no days selected
                                              ? () => setModalState(
                                                  () => _repeatedIntervalTime--)
                                              : null,
                                        ),
                                        const SizedBox(width: 12),
                                        NumberButton(
                                          icon: Icons.add_rounded,
                                          onPressed: _repeatedIntervalTime <
                                                  _getMaxInterval(
                                                      _selectedRepeatInterval)
                                              ? () => setModalState(
                                                  () => _repeatedIntervalTime++)
                                              : null,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),

                      // Category Selector
                      _buildInputLabel('Category'),
                      SizedBox(
                        height: 42,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          children: [
                            'Work',
                            'Personal',
                            'Entertainment',
                            'Health',
                            'Other'
                          ].map((category) {
                            bool isSelected = _selectedCategory == category;
                            IconData categoryIcon;
                            Color categoryColor;
                            switch (category) {
                              case 'Work':
                                categoryIcon = Icons.work_outline_rounded;
                                categoryColor = const Color(0xFF3F8CFF);
                                break;
                              case 'Personal':
                                categoryIcon = Icons.person_outline_rounded;
                                categoryColor = const Color(0xFFFF6B6B);
                                break;
                              case 'Entertainment':
                                categoryIcon = Icons.movie_outlined;
                                categoryColor = const Color(0xFFFFB347);
                                break;
                              case 'Health':
                                categoryIcon = Icons.monitor_heart_outlined;
                                categoryColor = const Color(0xFF4ECB71);
                                break;
                              default:
                                categoryIcon = Icons.category_outlined;
                                categoryColor = const Color(0xFFA78BFA);
                                break;
                            }
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: InkWell(
                                onTap: () => setModalState(
                                    () => _selectedCategory = category),
                                borderRadius: BorderRadius.circular(20),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeInOut,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? categoryColor
                                        : Colors.white.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected
                                          ? categoryColor
                                          : Colors.grey[300]!,
                                      width: 1.2,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: categoryColor
                                                  .withOpacity(0.3),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            )
                                          ]
                                        : [],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(categoryIcon,
                                          size: 18,
                                          color: isSelected
                                              ? Colors.white
                                              : categoryColor),
                                      const SizedBox(width: 6),
                                      Text(
                                        category,
                                        style: TextStyle(
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.grey[700],
                                          fontWeight: isSelected
                                              ? FontWeight.w500
                                              : FontWeight.w400,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Location Input
                      _buildInputLabel('Location'),
                      Container(
                        // Wrap GooglePlaceAutoCompleteTextField for consistent border if needed
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12.0),
                          border:
                              Border.all(color: Colors.grey[300]!, width: 1.0),
                        ),
                        child: GooglePlaceAutoCompleteTextField(
                          textEditingController: _placeURLController,
                          focusNode: _locationFocusNode,
                          textStyle:
                              TextStyle(color: Colors.grey[800], fontSize: 15),
                          inputDecoration: _styledInputDecoration(
                            hintText: 'Search for a place',
                            prefixIcon: const Icon(Icons.location_on_outlined),
                          ).copyWith(
                            // Remove borders from here as container provides it
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            fillColor: Colors
                                .transparent, // Make transparent to use container's color
                          ),
                          googleAPIKey: GOOGLE_API,
                          debounceTime: 600,
                          countries: const ["my"],
                          itemClick: (Prediction prediction) {
                            _placeURLController.text =
                                prediction.description ?? "";
                            _placeURLController.selection =
                                TextSelection.fromPosition(
                              TextPosition(
                                  offset: prediction.description?.length ?? 0),
                            );
                            String placeName =
                                Uri.encodeComponent(prediction.description!);
                            googleMapsUrl =
                                "https://www.google.com/maps/search/?api=1&query=$placeName&place_id=${prediction.placeId}";
                            _locationFocusNode.unfocus();
                            setModalState(() {});
                          },
                          itemBuilder: (context, index, Prediction prediction) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Icon(Icons.place_outlined,
                                      size: 20, color: Colors.grey[600]),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      prediction.description ?? "",
                                      style: TextStyle(
                                          fontSize: 15,
                                          color: Colors.grey[800]),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          seperatedBuilder: Divider(
                              height: 1,
                              thickness: 0.5,
                              color: Colors.grey[200]),
                          isCrossBtnShown: true,
                          containerHorizontalPadding: 0,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // URL Input
                      _buildInputLabel('URL (Optional)'),
                      TextField(
                        controller: _urlController,
                        style: const TextStyle(fontSize: 15),
                        decoration: _styledInputDecoration(
                          hintText: 'e.g., https://example.com',
                          prefixIcon: const Icon(Icons.link_rounded),
                        ),
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 20),

                      // File Attachments
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildInputLabel('Attachments'),
                          IconButton(
                            iconSize: 24,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () async {
                              FilePickerResult? result =
                                  await FilePicker.platform.pickFiles(
                                type: FileType.custom,
                                allowedExtensions: [
                                  'pdf',
                                  'png',
                                  'jpg',
                                  'jpeg',
                                  'doc',
                                  'docx'
                                ],
                                allowMultiple: true,
                              );
                              if (result != null) {
                                setModalState(() {
                                  _selectedFiles.addAll(
                                    result.paths
                                        .map((path) => File(path!))
                                        .toList(),
                                  );
                                });
                              }
                            },
                            icon: Icon(Icons.attach_file_rounded,
                                color: Colors.blue[400]),
                          ),
                        ],
                      ),
                      if (_selectedFiles.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _selectedFiles.length,
                            itemBuilder: (context, index) {
                              final file = _selectedFiles[index];
                              final fileName = file.path.split('/').last;
                              final fileExtension =
                                  fileName.split('.').last.toLowerCase();
                              IconData fileIcon;
                              if (['jpg', 'jpeg', 'png']
                                  .contains(fileExtension))
                                fileIcon = Icons.image_outlined;
                              else if (fileExtension == 'pdf')
                                fileIcon = Icons.picture_as_pdf_outlined;
                              else
                                fileIcon = Icons.insert_drive_file_outlined;

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 6),
                                child: Row(
                                  children: [
                                    Icon(fileIcon,
                                        color: Colors.grey[600], size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        fileName,
                                        style: TextStyle(
                                            color: Colors.grey[800],
                                            fontSize: 14),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.close_rounded,
                                          color: Colors.red[300], size: 20),
                                      onPressed: () => setModalState(
                                          () => _selectedFiles.removeAt(index)),
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(4),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      if (_selectedFiles.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text("No attachments added.",
                                style: TextStyle(color: Colors.grey[500])),
                          ),
                        ),
                      const SizedBox(height: 28),

                      // Submit Button
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (_titleController.text.isEmpty) {
                              ErrorToast.show(context,
                                  'Please enter a title for the schedule.');
                              return;
                            }
                            if (_selectedDateTime == null) {
                              ErrorToast.show(
                                  context, 'Please select a date and time.');
                              return;
                            }
                            if (_isRepeatEnabled &&
                                _selectedRepeatInterval == 'Weekly' &&
                                _selectedWeekdays.isEmpty) {
                              ErrorToast.show(context,
                                  'Please select at least one day for weekly repeat or disable repeat.');
                              return;
                            }
                            if (_isRepeatEnabled && _repeatedIntervalTime < 1) {
                              ErrorToast.show(context,
                                  'Number of repeat times must be at least 1.');
                              return;
                            }

                            String title = TextCleaner.removeDateAndTime(
                                _titleController.text);
                            String category = _selectedCategory;
                            String url = _urlController.text;
                            String placeURL =
                                googleMapsUrl; // Use the one generated from Google Places
                            DateTime time = _selectedDateTime!;
                            List<String> subtasks = _subtasksControllers
                                .map((controller) => controller.text.trim())
                                .where((text) => text.isNotEmpty)
                                .toList();

                            String repeatIntervalToSend =
                                _selectedRepeatInterval;
                            if (_isRepeatEnabled &&
                                _selectedRepeatInterval == 'Weekly' &&
                                _selectedWeekdays.isNotEmpty) {
                              repeatIntervalToSend =
                                  'Weekly,${_selectedWeekdays.map((day) => (day % 7)).join(',')}';
                            }

                            final scheduleService = ScheduleService();
                            final conflicts = await scheduleService
                                .getConflictTasks(newTaskTime: time);

                            if (conflicts.isNotEmpty) {
                              bool shouldProceed =
                                  await _showConflictSuggestionDialog(
                                      context, time, conflicts);
                              if (!shouldProceed) return;
                            }
                            // After conflict resolution, _selectedDateTime might have changed.
                            // Re-assign 'time' to ensure the latest selected time is used.
                            time = _selectedDateTime!;

                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (BuildContext context) => Dialog(
                                backgroundColor: Colors.transparent,
                                elevation: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4))
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                            color: Colors.blue[50],
                                            shape: BoxShape.circle),
                                        child: Icon(
                                            Icons.schedule_send_outlined,
                                            color: Colors.blue[400],
                                            size: 32),
                                      ),
                                      const SizedBox(height: 20),
                                      SizedBox(
                                          width: 40,
                                          height: 40,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 3,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Colors.blue[400]!))),
                                      const SizedBox(height: 20),
                                      const Text('Adding Schedule',
                                          style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w500)),
                                      const SizedBox(height: 8),
                                      const Text('Please wait...',
                                          style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey)),
                                    ],
                                  ),
                                ),
                              ),
                            );

                            try {
                              await widget.onAddSchedule(
                                title, category, url, placeURL, time, subtasks,
                                _selectedPriority, _isRepeatEnabled,
                                _isRepeatEnabled
                                    ? repeatIntervalToSend
                                    : _selectedRepeatInterval, // Send formatted or default
                                _isRepeatEnabled
                                    ? _repeatedIntervalTime
                                    : 0, // Send 0 if not enabled
                                _selectedFiles,
                              );
                              Navigator.of(context, rootNavigator: true)
                                  .pop(); // Close loading dialog
                              SuccessToast.show(
                                  context, 'Schedule added successfully');
                              Navigator.pop(
                                  context); // Close modal bottom sheet
                            } catch (e) {
                              Navigator.of(context, rootNavigator: true)
                                  .pop(); // Close loading dialog
                              ErrorToast.show(
                                  context, 'Failed to save schedule: $e');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[400],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                            shadowColor: Colors.blue[200],
                          ),
                          child: const Text(
                            'Add Schedule',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(
                          height: 10), // Ensure some padding at the very bottom
                    ],
                  ),
                ),
              ),
            ],
          ),
        ]);
      },
    );
  }

  Widget _buildIntervalPicker() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          ),
          ...[
            'Daily',
            'Weekly',
            'Monthly',
            'Yearly'
          ].map((interval) => Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: Icon(_getIntervalIcon(interval),
                      color: Colors.blue[400], size: 22),
                  title: Text(interval, style: const TextStyle(fontSize: 15)),
                  trailing: _selectedRepeatInterval == interval
                      ? Icon(Icons.check_circle_rounded,
                          color: Colors.blue[400], size: 22)
                      : null,
                  onTap: () => Navigator.pop(context, interval),
                ),
              )),
          const SizedBox(height: 16), // Padding at bottom of picker
        ],
      ),
    );
  }

  IconData _getIntervalIcon(String interval) {
    switch (interval) {
      case 'Daily':
        return Icons.today_rounded;
      case 'Weekly':
        return Icons.view_week_rounded;
      case 'Monthly':
        return Icons.calendar_view_month_rounded;
      case 'Yearly':
        return Icons.event_repeat_rounded;
      default:
        return Icons.event_rounded;
    }
  }

  int _getMaxInterval(String interval) {
    switch (interval) {
      case 'Daily':
        return 60;
      case 'Weekly':
        return 52; // Max weeks in a year
      case 'Monthly':
        return 24; // Max 2 years
      case 'Yearly':
        return 10; // Max 10 years
      default:
        return 1;
    }
  }
}
