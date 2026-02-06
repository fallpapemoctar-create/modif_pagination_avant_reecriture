import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/admin_service.dart';
import '../core/user_rights.dart';
import '../core/responsive_helper.dart';
import '../core/brand_footer.dart';

class AdminPage extends StatefulWidget {
	final UserRights? userRights;
	const AdminPage({super.key, this.userRights});

	@override
	State<AdminPage> createState() => _AdminPageState();
}


class _AdminPageState extends State<AdminPage> {
	final List<UserModel> _all = [];
	final List<UserModel> _filtered = [];
	final ScrollController _listScrollController = ScrollController();
	bool _loading = true;
	String? _error;

	@override
	void initState() {
		super.initState();
		_load();
	}

	@override
	void dispose() {
		_listScrollController.dispose();
		super.dispose();
	}

	Future<void> _load() async {
		try {
			final map = await AdminService.getUsers();
			final users = (map['users'] as List<UserModel>);
			setState(() {
				_all.clear();
				_all.addAll(users);
				_filtered.clear();
				_filtered.addAll(users);
				_loading = false;
				_error = null;
			});
		} catch (e) {
			setState(() {
				_loading = false;
				_error = e.toString();
			});
		}
	}

	void _onSearchChanged(String q) {
		final query = q.trim().toLowerCase();
		setState(() {
			_filtered.clear();
			if (query.isEmpty) {
				_filtered.addAll(_all);
			} else {
				_filtered.addAll(_all.where((u) {
					final hay = '${u.fullname} ${u.email} ${u.username}'.toLowerCase();
					return hay.contains(query);
				}).toList());
			}
		});
	}

	Future<void> _showEditDialog(UserModel user) async {
		final fullnameCtrl = TextEditingController(text: user.fullname);
		final emailCtrl = TextEditingController(text: user.email);
		final usernameCtrl = TextEditingController(text: user.username);
		final passwordCtrl = TextEditingController();

		final ok = await showDialog<bool>(
			context: context,
			builder: (ctx) {
				return StatefulBuilder(builder: (ctx2, setStateDialog) {
					return AlertDialog(
						title: const Text('Modifier l\'utilisateur'),
						content: SingleChildScrollView(
							child: Column(
								mainAxisSize: MainAxisSize.min,
								children: [
									TextField(controller: fullnameCtrl, decoration: const InputDecoration(labelText: 'Nom Prénom')),
									TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
									TextField(controller: usernameCtrl, decoration: const InputDecoration(labelText: 'Login')),
									TextField(controller: passwordCtrl, decoration: const InputDecoration(labelText: 'Mot de passe (laisser vide pour ne pas changer)'), obscureText: true),
								],
							),
						),
						actions: [
							TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
							ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enregistrer')),
						],
					);
				});
			},
		);

		if (!mounted) return;
		if (ok == true) {
			final updated = UserModel(
				id: user.id,
				username: usernameCtrl.text.trim(),
				fullname: fullnameCtrl.text.trim(),
				email: emailCtrl.text.trim(),
				canManageInterpreters: user.canManageInterpreters,
				canManageMissions: user.canManageMissions,
				isAdmin: user.isAdmin,
				isInterpreter: user.isInterpreter,
				rightsDisplay: user.rightsDisplay,
			);

			final messenger = ScaffoldMessenger.of(context);
			try {
				final success = await AdminService.updateUser(updated, password: passwordCtrl.text.trim().isEmpty ? null : passwordCtrl.text.trim());
				if (success) {
					messenger.showSnackBar(const SnackBar(content: Text('Utilisateur mis à jour')));
					await _load();
				} else {
					messenger.showSnackBar(const SnackBar(content: Text('Erreur lors de la mise à jour')));
				}
			} catch (e) {
				messenger.showSnackBar(SnackBar(content: Text('Erreur: $e')));
			}
		}
	}

	Future<void> _toggleRight(UserModel user, String rightKey) async {
		bool newIsInterpreter = user.isInterpreter;
		bool newCanManageInterpreters = user.canManageInterpreters;
		bool newMissions = user.canManageMissions;
		bool newAdmin = user.isAdmin;

		if (rightKey == 'interpreters') newIsInterpreter = !newIsInterpreter;
		if (rightKey == 'interpreters_manager') newCanManageInterpreters = !newCanManageInterpreters;
		if (rightKey == 'missions') newMissions = !newMissions;
		if (rightKey == 'admin') newAdmin = !newAdmin;

		final updated = UserModel(
			id: user.id,
			username: user.username,
			fullname: user.fullname,
			email: user.email,
			canManageInterpreters: newCanManageInterpreters,
			canManageMissions: newMissions,
			isAdmin: newAdmin,
			isInterpreter: newIsInterpreter,
			rightsDisplay: user.rightsDisplay,
		);

		// Optimistic UI update: reflect toggle instantly
		setState(() {
			final idxAll = _all.indexWhere((u) => u.id == user.id);
			if (idxAll != -1) _all[idxAll] = updated;
			final idxFiltered = _filtered.indexWhere((u) => u.id == user.id);
			if (idxFiltered != -1) _filtered[idxFiltered] = updated;
		});

		final messenger = ScaffoldMessenger.of(context);
		try {
			final success = await AdminService.updateUser(updated);
			if (success) {
				if (!mounted) return;
				messenger.showSnackBar(const SnackBar(content: Text('Droits mis à jour')));
				await _load();
			} else {
				if (!mounted) return;
				messenger.showSnackBar(const SnackBar(content: Text('Erreur lors de la mise à jour')));
				// Revert by reloading
				await _load();
			}
		} catch (e) {
			if (!mounted) return;
			messenger.showSnackBar(SnackBar(content: Text('Erreur: $e')));
			await _load();
		}
	}

	@override
	Widget build(BuildContext context) {
		final theme = Theme.of(context);
		final isMobile = ResponsiveHelper.isMobile(context);

		return Scaffold(
			appBar: AppBar(title: const Text('Administration')),
			body: Container(
				color: Colors.white,
				child: ResponsiveContainer(
					child: Column(
						children: [
						// Search bar
						Padding(
							padding: EdgeInsets.symmetric(
								vertical: ResponsiveHelper.getSpacing(context),
							),
							child: TextField(
							decoration: const InputDecoration(
								prefixIcon: Icon(Icons.search, color: Colors.grey),
								hintText: 'Rechercher...',
								hintStyle: TextStyle(color: Colors.grey),
								border: UnderlineInputBorder(),
								),
								onChanged: _onSearchChanged,
							),
						),
						SizedBox(height: ResponsiveHelper.getSpacing(context)),
						
						// Content area
						Expanded(
							child: _loading
								? const Center(child: CircularProgressIndicator())
								: _error != null
									? Center(child: Text('Erreur: $_error'))
									: _filtered.isEmpty
										? const Center(child: Text('Aucun utilisateur'))
										: isMobile
											? _buildMobileList()
											: _buildDesktopTable(theme),
						),
							const BrandFooter(),
						],
				),
			),
			),
		);
	}

	Widget _buildMobileList() {
		return ListView.builder(
			controller: _listScrollController,
			itemCount: _filtered.length,
			padding: EdgeInsets.symmetric(vertical: ResponsiveHelper.getSpacing(context, mobile: 4)),
			itemBuilder: (context, i) {
				final u = _filtered[i];
				return Card(
					elevation: ResponsiveHelper.getCardElevation(context),
					margin: EdgeInsets.symmetric(
						vertical: ResponsiveHelper.getSpacing(context, mobile: 6),
					),
					shape: RoundedRectangleBorder(
						borderRadius: ResponsiveHelper.getBorderRadius(context),
					),
					child: Padding(
						padding: EdgeInsets.all(ResponsiveHelper.getSpacing(context)),
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								// User info
								Row(
									children: [
										Expanded(
											child: Column(
												crossAxisAlignment: CrossAxisAlignment.start,
												children: [
													Text(
														u.fullname,
														style: TextStyle(
															fontSize: ResponsiveHelper.getFontSize(context, base: 15),
															fontWeight: FontWeight.bold,
														),
													),
													SizedBox(height: 4),
													Text(
														u.email,
														style: TextStyle(
															fontSize: ResponsiveHelper.getFontSize(context, base: 12),
															color: Theme.of(context).textTheme.bodySmall?.color,
														),
													),
												],
											),
										),
										IconButton(
											icon: const Icon(Icons.edit, color: Colors.blue),
											onPressed: () => _showEditDialog(u),
											tooltip: 'Modifier',
										),
										IconButton(
											icon: const Icon(Icons.delete, color: Colors.red),
											onPressed: () => _confirmDelete(u),
											tooltip: 'Supprimer',
										),
									],
								),
								Divider(height: 24),
								
								// Rights switches
								  _buildMobileRight('Interprète', u.isInterpreter, () => _toggleRight(u, 'interpreters')),
								  _buildMobileRight('Gestionnaire Interprètes', u.canManageInterpreters, () => _toggleRight(u, 'interpreters_manager')),
								SizedBox(height: 8),
								_buildMobileRight('Gestionnaire Missions', u.canManageMissions, () => _toggleRight(u, 'missions')),
								SizedBox(height: 8),
								_buildMobileRight('Administrateur', u.isAdmin, () => _toggleRight(u, 'admin')),
							],
						),
					),
				);
			},
		);
	}

	Widget _buildMobileRight(String label, bool value, VoidCallback onToggle) {
		return Row(
			mainAxisAlignment: MainAxisAlignment.spaceBetween,
			children: [
				Text(
					label,
					style: TextStyle(
						fontSize: ResponsiveHelper.getFontSize(context, base: 13),
						fontWeight: FontWeight.w500,
					),
				),
				Switch(value: value, onChanged: (_) => onToggle()),
			],
		);
	}

	Widget _buildDesktopTable(ThemeData theme) {
		final isWide = ResponsiveHelper.isDesktop(context);
		final interpWidth = isWide ? 220.0 : 180.0;
		final otherRightWidth = isWide ? 180.0 : 150.0;

		return Column(
			children: [
				// Header DSFR
				Container(
					decoration: BoxDecoration(
						color: const Color(0xFF000091), // Blue France
						borderRadius: const BorderRadius.vertical(
							top: Radius.circular(4),
						),
					),
					padding: EdgeInsets.all(ResponsiveHelper.getSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
					child: Row(
						children: [
							Expanded(
								child: Text(
									'Nom Prénom',
									style: TextStyle(
										fontWeight: FontWeight.w700,
										fontSize: ResponsiveHelper.getFontSize(context, base: 14),
										color: Colors.white,
									),
								),
							),
							const SizedBox(width: 16),
														SizedBox(
															width: interpWidth,
															child: Text(
																'Interprètes',
																textAlign: TextAlign.center,
																style: TextStyle(
																	fontWeight: FontWeight.w700,
																	color: Colors.white,
																	fontSize: ResponsiveHelper.getFontSize(context, base: 13),
																),
															),
														),
														const SizedBox(width: 16),
														SizedBox(
															width: otherRightWidth,
															child: Text(
																'Gest. Interprètes',
																textAlign: TextAlign.center,
																style: TextStyle(
																	fontWeight: FontWeight.w700,
																	color: Colors.white,
																	fontSize: ResponsiveHelper.getFontSize(context, base: 13),
																),
															),
														),
							const SizedBox(width: 16),
							SizedBox(
								width: otherRightWidth,
								child: Text(
									'Missions',
									textAlign: TextAlign.center,
									style: TextStyle(
										fontWeight: FontWeight.w700,
										color: Colors.white,
										fontSize: ResponsiveHelper.getFontSize(context, base: 13),
									),
								),
							),
							const SizedBox(width: 16),
							SizedBox(
								width: otherRightWidth,
								child: Text(
									'Admin',
									textAlign: TextAlign.center,
									style: TextStyle(
										fontWeight: FontWeight.w700,
										color: Colors.white,
										fontSize: ResponsiveHelper.getFontSize(context, base: 13),
									),
								),
							),
							const SizedBox(width: 16),
							SizedBox(
								width: 120,
								child: Text(
									'Actions',
									textAlign: TextAlign.right,
									style: TextStyle(
										fontWeight: FontWeight.w700,
										color: Colors.white,
										fontSize: ResponsiveHelper.getFontSize(context, base: 13),
									),
								),
							),
						],
					),
				),
				const SizedBox(height: 2),
				
				// List DSFR
				Expanded(
					child: Container(
						decoration: BoxDecoration(
							color: Colors.white,
							border: Border.all(color: const Color(0xFFDDDDDD)),
							borderRadius: const BorderRadius.vertical(
								bottom: Radius.circular(4),
							),
						),
						child: Scrollbar(
							thumbVisibility: true,
							controller: _listScrollController,
							child: ListView.builder(
								controller: _listScrollController,
								itemCount: _filtered.length,
								itemBuilder: (context, i) {
									final u = _filtered[i];
									final rowColor = (i % 2 == 0) ? Colors.white : const Color(0xFFF6F6F6); // Alternance DSFR
									
									return Container(
										decoration: BoxDecoration(
											color: rowColor,
											border: const Border(
												bottom: BorderSide(
													color: Color(0xFFDDDDDD),
													width: 1,
												),
											),
										),
										padding: EdgeInsets.symmetric(
											vertical: ResponsiveHelper.getSpacing(context, mobile: 12, desktop: 14),
											horizontal: ResponsiveHelper.getSpacing(context, mobile: 12, desktop: 16),
										),
										child: Row(
											children: [
												Expanded(
													child: Column(
														crossAxisAlignment: CrossAxisAlignment.start,
														children: [
															Text(
																u.fullname,
																style: TextStyle(
																	fontSize: ResponsiveHelper.getFontSize(context, base: 14),
																	fontWeight: FontWeight.w600,
																	color: const Color(0xFF161616),
																),
															),
															const SizedBox(height: 4),
															Text(
																u.email,
																style: TextStyle(
																	fontSize: ResponsiveHelper.getFontSize(context, base: 12),
																	color: const Color(0xFF666666),
																),
															),
														],
													),
												),
												Container(
													width: 1,
													height: 48,
													margin: const EdgeInsets.symmetric(horizontal: 12),
													color: const Color(0xFFDDDDDD),
												),
																								SizedBox(
																									width: interpWidth,
																									child: Center(
																										child: Switch(
																											value: u.isInterpreter,
																											onChanged: (v) => _toggleRight(u, 'interpreters'),
																											activeThumbColor: const Color(0xFF000091), // Blue France
																											activeTrackColor: const Color(0xFF000091).withValues(alpha: 0.5),
																										),
																									),
																								),
																								SizedBox(
																									width: otherRightWidth,
																									child: Center(
																										child: Switch(
																											value: u.canManageInterpreters,
																											onChanged: (v) => _toggleRight(u, 'interpreters_manager'),
																											activeThumbColor: const Color(0xFF000091),
																											activeTrackColor: const Color(0xFF000091).withValues(alpha: 0.5),
																										),
																									),
																								),
												SizedBox(
													width: otherRightWidth,
													child: Center(
														child: Switch(
															value: u.canManageMissions,
															onChanged: (v) => _toggleRight(u, 'missions'),
															activeThumbColor: const Color(0xFF000091),
																activeTrackColor: const Color(0xFF000091).withValues(alpha: 0.5),
														),
													),
												),
												SizedBox(
													width: otherRightWidth,
													child: Center(
														child: Switch(
															value: u.isAdmin,
															onChanged: (v) => _toggleRight(u, 'admin'),
															activeThumbColor: const Color(0xFF000091),
																activeTrackColor: const Color(0xFF000091).withValues(alpha: 0.5),
														),
													),
												),
												SizedBox(
													width: 120,
													child: Row(
														mainAxisAlignment: MainAxisAlignment.end,
														children: [
															IconButton(
																tooltip: 'Modifier',
																icon: const Icon(Icons.edit, color: Color(0xFF000091), size: 20),
																onPressed: () => _showEditDialog(u),
																splashRadius: 20,
															),
															IconButton(
																tooltip: 'Supprimer',
																icon: const Icon(Icons.delete, color: Color(0xFFCE0500), size: 20),
																onPressed: () => _confirmDelete(u),
																splashRadius: 20,
															),
														],
													),
												),
											],
										),
									);
								},
							),
						),
					),
				),
			],
		);
	}

	Future<void> _confirmDelete(UserModel u) async {
		final messenger = ScaffoldMessenger.of(context);
		final confirm = await showDialog<bool>(
			context: context,
			builder: (ctx) => AlertDialog(
				title: const Text('Confirmer la suppression'),
				content: Text('Supprimer ${u.fullname} ?'),
				actions: [
					TextButton(
						onPressed: () => Navigator.pop(ctx, false),
						child: const Text('Annuler'),
					),
					ElevatedButton(
						onPressed: () => Navigator.pop(ctx, true),
						style: ElevatedButton.styleFrom(
							backgroundColor: Colors.red,
							foregroundColor: Colors.white,
						),
						child: const Text('Supprimer'),
					),
				],
			),
		);
		if (confirm != true) return;
		if (!mounted) return;
		try {
			final ok = await AdminService.deleteUser(u.id);
			if (ok) {
				if (!mounted) return;
				messenger.showSnackBar(const SnackBar(content: Text('Utilisateur supprimé')));
				await _load();
			} else {
				messenger.showSnackBar(const SnackBar(content: Text('Erreur lors de la suppression')));
			}
		} catch (e) {
			messenger.showSnackBar(SnackBar(content: Text('Erreur: $e')));
		}
	}
}
