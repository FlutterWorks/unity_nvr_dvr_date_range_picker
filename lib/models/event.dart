/*
 * This file is a part of Bluecherry Client (https://https://github.com/bluecherrydvr/bluecherry_client).
 *
 * Copyright 2022 Bluecherry, LLC
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 3 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

import 'package:bluecherry_client/models/server.dart';

/// An [Event] received from the [Server] logs.
class Event {
  final Server server;
  final int id;
  final String title;
  final DateTime published;
  final DateTime updated;
  final String? category;
  final int mediaID;
  final Duration mediaDuration;
  final Uri mediaURL;

  Event(
    this.server,
    this.id,
    this.title,
    this.published,
    this.updated,
    this.category,
    this.mediaID,
    this.mediaDuration,
    this.mediaURL,
  );

  @override
  bool operator ==(dynamic other) {
    return other is Event &&
        id == other.id &&
        title == other.title &&
        published == other.published &&
        updated == other.updated &&
        category == other.category &&
        mediaID == other.mediaID &&
        mediaDuration == other.mediaDuration &&
        mediaURL == other.mediaURL;
  }

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      published.hashCode ^
      updated.hashCode ^
      category.hashCode ^
      mediaID.hashCode ^
      mediaDuration.hashCode ^
      mediaURL.hashCode;

  @override
  String toString() =>
      'Event($id, $title, $published, $updated, $category, $mediaID, $mediaDuration, $mediaURL)';

  Event copyWith(
    Server? server,
    int? id,
    String? title,
    DateTime? published,
    DateTime? updated,
    String? category,
    int? mediaID,
    Duration? mediaDuration,
    Uri? mediaURL,
  ) =>
      Event(
        server ?? this.server,
        id ?? this.id,
        title ?? this.title,
        published ?? this.published,
        updated ?? this.updated,
        category ?? this.category,
        mediaID ?? this.mediaID,
        mediaDuration ?? this.mediaDuration,
        mediaURL ?? this.mediaURL,
      );
}