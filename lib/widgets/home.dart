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

import 'package:bluecherry_client/providers/home_provider.dart';
import 'package:bluecherry_client/widgets/desktop_buttons.dart';
import 'package:bluecherry_client/widgets/misc.dart';
import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:bluecherry_client/widgets/device_grid/device_grid.dart';
import 'package:bluecherry_client/widgets/events/events_screen.dart';
import 'package:bluecherry_client/widgets/settings/settings.dart';
import 'package:bluecherry_client/utils/methods.dart';
import 'package:bluecherry_client/widgets/add_server_wizard.dart';
import 'package:bluecherry_client/widgets/direct_camera.dart';
import 'package:provider/provider.dart';
import 'package:status_bar_control/status_bar_control.dart';

class Home extends StatelessWidget {
  const Home({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MobileHome();
  }
}

Map<IconData, String> navigatorData(BuildContext context) {
  return {
    Icons.window: AppLocalizations.of(context).screens,
    Icons.camera: AppLocalizations.of(context).directCamera,
    Icons.description: AppLocalizations.of(context).eventBrowser,
    Icons.dns: AppLocalizations.of(context).addServer,
    Icons.settings: AppLocalizations.of(context).settings,
  };
}

class MobileHome extends StatefulWidget {
  const MobileHome({Key? key}) : super(key: key);

  @override
  State<MobileHome> createState() => _MobileHomeState();
}

class _MobileHomeState extends State<MobileHome> {
  @override
  void initState() {
    super.initState();
    if (!isDesktop) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final home = context.watch<HomeProvider>();
        final tab = home.tab;

        if (tab == 0) {
          await StatusBarControl.setHidden(true);
          await StatusBarControl.setStyle(
            getStatusBarStyleFromBrightness(Theme.of(context).brightness),
          );
          DeviceOrientations.instance.set(
            [
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ],
          );
        } else if (tab == 3) {
          // Use portrait orientation in "Add Server" tab.
          // See #14.
          await StatusBarControl.setHidden(false);
          await StatusBarControl.setStyle(
            getStatusBarStyleFromBrightness(Theme.of(context).brightness),
          );
          DeviceOrientations.instance.set(
            [
              DeviceOrientation.portraitUp,
              DeviceOrientation.portraitDown,
            ],
          );
        } else {
          await StatusBarControl.setHidden(false);
          await StatusBarControl.setStyle(
            getStatusBarStyleFromBrightness(Theme.of(context).brightness),
          );
          DeviceOrientations.instance.set(
            DeviceOrientation.values,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeProvider>();
    final tab = home.tab;

    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.biggest.width >= 640;

      // if isExtraWide is true, the rail will be extended. This is good for
      // desktop environments, but I like it compact (just like vscode)
      // final isExtraWide = constraints.biggest.width >= 1008;
      const isExtraWide = false;
      return Scaffold(
        resizeToAvoidBottomInset: false,
        drawer: isWide ? null : buildDrawer(context),
        body: Column(children: [
          const WindowButtons(),
          Expanded(
            child: Row(children: [
              // if it's desktop, we show the navigation in the window bar
              if ((isWide || isExtraWide) && !isDesktop) ...[
                buildNavigationRail(context, isExtraWide: isExtraWide),
                // SizedBox(
                //   width: 4.0,
                // ),
              ],
              Expanded(
                child: ClipRect(
                  child: PageTransitionSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: <int, Widget Function()>{
                      0: () => const DeviceGrid(),
                      1: () => const DirectCameraScreen(),
                      2: () => const EventsScreen(),
                      3: () => AddServerWizard(
                            onFinish: () async {
                              home.setTab(0);
                              if (!isDesktop) {
                                await StatusBarControl.setHidden(true);
                                await StatusBarControl.setStyle(
                                  getStatusBarStyleFromBrightness(
                                      Theme.of(context).brightness),
                                );
                                await SystemChrome.setPreferredOrientations(
                                  [
                                    DeviceOrientation.landscapeLeft,
                                    DeviceOrientation.landscapeRight,
                                  ],
                                );
                              }
                            },
                          ),
                      4: () => Settings(
                            changeCurrentTab: (i) => home.setTab(i),
                          ),
                    }[tab]!(),
                    transitionBuilder: (child, animation, secondaryAnimation) {
                      return SharedAxisTransition(
                        child: child,
                        animation: animation,
                        secondaryAnimation: secondaryAnimation,
                        transitionType: SharedAxisTransitionType.vertical,
                      );
                    },
                  ),
                ),
              ),
            ]),
          ),
        ]),
      );
    });
  }

  Drawer buildDrawer(BuildContext context) {
    final theme = NavigationRailDrawerData(theme: Theme.of(context));

    final home = context.watch<HomeProvider>();
    final tab = home.tab;

    return Drawer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          Container(
            width: double.infinity,
            height: MediaQuery.of(context).padding.top,
            color: Color.lerp(
              Theme.of(context).drawerTheme.backgroundColor,
              Colors.black,
              0.2,
            ),
          ),
          const SizedBox(height: 8.0),
          ...navigatorData(context).entries.map((entry) {
            final icon = entry.key;
            final text = entry.value;
            final index = navigatorData(context).keys.toList().indexOf(icon);

            return Stack(children: [
              ListTile(
                dense: true,
                leading: CircleAvatar(
                  backgroundColor: Colors.transparent,
                  child: Icon(
                    icon,
                    color: index == tab
                        ? theme.selectedForegroundColor
                        : theme.unselectedForegroundColor,
                  ),
                ),
                title: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyText1?.copyWith(
                        color:
                            index == tab ? theme.selectedForegroundColor : null,
                      ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.only(
                    right: 12.0,
                  ),
                  width: double.infinity,
                  height: 48.0,
                  child: InkWell(
                    borderRadius: const BorderRadiusDirectional.only(
                      topEnd: Radius.circular(28.0),
                      bottomEnd: Radius.circular(28.0),
                    ).resolve(Directionality.of(context)),
                    onTap: () async {
                      if (!isDesktop) {
                        if (index == 0 && tab != 0) {
                          debugPrint(index.toString());
                          await StatusBarControl.setHidden(true);
                          await StatusBarControl.setStyle(
                            getStatusBarStyleFromBrightness(
                              Theme.of(context).brightness,
                            ),
                          );
                          DeviceOrientations.instance.set(
                            [
                              DeviceOrientation.landscapeLeft,
                              DeviceOrientation.landscapeRight,
                            ],
                          );
                        } else if (index == 3 && tab != 3) {
                          debugPrint(index.toString());
                          // Use portrait orientation in "Add Server" tab. See #14.
                          await StatusBarControl.setHidden(false);
                          await StatusBarControl.setStyle(
                            // Always white status bar style in [AddServerWizard].
                            StatusBarStyle.LIGHT_CONTENT,
                          );
                          DeviceOrientations.instance.set(
                            [
                              DeviceOrientation.portraitUp,
                              DeviceOrientation.portraitDown,
                            ],
                          );
                        } else if (![0, 3].contains(index) &&
                            [0, 3].contains(tab)) {
                          debugPrint(index.toString());
                          await StatusBarControl.setHidden(false);
                          await StatusBarControl.setStyle(
                            getStatusBarStyleFromBrightness(
                              Theme.of(context).brightness,
                            ),
                          );
                          DeviceOrientations.instance.set(
                            DeviceOrientation.values,
                          );
                        }
                      }

                      await Future.delayed(const Duration(milliseconds: 200));
                      Navigator.of(context).pop();
                      if (tab != index) {
                        home.setTab(index);
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color:
                            index == tab ? theme.selectedBackgroundColor : null,
                        borderRadius: const BorderRadiusDirectional.only(
                          topEnd: Radius.circular(28.0),
                          bottomEnd: Radius.circular(28.0),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ]);
          }),
        ],
      ),
    );
  }

  Widget buildNavigationRail(
    BuildContext context, {
    required bool isExtraWide,
  }) {
    final theme = NavigationRailDrawerData(theme: Theme.of(context));
    final home = context.watch<HomeProvider>();

    final backgroundColor = Theme.of(context).appBarTheme.backgroundColor;
    return Material(
      color: backgroundColor,
      child: Column(children: [
        const Spacer(),
        Expanded(
          flex: 3,
          child: Center(
            child: NavigationRail(
              minExtendedWidth: 220,
              elevation: Theme.of(context).appBarTheme.elevation,
              backgroundColor: backgroundColor,
              extended: isExtraWide,
              useIndicator: !isExtraWide,
              indicatorColor: theme.selectedBackgroundColor,
              selectedLabelTextStyle: TextStyle(
                color: theme.selectedForegroundColor,
              ),
              unselectedLabelTextStyle: TextStyle(
                color: theme.unselectedForegroundColor,
              ),
              destinations: navigatorData(context).entries.map((entry) {
                final icon = entry.key;
                final text = entry.value;
                final index =
                    navigatorData(context).keys.toList().indexOf(icon);

                return NavigationRailDestination(
                  icon: Icon(
                    icon,
                    color: index == home.tab
                        ? theme.selectedForegroundColor
                        : theme.unselectedForegroundColor,
                  ),
                  label: Text(text),
                );
              }).toList(),
              selectedIndex: home.tab,
              onDestinationSelected: (index) {
                if (home.tab != index) {
                  home.setTab(index);
                }
              },
            ),
          ),
        ),
        const Spacer(),
      ]),
    );
  }
}

class NavigationRailDrawerData {
  final ThemeData theme;

  const NavigationRailDrawerData({required this.theme});

  Color get selectedBackgroundColor => theme.primaryColor.withOpacity(0.2);
  Color get selectedForegroundColor => theme.primaryColor;
  Color? get unselectedForegroundColor => theme.iconTheme.color;
}
