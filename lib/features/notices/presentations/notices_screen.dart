import 'package:al_sakr/core/network/pb_helper_provider.dart';
import 'package:al_sakr/features/notices/controllers/notices_controller.dart';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/pb_helper.dart';
import 'package:url_launcher/url_launcher.dart';

const _superAdminId = 'admin123';

// =========================================================
// 1. الشاشة الرئيسية (سريعة جداً 🚀)
// =========================================================
class NoticesScreen extends ConsumerStatefulWidget {
  const NoticesScreen({super.key});

  @override
  ConsumerState<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends ConsumerState<NoticesScreen> {
  final bool _canAdd = true;
  final String _superAdminId = "1sxo74splxbw1yh";
  String _currentUserId = "";

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    if (mounted) {
      setState(() {
        _currentUserId = globalPb.authStore.record?.id ?? "";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final noticesAsync = ref.watch(noticesControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(" الإشعارات"), centerTitle: true),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: noticesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, st) => Center(child: Text("حدث خطأ: $err")),
            data: (allNotices) {
              // تصفية القائمة
              final notices = allNotices.where((notice) {
                if (_currentUserId == _superAdminId) return true;
                if (notice['user'] == _currentUserId) return true;
                String createdBy = notice['created_by'] ?? '';
                if (createdBy == _currentUserId) return true;

                List<dynamic> targets = [];
                if (notice['target_users'] is String) {
                  try {
                    targets = jsonDecode(notice['target_users']);
                  } catch (_) {}
                } else if (notice['target_users'] is List) {
                  targets = notice['target_users'];
                }

                if (targets.isEmpty) return true;
                return targets.contains(_currentUserId);
              }).toList();

              if (notices.isEmpty) {
                return const Center(child: Text("لا توجد اشعارات"));
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: notices.length,
                separatorBuilder: (c, i) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  return NoticeCard(
                    notice: notices[index],
                    currentUserId: _currentUserId,
                    superAdminId: _superAdminId,
                    onEdit: () async {
                      await showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) => AddEditNoticeDialog(
                          existingNotice: notices[index],
                          currentUserId: _currentUserId,
                          superAdminId: _superAdminId,
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
      floatingActionButton: _canAdd
          ? FloatingActionButton.extended(
              onPressed: () async {
                await showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => AddEditNoticeDialog(
                    currentUserId: _currentUserId,
                    superAdminId: _superAdminId,
                  ),
                );
              },
              label: const Text("اشعار جديد"),
              icon: const Icon(Icons.add),
              backgroundColor: const Color(0xFF1565C0),
            )
          : null,
    );
  }
}

// =========================================================
// 2. نافذة الإضافة/التعديل (التصميم الجديد ✅)
// =========================================================
class AddEditNoticeDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existingNotice;
  final String currentUserId;
  final String superAdminId;

  const AddEditNoticeDialog({
    super.key,
    this.existingNotice,
    required this.currentUserId,
    required this.superAdminId,
  });

  @override
  ConsumerState<AddEditNoticeDialog> createState() =>
      _AddEditNoticeDialogState();
}

class _AddEditNoticeDialogState extends ConsumerState<AddEditNoticeDialog> {
  late TextEditingController titleCtrl;
  late TextEditingController contentCtrl;
  late String priority;

  List<PlatformFile> selectedFiles = [];
  List<String> existingImages = [];
  List<String> selectedUserIds = [];
  bool isAllEmployees = true;
  bool isEdit = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    isEdit = widget.existingNotice != null;

    titleCtrl = TextEditingController(
      text: isEdit ? widget.existingNotice!['title'] : '',
    );

    String rawContent = isEdit ? (widget.existingNotice!['content'] ?? '') : '';
    contentCtrl = TextEditingController(text: _cleanContent(rawContent));

    priority = isEdit
        ? (widget.existingNotice!['priority'] ?? 'normal')
        : 'normal';

    if (isEdit && widget.existingNotice!['image'] != null) {
      existingImages = List<String>.from(
        widget.existingNotice!['image'] is List
            ? widget.existingNotice!['image']
            : [widget.existingNotice!['image']],
      );
    }

    if (isEdit) {
      List<dynamic> targets = widget.existingNotice!['target_users'] ?? [];
      if (targets.isNotEmpty) {
        isAllEmployees = false;
        selectedUserIds = targets.map((e) => e.toString()).toList();
      }
    }
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    contentCtrl.dispose();
    super.dispose();
  }

  Future<void> pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'png', 'jpeg', 'pdf', 'doc', 'docx'],
    );
    if (result != null) {
      setState(() => selectedFiles.addAll(result.files));
    }
  }

  Future<void> pickUsers() async {
    final allUsers = await globalPb.collection('_superusers').getFullList();
    allUsers.removeWhere(
      (u) => u.id == widget.superAdminId || u.id == widget.currentUserId,
    );

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (innerCtx) {
        List<String> tempSelected = List.from(selectedUserIds);
        return StatefulBuilder(
          builder: (context, setInnerState) {
            return AlertDialog(
              title: const Text("تحديد الموظفين"),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: allUsers.length,
                  itemBuilder: (c, i) {
                    final u = allUsers[i];
                    final isSelected = tempSelected.contains(u.id);
                    String name =
                        u.data['name']?.toString() ??
                        u.data['username'] ??
                        "Unknown";
                    return CheckboxListTile(
                      title: Text(name),
                      value: isSelected,
                      onChanged: (val) {
                        setInnerState(() {
                          if (val == true)
                            tempSelected.add(u.id);
                          else
                            tempSelected.remove(u.id);
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(innerCtx),
                  child: const Text("إلغاء"),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      selectedUserIds = tempSelected;
                      if (selectedUserIds.isEmpty) isAllEmployees = true;
                    });
                    Navigator.pop(innerCtx);
                  },
                  child: const Text("تأكيد"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _save() async {
    if (titleCtrl.text.isNotEmpty && contentCtrl.text.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        String contentText = contentCtrl.text;
        List<File> filesToUpload = selectedFiles
            .map((e) => File(e.path!))
            .toList();

        if (isEdit) {
          await ref
              .read(noticesControllerProvider.notifier)
              .updateAnnouncement(widget.existingNotice!['id'], {
                'title': titleCtrl.text,
                'content': contentText,
                'priority': priority,
                'target_users': isAllEmployees ? [] : selectedUserIds,
              });
        } else {
          await ref
              .read(noticesControllerProvider.notifier)
              .createAnnouncement({
                'title': titleCtrl.text,
                'content': contentText,
                'priority': priority,
                'target_users': isAllEmployees ? [] : selectedUserIds,
              }, files: filesToUpload);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("تم النشر بنجاح ✅"),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("خطأ: $e"), backgroundColor: Colors.red),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("برجاء إدخال البيانات المطلوبة")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    Color activeColor = getPriorityColor(priority);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      insetPadding: EdgeInsets.all(isMobile ? 10 : 20),
      child: _isLoading
          ? const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          : Container(
              width: isMobile ? size.width : 550,
              constraints: BoxConstraints(maxHeight: size.height * 0.9),
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isEdit ? Icons.edit : Icons.edit_note,
                          color: activeColor,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isEdit ? "تعديل الاشعار" : "تنبيه جديد",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Priority
                    Wrap(
                      spacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildModernChip(
                          "low",
                          "low",
                          priority,
                          (v) => setState(() => priority = v),
                        ),
                        _buildModernChip(
                          "normal",
                          "normal",
                          priority,
                          (v) => setState(() => priority = v),
                        ),
                        _buildModernChip(
                          "high",
                          "high",
                          priority,
                          (v) => setState(() => priority = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Target Users
                    InkWell(
                      onTap: () {
                        setState(() => isAllEmployees = !isAllEmployees);
                        if (!isAllEmployees) pickUsers();
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.3),
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color: isDark ? Colors.black12 : Colors.grey[50],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isAllEmployees ? Icons.public : Icons.people,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                isAllEmployees
                                    ? "موجه لجميع الموظفين"
                                    : "تم تحديد ${selectedUserIds.length} موظف",
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            if (!isAllEmployees)
                              const Icon(
                                Icons.settings,
                                size: 20,
                                color: Colors.blue,
                              )
                            else
                              Switch(
                                value: isAllEmployees,
                                onChanged: (v) {
                                  setState(() {
                                    isAllEmployees = v;
                                    if (v)
                                      selectedUserIds.clear();
                                    else
                                      pickUsers();
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title
                    TextField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        labelText: "موضوع الاشعار",
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF252525)
                            : Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: Icon(Icons.title, color: activeColor),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ✅ تفاصيل الإشعار (مفصول عن الحقل لحل مشكلة الشكل)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 5, bottom: 8),
                          child: Text(
                            "تفاصيل الإشعار",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[700],
                            ),
                          ),
                        ),
                        TextField(
                          controller: contentCtrl,
                          minLines: 4,
                          maxLines: 15,
                          decoration: InputDecoration(
                            hintText: "اكتب التفاصيل هنا...",
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF252525)
                                : Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 15),

                    // Files Preview
                    if (selectedFiles.isNotEmpty || existingImages.isNotEmpty)
                      Container(
                        height: 70,
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            ...existingImages.map((img) {
                              String ext = img.split('.').last.toLowerCase();
                              bool isDoc =
                                  ext == 'pdf' || ext == 'doc' || ext == 'docx';
                              String url = PBHelper().getImageUrl(
                                widget.existingNotice!['collectionId'],
                                widget.existingNotice!['id'],
                                img,
                              );
                              return _buildFilePreview(isDoc, url: url);
                            }),
                            ...selectedFiles.map((f) {
                              String ext = f.extension?.toLowerCase() ?? "";
                              bool isDoc =
                                  ext == 'pdf' || ext == 'doc' || ext == 'docx';
                              return Stack(
                                children: [
                                  _buildFilePreview(isDoc, file: File(f.path!)),
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: InkWell(
                                      onTap: () => setState(
                                        () => selectedFiles.remove(f),
                                      ),
                                      child: const CircleAvatar(
                                        radius: 10,
                                        backgroundColor: Colors.red,
                                        child: Icon(
                                          Icons.close,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: pickFiles,
                        icon: const Icon(Icons.attach_file, size: 20),
                        label: Text(
                          "إرفاق ملفات (${selectedFiles.length + existingImages.length})",
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: activeColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: Icon(
                          isEdit ? Icons.save : Icons.send_rounded,
                          color: Colors.white,
                        ),
                        label: Text(
                          isEdit ? "حفظ التعديلات" : "نشر الآن",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFilePreview(bool isDoc, {String? url, File? file}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[200],
        ),
        child: isDoc
            ? const Icon(Icons.description, color: Colors.blue)
            : (file != null
                  ? Image.file(file, fit: BoxFit.cover)
                  : Image.network(url!, fit: BoxFit.cover)),
      ),
    );
  }

  Widget _buildModernChip(
    String label,
    String value,
    String groupVal,
    Function(String) onTap,
  ) {
    bool isSelected = value == groupVal;
    Color color = getPriorityColor(value);
    return InkWell(
      onTap: () => onTap(value),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          border: Border.all(
            color: isSelected ? color : Colors.grey[400]!,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : Colors.grey[600],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// =========================================================
// 3. كارت الإشعار (Stateful لأداء أفضل)
// =========================================================
class NoticeCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> notice;
  final String currentUserId;
  final String superAdminId;
  final VoidCallback onEdit;

  const NoticeCard({
    super.key,
    required this.notice,
    required this.currentUserId,
    required this.superAdminId,
    required this.onEdit,
  });

  @override
  ConsumerState<NoticeCard> createState() => _NoticeCardState();
}

class _NoticeCardState extends ConsumerState<NoticeCard> {
  // ✅ التخزين المؤقت للنص المعالج
  late String _cachedContent;

  @override
  void initState() {
    super.initState();
    _cachedContent = _cleanContent(widget.notice['content'] ?? '');
  }

  @override
  void didUpdateWidget(NoticeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.notice['content'] != oldWidget.notice['content']) {
      setState(() {
        _cachedContent = _cleanContent(widget.notice['content'] ?? '');
      });
    }
  }

  Future<void> _openFile(BuildContext context, String url) async {
    final Uri uri = Uri.parse(url);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("تعذر فتح الملف")));
      }
    }
  }

  void _openImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(url),
              ),
            ),
            Positioned(
              top: 40,
              left: 20,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSeenByList(BuildContext context) {
    List<dynamic> seenUsers = [];
    if (widget.notice['expand'] != null &&
        widget.notice['expand']['seen_by'] != null) {
      var data = widget.notice['expand']['seen_by'];
      seenUsers = data is List ? data : [data];
    }
    if (seenUsers.isEmpty) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        height: MediaQuery.of(context).size.height * 0.5,
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 15),
            Text(
              "المشاهدات (${seenUsers.length})",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            Expanded(
              child: ListView.separated(
                itemCount: seenUsers.length,
                separatorBuilder: (c, i) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final user = seenUsers[index];
                  String name =
                      user['name']?.toString() ?? user['username'] ?? "موظف";
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue[50],
                      child: Text(
                        name.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          color: Colors.blue[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 18,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String priority = widget.notice['priority'] ?? 'normal';
    Color priorityColor = getPriorityColor(priority);
    Color bgColor = getPriorityBg(priority, isDark);

    bool isOwner = widget.notice['user'] == widget.currentUserId;
    bool isAdmin = widget.currentUserId == widget.superAdminId;
    bool canControl = isOwner || isAdmin;
    List<String> seenByIds = [];
    if (widget.notice['seen_by'] is String) {
      try {
        final decoded = jsonDecode(widget.notice['seen_by']);
        if (decoded is List) seenByIds = List<String>.from(decoded);
      } catch (_) {}
    } else if (widget.notice['seen_by'] is List) {
      seenByIds = List<String>.from(widget.notice['seen_by']);
    }
    bool isSeen = seenByIds.contains(widget.currentUserId);

    List<String> files = [];
    if (widget.notice['image'] != null &&
        widget.notice['image'].toString().isNotEmpty) {
      if (widget.notice['image'] is String) {
        try {
          final decoded = jsonDecode(widget.notice['image']);
          if (decoded is List) {
            files = List<String>.from(decoded);
          } else {
            files = [widget.notice['image']];
          }
        } catch (_) {
          files = [widget.notice['image']];
        }
      } else if (widget.notice['image'] is List) {
        files = List<String>.from(widget.notice['image']);
      } else {
        files = [widget.notice['image'].toString()];
      }
    }

    String senderName = "الإدارة";
    if (widget.notice['expand'] != null &&
        widget.notice['expand']['user'] != null) {
      senderName =
          widget.notice['expand']['user']['name'] ??
          widget.notice['expand']['user']['username'] ??
          "موظف";
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: priorityColor.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                  child: const Icon(Icons.person, size: 20, color: Colors.grey),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        senderName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        intl.DateFormat('yyyy-MM-dd hh:mm a').format(
                          DateTime.parse(widget.notice['created']).toLocal(),
                        ),
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    getPriorityText(priority),
                    style: TextStyle(
                      color: priorityColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                InkWell(
                  onTap: () async {
                    await Clipboard.setData(
                      ClipboardData(text: _cachedContent),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("تم نسخ النص بنجاح ✅")),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.copy, size: 18, color: Colors.grey[600]),
                  ),
                ),
                if (canControl) ...[
                  const SizedBox(width: 5),
                  InkWell(
                    onTap: widget.onEdit,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      child: const Icon(
                        Icons.edit,
                        size: 18,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => _confirmDelete(context, widget.notice['id']),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      child: const Icon(
                        Icons.delete,
                        size: 18,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.notice['title'] != null &&
                    widget.notice['title'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      widget.notice['title'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),

                // ✅ عرض النص المحفوظ
                SelectableText(
                  _cachedContent,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),

                if (files.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 15),
                    child: SizedBox(
                      height: 80,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: files.length,
                        separatorBuilder: (c, i) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          String fileId = files[index];
                          String url = PBHelper().getImageUrl(
                            widget.notice['collectionId'],
                            widget.notice['id'],
                            fileId,
                          );
                          String ext = fileId.split('.').last.toLowerCase();
                          bool isDoc =
                              ext == 'pdf' || ext == 'doc' || ext == 'docx';
                          return GestureDetector(
                            onTap: () => (isDoc)
                                ? _openFile(context, url)
                                : _openImage(context, url),
                            child: Container(
                              width: 80,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.grey.withOpacity(0.3),
                                ),
                                image: (isDoc)
                                    ? null
                                    : DecorationImage(
                                        image: NetworkImage(url),
                                        fit: BoxFit.cover,
                                      ),
                                color: (isDoc) ? Colors.grey[100] : null,
                              ),
                              child: (isDoc)
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            ext == 'pdf'
                                                ? Icons.picture_as_pdf
                                                : Icons.description,
                                            color: ext == 'pdf'
                                                ? Colors.red
                                                : Colors.blue,
                                            size: 24,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            ext.toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                if (canControl)
                  InkWell(
                    onTap: seenByIds.isNotEmpty
                        ? () => _showSeenByList(context)
                        : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.visibility,
                            size: 16,
                            color: seenByIds.isNotEmpty
                                ? Colors.blue
                                : Colors.grey,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            "شاهده: ${seenByIds.length}",
                            style: TextStyle(
                              fontSize: 12,
                              color: seenByIds.isNotEmpty
                                  ? Colors.blue
                                  : Colors.grey,
                              fontWeight: FontWeight.bold,
                              decoration: seenByIds.isNotEmpty
                                  ? TextDecoration.underline
                                  : TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const Spacer(),
                if (!canControl)
                  if (!isSeen)
                    InkWell(
                      onTap: () async => await ref
                          .read(noticesControllerProvider.notifier)
                          .markAnnouncementAsSeen(
                            widget.notice['id'],
                            widget.currentUserId,
                          ),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: priorityColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: priorityColor.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check, size: 16, color: Colors.white),
                            SizedBox(width: 5),
                            Text(
                              "تأكيد القراءة",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Icon(Icons.done_all, size: 18, color: Colors.blue[300]),
                        const SizedBox(width: 5),
                        Text(
                          "تم الاطلاع",
                          style: TextStyle(
                            color: Colors.blue[300],
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("تأكيد الحذف"),
        content: const Text("هل أنت متأكد من حذف هذا الاشعار"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await ref
                  .read(noticesControllerProvider.notifier)
                  .deleteAnnouncement(id);
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text("حذف", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// =========================================================
// 4. دوال مساعدة
// =========================================================
Color getPriorityColor(String priority) {
  switch (priority) {
    case 'high':
      return const Color(0xFFE53935);
    case 'normal':
      return const Color(0xFF1E88E5);
    case 'low':
      return const Color(0xFF43A047);
    default:
      return Colors.grey;
  }
}

Color getPriorityBg(String priority, bool isDark) {
  if (isDark) return getPriorityColor(priority).withOpacity(0.1);
  return getPriorityColor(priority).withOpacity(0.05);
}

String getPriorityText(String priority) {
  switch (priority) {
    case 'high':
      return "high";
    case 'normal':
      return "normal";
    case 'low':
      return "low";
    default:
      return "general";
  }
}

String _cleanContent(String content) {
  try {
    if (content.trim().startsWith('[')) {
      List<dynamic> json = jsonDecode(content);
      StringBuffer buffer = StringBuffer();
      for (var item in json) {
        if (item is Map && item.containsKey('insert')) {
          buffer.write(item['insert']);
        }
      }
      return buffer.toString().trim();
    }
  } catch (e) {
    // ignore
  }
  return content;
}
