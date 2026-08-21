import 'package:flutter/material.dart';

import '../../widgets/app_skeleton.dart';
import 'admin_models.dart';
import 'admin_navigation.dart';
import 'admin_service.dart';
import 'widgets/admin_shared.dart';

enum _DocumentReviewFilter {
  all,
  drivers,
  passengers;

  String get label => switch (this) {
    _DocumentReviewFilter.all => 'All reviews',
    _DocumentReviewFilter.drivers => 'Drivers',
    _DocumentReviewFilter.passengers => 'Passengers',
  };
}

enum _DocumentReviewSort {
  newest,
  alphabetical;

  String get label => switch (this) {
    _DocumentReviewSort.newest => 'Newest submission',
    _DocumentReviewSort.alphabetical => 'Alphabetical',
  };
}

class AdminDocumentReviewsPage extends StatefulWidget {
  final String adminId;

  const AdminDocumentReviewsPage({super.key, required this.adminId});

  @override
  State<AdminDocumentReviewsPage> createState() =>
      _AdminDocumentReviewsPageState();
}

class _AdminDocumentReviewsPageState extends State<AdminDocumentReviewsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  _DocumentReviewFilter _filter = _DocumentReviewFilter.all;
  _DocumentReviewSort _sort = _DocumentReviewSort.newest;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminUi.background,
      appBar: const AdminDetailAppBar(title: 'Document Reviews'),
      body: AdminPageContainer(
        maxContentWidth: AdminUi.listContentWidth,
        child: StreamBuilder<List<AdminUserRecord>>(
          stream: AdminService.watchUsers(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const AdminErrorCard(
                message: 'Unable to load document reviews. Please try again.',
              );
            }
            if (!snapshot.hasData) {
              return const AppSkeletonList(padding: EdgeInsets.zero);
            }

            final allReviews = snapshot.data!
                .where((user) => user.hasReviewOnlySubmission)
                .toList(growable: false);
            final visibleReviews = allReviews
                .where(_matchesRoleFilter)
                .where(_matchesSearch)
                .toList(growable: false);
            _sortReviews(visibleReviews);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AdminCountPageHeader(
                  title: 'Document Reviews',
                  subtitle:
                      'Review document, identity, vehicle, and renewal updates without changing verified account access.',
                  count: allReviews.length.toString(),
                  countLabel: 'Pending Reviews',
                  accentColor: AdminUi.highlightAmber,
                ),
                const SizedBox(height: 12),
                _DocumentReviewControls(
                  searchController: _searchController,
                  filter: _filter,
                  sort: _sort,
                  onFilterChanged: (value) => setState(() => _filter = value),
                  onSortChanged: (value) => setState(() => _sort = value),
                ),
                const SizedBox(height: 18),
                Text('Review-only Queue', style: AdminUi.sectionTitle),
                const SizedBox(height: 6),
                Text(
                  'These users remain verified while their submitted changes wait for an admin decision.',
                  style: AdminUi.bodyText,
                ),
                const SizedBox(height: 12),
                if (visibleReviews.isEmpty)
                  AdminEmptyCollection(
                    icon: Icons.fact_check_outlined,
                    title: allReviews.isEmpty
                        ? 'No document reviews waiting'
                        : 'No matching reviews found',
                    description: allReviews.isEmpty
                        ? 'Verified-user document updates and driver renewals will appear here.'
                        : 'Try another search term or review filter.',
                  )
                else
                  ...visibleReviews.map(
                    (user) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AdminQueueUserTile(
                        user: user,
                        detail: _reviewLabel(user),
                        onView: () => AdminNavigation.openUserReview(
                          context,
                          adminId: widget.adminId,
                          userId: user.userId,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  bool _matchesRoleFilter(AdminUserRecord user) => switch (_filter) {
    _DocumentReviewFilter.all => true,
    _DocumentReviewFilter.drivers => user.isDriver,
    _DocumentReviewFilter.passengers => user.isPassenger,
  };

  bool _matchesSearch(AdminUserRecord user) {
    if (_query.isEmpty) return true;
    return <String>[
      user.fullName,
      user.email,
      user.roleLabel,
      user.statusLabel,
      _reviewLabel(user),
    ].join(' ').toLowerCase().contains(_query);
  }

  void _sortReviews(List<AdminUserRecord> users) {
    switch (_sort) {
      case _DocumentReviewSort.newest:
        users.sort((a, b) => _submittedAt(b).compareTo(_submittedAt(a)));
      case _DocumentReviewSort.alphabetical:
        users.sort(
          (a, b) =>
              a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
        );
    }
  }

  DateTime _submittedAt(AdminUserRecord user) =>
      user.documentReviewSubmittedAt ??
      user.driverDocumentStatus.renewalSubmittedAt ??
      user.createdAt ??
      DateTime.fromMillisecondsSinceEpoch(0);

  String _reviewLabel(AdminUserRecord user) {
    if (user.hasPendingDocumentReview) {
      return user.pendingDocumentReviewLabel;
    }
    return 'Driver document renewal';
  }
}

class _DocumentReviewControls extends StatelessWidget {
  final TextEditingController searchController;
  final _DocumentReviewFilter filter;
  final _DocumentReviewSort sort;
  final ValueChanged<_DocumentReviewFilter> onFilterChanged;
  final ValueChanged<_DocumentReviewSort> onSortChanged;

  const _DocumentReviewControls({
    required this.searchController,
    required this.filter,
    required this.sort,
    required this.onFilterChanged,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 720;
    final search = TextField(
      controller: searchController,
      textInputAction: TextInputAction.search,
      decoration: AdminUi.inputDecoration(
        hintText: 'Search by name, email, role, or review type',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: searchController.text.isEmpty
            ? null
            : IconButton(
                onPressed: searchController.clear,
                icon: const Icon(Icons.close_rounded),
              ),
      ),
    );
    final filterField = DropdownButtonFormField<_DocumentReviewFilter>(
      value: filter,
      isExpanded: true,
      decoration: AdminUi.inputDecoration(
        hintText: '',
        labelText: 'Users',
        prefixIcon: const Icon(Icons.filter_alt_outlined),
      ),
      items: _DocumentReviewFilter.values
          .map(
            (value) => DropdownMenuItem<_DocumentReviewFilter>(
              value: value,
              child: Text(value.label),
            ),
          )
          .toList(growable: false),
      onChanged: (value) {
        if (value != null) onFilterChanged(value);
      },
    );
    final sortField = DropdownButtonFormField<_DocumentReviewSort>(
      value: sort,
      isExpanded: true,
      decoration: AdminUi.inputDecoration(
        hintText: '',
        labelText: 'Sort',
        prefixIcon: const Icon(Icons.sort_rounded),
      ),
      items: _DocumentReviewSort.values
          .map(
            (value) => DropdownMenuItem<_DocumentReviewSort>(
              value: value,
              child: Text(value.label),
            ),
          )
          .toList(growable: false),
      onChanged: (value) {
        if (value != null) onSortChanged(value);
      },
    );

    if (compact) {
      return Column(
        children: <Widget>[
          search,
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(child: filterField),
              const SizedBox(width: 10),
              Expanded(child: sortField),
            ],
          ),
        ],
      );
    }

    return Row(
      children: <Widget>[
        Expanded(child: search),
        const SizedBox(width: 12),
        SizedBox(width: 190, child: filterField),
        const SizedBox(width: 12),
        SizedBox(width: 220, child: sortField),
      ],
    );
  }
}
