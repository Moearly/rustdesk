import 'dart:async';

import 'package:auto_size_text_field/auto_size_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_hbb/common/formatter/id_formatter.dart';
import 'package:flutter_hbb/common/widgets/connection_page_title.dart';
import 'package:flutter_hbb/models/state_model.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_hbb/models/peer_model.dart';

import '../../common.dart';
import '../../common/widgets/peer_tab_page.dart';
import '../../common/widgets/autocomplete.dart';
import '../../consts.dart';
import '../../models/model.dart';
import '../../models/platform_model.dart';
import '../../models/server_model.dart';
import 'home_page.dart';

/// 控多多移动端首页配色（深色商业级，紫罗兰品牌）
class _KddColors {
  static const Color bgBase = Color(0xFF0B0E14);
  static const Color surface = Color(0xFF161A22);
  static const Color input = Color(0xFF1F242E);
  static const Color borderDefault = Color(0xFF272D38);
  static const Color borderSubtle = Color(0xFF20252F);
  static const Color brand = Color(0xFF7355ED);
  static const Color brandDark = Color(0xFF5032BD);
  static const Color textPrimary = Color(0xFFE6EAF2);
  static const Color textSecondary = Color(0xFF9CA5B4);
  static const Color textTertiary = Color(0xFF6C7280);
  static const Color online = Color(0xFF22C55E);
  static const Color amber = Color(0xFFF59E0B);
}

/// Connection page for connecting to a remote peer.
class ConnectionPage extends StatefulWidget implements PageShape {
  ConnectionPage({Key? key, required this.appBarActions}) : super(key: key);

  @override
  final icon = const Icon(LucideIcons.monitor_smartphone);

  @override
  final title = translate("Connection");

  @override
  final List<Widget> appBarActions;

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

/// State for the connection page.
class _ConnectionPageState extends State<ConnectionPage> {
  /// Controller for the id input bar.
  final _idController = IDTextEditingController();
  final RxBool _idEmpty = true.obs;

  final FocusNode _idFocusNode = FocusNode();
  final TextEditingController _idEditingController = TextEditingController();

  final AllPeersLoader _allPeersLoader = AllPeersLoader();

  StreamSubscription? _uniLinksSubscription;

  // https://github.com/flutter/flutter/issues/157244
  Iterable<Peer> _autocompleteOpts = [];

  _ConnectionPageState() {
    if (!isWeb) _uniLinksSubscription = listenUniLinks();
    _idController.addListener(() {
      _idEmpty.value = _idController.text.isEmpty;
    });
    Get.put<IDTextEditingController>(_idController);
  }

  @override
  void initState() {
    super.initState();
    _allPeersLoader.init(setState);
    _idFocusNode.addListener(onFocusChanged);
    if (_idController.text.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final lastRemoteId = await bind.mainGetLastRemoteId();
        if (lastRemoteId != _idController.id) {
          setState(() {
            _idController.id = lastRemoteId;
          });
        }
      });
    }
    Get.put<TextEditingController>(_idEditingController);
  }

  @override
  Widget build(BuildContext context) {
    Provider.of<FfiModel>(context);
    return Container(
      color: _KddColors.bgBase,
      child: Stack(
        children: [
          // 顶部品牌光晕
          Positioned(
            top: -180,
            left: -60,
            child: Container(
              width: 420,
              height: 420,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _KddColors.brand.withOpacity(0.22),
                    _KddColors.brand.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          CustomScrollView(
            slivers: [
              SliverList(
                delegate: SliverChildListDelegate([
                  if (!bind.isCustomClient() && !isIOS)
                    Obx(() => _buildUpdateUI(stateGlobal.updateUrl.value)),
                  const SizedBox(height: 8),
                  _buildDeviceCard(),
                  const SizedBox(height: 22),
                  _buildSectionTitle(translate('Control Remote Desktop')),
                  const SizedBox(height: 10),
                  _buildRemoteIDTextField(),
                  const SizedBox(height: 22),
                  _buildQuickActions(),
                  const SizedBox(height: 18),
                  _buildSectionTitle(translate('Recent sessions')),
                  const SizedBox(height: 4),
                ]),
              ),
              SliverFillRemaining(
                hasScrollBody: true,
                child: PeerTabPage(),
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Text(
        text,
        style: const TextStyle(
          color: _KddColors.textTertiary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  /// 英雄设备卡：展示本机 ID + 一次性密码（数据来自 ServerModel）
  Widget _buildDeviceCard() {
    return Consumer<ServerModel>(
      builder: (context, model, child) {
        final id = model.serverId.text.trim();
        final pwd = model.serverPasswd.text.trim();
        final online = model.connectStatus > 0;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 14),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _KddColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _KddColors.borderDefault, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 30,
                spreadRadius: -4,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 状态胶囊
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  color: (online ? _KddColors.online : _KddColors.textTertiary)
                      .withOpacity(0.13),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: online
                            ? _KddColors.online
                            : _KddColors.textTertiary,
                        boxShadow: online
                            ? [
                                BoxShadow(
                                    color: _KddColors.online.withOpacity(0.8),
                                    blurRadius: 6)
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      online
                          ? translate('Ready')
                          : translate('Not ready'),
                      style: TextStyle(
                        color: online
                            ? _KddColors.online
                            : _KddColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              // ID
              Text(translate('ID'),
                  style: const TextStyle(
                      color: _KddColors.textTertiary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      formatID(id),
                      style: const TextStyle(
                        color: _KddColors.textPrimary,
                        fontSize: 27,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _miniIconButton(LucideIcons.copy, () {
                    Clipboard.setData(ClipboardData(text: id));
                    showToast(translate('Copied'));
                  }),
                ],
              ),
              const SizedBox(height: 16),
              Container(height: 1, color: _KddColors.borderSubtle),
              const SizedBox(height: 16),
              // 密码
              Text(translate('One-time Password'),
                  style: const TextStyle(
                      color: _KddColors.textTertiary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    pwd.isEmpty ? '-' : pwd,
                    style: const TextStyle(
                      color: _KddColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                    ),
                  ),
                  _miniIconButton(LucideIcons.refresh_cw, () {
                    bind.mainUpdateTemporaryPassword();
                  }, color: _KddColors.brand),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _miniIconButton(IconData icon, VoidCallback onTap,
      {Color color = _KddColors.textSecondary}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: _KddColors.input,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Expanded(
            child: _quickCard(
              icon: LucideIcons.scan_line,
              accent: _KddColors.brand,
              title: translate('Scan QR Code'),
              onTap: () => onConnect(),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _quickCard(
              icon: LucideIcons.arrow_right_left,
              accent: _KddColors.amber,
              title: translate('Transfer file'),
              onTap: () {
                final id = _idController.id;
                if (id.isNotEmpty) {
                  connect(context, id, isFileTransfer: true);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickCard({
    required IconData icon,
    required Color accent,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _KddColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _KddColors.borderDefault, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: accent),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: _KddColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Callback for the connect button.
  /// Connects to the selected peer.
  void onConnect() {
    var id = _idController.id;
    connect(context, id);
  }

  void onFocusChanged() {
    _idEmpty.value = _idEditingController.text.isEmpty;
    if (_idFocusNode.hasFocus) {
      if (_allPeersLoader.needLoad) {
        _allPeersLoader.getAllPeers();
      }

      final textLength = _idEditingController.value.text.length;
      // Select all to facilitate removing text, just following the behavior of address input of chrome.
      _idEditingController.selection =
          TextSelection(baseOffset: 0, extentOffset: textLength);
    }
  }

  /// UI for software update.
  /// If _updateUrl] is not empty, shows a button to update the software.
  Widget _buildUpdateUI(String updateUrl) {
    return updateUrl.isEmpty
        ? const SizedBox(height: 0)
        : InkWell(
            onTap: () async {
              final url = 'https://rustdesk.com/download';
              // https://pub.dev/packages/url_launcher#configuration
              // https://developer.android.com/training/package-visibility/use-cases#open-urls-custom-tabs
              //
              // `await launchUrl(Uri.parse(url))` can also run if skip
              // 1. The following check
              // 2. `<action android:name="android.support.customtabs.action.CustomTabsService" />` in AndroidManifest.xml
              //
              // But it is better to add the check.
              await launchUrl(Uri.parse(url));
            },
            child: Container(
                alignment: AlignmentDirectional.center,
                width: double.infinity,
                color: Colors.pinkAccent,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(translate('Download new version'),
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold))));
  }

  /// UI for the remote ID TextField.
  /// Search for a peer and connect to it if the id exists.
  Widget _buildRemoteIDTextField() {
    final w = SizedBox(
      height: 72,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 14),
        child: Ink(
          decoration: BoxDecoration(
            color: _KddColors.surface,
            borderRadius: BorderRadius.all(Radius.circular(16)),
            border: Border.all(color: _KddColors.borderDefault, width: 1),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Container(
                  padding: const EdgeInsets.only(left: 16, right: 16),
                  child: RawAutocomplete<Peer>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text == '') {
                        _autocompleteOpts = const Iterable<Peer>.empty();
                      } else if (_allPeersLoader.peers.isEmpty &&
                          !_allPeersLoader.isPeersLoaded) {
                        Peer emptyPeer = Peer(
                          id: '',
                          username: '',
                          hostname: '',
                          alias: '',
                          platform: '',
                          tags: [],
                          hash: '',
                          password: '',
                          forceAlwaysRelay: false,
                          rdpPort: '',
                          rdpUsername: '',
                          loginName: '',
                          device_group_name: '',
                          note: '',
                        );
                        _autocompleteOpts = [emptyPeer];
                      } else {
                        String textWithoutSpaces =
                            textEditingValue.text.replaceAll(" ", "");
                        if (int.tryParse(textWithoutSpaces) != null) {
                          textEditingValue = TextEditingValue(
                            text: textWithoutSpaces,
                            selection: textEditingValue.selection,
                          );
                        }
                        String textToFind = textEditingValue.text.toLowerCase();

                        _autocompleteOpts = _allPeersLoader.peers
                            .where((peer) =>
                                peer.id.toLowerCase().contains(textToFind) ||
                                peer.username
                                    .toLowerCase()
                                    .contains(textToFind) ||
                                peer.hostname
                                    .toLowerCase()
                                    .contains(textToFind) ||
                                peer.alias.toLowerCase().contains(textToFind))
                            .toList();
                      }
                      return _autocompleteOpts;
                    },
                    focusNode: _idFocusNode,
                    textEditingController: _idEditingController,
                    fieldViewBuilder: (BuildContext context,
                        TextEditingController fieldTextEditingController,
                        FocusNode fieldFocusNode,
                        VoidCallback onFieldSubmitted) {
                      updateTextAndPreserveSelection(
                          fieldTextEditingController, _idController.text);
                      return AutoSizeTextField(
                        controller: fieldTextEditingController,
                        focusNode: fieldFocusNode,
                        minFontSize: 18,
                        autocorrect: false,
                        enableSuggestions: false,
                        keyboardType: TextInputType.visiblePassword,
                        // keyboardType: TextInputType.number,
                        onChanged: (String text) {
                          _idController.id = text;
                        },
                        style: const TextStyle(
                          fontFamily: 'WorkSans',
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          color: _KddColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: translate('Enter Remote ID'),
                          border: InputBorder.none,
                          helperStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: _KddColors.textTertiary,
                          ),
                          hintStyle: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                            color: _KddColors.textTertiary,
                          ),
                        ),
                        inputFormatters: [IDTextInputFormatter()],
                        onSubmitted: (_) {
                          onConnect();
                        },
                      );
                    },
                    onSelected: (option) {
                      setState(() {
                        _idController.id = option.id;
                        FocusScope.of(context).unfocus();
                      });
                    },
                    optionsViewBuilder: (BuildContext context,
                        AutocompleteOnSelected<Peer> onSelected,
                        Iterable<Peer> options) {
                      options = _autocompleteOpts;
                      double maxHeight = options.length * 50;
                      if (options.length == 1) {
                        maxHeight = 52;
                      } else if (options.length == 3) {
                        maxHeight = 146;
                      } else if (options.length == 4) {
                        maxHeight = 193;
                      }
                      maxHeight = maxHeight.clamp(0, 200);
                      return Align(
                          alignment: Alignment.topLeft,
                          child: Container(
                              decoration: BoxDecoration(
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 5,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                  borderRadius: BorderRadius.circular(5),
                                  child: Material(
                                      elevation: 4,
                                      child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                            maxHeight: maxHeight,
                                            maxWidth: 320,
                                          ),
                                          child: _allPeersLoader
                                                      .peers.isEmpty &&
                                                  !_allPeersLoader.isPeersLoaded
                                              ? Container(
                                                  height: 80,
                                                  child: Center(
                                                      child:
                                                          CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                  )))
                                              : ListView(
                                                  padding:
                                                      EdgeInsets.only(top: 5),
                                                  children: options
                                                      .map((peer) =>
                                                          AutocompletePeerTile(
                                                              onSelect: () =>
                                                                  onSelected(
                                                                      peer),
                                                              peer: peer))
                                                      .toList(),
                                                ))))));
                    },
                  ),
                ),
              ),
              Obx(() => Offstage(
                    offstage: _idEmpty.value,
                    child: IconButton(
                        onPressed: () {
                          setState(() {
                            _idController.clear();
                          });
                        },
                        icon: Icon(LucideIcons.x,
                            size: 20, color: MyTheme.darkGray)),
                  )),
              Container(
                width: 48,
                height: 48,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_KddColors.brand, _KddColors.brandDark],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _KddColors.brand.withOpacity(0.45),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(LucideIcons.arrow_right_left,
                      color: Colors.white, size: 20),
                  onPressed: onConnect,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final child = Column(children: [
      if (isWebDesktop)
        getConnectionPageTitle(context, true)
            .marginOnly(bottom: 10, top: 15, left: 12),
      w
    ]);
    return Align(
        alignment: Alignment.topCenter,
        child: Container(constraints: kMobilePageConstraints, child: child));
  }

  @override
  void dispose() {
    _uniLinksSubscription?.cancel();
    _idController.dispose();
    _idFocusNode.removeListener(onFocusChanged);
    _allPeersLoader.clear();
    _idFocusNode.dispose();
    _idEditingController.dispose();
    if (Get.isRegistered<IDTextEditingController>()) {
      Get.delete<IDTextEditingController>();
    }
    if (Get.isRegistered<TextEditingController>()) {
      Get.delete<TextEditingController>();
    }
    super.dispose();
  }
}
