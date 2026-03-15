// lib/widgets/video_search_widget.dart
import 'package:flutter/material.dart';
import '../services/video_search_service.dart';
import '../data/video_record.dart';

class VideoSearchWidget extends StatefulWidget {
  final Function(VideoRecord)? onVideoSelected;
  final bool showSearchBar;

  const VideoSearchWidget({
    super.key,
    this.onVideoSelected,
    this.showSearchBar = true,
  });

  @override
  _VideoSearchWidgetState createState() => _VideoSearchWidgetState();
}

class _VideoSearchWidgetState extends State<VideoSearchWidget> {
  final VideoSearchService _searchService = VideoSearchService();
  final TextEditingController _searchController = TextEditingController();
  List<VideoRecord> _searchResults = [];
  bool _isSearching = false;
  bool _isInitialized = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    try {
      await _searchService.initialize();
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize video search: $e';
      });
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty || !_isInitialized) return;

    setState(() {
      _isSearching = true;
      _errorMessage = '';
    });

    try {
      final results = await _searchService.searchSimilarVideos(
        query: query,
        topN: 5,
      );

      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Search failed: $e';
        _searchResults = [];
      });
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _errorMessage = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showSearchBar) ...[
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search for educational videos...',
                      border: OutlineInputBorder(),
                      suffixIcon: _isSearching
                          ? Padding(
                        padding: EdgeInsets.all(12.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: _clearSearch,
                      ),
                    ),
                    onSubmitted: _performSearch,
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _performSearch(_searchController.text),
                  child: Text('Search'),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
        ],

        if (!_isInitialized && _errorMessage.isEmpty)
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          ),

        if (_errorMessage.isNotEmpty)
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red),
                  SizedBox(width: 8),
                  Expanded(child: Text(_errorMessage)),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => setState(() => _errorMessage = ''),
                  ),
                ],
              ),
            ),
          ),

        if (_isSearching)
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          ),

        Expanded(
          child: _searchResults.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search, size: 64, color: Colors.grey[300]),
                SizedBox(height: 16),
                Text(
                  _isInitialized
                      ? 'Search for educational videos'
                      : 'Initializing video search...',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          )
              : ListView.builder(
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final video = _searchResults[index];
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: Icon(Icons.ondemand_video, color: Colors.blue),
                  title: Text(
                    video.title,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(video.videoUrl),
                  trailing: widget.onVideoSelected != null
                      ? IconButton(
                    icon: Icon(Icons.play_arrow),
                    onPressed: () => widget.onVideoSelected!(video),
                  )
                      : null,
                  onTap: () {
                    if (widget.onVideoSelected != null) {
                      widget.onVideoSelected!(video);
                    }
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}