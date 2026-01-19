import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'Resultscreen.dart';

class MyCollectionScreen extends StatefulWidget {
  const MyCollectionScreen({super.key});

  @override
  State<MyCollectionScreen> createState() => _MyCollectionScreenState();
}

class _MyCollectionScreenState extends State<MyCollectionScreen> {
  List<Map<String, dynamic>> items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('collection') ?? [];
    setState(() {
      items = list.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
    });
  }

  Future<void> _deleteItem(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('collection') ?? [];
    if (index < list.length) {
      list.removeAt(index);
      await prefs.setStringList('collection', list);
    }
    _load();
  }

  Future<void> _toggleFavorite(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('collection') ?? [];
    if (index < list.length) {
      final map = jsonDecode(list[index]) as Map<String, dynamic>;
      final current = map['favorite'] as bool? ?? false;
      map['favorite'] = !current;
      list[index] = jsonEncode(map);
      await prefs.setStringList('collection', list);
    }
    _load();
  }

  void _showDeleteConfirmation(int index) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
        backgroundColor: const Color(0xFF193322),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Item', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this item from your collection?',
          style: TextStyle(color: Color(0xFF92C9A4)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF92C9A4))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteItem(index);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final empty = items.isEmpty;
    final width = MediaQuery.of(context).size.width;
    final isTablet = width > 600;

    return Scaffold(
      appBar: AppBar(title: const Text('My Collection')),
      body:
      empty
          ? const _EmptyCollection()
          : Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child:
          isTablet
              ? GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 2.5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: items.length,
            itemBuilder: (_, i) => _buildItem(i),
          )
              : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _buildItem(i),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(int i) {
    final it = items[i];
    final path = it['imagePath'] as String?;
    final isFav = it['favorite'] as bool? ?? false;

    return Container(
      decoration: BoxDecoration(color: const Color(0xFF193322), borderRadius: BorderRadius.circular(16)),
      child: Center(
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),
          leading:
          path != null && File(path).existsSync()
              ? ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(File(path), width: 56, height: 56, fit: BoxFit.cover),
          )
              : Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF13EC5B).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.toll, size: 32, color: Color(0xFF13EC5B)),
          ),
          title: Text((it['type'] as String?)?.toUpperCase() ?? 'ITEM', style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(
            (it['analysis'] as String?)?.split('\n').take(2).join('\n') ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF92C9A4), fontSize: 12),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(isFav ? Icons.favorite : Icons.favorite_border_rounded, color: isFav ? Colors.red : Colors.white70),
                onPressed: () => _toggleFavorite(i),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white70),
                onPressed: () => _showDeleteConfirmation(i),
              ),
            ],
          ),
          onTap: () {
            if (path != null && File(path).existsSync()) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => ResultScreen(
                    imageFile: File(path),
                    analysis: it['analysis'] as String? ?? '',
                    type: it['type'] as String? ?? 'coin',
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }
}

class _EmptyCollection extends StatelessWidget {
  const _EmptyCollection();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [const Color(0xFF13EC5B).withValues(alpha: 0.2), const Color(0xFF23482F)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.toll, size: 100, color: Color(0xFF13EC5B)),
            ),
            const SizedBox(height: 24),
            const Text('You have no items yet.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
              'Add your first item and start\nbuilding your collection.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF92C9A4), fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
