import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../core/brand_footer.dart';
import '../core/responsive_helper.dart';
import '../core/user_rights.dart';
import '../models/company_info.dart';
import '../services/client_service.dart';
import '../services/company_info_service.dart';
import '../services/mission_service.dart';
import '../utils/pdf_download_helper_stub.dart'
	if (dart.library.html) '../utils/pdf_download_helper_web.dart';

class BillingPageArguments {
	const BillingPageArguments({required this.missions});
	final List<Map<String, dynamic>> missions;
}

class BillingPage extends StatefulWidget {
	const BillingPage({super.key, required this.userRights});
	final UserRights userRights;

	@override
	State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
	TextEditingController? _clientFieldCtrl;
	FocusNode? _clientFocusNode;
	final GlobalKey _clientAutocompleteKey = GlobalKey();
	String _clientInput = '';
	List<String> _clientOptions = [];
	List<Map<String, dynamic>> _missions = [];
	List<Map<String, dynamic>> _allClientMissions = [];
	bool _routeArgsLoaded = false;
	bool _loadingMissions = false;
	bool _loadingClients = false;
	bool _isTableFullscreen = false;
	final ScrollController _tableVerticalController = ScrollController();
	final ScrollController _tableHorizontalController = ScrollController();
	final ScrollController _fullscreenVerticalController = ScrollController();
	final ScrollController _fullscreenHorizontalController = ScrollController();
	String? _loadError;
	String? _clientsError;
	late final List<DateTime> _availableMonths;
	late DateTime _selectedMonth;
	late final NumberFormat _currencyFormat;
	late final NumberFormat _quantityFormat;
	bool _generatingPdf = false;
	pw.Font? _pdfFontRegular;
	pw.Font? _pdfFontBold;
	pw.MemoryImage? _pdfLogoImage;
	CompanyInfo? _companyInfo;
	bool _loadingCompanyInfo = false;

	static const List<String> _monthNames = [
		'Janvier',
		'Février',
		'Mars',
		'Avril',
		'Mai',
		'Juin',
		'Juillet',
		'Août',
		'Septembre',
		'Octobre',
		'Novembre',
		'Décembre',
	];

	double? _parseDurationMinutes(dynamic raw) {
		if (raw == null) return null;
		if (raw is num) return raw.toDouble();
		final text = raw.toString().trim();
		if (text.isEmpty) return null;
		final normalized = text.replaceAll(',', '.');
		final hhmmMatch = RegExp(r'^(\d{1,2})[:hH](\d{1,2})$').firstMatch(normalized);
		if (hhmmMatch != null) {
			final hours = int.tryParse(hhmmMatch.group(1)!);
			final minutes = int.tryParse(hhmmMatch.group(2)!);
			if (hours != null && minutes != null) {
				return ((hours * 60) + minutes).toDouble();
			}
		}
		return double.tryParse(normalized);
	}

	double _quantizeMinutes(double minutes) {
		if (minutes <= 0) return 0;
		if (minutes <= 15) return 15;
		if (minutes <= 30) return 30;
		if (minutes <= 60) return 60;
		return 15 * ((minutes / 15).ceilToDouble());
	}

	double _quantityForMission(Map<String, dynamic> mission) {
		final raw = mission['quantity'] ?? mission['qty'];
		if (raw != null) {
			final parsed = double.tryParse(raw.toString());
			if (parsed != null && parsed > 0) return parsed;
		}
		final minutes = _extractDurationMinutes(mission);
		if (minutes != null && minutes > 0) {
			final quantizedMinutes = _quantizeMinutes(minutes);
			return quantizedMinutes / 60;
		}
		return 1;
	}

	double _unitPriceForMission(Map<String, dynamic> mission) {
		final productPrice = _parseAmount(mission['produit_price']);
		if (productPrice > 0) return productPrice;
		final total = _parseAmount(mission['montant_mission']);
		final qty = _quantityForMission(mission);
		if (total > 0 && qty > 0) {
			return total / qty;
		}
		return 0;
	}

	double _lineTotalFor(Map<String, dynamic> mission) {
		final total = _parseAmount(mission['montant_mission']);
		if (total > 0) return total;
		final unit = _unitPriceForMission(mission);
		final qty = _quantityForMission(mission);
		return unit * qty;
	}

	double get _totalHt => _missions.fold(0, (sum, m) => sum + _lineTotalFor(m));

	@override
	void initState() {
		super.initState();
		_currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: '€', decimalDigits: 2);
		_quantityFormat = NumberFormat('#,##0.##', 'fr_FR');
		_availableMonths = _buildAvailableMonths();
		_selectedMonth = _availableMonths.first;
		_loadClients();
		_loadCompanyInfo();
	}

	@override
	void didChangeDependencies() {
		super.didChangeDependencies();
		if (_routeArgsLoaded) return;
		_routeArgsLoaded = true;
		final args = ModalRoute.of(context)?.settings.arguments;
		if (args is BillingPageArguments && args.missions.isNotEmpty) {
			setState(() {
				_allClientMissions = args.missions.map((mission) => Map<String, dynamic>.from(mission)).toList();
				final inferredClient = (_allClientMissions.first['client_name'] ?? '').toString().trim();
				if (inferredClient.isNotEmpty) {
					_setClientInput(inferredClient);
				}
				_applyMonthFilter();
			});
		}
	}

	@override
	void dispose() {
		_clientFieldCtrl?.dispose();
		_clientFocusNode?.dispose();
		_tableVerticalController.dispose();
		_tableHorizontalController.dispose();
		_fullscreenVerticalController.dispose();
		_fullscreenHorizontalController.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		final spacing = ResponsiveHelper.getSpacing(context);
		return Scaffold(
			body: SafeArea(
				top: true,
				bottom: false,
				child: Stack(
					fit: StackFit.expand,
					children: [
						ResponsiveContainer(
							maxWidth: double.infinity,
							padding: EdgeInsets.zero,
							child: Padding(
								padding: EdgeInsets.fromLTRB(spacing, 0, spacing, spacing),
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										_buildClientSection(),
										const SizedBox(height: 4),
										Expanded(
											child: _loadingMissions
												? const Center(child: CircularProgressIndicator())
												: _missions.isEmpty
													? _buildEmptyState()
													: _buildInvoiceCard(spacing),
										),
									],
								),
							),
						),
						if (_isTableFullscreen) _buildFullscreenOverlay(spacing),
					],
				),
			),
			bottomNavigationBar: const Padding(
				padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
				child: BrandFooter(),
			),
		);
	}

	Widget _buildClientSection() {
		return Column(
			crossAxisAlignment: CrossAxisAlignment.start,
			children: [
				LayoutBuilder(
					builder: (context, constraints) {
						final isCompact = constraints.maxWidth < 960;
						final fieldWidth = isCompact ? constraints.maxWidth : 280.0;
						final monthWidth = isCompact ? constraints.maxWidth : 220.0;
						final buttonsWidth = isCompact ? constraints.maxWidth : 240.0;
						final statWidth = isCompact ? constraints.maxWidth : 150.0;
						return Wrap(
							spacing: 16,
							runSpacing: 6,
							crossAxisAlignment: WrapCrossAlignment.center,
							children: [
								_buildToolbarField(
									label: 'Client',
									width: fieldWidth,
									child: RawAutocomplete<String>(
										key: _clientAutocompleteKey,
										textEditingController: _ensureClientController(),
										focusNode: _ensureClientFocusNode(),
										displayStringForOption: (option) => option,
										optionsBuilder: (TextEditingValue value) {
											if (_clientOptions.isEmpty) return const Iterable<String>.empty();
											final query = value.text.trim().toLowerCase();
											if (query.isEmpty) return _clientOptions;
											return _clientOptions.where((option) => option.toLowerCase().contains(query));
										},
										onSelected: (selected) => setState(() => _setClientInput(selected)),
										fieldViewBuilder: (context, controller, focusNode, _) {
											return TextField(
												controller: controller,
												focusNode: focusNode,
												textInputAction: TextInputAction.search,
												onChanged: (value) => _clientInput = value,
												onSubmitted: (_) => _loadMissionsForClient(),
												decoration: InputDecoration(
													isDense: true,
													prefixIcon: const Icon(Icons.business),
													hintText: 'Sélectionner un client',
													suffixIcon: Row(
														mainAxisSize: MainAxisSize.min,
														children: [
															IconButton(
																icon: const Icon(Icons.arrow_drop_down),
																onPressed: _loadingClients ? null : _openClientOptions,
																tooltip: 'Voir les clients',
															),
															IconButton(
																icon: _loadingMissions
																	? const SizedBox(
																		width: 16,
																		height: 16,
																		child: CircularProgressIndicator(strokeWidth: 2),
																	)
																: const Icon(Icons.search),
																onPressed: _loadingMissions ? null : _loadMissionsForClient,
																tooltip: 'Charger les missions',
															),
														],
													),
												),
											);
										},
										optionsViewBuilder: (context, onSelected, options) {
											final list = options.take(30).toList();
											if (list.isEmpty) {
												return const SizedBox.shrink();
											}
											return Align(
												alignment: Alignment.topLeft,
												child: Material(
													elevation: 6,
													borderRadius: BorderRadius.circular(8),
													child: ConstrainedBox(
														constraints: const BoxConstraints(maxHeight: 300, minWidth: 280),
														child: ListView.separated(
															padding: EdgeInsets.zero,
															itemCount: list.length,
															separatorBuilder: (context, _) => const Divider(height: 1),
															itemBuilder: (context, index) {
																final option = list[index];
																return ListTile(
																	title: Text(option),
																	onTap: () => onSelected(option),
																);
															},
														),
													),
												),
											);
										},
									),
								),
								_buildToolbarField(
									label: 'Mois',
									width: monthWidth,
									child: DropdownButtonFormField<DateTime>(
										initialValue: _selectedMonth,
										decoration: const InputDecoration(
											isDense: true,
											prefixIcon: Icon(Icons.calendar_month),
										),
										items: _availableMonths
											.map(
												(month) => DropdownMenuItem<DateTime>(
													value: month,
													child: Text(_monthLabel(month)),
												),
											)
											.toList(),
										onChanged: (value) {
											if (value == null) return;
											setState(() {
												_selectedMonth = value;
												_applyMonthFilter();
											});
										},
									),
								),
								_buildToolbarButtons(width: buttonsWidth),
								SizedBox(
									width: statWidth,
									child: _buildToolbarStat('Missions sélectionnées', _missions.length.toString()),
								),
								SizedBox(
									width: statWidth,
									child: _buildToolbarStat('Total HT', _formatCurrency(_totalHt)),
								),
							],
						);
					},
				),
				if (_loadingClients)
					const Padding(
						padding: EdgeInsets.only(top: 8),
						child: LinearProgressIndicator(minHeight: 2),
					)
				else if (_clientsError != null)
					Padding(
						padding: const EdgeInsets.only(top: 8),
						child: Text(
							_clientsError!,
							style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
						),
					)
				else if (_clientOptions.isNotEmpty)
					Padding(
						padding: const EdgeInsets.only(top: 8),
						child: Text(
							'${_clientOptions.length} client(s) disponibles',
							style: const TextStyle(color: Color(0xFF4B5563), fontSize: 12),
						),
					),
				if (_loadError != null)
					Padding(
						padding: const EdgeInsets.only(top: 8),
						child: Text(
							_loadError!,
							style: const TextStyle(color: Color(0xFFB91C1C)),
						),
					),
			],
		);
	}

	Widget _buildToolbarField({required String label, required Widget child, double? width}) {
		final content = Column(
			crossAxisAlignment: CrossAxisAlignment.start,
			children: [
				Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
				const SizedBox(height: 2),
				child,
			],
		);
		if (width == null) return content;
		return SizedBox(width: width, child: content);
	}

	Widget _buildToolbarStat(String label, String value) {
		return Container(
			padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
			decoration: BoxDecoration(
				color: const Color(0xFFF9FAFB),
				borderRadius: BorderRadius.circular(8),
				border: Border.all(color: const Color(0xFFE5E7EB)),
			),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
					const SizedBox(height: 2),
					Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
				],
			),
		);
	}

	Widget _buildToolbarButtons({double? width}) {
		final buttons = Wrap(
			spacing: 10,
			runSpacing: 10,
			alignment: WrapAlignment.end,
			children: [
				ElevatedButton.icon(
					onPressed: _loadingMissions ? null : _loadMissionsForClient,
					icon: _loadingMissions
						? const SizedBox(
							width: 16,
							height: 16,
							child: CircularProgressIndicator(strokeWidth: 2),
						)
						: const Icon(Icons.sync),
					label: Text(_loadingMissions ? 'Chargement...' : 'Charger les missions'),
				),
				FilledButton.icon(
					onPressed: (_missions.isEmpty || _generatingPdf) ? null : _generatePdfFromTable,
					icon: _generatingPdf
						? const SizedBox(
							width: 16,
							height: 16,
							child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
						)
						: const Icon(Icons.picture_as_pdf_outlined),
					label: Text(_generatingPdf ? 'Préparation...' : 'Générer facture en PDF'),
				),
			],
		);
		if (width == null) return buttons;
		return SizedBox(width: width, child: buttons);
	}

	Widget _buildFullscreenOverlay(double spacing) {
		return Positioned.fill(
			child: Material(
				color: Colors.black.withValues(alpha: 0.55),
				child: SafeArea(
					child: Padding(
						padding: EdgeInsets.all(spacing),
						child: Column(
							children: [
								Align(
									alignment: Alignment.centerRight,
									child: FilledButton.icon(
										onPressed: () => _toggleTableFullscreen(false),
										icon: const Icon(Icons.close_fullscreen),
										label: const Text('Quitter le plein écran'),
									),
								),
								const SizedBox(height: 12),
								Expanded(child: _buildInvoiceCard(spacing, fullscreen: true)),
							],
						),
					),
				),
			),
		);
	}

	Widget _buildInvoiceCard(double spacing, {bool fullscreen = false}) {
		final borderRadius = fullscreen ? 10.0 : 6.0;
		final verticalController = fullscreen ? _fullscreenVerticalController : _tableVerticalController;
		final horizontalController = fullscreen ? _fullscreenHorizontalController : _tableHorizontalController;
		return Card(
			elevation: fullscreen ? 4 : 0,
			margin: EdgeInsets.zero,
			shape: RoundedRectangleBorder(
				borderRadius: BorderRadius.circular(borderRadius),
				side: BorderSide(color: fullscreen ? Colors.transparent : const Color(0xFFE5E7EB)),
			),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.stretch,
				children: [
					Container(
						padding: EdgeInsets.symmetric(horizontal: spacing, vertical: spacing / 1.5),
						decoration: BoxDecoration(
							color: Colors.white,
							borderRadius: BorderRadius.vertical(top: Radius.circular(borderRadius)),
						),
						child: Row(
							children: [
								const Icon(Icons.table_rows, color: Color(0xFF000091)),
								const SizedBox(width: 8),
								const Text(
									'Détail des lignes de facturation',
									style: TextStyle(fontWeight: FontWeight.w700),
								),
								const Spacer(),
								Text('${_missions.length} ligne(s)'),
								IconButton(
									icon: Icon(fullscreen ? Icons.fullscreen_exit : Icons.fullscreen),
									onPressed: () => _toggleTableFullscreen(!fullscreen),
									tooltip: fullscreen ? 'Quitter le plein écran' : 'Afficher en plein écran',
								),
							],
						),
					),
					const Divider(height: 1, color: Color(0xFFE5E7EB)),
					Expanded(
						child: LayoutBuilder(
							builder: (context, constraints) {
								final viewportWidth = constraints.hasBoundedWidth ? constraints.maxWidth : MediaQuery.of(context).size.width;
								final tableWidth = math.max(viewportWidth, 960.0);
								const fractions = <double>[0.14, 0.34, 0.1, 0.14, 0.1, 0.18];
								final List<double> columnWidths =
									fractions.map((ratio) => tableWidth * ratio).toList();
								return Scrollbar(
									controller: verticalController,
									thumbVisibility: true,
									child: SingleChildScrollView(
										controller: verticalController,
										scrollDirection: Axis.vertical,
										child: SingleChildScrollView(
											controller: horizontalController,
											scrollDirection: Axis.horizontal,
											child: ConstrainedBox(
												constraints: BoxConstraints(minWidth: tableWidth),
												child: DataTable(
													columnSpacing: 12,
													headingRowHeight: 42,
													dataRowMinHeight: 60,
													dataRowMaxHeight: 140,
													columns: [
														DataColumn(label: SizedBox(width: columnWidths[0], child: const Text('Ref. mission'))),
														DataColumn(label: SizedBox(width: columnWidths[1], child: const Text('Désignation'))),
														DataColumn(label: SizedBox(width: columnWidths[2], child: const Text('TVA'))),
														DataColumn(label: SizedBox(width: columnWidths[3], child: const Text('P.U. HT'))),
														DataColumn(label: SizedBox(width: columnWidths[4], child: const Text('Qté'))),
														DataColumn(label: SizedBox(width: columnWidths[5], child: const Text('Total HT'))),
													],
													rows: _missions.map((mission) => _buildRow(mission, columnWidths)).toList(),
												),
											),
										),
									),
								);
							},
						),
					),
					const Divider(height: 1, color: Color(0xFFE5E7EB)),
					Padding(
						padding: EdgeInsets.symmetric(horizontal: spacing, vertical: spacing / 1.5),
						child: Align(
							alignment: Alignment.centerRight,
							child: Text(
								'Total HT: ${_formatCurrency(_totalHt)}',
								style: const TextStyle(
									fontWeight: FontWeight.w700,
									color: Color(0xFF000091),
									fontSize: 16,
								),
							),
						),
					),
				],
			),
		);
	}

	DataRow _buildRow(Map<String, dynamic> mission, List<double> columnWidths) {
		final ref = (mission['reference_devis'] ?? '').toString();
		final designation = _designationFor(mission);
		final tva = _formatTva(mission);
		final unitPrice = _unitPriceForMission(mission);
		final qty = _quantityForMission(mission);
		final lineTotal = _lineTotalFor(mission);
		return DataRow(
			cells: [
				_buildSelectableCell(ref.isEmpty ? '-' : ref, width: columnWidths[0]),
				_buildDesignationCell(mission, designation, columnWidths[1]),
				_buildSelectableCell(tva, width: columnWidths[2], align: TextAlign.center),
				_buildSelectableCell(_formatCurrency(unitPrice), width: columnWidths[3], align: TextAlign.right),
				_buildSelectableCell(_formatQuantity(qty), width: columnWidths[4], align: TextAlign.right),
				_buildSelectableCell(_formatCurrency(lineTotal), width: columnWidths[5], align: TextAlign.right),
			],
		);
	}

	DataCell _buildDesignationCell(Map<String, dynamic> mission, String fallback, double width) {
		final lines = _designationLinesForUi(mission);
		final content = lines.isEmpty ? fallback : lines.join('\n');
		return DataCell(
			SizedBox(
				width: width,
				child: SelectableText(
					content,
					style: const TextStyle(height: 1.35),
				),
			),
		);
	}

	DataCell _buildSelectableCell(String value, {double? width, TextAlign align = TextAlign.left}) {
		final widget = SelectableText(
			value,
			textAlign: align,
			style: const TextStyle(height: 1.2),
		);
		if (width != null) {
			return DataCell(SizedBox(width: width, child: widget));
		}
		return DataCell(widget);
	}

	Widget _buildEmptyState() {
		return Center(
			child: Column(
				mainAxisSize: MainAxisSize.min,
				children: const [
					Icon(Icons.inbox_outlined, size: 48, color: Color(0xFF9CA3AF)),
					SizedBox(height: 12),
					Text('Aucune mission à afficher', style: TextStyle(fontWeight: FontWeight.w600)),
					SizedBox(height: 4),
					Text(
						'Saisissez un client, choisissez un mois puis cliquez sur "Charger les missions" pour préparer la facture.',
						textAlign: TextAlign.center,
					),
				],
			),
		);
	}

	Future<void> _loadMissionsForClient() async {
		final client = _currentClientName;
		if (client.isEmpty) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Veuillez sélectionner un client dans la liste (ou taper pour filtrer).')),
			);
			_openClientOptions();
			_clientFocusNode?.requestFocus();
			return;
		}
		setState(() {
			_loadingMissions = true;
			_loadError = null;
		});
		final normalized = client.toLowerCase();
		try {
			final missions = await MissionService.getMissionsDatatableAll(q: client);
			if (!mounted) return;
			final filtered = missions
				.where((mission) => _missionMatchesClient(mission, normalized))
				.map((mission) => Map<String, dynamic>.from(mission))
				.toList();
			setState(() {
				_allClientMissions = filtered;
				_applyMonthFilter();
				_loadingMissions = false;
			});
			if (filtered.isEmpty) {
				ScaffoldMessenger.of(context).showSnackBar(
					const SnackBar(content: Text('Aucune mission trouvée pour ce client sur les 12 derniers mois.')),
				);
			}
		} catch (_) {
			if (!mounted) return;
			setState(() {
				_loadingMissions = false;
				_allClientMissions = [];
				_missions = [];
				_loadError = 'Impossible de récupérer les missions (connexion ou API).';
			});
		}
	}

	Future<void> _generatePdfFromTable() async {
		if (_missions.isEmpty) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Chargez des missions avant de générer un PDF.')),
			);
			return;
		}
		setState(() => _generatingPdf = true);
		try {
			await _ensurePdfAssets();
			final headers = ['Désignation', 'TVA', 'P.U. HT', 'Qté', 'Total HT'];
			final rows = _missions
				.map(
					(mission) => [
						_designationFor(mission),
						_formatTva(mission),
						_formatCurrency(_unitPriceForMission(mission)),
						_formatQuantity(_quantityForMission(mission)),
						_formatCurrency(_lineTotalFor(mission)),
					],
				)
				.toList();
			final clientLabel = _currentClientName.isEmpty ? 'Client non renseigné' : _currentClientName;
			final clientAddressLines = _clientAddressLinesForPdf();
			final now = DateTime.now();
			final theme = pw.ThemeData.withFont(base: _pdfFontRegular!, bold: _pdfFontBold!);
			final doc = pw.Document(theme: theme);
			final accent = PdfColor.fromHex('#000091');
			final borderColor = PdfColor.fromHex('#E5E7EB');
			final companyInfo = _resolvedCompanyInfo;
			final companyLines = _companyInfoLinesForPdf(companyInfo);
			final hasLogo = _pdfLogoImage != null;
			final logoWidget = hasLogo
				? pw.Container(
					margin: const pw.EdgeInsets.only(bottom: 8),
					height: 48,
					child: pw.Image(_pdfLogoImage!, fit: pw.BoxFit.contain),
				)
				: null;
			final companyCard = (companyLines.isEmpty && !hasLogo)
				? null
				: pw.Container(
					padding: const pw.EdgeInsets.all(12),
					decoration: pw.BoxDecoration(
						color: PdfColor.fromHex('#F9FAFB'),
						borderRadius: pw.BorderRadius.circular(8),
						border: pw.Border.all(color: borderColor, width: 0.5),
					),
					child: pw.Column(
						crossAxisAlignment: pw.CrossAxisAlignment.start,
						children: [
							pw.Text(
								'Emetteur',
								style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: accent),
							),
							pw.SizedBox(height: 4),
							...companyLines.map(
								(line) => pw.Text(line, style: const pw.TextStyle(fontSize: 11)),
							),
						],
					),
				);
			final clientCard = pw.Container(
				padding: const pw.EdgeInsets.all(12),
				decoration: pw.BoxDecoration(
					color: PdfColor.fromHex('#FDF2F8'),
					borderRadius: pw.BorderRadius.circular(8),
					border: pw.Border.all(color: PdfColor.fromHex('#FBCFE8'), width: 0.5),
				),
				child: pw.Column(
					crossAxisAlignment: pw.CrossAxisAlignment.start,
					children: [
						pw.Text(
							'Destinataire',
							style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#BE185D')),
						),
						pw.SizedBox(height: 4),
						pw.Text(
							clientLabel,
							style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13),
						),
						if (clientAddressLines.isNotEmpty) ...[
							pw.SizedBox(height: 2),
							...clientAddressLines.map(
								(line) => pw.Text(line, style: const pw.TextStyle(fontSize: 11)),
							),
						],
						pw.SizedBox(height: clientAddressLines.isNotEmpty ? 6 : 2),
						pw.Text('Période : ${_monthLabel(_selectedMonth)}', style: const pw.TextStyle(fontSize: 11)),
						pw.Text('Lignes sélectionnées : ${_missions.length}', style: const pw.TextStyle(fontSize: 11)),
						pw.Text('Total HT estimé : ${_formatCurrency(_totalHt)}', style: const pw.TextStyle(fontSize: 11)),
					],
				),
			);
			final headerColumns = <pw.Widget>[];
			if (companyCard != null) {
				headerColumns.add(pw.Expanded(flex: 3, child: companyCard));
			}
			if (companyCard != null) {
				headerColumns.add(pw.SizedBox(width: 14));
			}
			headerColumns.add(pw.Expanded(flex: 3, child: clientCard));
			final headerStack = <pw.Widget>[];
			if (logoWidget != null) {
				headerStack.add(
					pw.Align(
						alignment: pw.Alignment.centerLeft,
						child: logoWidget,
					),
				);
			}
			headerStack.add(
				pw.Row(
					crossAxisAlignment: pw.CrossAxisAlignment.start,
					children: headerColumns,
				),
			);
			doc.addPage(
				pw.MultiPage(
					pageFormat: PdfPageFormat.a4,
					margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 40),
					build: (context) => [
						pw.SizedBox(height: 6),
						...headerStack,
						pw.SizedBox(height: 16),
						pw.TableHelper.fromTextArray(
							headers: headers,
							data: rows,
							border: pw.TableBorder.symmetric(
								inside: pw.BorderSide(color: borderColor, width: 0.25),
								outside: pw.BorderSide(color: borderColor, width: 0.5),
							),
							headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
							headerDecoration: pw.BoxDecoration(color: accent),
							cellStyle: const pw.TextStyle(fontSize: 10.5),
							cellAlignments: {
								0: pw.Alignment.centerLeft,
								1: pw.Alignment.center,
								2: pw.Alignment.centerRight,
								3: pw.Alignment.centerRight,
								4: pw.Alignment.centerRight,
							},
							columnWidths: {
								0: const pw.FlexColumnWidth(3.2),
								1: const pw.FlexColumnWidth(1.0),
								2: const pw.FlexColumnWidth(1.2),
								3: const pw.FlexColumnWidth(1.0),
								4: const pw.FlexColumnWidth(1.2),
							},
						),
						pw.SizedBox(height: 12),
						pw.Align(
							alignment: pw.Alignment.centerRight,
							child: pw.Text(
								'Total HT : ${_formatCurrency(_totalHt)}',
								style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: accent),
							),
						),
						pw.SizedBox(height: 6),
						pw.Text(
							'Document généré le ${DateFormat('dd/MM/yyyy HH:mm').format(now)}',
							style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#6B7280')),
						),
					],
				),
			);
			final Uint8List bytes = await doc.save();
			final filename = 'facture_${DateFormat('yyyyMMdd_HHmmss').format(now)}.pdf';
			if (canSavePdfToDownloads) {
				await savePdfToDownloads(bytes, filename);
			} else {
				await Printing.layoutPdf(name: filename, onLayout: (_) async => bytes);
			}
		} catch (e, stack) {
			debugPrint('PDF generation failed: $e');
			debugPrint(stack.toString());
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Impossible de générer le PDF. Veuillez réessayer.')),
			);
		} finally {
			if (mounted) {
				setState(() => _generatingPdf = false);
			}
		}
	}

	Future<void> _ensurePdfAssets() async {
		_pdfFontRegular ??= await PdfGoogleFonts.openSansRegular();
		_pdfFontBold ??= await PdfGoogleFonts.openSansBold();
		if (_pdfLogoImage == null) {
			try {
				final data = await rootBundle.load('assets/logo.png');
				_pdfLogoImage = pw.MemoryImage(data.buffer.asUint8List());
			} catch (_) {
				_pdfLogoImage = null;
			}
		}
	}

	List<DateTime> _buildAvailableMonths({int monthsBack = 12}) {
		final now = DateTime.now();
		return List<DateTime>.generate(monthsBack, (index) {
			final date = DateTime(now.year, now.month - index, 1);
			return DateTime(date.year, date.month);
		});
	}

	String _monthLabel(DateTime month) {
		final index = (month.month - 1).clamp(0, _monthNames.length - 1);
		return '${_monthNames[index]} ${month.year}';
	}

	TextEditingController _ensureClientController() {
		_clientFieldCtrl ??= TextEditingController(text: _clientInput);
		return _clientFieldCtrl!;
	}

	FocusNode _ensureClientFocusNode() {
		_clientFocusNode ??= FocusNode();
		return _clientFocusNode!;
	}

	void _setClientInput(String value) {
		_clientInput = value;
		final controller = _clientFieldCtrl;
		if (controller != null && controller.text != value) {
			controller.text = value;
			controller.selection = TextSelection.collapsed(offset: controller.text.length);
		}
	}

	String get _currentClientName => _clientInput.trim();

	void _openClientOptions() {
		if (_clientOptions.isEmpty && !_loadingClients) {
			_loadClients();
		}
		final controller = _ensureClientController();
		final focusNode = _ensureClientFocusNode();
		if (!focusNode.hasFocus) {
			focusNode.requestFocus();
		}
		controller.value = controller.value.copyWith(
			text: controller.text,
			selection: TextSelection.collapsed(offset: controller.text.length),
		);
	}

	void _toggleTableFullscreen(bool value) {
		if (_isTableFullscreen == value) return;
		setState(() => _isTableFullscreen = value);
	}

	Future<void> _loadCompanyInfo() async {
		if (_loadingCompanyInfo) return;
		setState(() {
			_loadingCompanyInfo = true;
		});
		try {
			final info = await CompanyInfoService.fetch();
			if (!mounted) return;
			setState(() {
				_companyInfo = info;
				_loadingCompanyInfo = false;
			});
		} catch (error, stack) {
			debugPrint('Failed to load company info: $error');
			debugPrint(stack.toString());
			if (!mounted) return;
			setState(() {
				_companyInfo = CompanyInfo.fallback();
				_loadingCompanyInfo = false;
			});
		}
	}

	Future<void> _loadClients() async {
		if (_loadingClients) return;
		setState(() {
			_loadingClients = true;
			_clientsError = null;
		});
		try {
			final clients = await ClientService.getClients(limit: 500);
			if (!mounted) return;
			final seen = <String>{};
			final deduped = <String>[];
			for (final client in clients) {
				final trimmed = client.trim();
				if (trimmed.isEmpty) continue;
				final key = trimmed.toLowerCase();
				if (seen.add(key)) {
					deduped.add(trimmed);
				}
			}
			deduped.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
			setState(() {
				_clientOptions = deduped;
				_loadingClients = false;
			});
		} catch (_) {
			if (!mounted) return;
			setState(() {
				_loadingClients = false;
				_clientsError = 'Impossible de charger les clients.';
			});
		}
	}

	void _applyMonthFilter() {
		final filtered = _allClientMissions.where((mission) {
			final date = _missionDate(mission);
			if (date == null) return false;
			return date.year == _selectedMonth.year && date.month == _selectedMonth.month;
		}).toList();
		filtered.sort((a, b) {
			final dateA = _missionDate(a);
			final dateB = _missionDate(b);
			if (dateA == null && dateB == null) return 0;
			if (dateA == null) return 1;
			if (dateB == null) return -1;
			return dateB.compareTo(dateA);
		});
		_missions = filtered;
	}

	DateTime? _missionDate(Map<String, dynamic> mission) {
		final candidates = [
			mission['datemission_iso'],
			mission['datemission'],
			mission['date_mission'],
			mission['mission_date'],
			mission['date'],
		];
		for (final raw in candidates) {
			final parsed = _parseDate(raw);
			if (parsed != null) return parsed;
		}
		return null;
	}

	DateTime? _parseDate(dynamic raw) {
		if (raw == null) return null;
		if (raw is DateTime) return raw;
		if (raw is int) {
			if (raw.toString().length > 10) {
				return DateTime.fromMillisecondsSinceEpoch(raw);
			}
			return DateTime.fromMillisecondsSinceEpoch(raw * 1000);
		}
		if (raw is String) {
			final text = raw.trim();
			if (text.isEmpty) return null;
			try {
				return DateTime.parse(text.replaceAll(' ', 'T'));
			} catch (_) {
				for (final pattern in ['dd/MM/yyyy', 'dd/MM/yyyy HH:mm']) {
					try {
						return DateFormat(pattern).parseStrict(text);
					} catch (_) {
						continue;
					}
				}
			}
		}
		return null;
	}

	bool _missionMatchesClient(Map<String, dynamic> mission, String normalizedClient) {
		final clientName = (mission['client_name'] ?? mission['nom'] ?? mission['company'] ?? '').toString().toLowerCase();
		if (clientName.contains(normalizedClient)) return true;
		final ref = (mission['reference_devis'] ?? mission['ref'] ?? '').toString().toLowerCase();
		return ref.contains(normalizedClient);
	}

	String _formatCurrency(double value) {
		final formatted = _currencyFormat.format(value);
		return formatted.replaceAll('\u00A0', ' ').replaceAll('\u202F', ' ');
	}

	String _formatQuantity(double value) {
		final formatted = _quantityFormat.format(value);
		return formatted.replaceAll('\u00A0', ' ').replaceAll('\u202F', ' ');
	}

	String _formatTva(Map<String, dynamic> mission) {
		final raw = mission['produit_tva_tx'] ?? mission['tva_tx'] ?? mission['tva'];
		final value = raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '');
		if (value == null || value <= 0) return '0 %';
		return '${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2)} %';
	}

	String _designationFor(Map<String, dynamic> mission) {
		return _designationLines(mission).join('\n');
	}

	String _formatMissionDuration(Map<String, dynamic> mission) {
		final raw = mission['dureemission'] ?? mission['duration'] ?? mission['duration_minutes'];
		final parsed = _parseDurationMinutes(raw);
		if (parsed == null || parsed <= 0) return '';
		if (parsed % 60 == 0) {
			return '${(parsed / 60).round()}h';
		}
		return '${parsed.round()} min';
	}

	List<String> _designationLinesForUi(Map<String, dynamic> mission) {
		return _designationLines(mission);
	}

	List<String> _designationLines(Map<String, dynamic> mission) {
		final lines = <String>[];
		final produitLabel = mission['produit_label']?.toString().trim();
		final produitRef = mission['produit_ref']?.toString().trim();
		final title = (produitLabel != null && produitLabel.isNotEmpty)
			? produitLabel
			: ((produitRef != null && produitRef.isNotEmpty) ? produitRef : 'Mission');
		lines.add(title);
		final date = _missionDate(mission);
		final dateLabel = date != null ? DateFormat('dd/MM/yyyy').format(date) : '-';
		lines.add('Date : $dateLabel');
		final timeRange = _timeRangeLabel(mission);
		lines.add('Heure : ${timeRange.isNotEmpty ? timeRange : '-'}');
		final duration = _formatMissionDuration(mission);
		lines.add('Durée : ${duration.isNotEmpty ? duration : '-'}');
		final requester = _missionRequester(mission);
		lines.add('Demandeur : ${requester.isNotEmpty ? requester : '-'}');
		return lines;
	}

	String _timeRangeLabel(Map<String, dynamic> mission) {
		final start = (mission['heuredebutmission'] ?? mission['heure_debut'] ?? mission['start_time'] ?? '').toString().trim();
		final end = (mission['heurefinmission'] ?? mission['heure_fin'] ?? mission['end_time'] ?? '').toString().trim();
		if (start.isEmpty && end.isEmpty) return '';
		if (start.isNotEmpty && end.isNotEmpty) {
			return '$start → $end';
		}
		return start.isNotEmpty ? start : end;
	}

	String _missionRequester(Map<String, dynamic> mission) {
		final firstCandidates = [
			mission['prenom_demandeur'],
			mission['contactdemandeur_firstname'],
			mission['demandeur_firstname'],
		];
		final lastCandidates = [
			mission['nom_demandeur'],
			mission['contactdemandeur_lastname'],
			mission['demandeur_lastname'],
		];
		final firstName = _cleanPersonPart(firstCandidates);
		final lastName = _cleanPersonPart(lastCandidates);
		if (firstName != null && lastName != null) {
			return '${_capitalize(firstName)} ${lastName.toUpperCase()}';
		}
		final combinedCandidates = [
			mission['demandeur'],
			mission['contactdemandeur_name'],
		];
		for (final raw in combinedCandidates) {
			final value = raw?.toString().trim();
			if (value != null && value.isNotEmpty) {
				return value;
			}
		}
		return firstName ?? lastName ?? '';
	}

	String? _cleanPersonPart(List<dynamic> inputs) {
		for (final raw in inputs) {
			final value = raw?.toString().trim();
			if (value != null && value.isNotEmpty) {
				return value;
			}
		}
		return null;
	}

	String _capitalize(String input) {
		if (input.isEmpty) return input;
		return input[0].toUpperCase() + input.substring(1).toLowerCase();
	}

	CompanyInfo get _resolvedCompanyInfo => _companyInfo ?? CompanyInfo.fallback();

	List<String> _companyInfoMetaLines(CompanyInfo info) {
		final lines = <String>[];
		final siret = info.siret.trim();
		if (siret.isNotEmpty) {
			lines.add('SIRET : $siret');
		}
		final phone = info.phone.trim();
		if (phone.isNotEmpty) {
			lines.add('Tél. : $phone');
		}
		final email = info.email.trim();
		if (email.isNotEmpty) {
			lines.add('Email : $email');
		}
		final website = info.website.trim();
		if (website.isNotEmpty) {
			lines.add('Site : $website');
		}
		return lines;
	}

	List<String> _companyInfoLinesForPdf(CompanyInfo info) {
		final lines = <String>[];
		final name = info.name.trim();
		if (name.isNotEmpty) {
			lines.add(name);
		}
		lines.addAll(info.addressLines);
		lines.addAll(_companyInfoMetaLines(info));
		return lines;
	}

	List<String> _clientAddressLinesForPdf() {
		final mission = _missionWithClientDetails();
		if (mission == null) return [];
		final lines = <String>[];
		final address1 = _stringValueFromKeys(mission, const [
			'client_address',
			'client_address_line1',
			'client_address1',
			'adresse_client',
			'adresse',
			'address',
		]);
		final address2 = _stringValueFromKeys(mission, const [
			'client_address2',
			'client_address_line2',
			'adresse_client2',
			'adresse2',
			'address2',
		]);
		final zip = _stringValueFromKeys(mission, const ['client_zip', 'zip', 'cp']);
		final city = _stringValueFromKeys(mission, const ['client_town', 'client_city', 'ville', 'town', 'city']);
		if (address1.isNotEmpty) {
			lines.add(address1);
		}
		if (address2.isNotEmpty && address2 != address1) {
			lines.add(address2);
		}
		final cityLine = [zip, city].where((part) => part.isNotEmpty).join(' ');
		if (cityLine.isNotEmpty) {
			lines.add(cityLine);
		}
		return lines;
	}

	Map<String, dynamic>? _missionWithClientDetails() {
		for (final mission in _missions) {
			if (_hasClientAddressData(mission)) return mission;
		}
		if (_missions.isNotEmpty) return _missions.first;
		for (final mission in _allClientMissions) {
			if (_hasClientAddressData(mission)) return mission;
		}
		return _allClientMissions.isNotEmpty ? _allClientMissions.first : null;
	}

	bool _hasClientAddressData(Map<String, dynamic> mission) {
		return _stringValueFromKeys(mission, const [
			'client_address',
			'client_address_line1',
			'client_address1',
			'adresse_client',
			'adresse',
			'address',
		])
				.isNotEmpty ||
			_stringValueFromKeys(mission, const ['client_zip', 'zip', 'cp', 'client_town', 'client_city', 'ville', 'town', 'city']).isNotEmpty;
	}

	String _stringValueFromKeys(Map<String, dynamic> mission, List<String> keys) {
		for (final key in keys) {
			final value = mission[key];
			if (value == null) continue;
			final text = value.toString().trim();
			if (text.isNotEmpty) {
				return text;
			}
		}
		return '';
	}

	double _parseAmount(dynamic raw) {
		if (raw == null) return 0;
		if (raw is num) return raw.toDouble();
		final cleaned = raw.toString().replaceAll(RegExp(r'[^0-9,.-]'), '').replaceAll(',', '.');
		return double.tryParse(cleaned) ?? 0;
	}

	double? _extractDurationMinutes(Map<String, dynamic> mission) {
		final direct = mission['dureemission'] ?? mission['duration'] ?? mission['duration_minutes'];
		final parsed = _parseDurationMinutes(direct);
		if (parsed != null) return parsed;
		final startRaw = mission['heuredebutmission'] ?? mission['heure_debut'] ?? mission['start_time'];
		final endRaw = mission['heurefinmission'] ?? mission['heure_fin'] ?? mission['end_time'];
		if (startRaw == null || endRaw == null) return null;
		final start = _parseTimeOfDay(startRaw.toString());
		final end = _parseTimeOfDay(endRaw.toString());
		if (start == null || end == null) return null;
		var duration = end.difference(start).inMinutes;
		if (duration <= 0) {
			duration = end.add(const Duration(days: 1)).difference(start).inMinutes;
		}
		return duration > 0 ? duration.toDouble() : null;
	}

	DateTime? _parseTimeOfDay(String input) {
		final match = RegExp(r'^(\d{1,2})[:hH](\d{1,2})$').firstMatch(input.trim());
		if (match == null) return null;
		final hours = int.tryParse(match.group(1)!);
		final minutes = int.tryParse(match.group(2)!);
		if (hours == null || minutes == null) return null;
		return DateTime(2000, 1, 1, hours, minutes);
	}
}
