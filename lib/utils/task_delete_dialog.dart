import 'package:flutter/material.dart';
import 'package:planit_schedule_manager/models/task.dart';
import 'package:intl/intl.dart';

class TaskDeleteDialog extends StatefulWidget {
  final List<Task> tasks;
  final Function(List<Task>) onDelete;

  const TaskDeleteDialog({
    super.key, 
    required this.tasks, 
    required this.onDelete
  });

  @override
  State<TaskDeleteDialog> createState() => _TaskDeleteDialogState();
}

class _TaskDeleteDialogState extends State<TaskDeleteDialog> {
  List<Task> _selectedTasks = [];
  bool _isSelectAll = false;

  void _toggleSelectAll(bool? value) {
    setState(() {
      _isSelectAll = value ?? false;
      _selectedTasks = _isSelectAll ? List.from(widget.tasks) : [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.red.shade100, width: 2)
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        constraints: const BoxConstraints(
          maxHeight: 600,
          maxWidth: 450,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white, 
              Colors.red.shade50
            ],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade400,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                )
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Confirm Task Deletion',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            blurRadius: 10.0,
                            color: Colors.black45,
                            offset: Offset(1.0, 1.0),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                ],
              ),
            ),

            // Select All Checkbox
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Checkbox(
                    value: _isSelectAll,
                    onChanged: _toggleSelectAll,
                    activeColor: Colors.red.shade300,
                  ),
                  Text(
                    'Select All Tasks',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),

            // Task List with Animated Tiles
            Expanded(
              child: ListView.builder(
                itemCount: widget.tasks.length,
                itemBuilder: (context, index) {
                  final task = widget.tasks[index];
                  final isSelected = _selectedTasks.contains(task);

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected 
                        ? Colors.red.shade100 
                        : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: isSelected 
                        ? [BoxShadow(
                            color: Colors.red.shade200, 
                            blurRadius: 5,
                            offset: const Offset(0, 3)
                          )]
                        : null,
                    ),
                    child: CheckboxListTile(
                      title: Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.red.shade800 : Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        DateFormat('EEE, MMM d, yyyy • h:mm a').format(task.time),
                        style: const TextStyle(fontSize: 14),
                      ),
                      value: isSelected,
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            _selectedTasks.add(task);
                          } else {
                            _selectedTasks.remove(task);
                          }
                          // Update select all checkbox state
                          _isSelectAll = _selectedTasks.length == widget.tasks.length;
                        });
                      },
                      activeColor: Colors.red.shade300,
                      checkColor: Colors.white,
                    ),
                  );
                },
              ),
            ),

            // Bottom Action Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.red.shade100, width: 1)
                  
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16)
                )
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Selected: ${_selectedTasks.length}/${widget.tasks.length}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _selectedTasks.isEmpty ? null : () {
                      widget.onDelete(_selectedTasks);
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Delete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade400,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}