import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:intl/intl.dart';
import 'package:planit_schedule_manager/const.dart';
import 'package:planit_schedule_manager/models/subtask.dart';
import 'package:planit_schedule_manager/models/task_file.dart';
import 'package:planit_schedule_manager/services/file_upload_service.dart';
import 'package:planit_schedule_manager/widgets/in_app_viewer.dart';
import 'package:planit_schedule_manager/widgets/repeat_task_widget.dart';
import 'package:uuid/uuid.dart';

class EditScheduleSheet extends StatefulWidget {
  final String taskId;
  final TextEditingController titleController;
  final TextEditingController urlController;
  final TextEditingController placeUrlController;

  final String selectedCategory;
  final DateTime selectedDateTime;
  final String priority;
  final bool isRepeatEnabled;
  final String selectedRepeatInterval;
  final int repeatedIntervalTime;
  final List<SubTask> subtasks;
  final List<TaskFile> files;

  // final Function(StateSetter) buildCategorySelector;
  final Function(String, String, String, String, DateTime, String, bool, String,
      int, List<SubTask>, List<TaskFile>) onUpdate;

  const EditScheduleSheet({
    super.key,
    required this.taskId,
    required this.titleController,
    required this.urlController,
    required this.placeUrlController,
    required this.selectedCategory,
    required this.selectedDateTime,
    required this.priority,
    required this.isRepeatEnabled,
    required this.selectedRepeatInterval,
    required this.repeatedIntervalTime,
    // required this.buildCategorySelector,
    required this.subtasks,
    required this.files,
    required this.onUpdate,
  });

  @override
  State<EditScheduleSheet> createState() => _EditScheduleSheetState();
}

class _EditScheduleSheetState extends State<EditScheduleSheet> {
  late String _selectedCategory;
  late DateTime _selectedDateTime;
  late String _selectedPriority;
  late bool _isRepeatEnabled;
  late String _selectedRepeatInterval;
  late int _repeatedIntervalTime;
  late List<SubTask> _subtasks;
  late List<TaskFile> _files;

  final TextEditingController _locationController = TextEditingController();
  final FocusNode _locationFocusNode = FocusNode();
  final FocusNode _intervalSelectorFocusNode = FocusNode();

  final FileUploadService _fileUploadService = FileUploadService();
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.selectedCategory;
    _selectedDateTime = widget.selectedDateTime;
    _selectedPriority = widget.priority.toUpperCase();
    _isRepeatEnabled = widget.isRepeatEnabled;
    _selectedRepeatInterval = widget.selectedRepeatInterval;
    _repeatedIntervalTime = widget.repeatedIntervalTime;
    _locationController.text = widget.placeUrlController.text;
    _subtasks = List.from(widget.subtasks);
    _files = List.from(widget.files);
    // _subtasks = widget.subtasks;
  }

  Future<void> _updateFirestoreFiles() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('schedules')
          .doc(widget.taskId)
          .update({
        'files': _files
            .map((f) => {
                  'id': f.id,
                  'name': f.name,
                  'url': f.url,
                  'type': f.type,
                  'uploadedAt': Timestamp.fromDate(f.uploadedAt),
                })
            .toList(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: StatefulBuilder(
        builder: (context, setModalState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.edit_calendar,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Edit Schedule',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 32),
              // Form Content
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                    left: 24,
                    right: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 10),
                      _buildInputField(
                        controller: widget.titleController,
                        label: 'Schedule Title',
                        icon: Icons.title,
                        required: true,
                        maxLines: null,
                      ),
                      const SizedBox(height: 20),
                      _buildSubtasksSection(context, setModalState),
                      const SizedBox(height: 20),
                      _buildDateTimePicker(context, setModalState),
                      const SizedBox(height: 20),
                      _buildCategorySection(context, setModalState),
                      const SizedBox(height: 20),
                      _buildPrioritySection(context, setModalState),
                      const SizedBox(height: 20),
                      _buildRepeatSection(context, setModalState),
                      const SizedBox(height: 20),
                      _buildInputField(
                        controller: widget.urlController,
                        label: 'URL (Optional)',
                        icon: Icons.link,
                        keyboardType: TextInputType.url,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 20),
                      _buildLocationField(),
                      const SizedBox(height: 20),
                      _buildFileManagementSection(context, setModalState),
                      const SizedBox(height: 24),
                      _buildActionButtons(context, setModalState),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool required = false,
    TextInputType? keyboardType,
    int? maxLines, // Add maxLines parameter to control the number of lines
  }) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType:
            keyboardType ?? TextInputType.multiline, // Set multiline by default
        maxLines:
            maxLines, // Set maxLines to control line count, null for unlimited
        textInputAction: TextInputAction
            .newline, // Adjust text input action for multi-line support
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: required
              ? const Icon(Icons.star, size: 8, color: Colors.red)
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(
              color: Colors.blue.shade300,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubtasksSection(
      BuildContext context, StateSetter setModalState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Subtasks',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            IconButton(
              icon: Icon(Icons.add, color: Theme.of(context).primaryColor),
              onPressed: () {
                setModalState(() {
                  _subtasks.add(SubTask(
                    id: DateTime.now().toString(),
                    title: '',
                    isDone: false,
                  ));
                });
              },
            ),
          ],
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _subtasks.length,
          itemBuilder: (context, index) {
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: _subtasks[index].isDone,
                    onChanged: (bool? value) {
                      setModalState(() {
                        _subtasks[index].isDone = value ?? false;
                        _subtasks[index].completedAt =
                            value == true ? DateTime.now() : null;
                      });
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: TextEditingController(
                          text: _subtasks[index].title)
                        ..selection = TextSelection.fromPosition(
                          TextPosition(offset: _subtasks[index].title.length),
                        ),
                      onChanged: (value) {
                        _subtasks[index].title = value;
                      },
                      decoration: const InputDecoration(
                        hintText: 'Enter subtask',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setModalState(() {
                        _subtasks.removeAt(index);
                      });
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDateTimePicker(BuildContext context, StateSetter setModalState) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: widget.selectedDateTime,
              firstDate: DateTime(2000),
              lastDate: DateTime(2101),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.light(
                      primary: Theme.of(context).primaryColor,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              final TimeOfDay? timePicked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: ColorScheme.light(
                        primary: Theme.of(context).primaryColor,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (timePicked != null) {
                setModalState(() {
                  // Create a new DateTime combining the picked date and time
                  _selectedDateTime = DateTime(
                    picked.year,
                    picked.month,
                    picked.day,
                    timePicked.hour,
                    timePicked.minute,
                  );
                });
              }
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: Row(
              children: [
                Icon(Icons.calendar_today,
                    color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Date and Time',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMM dd, yyyy - HH:mm')
                          .format(_selectedDateTime),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Icon(Icons.arrow_forward_ios,
                    size: 16, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySection(
      BuildContext context, StateSetter setModalState) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Category',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    'Work',
                    'Personal',
                    'Health',
                    'Entertainment',
                    'Other'
                  ].map((category) {
                    return ChoiceChip(
                      label: Text(category),
                      selected: _selectedCategory == category,
                      onSelected: (selected) {
                        setModalState(() {
                          _selectedCategory =
                              selected ? category : _selectedCategory;
                        });
                      },
                      selectedColor: Theme.of(context).primaryColor,
                      backgroundColor: Colors.grey[200],
                      labelStyle: TextStyle(
                        color: _selectedCategory == category
                            ? Colors.white
                            : Colors.black87,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Location',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            // Unfocus other fields first
            FocusScope.of(context).unfocus();
            // Then request focus for the location field
            _locationFocusNode.requestFocus();
          },
          child: GooglePlaceAutoCompleteTextField(
            textEditingController: _locationController,
            focusNode: _locationFocusNode,
            inputDecoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              hintText: 'Enter Place',
              hintStyle: TextStyle(color: Colors.grey[400]),
              prefixIcon:
                  Icon(Icons.location_on_outlined, color: Colors.grey[400]),
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            googleAPIKey: GOOGLE_API, // Replace with your Google API key
            debounceTime: 800,
            countries: ["my"], // Malaysia
            itemClick: (Prediction prediction) {
              _locationController.text = prediction.description!;
              _locationController.selection = TextSelection.fromPosition(
                TextPosition(offset: prediction.description!.length),
              );

              String placeName = Uri.encodeComponent(prediction.description!);
              String googleMapsUrl =
                  "https://www.google.com/maps/search/?api=1&query=$placeName&place_id=${prediction.placeId}";

              print("Google Maps URL: $googleMapsUrl");

              widget.placeUrlController.text = googleMapsUrl;

              setState(() {});
            },
            itemBuilder: (context, index, Prediction prediction) {
              return Container(
                padding: EdgeInsets.all(10),
                child: Row(
                  children: [
                    Icon(Icons.location_on),
                    SizedBox(width: 7),
                    Expanded(child: Text(prediction.description ?? "")),
                  ],
                ),
              );
            },
            seperatedBuilder: Divider(),
            isCrossBtnShown: true,
            containerHorizontalPadding: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildPrioritySection(
      BuildContext context, StateSetter setModalState) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Priority',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['HIGH', 'MEDIUM', 'LOW', "NONE"].map((priority) {
                    return ChoiceChip(
                      label: Text(priority),
                      selected: _selectedPriority == priority.toUpperCase(),
                      onSelected: (selected) {
                        if (selected) {
                          setModalState(() {
                            _selectedPriority = priority.toUpperCase();
                          });
                        }
                      },
                      selectedColor: priority == 'HIGH'
                          ? Colors.red[400]
                          : priority == 'MEDIUM'
                              ? Colors.orange[400]
                              : priority == 'LOW'
                                  ? Colors.green[400]
                                  : Colors.grey[200],
                      backgroundColor: Colors.grey[200],
                      labelStyle: TextStyle(
                        color: widget.priority == priority
                            ? Colors.white
                            : Colors.black87,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRepeatSection(BuildContext context, StateSetter setModalState) {
    // Initialize weekdays if the interval is weekly
    final List<int> selectedWeekdays =
        _selectedRepeatInterval.startsWith('Weekly')
            ? _selectedRepeatInterval
                .split(',')
                .skip(1)
                .map((e) => int.parse(e))
                .toList()
            : [];

    _repeatedIntervalTime = _repeatedIntervalTime ?? 1;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Repeat Toggle Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.repeat,
                    color: Theme.of(context).primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Repeat',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isRepeatEnabled ? 'Enabled' : 'Disabled',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isRepeatEnabled,
                  onChanged: (value) {
                    setModalState(() {
                      _isRepeatEnabled = value;
                      if (value && _selectedRepeatInterval.isEmpty) {
                        _selectedRepeatInterval = 'Daily';
                      }
                    });
                  },
                  activeColor: Theme.of(context).primaryColor,
                ),
              ],
            ),
          ),

          if (_isRepeatEnabled) ...[
            const Divider(height: 1),
            // Interval Selection
            Material(
              color: Colors.transparent,
              child: InkWell(
                focusNode: _intervalSelectorFocusNode, 
                onTap: () {
                  _intervalSelectorFocusNode.requestFocus();
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (context) => Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20)),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: ['Daily', 'Weekly', 'Monthly', 'Yearly']
                                .map((interval) {
                              return ChoiceChip(
                                label: Text(interval),
                                selected: _selectedRepeatInterval
                                    .startsWith(interval),
                                onSelected: (selected) {
                                  if (selected) {
                                    setModalState(() {
                                      _selectedRepeatInterval = interval;
                                      if (interval == 'Weekly') {
                                        _selectedRepeatInterval = 'Weekly,1';
                                      }
                                      _repeatedIntervalTime = 1;
                                    });
                                    Navigator.pop(context);
                                  }
                                },
                                selectedColor: Theme.of(context).primaryColor,
                                backgroundColor: Colors.grey[200],
                                labelStyle: TextStyle(
                                  color: _selectedRepeatInterval
                                          .startsWith(interval)
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.calendar_today,
                          color: Theme.of(context).primaryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Repeat Interval',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectedRepeatInterval.split(',')[0],
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: Colors.grey[400],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Weekday Selection for Weekly Repeat
            if (_selectedRepeatInterval.startsWith('Weekly')) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.calendar_view_week,
                            color: Theme.of(context).primaryColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Repeat on',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (int i = 1; i <= 7; i++)
                            Padding(
                              padding: EdgeInsets.only(
                                right: i < 7 ? 8.0 : 0,
                              ),
                              child: FilterChip(
                                label: Text(_getWeekdayShort(i)),
                                selected: selectedWeekdays.contains(i),
                                onSelected: (selected) {
                                  setModalState(() {
                                    List<int> newWeekdays;
                                    if (selected) {
                                      newWeekdays = [...selectedWeekdays, i]
                                        ..sort();
                                    } else {
                                      newWeekdays = selectedWeekdays
                                          .where((day) => day != i)
                                          .toList();
                                      if (newWeekdays.isEmpty) {
                                        newWeekdays = [i];
                                        return;
                                      }
                                    }
                                    _selectedRepeatInterval =
                                        'Weekly,${newWeekdays.join(',')}';
                                  });
                                },
                                selectedColor: Theme.of(context)
                                    .primaryColor
                                    .withOpacity(0.2),
                                checkmarkColor: Theme.of(context).primaryColor,
                                backgroundColor: Colors.grey[200],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const Divider(height: 1),
            // Number of Repetitions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.repeat,
                      color: Theme.of(context).primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Number of Times',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$_repeatedIntervalTime time${_repeatedIntervalTime == 1 ? '' : 's'}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      NumberButton(
                        icon: Icons.remove,
                        onPressed: _repeatedIntervalTime > 1
                            ? () => setModalState(() => _repeatedIntervalTime--)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      NumberButton(
                        icon: Icons.add,
                        onPressed: _repeatedIntervalTime <
                                _getMaxInterval(_selectedRepeatInterval)
                            ? () => setModalState(() => _repeatedIntervalTime++)
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

// Helper function to get weekday short name
  String _getWeekdayShort(int day) {
    return switch (day) {
      1 => 'Mon',
      2 => 'Tue',
      3 => 'Wed',
      4 => 'Thu',
      5 => 'Fri',
      6 => 'Sat',
      7 => 'Sun',
      _ => '',
    };
  }

// Helper function to get maximum interval based on repeat type
  int _getMaxInterval(String interval) {
    return switch (interval.split(',')[0]) {
      'Daily' => 60,
      'Weekly' => 20,
      'Monthly' => 20,
      _ => 10,
    };
  }

  Widget _buildFileManagementSection(
      BuildContext context, StateSetter setModalState) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.attachment,
                    size: 20,
                    color: Colors.grey[600],
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Attachments',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                icon: Icon(
                  Icons.add_circle_outline,
                  size: 18,
                  color: Theme.of(context).primaryColor,
                ),
                label: Text(
                  'Add File',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                onPressed: () async {
                  try {
                    FilePickerResult? result =
                        await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: [
                        'jpg',
                        'jpeg',
                        'png',
                        'pdf',
                        'doc',
                        'docx'
                      ],
                    );

                    if (result != null && result.files.first.path != null) {
                      setModalState(() {
                        _isUploading = true;
                      });

                      PlatformFile pickedFile = result.files.first;
                      File file = File(pickedFile.path!);
                      String fileType =
                          _getFileType(pickedFile.extension ?? '');

                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (BuildContext context) {
                          return Dialog(
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
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              constraints: const BoxConstraints(maxWidth: 320),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Upload Icon
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.cloud_upload_rounded,
                                      color: Colors.blue,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // Loading Indicator
                                  const SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.blue),
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // Upload Text
                                  Text(
                                    'Uploading ${pickedFile.name}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Please wait while we process your file...',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );

                      // Upload to Firebase Storage
                      String downloadUrl = await _fileUploadService.uploadFile(
                        file,
                        widget.taskId,
                      );

                      // Create new TaskFile with the download URL
                      TaskFile newFile = TaskFile(
                        id: const Uuid().v4(),
                        name: pickedFile.name,
                        url: downloadUrl,
                        type: fileType,
                        uploadedAt: DateTime.now(),
                      );

                      Navigator.of(context, rootNavigator: true).pop();

                      setModalState(() {
                        _files.add(newFile);
                        _isUploading = false;
                      });

                      // Update Firestore
                      await _updateFirestoreFiles();
                    }
                  } catch (e) {
                    setModalState(() {
                      _isUploading = false;
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error uploading file: $e'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          SizedBox(height: 12),
          if (_files.isEmpty)
            Container(
              padding: EdgeInsets.symmetric(vertical: 24),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey[200]!,
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.attachment_outlined,
                    color: Colors.grey[400],
                    size: 32,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'No attachments yet',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Tap "Add File" to attach documents',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _files.length,
              separatorBuilder: (context, index) => SizedBox(height: 8),
              itemBuilder: (context, index) {
                return Dismissible(
                  key: Key(_files[index].id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.centerRight,
                    padding: EdgeInsets.only(right: 20),
                    child: Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                    ),
                  ),
                  onDismissed: (direction) async {
                    final deleteFile = _files[index];
                    final deletedIndex = index;

                    try {
                      setModalState(() {
                        _files.removeAt(index);
                      });

                      if (deleteFile.url.startsWith('http')) {
                        await _fileUploadService.deleteFile(deleteFile.url);
                      }

                      await _updateFirestoreFiles();
                    } catch (e) {
                      print(e.toString());

                      setModalState(() {
                        _files.insert(deletedIndex, deleteFile);
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error deleting file'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: _buildFileCard(_files[index]),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFileCard(TaskFile file) {
    IconData getFileIcon(String type) {
      switch (type) {
        case 'image':
          return Icons.image_rounded;
        case 'pdf':
          return Icons.picture_as_pdf_rounded;
        case 'document':
          return Icons.description_rounded;
        default:
          return Icons.insert_drive_file_rounded;
      }
    }

    Color getFileColor(String type) {
      switch (type) {
        case 'image':
          return Colors.purple;
        case 'pdf':
          return Colors.red;
        case 'document':
          return Colors.blue;
        default:
          return Colors.grey;
      }
    }

    final Color fileColor = getFileColor(file.type);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => InAppViewer(
                url: file.url,
                type: file.type,
                title: file.name,
              ),
            ),
          );
        },
        child: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: fileColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: fileColor.withOpacity(0.1),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: fileColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  getFileIcon(file.type),
                  color: fileColor,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[800],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Added ${DateFormat.yMMMd().format(file.uploadedAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: fileColor,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getFileType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
      case 'png':
        return 'image';
      case 'pdf':
        return 'pdf';
      case 'doc':
      case 'docx':
        return 'document';
      default:
        return 'other';
    }
  }

  Widget _buildActionButtons(BuildContext context, StateSetter setModalState) {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: BorderSide(color: Theme.of(context).primaryColor),
              ),
            ),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: () {
              print(_selectedCategory);
              print("Location TEXT: ${widget.placeUrlController.text}");
              if (widget.titleController.text.isNotEmpty) {
                widget.onUpdate(
                    widget.titleController.text,
                    _selectedCategory,
                    widget.urlController.text,
                    widget.placeUrlController.text,
                    // _locationController.text,
                    _selectedDateTime,
                    _selectedPriority,
                    _isRepeatEnabled,
                    _selectedRepeatInterval,
                    _repeatedIntervalTime!,
                    _subtasks,
                    _files);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill all required fields'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Update Schedule',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }
}
