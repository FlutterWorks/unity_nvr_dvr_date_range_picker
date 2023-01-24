/*
 * This file is a part of Bluecherry Client (https://github.com/bluecherrydvr/unity).
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

import 'package:bluecherry_client/providers/server_provider.dart';
import 'package:flutter/foundation.dart';

enum UnityTab {
  deviceGrid,
  directCameraScreen,
  eventsScreen,
  addServer,
  downloads,
  settings,
}

class HomeProvider extends ChangeNotifier {
  int tab = ServersProvider.instance.serverAdded
      ? UnityTab.deviceGrid.index
      : UnityTab.addServer.index;

  void setTab(int tab) {
    this.tab = tab;

    if (tab != UnityTab.downloads.index) {
      initiallyExpandedDownloadEventId = null;
    }

    notifyListeners();
  }

  int? initiallyExpandedDownloadEventId;
  void toDownloads(int eventId) {
    initiallyExpandedDownloadEventId = eventId;

    setTab(UnityTab.downloads.index);
  }
}