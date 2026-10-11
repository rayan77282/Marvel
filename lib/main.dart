import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TaskMasterApp());
}

class AppTheme {
  static const Color background = Color(0xFF0D1117);
  static const Color surface = Color(0xFF161B22);
  static const Color surfaceAlt = Color(0xFF21262D);
  static const Color border = Color(0xFF30363D);
  static const Color primary = Color(0xFF1F6FEB);
  static const Color primaryLight = Color(0xFF58A6FF);
  static const Color success = Color(0xFF2EA043);
  static const Color danger = Color(0xFFCF222E);
  static const Color warning = Color(0xFFD29922);
  static const Color textPrimary = Color(0xFFE6EDF3);
  static const Color textMuted = Color(0xFF8B949E);

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.dark(
          primary: primary,
          secondary: primaryLight,
          surface: surface,
          error: danger,
          onPrimary: Colors.white,
          onSurface: textPrimary,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primary,
          foregroundColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceAlt,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: primaryLight, width: 1.5),
          ),
        ),
      );
}

class Task {
  final String id;
  String title;
  bool done;
  final DateTime createdAt;

  Task({
    required this.id,
    required this.title,
    this.done = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'done': done,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'] as String,
        title: json['title'] as String,
        done: json['done'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class TaskMasterApp extends StatelessWidget {
  const TaskMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Marvel',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const TaskHomePage(),
    );
  }
}

enum TaskFilter { all, active, completed }

class TaskHomePage extends StatefulWidget {
  const TaskHomePage({super.key});

  @override
  State<TaskHomePage> createState() => _TaskHomePageState();
}

class _TaskHomePageState extends State<TaskHomePage>
    with SingleTickerProviderStateMixin {
  static const String _storageKey = 'klencod_tasks_v1';

  final List<Task> _tasks = [];
  final TextEditingController _searchController = TextEditingController();
  TaskFilter _filter = TaskFilter.all;
  String _searchQuery = '';
  bool _loading = true;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadTasks();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_storageKey);
      if (data != null && data.isNotEmpty) {
        final list = jsonDecode(data) as List<dynamic>;
        _tasks.clear();
        _tasks.addAll(list.map((e) => Task.fromJson(e as Map<String, dynamic>)));
      }
    } catch (_) {}
    setState(() => _loading = false);
    _fadeController.forward();
  }

  Future<void> _saveTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(_tasks.map((t) => t.toJson()).toList());
      await prefs.setString(_storageKey, data);
    } catch (_) {}
  }

  void _addTask(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _tasks.insert(
        0,
        Task(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: trimmed,
          createdAt: DateTime.now(),
        ),
      );
    });
    _saveTasks();
    HapticFeedback.lightImpact();
    _showSnack('تمت إضافة المهمة', success: true);
  }

  void _toggleTask(Task task) {
    setState(() => task.done = !task.done);
    _saveTasks();
    HapticFeedback.selectionClick();
  }

  void _deleteTask(Task task) {
    final index = _tasks.indexOf(task);
    if (index == -1) return;
    setState(() => _tasks.removeAt(index));
    _saveTasks();
    _showSnack(
      'تم حذف المهمة',
      actionLabel: 'تراجع',
      onAction: () {
        setState(() => _tasks.insert(index, task));
        _saveTasks();
      },
    );
  }

  void _clearCompleted() {
    final completed = _tasks.where((t) => t.done).toList();
    if (completed.isEmpty) {
      _showSnack('لا توجد مهام مكتملة');
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => _buildConfirmDialog(
        ctx,
        title: 'حذف المهام المكتملة',
        message: 'سيتم حذف ${completed.length} مهمة مكتملة. لا يمكن التراجع.',
        onConfirm: () {
          setState(() => _tasks.removeWhere((t) => t.done));
          _saveTasks();
          Navigator.pop(ctx);
          _showSnack('تم حذف ${completed.length} مهمة', success: true);
        },
      ),
    );
  }

  void _showSnack(String message,
      {String? actionLabel, VoidCallback? onAction, bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle_rounded : Icons.info_outline_rounded,
              color: success ? AppTheme.success : AppTheme.textPrimary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.surfaceAlt,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        action: actionLabel != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: AppTheme.primaryLight,
                onPressed: onAction ?? () {},
              )
            : null,
      ),
    );
  }

  Widget _buildConfirmDialog(
    BuildContext ctx, {
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(title, style: const TextStyle(color: AppTheme.textPrimary)),
      content: Text(message, style: const TextStyle(color: AppTheme.textMuted)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('إلغاء',
              style: TextStyle(color: AppTheme.textMuted)),
        ),
        TextButton(
          onPressed: onConfirm,
          child: const Text('تأكيد',
              style: TextStyle(
                  color: AppTheme.danger, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  void _openAddDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: const [
            Icon(Icons.add_task_rounded, color: AppTheme.primaryLight),
            SizedBox(width: 10),
            Text('مهمة جديدة',
                style: TextStyle(color: AppTheme.textPrimary)),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (v) {
            _addTask(v);
            Navigator.pop(ctx);
          },
          decoration: const InputDecoration(
            hintText: 'اكتب المهمة...',
            prefixIcon: Icon(Icons.edit_rounded),
          ),
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء',
                style: TextStyle(color: AppTheme.textMuted)),
          ),
          FilledButton(
            onPressed: () {
              _addTask(controller.text);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  List<Task> get _visibleTasks {
    Iterable<Task> result = _tasks;
    if (_filter == TaskFilter.active) {
      result = result.where((t) => !t.done);
    } else if (_filter == TaskFilter.completed) {
      result = result.where((t) => t.done);
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((t) => t.title.toLowerCase().contains(q));
    }
    return result.toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryLight),
        ),
      );
    }

    final visible = _visibleTasks;
    final total = _tasks.length;
    final completed = _tasks.where((t) => t.done).length;
    final active = total - completed;
    final progress = total == 0 ? 0.0 : completed / total;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Marvel'),
        actions: [
          if (completed > 0)
            IconButton(
              tooltip: 'حذف المكتملة',
              icon: const Icon(Icons.delete_sweep_rounded),
              onPressed: _clearCompleted,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('مهمة جديدة',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          _buildHeader(total, completed, active, progress),
          _buildSearchBar(),
          _buildFilters(total, active, completed),
          Expanded(
            child: visible.isEmpty
                ? _buildEmptyState()
                : _buildTaskList(visible),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int total, int completed, int active, double progress) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1F6FEB), Color(0xFF0D419D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.task_alt_rounded,
                    color: Colors.white, size: 28),
                const SizedBox(width: 10),
                Text(
                  total == 0 ? 'لا توجد مهام بعد' : 'مهامك',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _statChip('الإجمالي', total, Colors.white),
                _statChip('نشطة', active, AppTheme.warning),
                _statChip('مكتملة', completed, AppTheme.success),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 600),
                builder: (_, value, __) => LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  backgroundColor: Colors.white24,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${(progress * 100).toStringAsFixed(0)}% إنجاز',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        style: const TextStyle(color: AppTheme.textPrimary),
        decoration: InputDecoration(
          hintText: 'بحث في المهام...',
          prefixIcon: const Icon(Icons.search_rounded,
              color: AppTheme.textMuted),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded,
                      color: AppTheme.textMuted),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildFilters(int total, int active, int completed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _filterChip('الكل', TaskFilter.all, total),
          const SizedBox(width: 8),
          _filterChip('نشطة', TaskFilter.active, active),
          const SizedBox(width: 8),
          _filterChip('مكتملة', TaskFilter.completed, completed),
        ],
      ),
    );
  }

  Widget _filterChip(String label, TaskFilter filter, int count) {
    final selected = _filter == filter;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filter = filter),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : AppTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppTheme.primaryLight : AppTheme.border,
            ),
          ),
          child: Column(
            children: [
              Text(
                '$count',
                style: TextStyle(
                  color: selected ? Colors.white : AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white70 : AppTheme.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskList(List<Task> visible) {
    return FadeTransition(
      opacity: _fadeController,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
        itemCount: visible.length,
        itemBuilder: (context, index) {
          final task = visible[index];
          return _buildTaskItem(task);
        },
      ),
    );
  }

  Widget _buildTaskItem(Task task) {
    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppTheme.danger,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete_rounded,
            color: Colors.white, size: 26),
      ),
      confirmDismiss: (_) async {
        _deleteTask(task);
        return false;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: task.done
                ? AppTheme.success.withOpacity(0.4)
                : AppTheme.border,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _toggleTask(task),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: task.done
                          ? AppTheme.success
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: task.done
                            ? AppTheme.success
                            : AppTheme.textMuted,
                        width: 2,
                      ),
                    ),
                    child: task.done
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 18)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: TextStyle(
                            color: task.done
                                ? AppTheme.textMuted
                                : AppTheme.textPrimary,
                            fontSize: 15,
                            decoration: task.done
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(task.createdAt),
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'حذف',
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: AppTheme.textMuted),
                    onPressed: () => _deleteTask(task),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inHours < 1) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inDays < 1) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays == 1) return 'أمس';
    return 'منذ ${diff.inDays} يوم';
  }

  Widget _buildEmptyState() {
    final String message;
    final IconData icon;
    if (_searchQuery.isNotEmpty) {
      message = 'لا توجد نتائج للبحث';
      icon = Icons.search_off_rounded;
    } else if (_filter == TaskFilter.completed) {
      message = 'لا توجد مهام مكتملة بعد';
      icon = Icons.check_circle_outline_rounded;
    } else if (_filter == TaskFilter.active) {
      message = 'كل المهام مكتملة!';
      icon = Icons.celebration_rounded;
    } else {
      message = 'ابدأ بإضافة مهمتك الأولى';
      icon = Icons.playlist_add_rounded;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surfaceAlt,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.border),
            ),
            child: Icon(icon, size: 56, color: AppTheme.primaryLight),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'استخدم الزر أدناه للبدء',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>تتبع مشاهدة عالم مارفل - Avengers: Doomsday</title>
    <style>
        :root {
            --bg-dark: #0a1f13;
            --bg-card: #113821;
            --accent-green: #1db954;
            --marvel-red: #ed1d24;
            --text-light: #f0f6f0;
            --text-muted: #a3c1ad;
        }

        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background-color: var(--bg-dark);
            color: var(--text-light);
            margin: 0;
            padding: 20px;
        }

        header {
            text-align: center;
            padding: 20px 0;
            border-bottom: 2px solid var(--accent-green);
            margin-bottom: 30px;
        }

        .marvel-logo {
            font-size: 3rem;
            font-weight: 900;
            background-color: var(--marvel-red);
            color: white;
            display: inline-block;
            padding: 5px 20px;
            letter-spacing: 3px;
            border-radius: 4px;
            box-shadow: 0 4px 15px rgba(237, 29, 36, 0.4);
            margin-bottom: 10px;
        }

        h1 {
            margin: 10px 0 5px;
            font-size: 1.8rem;
        }

        p.subtitle {
            color: var(--text-muted);
            margin: 0;
        }

        .phase-section {
            background-color: var(--bg-card);
            border-radius: 12px;
            padding: 20px;
            margin-bottom: 30px;
            box-shadow: 0 6px 20px rgba(0, 0, 0, 0.4);
            border: 1px solid rgba(29, 185, 84, 0.2);
        }

        .phase-title {
            color: var(--accent-green);
            font-size: 1.5rem;
            border-bottom: 1px solid rgba(29, 185, 84, 0.3);
            padding-bottom: 10px;
            margin-top: 0;
            margin-bottom: 20px;
        }

        .movies-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
            gap: 15px;
        }

        .movie-card {
            background-color: #0d2b19;
            border-radius: 8px;
            overflow: hidden;
            display: flex;
            flex-direction: column;
            border: 1px solid #1c5231;
            transition: transform 0.2s, box-shadow 0.2s;
            position: relative;
        }

        .movie-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 6px 15px rgba(29, 185, 84, 0.25);
        }

        .movie-poster {
            width: 100%;
            height: 280px;
            object-fit: cover;
            background-color: #1a1a1a;
        }

        .movie-info {
            padding: 12px;
            display: flex;
            flex-direction: column;
            flex-grow: 1;
            justify-content: space-between;
        }

        .movie-title {
            font-size: 0.95rem;
            font-weight: 600;
            margin-bottom: 10px;
            line-height: 1.4;
        }

        .watched-checkbox {
            display: flex;
            align-items: center;
            gap: 8px;
            font-size: 0.85rem;
            color: var(--text-muted);
            cursor: pointer;
            user-select: none;
        }

        .watched-checkbox input {
            accent-color: var(--accent-green);
            width: 16px;
            height: 16px;
            cursor: pointer;
        }

        .movie-card.completed {
            opacity: 0.5;
            border-color: #0b2214;
        }
        
        .movie-card.completed .movie-title {
            text-decoration: line-through;
        }
    </style>
</head>
<body>

    <header>
        <div class="marvel-logo">MARVEL</div>
        <h1>خطة متابعة أفلام ومسلسلات Avengers: Doomsday</h1>
        <p class="subtitle">تتبع جدولك الترتيب الكامل خطوة بخطوة</p>
    </header>

    <main id="app-container">
        <!-- سيتم تعبئة المراحل ديناميكياً بواسطة JavaScript -->
    </main>

    <script>
        const phasesData = [
            {
                title: "المرحلة 1",
                movies: [
                    { name: "Iron Man (2008)", poster: "https://image.tmdb.org/t/p/w500/78lPtwv72eTNqFW9COBYI0dWDJa.jpg" },
                    { name: "The Incredible Hulk (2008)", poster: "https://image.tmdb.org/t/p/w500/gKzYx79y0AQTL4UAk1cBQJ3nvQ0.jpg" },
                    { name: "Iron Man II (2010)", poster: "https://image.tmdb.org/t/p/w500/6WBeq4fCfn7AN0o21W9qNcRF2l9.jpg" },
                    { name: "Thor (2011)", poster: "https://image.tmdb.org/t/p/w500/prSfAi1xGrhLQNxVSUFh61xQ4Qy.jpg" },
                    { name: "Captain America: The First Avenger (2011)", poster: "https://image.tmdb.org/t/p/w500/vSNxAJQMDLDMRMYmgz6M1mY4i21.jpg" },
                    { name: "The Avengers (2012)", poster: "https://image.tmdb.org/t/p/w500/RYMX2wcKCBAr24UyPD7xwmjaTn.jpg" }
                ]
            },
            {
                title: "المرحلة 2",
                movies: [
                    { name: "Iron Man III (2013)", poster: "https://image.tmdb.org/t/p/w500/qhPtAc1DJBNKPqtvktzvOaDjAk8.jpg" },
                    { name: "Thor: The Dark World (2013)", poster: "https://image.tmdb.org/t/p/w500/wp6OxE4poJ4G7c0U2ZIXasTSMR7.jpg" },
                    { name: "Captain America: The Winter Soldier (2014)", poster: "https://image.tmdb.org/t/p/w500/tVFRk9fMWIyPWqSmitL6qHj6R7s.jpg" },
                    { name: "Guardians of the Galaxy (2014)", poster: "https://image.tmdb.org/t/p/w500/rrvnloUuCHmrSfaVnK44y1Gf57u.jpg" },
                    { name: "Avengers: Age of Ultron (2015)", poster: "https://image.tmdb.org/t/p/w500/4ssDuvEDkSArWEdyBl2X5EHvYKU.jpg" },
                    { name: "Ant-Man (2015)", poster: "https://image.tmdb.org/t/p/w500/7LGULrxbc63C2W4g88gR8eL9r3P.jpg" }
                ]
            },
            {
                title: "المرحلة 3",
                movies: [
                    { name: "Captain America: Civil War (2016)", poster: "https://image.tmdb.org/t/p/w500/kY2c7RSOHqAIrvp9n6D5QjS58WJ.jpg" },
                    { name: "Doctor Strange (2016)", poster: "https://image.tmdb.org/t/p/w500/uGBVj3bEbCoZbDjjl9wTxcygko1.jpg" },
                    { name: "Guardians of the Galaxy Vol. 2 (2017)", poster: "https://image.tmdb.org/t/p/w500/y4MBh0Ej6MuKzv8z8U0kKqBqX2a.jpg" },
                    { name: "Spider-Man: Homecoming (2017)", poster: "https://image.tmdb.org/t/p/w500/c24sv2weTHPsmDa7jEMN0r2P3RT.jpg" },
                    { name: "Thor: Ragnarok (2017)", poster: "https://image.tmdb.org/t/p/w500/rzRwTcFvttcN1ZpX2xv4j3tSdJu.jpg" },
                    { name: "Black Panther (2018)", poster: "https://image.tmdb.org/t/p/w500/uxzzxijgPIY7slzFv7V8bfIgIbw.jpg" },
                    { name: "Avengers: Infinity War (2018)", poster: "https://image.tmdb.org/t/p/w500/7WsyChQLEftFiDOVTGkv3hFpyyt.jpg" },
                    { name: "Ant-Man and the Wasp (2018)", poster: "https://image.tmdb.org/t/p/w500/eivQmS38vW4IJydSFsXoqj1y9A8.jpg" },
                    { name: "Captain Marvel (2019)", poster: "https://image.tmdb.org/t/p/w500/AtsgWhGz86SUv9uTJskRIqWvhIL.jpg" },
                    { name: "Avengers: Endgame (2019)", poster: "https://image.tmdb.org/t/p/w500/ulzhLuioj0TtixIVAvW1CXUKGz0.jpg" },
                    { name: "Spider-Man: Far From Home (2019)", poster: "https://image.tmdb.org/t/p/w500/4q2NNj4S5dG2RLF9CpXsej7yXl.jpg" }
                ]
            },
            {
                title: "المرحلة 4",
                movies: [
                    { name: "Black Widow (2021)", poster: "https://image.tmdb.org/t/p/w500/qAZ0pzat24kLdO3o8ejmbLxyOac.jpg" },
                    { name: "Shang-Chi and the Legend of the Ten Rings (2021)", poster: "https://image.tmdb.org/t/p/w500/1BIoJBhX7oStYvFpP0W0N7Kq3x5.jpg" },
                    { name: "Eternals (2021)", poster: "https://image.tmdb.org/t/p/w500/bcCBq9N1EMo3daNIjWJ8kYvrQm6.jpg" },
                    { name: "Spider-Man (2002)", poster: "https://image.tmdb.org/t/p/w500/gh4cZbhZxyTbgxQPxD0dOudNPTn.jpg" },
                    { name: "Spider-Man II (2004)", poster: "https://image.tmdb.org/t/p/w500/olxpyq9kJAZ2NU1siLshhhXEPR7.jpg" },
                    { name: "Spider-Man III (2007)", poster: "https://image.tmdb.org/t/p/w500/qFv8Lj3Zk8P4z8m8z4x8N8S8S8W.jpg" },
                    { name: "The Amazing Spider-Man (2012)", poster: "https://image.tmdb.org/t/p/w500/j9mHjWbjpSTy8oO2b1G9Nq3qT2W.jpg" },
                    { name: "The Amazing Spider-Man II (2014)", poster: "https://image.tmdb.org/t/p/w500/c3e9eMhdqZMsCgC2V0G9oZ9K6T8.jpg" },
                    { name: "Venom (2018)", poster: "https://image.tmdb.org/t/p/w500/2uNW4WbgBXL25BAbXGLnLqX71Sw.jpg" },
                    { name: "Venom: Let There Be Carnage (2021)", poster: "https://image.tmdb.org/t/p/w500/rjkmN1dniUHVYAtwuV3Tji7FsDO.jpg" },
                    { name: "Spider-Man: No Way Home (2021)", poster: "https://image.tmdb.org/t/p/w500/1g0dhYtq4irTY1GPXvft6k4YLjm.jpg" },
                    { name: "WandaVision (2021)", poster: "https://image.tmdb.org/t/p/w500/glrjwLxgh8AMN2pW9M9XvQeP1A3.jpg" },
                    { name: "Fantastic Four (2005)", poster: "https://image.tmdb.org/t/p/w500/qW09E1y4N3iQ1Xz0Z1l0Z0Z0Z0Z.jpg" },
                    { name: "Fantastic Four: Rise of the Silver Surfer (2007)", poster: "https://image.tmdb.org/t/p/w500/8d8o0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z0.jpg" },
                    { name: "Fantastic Four (2015)", poster: "https://image.tmdb.org/t/p/w500/o9Q5aV2K0Z0Z0Z0Z0Z0Z0Z0Z0Z0.jpg" },
                    { name: "Doctor Strange in the Multiverse of Madness (2022)", poster: "https://image.tmdb.org/t/p/w500/9Gtg2DzBhmYamXBS1hKAhiwbBKS.jpg" },
                    { name: "Thor: Love and Thunder (2022)", poster: "https://image.tmdb.org/t/p/w500/pIkRyD18kl4FhoCNQuWxWu5cBLM.jpg" },
                    { name: "Black Panther: Wakanda Forever (2022)", poster: "https://image.tmdb.org/t/p/w500/sv1xJUazXeYqALzczSZ3O6nkH75.jpg" }
                ]
            },
            {
                title: "المرحلة 5",
                movies: [
                    { name: "Loki saison 1 (2021)", poster: "https://image.tmdb.org/t/p/w500/kEl2t3OhXc3Zb9FBh1AuYzRTgZp.jpg" },
                    { name: "Ant-Man and the Wasp: Quantumania (2023)", poster: "https://image.tmdb.org/t/p/w500/ngl2FKBlU4fhbdsrtdom9LVLBXw.jpg" },
                    { name: "Loki saison 2 (2023)", poster: "https://image.tmdb.org/t/p/w500/voHUmluYmKyleFkTu3lOXQG702u.jpg" },
                    { name: "Guardians of the Galaxy Vol. 3 (2023)", poster: "https://image.tmdb.org/t/p/w500/r2J02Z2OpNTctfOSN1Ydgii51I3.jpg" },
                    { name: "The Marvels (2023)", poster: "https://image.tmdb.org/t/p/w500/9GBhzXMFjgcZ3FdR9w3bUMMTps5.jpg" },
                    { name: "X-Men (2000)", poster: "https://image.tmdb.org/t/p/w500/vGbpzZ3qQWl51V9tHq6qV0k8v3v.jpg" },
                    { name: "X2 (2003)", poster: "https://image.tmdb.org/t/p/w500/f89uFLkxdmcj543cE0U1H1Z9p9s.jpg" },
                    { name: "X-Men: The Last Stand (2006)", poster: "https://image.tmdb.org/t/p/w500/kZJ1p1x7Z7k9Z1k1Z1k1Z1k1Z1k.jpg" },
                    { name: "X-Men Origins: Wolverine (2009)", poster: "https://image.tmdb.org/t/p/w500/wj4O61mSScX7609uH363533s.jpg" },
                    { name: "X-Men: First Class (2011)", poster: "https://image.tmdb.org/t/p/w500/4Tf0mD2v0W0Z0Z0Z0Z0Z0Z0Z0Z0.jpg" },
                    { name: "The Wolverine (2013)", poster: "https://image.tmdb.org/t/p/w500/q3Z0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z.jpg" },
                    { name: "X-Men: Days of Future Past (2014)", poster: "https://image.tmdb.org/t/p/w500/z0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z.jpg" },
                    { name: "X-Men: Apocalypse (2016)", poster: "https://image.tmdb.org/t/p/w500/z0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z.jpg" },
                    { name: "Deadpool (2016)", poster: "https://image.tmdb.org/t/p/w500/3E53WEZJqP6nM84L8r8r8r8r8r8.jpg" },
                    { name: "Logan (2017)", poster: "https://image.tmdb.org/t/p/w500/fnbjcRDYn6YviCcePDnGdyAkYsB.jpg" },
                    { name: "Deadpool 2 (2018)", poster: "https://image.tmdb.org/t/p/w500/to0spRl1CMDvyUbOnbb4fTk3VAd.jpg" },
                    { name: "Dark Phoenix (2019)", poster: "https://image.tmdb.org/t/p/w500/cCTStoQrpyyyUJjFSSV499JvWwE.jpg" },
                    { name: "Deadpool & Wolverine (2024)", poster: "https://image.tmdb.org/t/p/w500/8cdWjvZQUExUUTzyp4t6EDMubfO.jpg" },
                    { name: "Captain America: Brave New World (2025)", poster: "https://image.tmdb.org/t/p/w500/pzIdioOUwv692vP9k9X5m2L6B.jpg" },
                    { name: "Thunderbolts* (2025)", poster: "https://image.tmdb.org/t/p/w500/xxVtFFQ8wk0yq5p55n90w.jpg" }
                ]
            },
            {
                title: "المرحلة 6",
                movies: [
                    { name: "The Punisher saison 1", poster: "https://image.tmdb.org/t/p/w500/p9n2206iCjQ3B1j8y0k9r3L3E6M.jpg" },
                    { name: "The punisher saison 2", poster: "https://image.tmdb.org/t/p/w500/k9r3L3E6Mp9n2206iCjQ3B1j8y0.jpg" },
                    { name: "The Punisher: One Last Kill (2027)", poster: "https://image.tmdb.org/t/p/w500/default_movie.jpg" },
                    { name: "The Fantastic 4: First Steps (2025)", poster: "https://image.tmdb.org/t/p/w500/default_movie.jpg" },
                    { name: "Spider-Man: Brand New Day (2026)", poster: "https://image.tmdb.org/t/p/w500/default_movie.jpg" }
                ]
            }
        ];

        const container = document.getElementById('app-container');

        // استرجاع الحالة المحفوظة من متصفح المستخدم
        const savedProgress = JSON.parse(localStorage.getItem('marvel_progress') || '{}');

        phasesData.forEach((phase, phaseIndex) => {
            const section = document.createElement('div');
            section.className = 'phase-section';

            const title = document.createElement('h2');
            title.className = 'phase-title';
            title.textContent = phase.title;
            section.appendChild(title);

            const grid = document.createElement('div');
            grid.className = 'movies-grid';

            phase.movies.forEach((movie, movieIndex) => {
                const movieId = `p${phaseIndex}_m${movieIndex}`;
                const isCompleted = savedProgress[movieId] || false;

                const card = document.createElement('div');
                card.className = `movie-card ${isCompleted ? 'completed' : ''}`;
                card.id = `card_${movieId}`;

                const img = document.createElement('img');
                img.className = 'movie-poster';
                img.src = movie.poster;
                img.alt = movie.name;
                img.loading = 'lazy';
                // بديل في حال لم تتوفر الصورة مباشرة
                img.onerror = function() {
                    this.src = 'https://via.placeholder.com/500x750/113821/1db954?text=MARVEL';
                };

                const info = document.createElement('div');
                info.className = 'movie-info';

                const nameDiv = document.createElement('div');
                nameDiv.className = 'movie-title';
                nameDiv.textContent = movie.name;

                const label = document.createElement('label');
                label.className = 'watched-checkbox';

                const checkbox = document.createElement('input');
                checkbox.type = 'checkbox';
                checkbox.checked = isCompleted;
                checkbox.onchange = function() {
                    savedProgress[movieId] = this.checked;
                    localStorage.setItem('marvel_progress', JSON.stringify(savedProgress));
                    if (this.checked) {
                        card.classList.add('completed');
                    } else {
                        card.classList.remove('completed');
                    }
                };

                label.appendChild(checkbox);
                label.appendChild(document.createTextNode(' تم المشاهدة'));

                info.appendChild(nameDiv);
                info.appendChild(label);

                card.appendChild(img);
                card.appendChild(info);
                grid.appendChild(card);
            });

            section.appendChild(grid);
            container.appendChild(section);
        });
    </script>
</body>
</html>