import 'package:flutter/material.dart';

class AdminMockupPreview extends StatelessWidget {
  const AdminMockupPreview({super.key});

  Widget _badge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.03), blurRadius: 6)],
      ),
      child: Row(children: [Text('$label: ', style: const TextStyle(color: Colors.black54)), Text(value, style: const TextStyle(fontWeight: FontWeight.w700))]),
    );
  }

  DataRow _userRow(String name, String email, List<String> chips) {
    return DataRow(cells: [
      DataCell(
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(email, style: const TextStyle(fontSize: 13, color: Colors.black54)),
        ]),
      ),
      DataCell(Text(email)),
      DataCell(Wrap(spacing: 6, runSpacing: 6, children: chips.map((c) => Chip(label: Text(c), backgroundColor: Colors.blue.shade50, labelStyle: const TextStyle(color: Color(0xFF0F172A)))).toList())),
      DataCell(Row(children: [
        IconButton(onPressed: () {}, icon: const Icon(Icons.edit, color: Colors.green)),
        IconButton(onPressed: () {}, icon: const Icon(Icons.delete, color: Colors.red)),
      ])),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Users — Admin')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Users — Admin', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            Row(children: [
              _badge('Total', '24'),
              const SizedBox(width: 8),
              _badge('Active', '18'),
              const SizedBox(width: 8),
              _badge('Interpreters', '9'),
              const SizedBox(width: 8),
              _badge('Admins', '3'),
            ])
          ]),

          const SizedBox(height: 12),

          Expanded(
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: DataTable(
                  headingRowHeight: 48,
                  dataRowMinHeight: 76,
                  dataRowMaxHeight: 76,
                  columns: const [
                    DataColumn(label: Text('User')),
                    DataColumn(label: Text('Email')),
                    DataColumn(label: Text('Rights')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: [
                    _userRow('Marie Dupont', 'marie.dupont@example.com', ['Agent Admin', 'Interprete']),
                    _userRow('Paul Martin', 'paul.martin@example.com', ['Admin', 'Mission Manager']),
                    _userRow('Inès Leroy', 'ines.leroy@example.com', ['Interprete']),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),
          const Text('Open this screen by pushing the route to AdminMockupPreview', style: TextStyle(color: Colors.black54)),
        ]),
      ),
    );
  }
}
