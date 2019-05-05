import 'package:flutter/material.dart';
import 'package:ssh/ssh.dart';
import 'package:outline_material_icons/outline_material_icons.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' as Io;
import 'custom_tooltip.dart';
import 'custom_show_dialog.dart';
import 'favorites_page.dart';
import 'main.dart';

class ConnectionPage extends StatefulWidget {
  ConnectionPage({Key key, this.address, this.port, this.username, this.passwordOrKey, this.path, this.map}) : super(key: key);

  final String address;
  final String port;
  final String username;
  final String passwordOrKey;
  final String path;
  final Map<String, String> map;

  connectToSftpMap(Map<String, String> map) {
    _ConnectionPageState()._connectToSftpMap(map);
  }

  connectToSftp({@required String address, String port, String username, String passwordOrKey, String path}) {
    _ConnectionPageState()._connectToSftp(address: address, port: port, username: username, passwordOrKey: passwordOrKey, path: path);
  }

  static Map<String, String> currentConnection = {};

  @override
  _ConnectionPageState createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> with TickerProviderStateMixin {
  var _refreshKey = GlobalKey<RefreshIndicatorState>();

  SSHClient _client;

  List<Map<String, String>> _fileInfos = [];
  bool _isLoaded = false;
  int _itemNum = FavoritesPage.favorites.length > 0 ? FavoritesPage.favorites.length : 1;
  bool _isLoading = false;
  bool _showProgressIndicator = false;
  bool _showHiddenFiles = false;

  String _directoryBefore = "";

  _connectToSftpMap(Map<String, String> map) {
    _connectToSftp(
      address: map["address"],
      port: map["port"],
      username: map["username"],
      passwordOrKey: map["passwordOrKey"],
      path: map["path"],
    );
  }

  _connectToSftp({@required String address, String port, String username, String passwordOrKey, String path}) async {
    ConnectionPage.currentConnection = {
      "address": address,
      "port": port != null ? port : "22",
      "username": username != null ? username : "",
      "passwordOrKey": passwordOrKey != null ? passwordOrKey : "",
      "path": path != null ? path : ""
    };
    _client = SSHClient(
      host: address,
      port: port != null && port != "" ? int.parse(port) : 22,
      username: username,
      passwordOrKey: passwordOrKey,
    );
    setState(() {
      _isLoading = true;
      _showProgressIndicatorAsync();
    });
    await _client.connect();
    await _client.connectSFTP();
    var _list = await _client.sftpLs(path != null && path != "" ? path : "/");
    _fileInfos = [];
    _fileInfos.length = _list.length;
    for (int i = 0; i < _list.length; i++) {
      _fileInfos[i] = {};
      _list[i].forEach((k, v) {
        setState(() {
          _fileInfos[i].addAll({k.toString(): v.toString()});
        });
      });
    }
    setState(() {
      _isLoading = false;
      _showProgressIndicator = false;
      _isLoaded = true;
      _itemNum = _fileInfos.length;
    });
  }

  Future<void> _refresh() async {
    await Future.delayed(Duration(milliseconds: 50));
    _connectToSftpMap(ConnectionPage.currentConnection);
    return null;
  }

  _connectToDirectoryBefore() {
    String current = ConnectionPage.currentConnection["path"];
    int lastSlashIndex;
    for (int i = 0; i < current.length - 1; i++) {
      if (current.substring(i, i + 1) == "/") {
        lastSlashIndex = i;
      }
    }
    _directoryBefore = current.substring(0, lastSlashIndex);
    _connectToSftp(
      address: ConnectionPage.currentConnection["address"],
      port: ConnectionPage.currentConnection["port"],
      username: ConnectionPage.currentConnection["username"],
      passwordOrKey: ConnectionPage.currentConnection["passwordOrKey"],
      path: _directoryBefore,
    );
  }

  _goToDirectory(String value) {
    _connectToSftp(
      address: ConnectionPage.currentConnection["address"],
      port: ConnectionPage.currentConnection["port"],
      username: ConnectionPage.currentConnection["username"],
      passwordOrKey: ConnectionPage.currentConnection["passwordOrKey"],
      path: value,
    );
  }

  _showProgressIndicatorAsync() async {
    await Future.delayed(Duration(milliseconds: 200));
    setState(() {
      _showProgressIndicator = !_showProgressIndicator;
    });
  }

  Future<bool> _downloadFile(String filePath) async {
    await Future.delayed(Duration(seconds: 2));
    //bool checkResult = await SimplePermissions.checkPermission(Permission.WriteExternalStorage);
    PermissionStatus permissionStatus = await PermissionHandler().checkPermissionStatus(PermissionGroup.storage);
    if (permissionStatus == PermissionStatus.denied || permissionStatus == PermissionStatus.disabled) {
      //var status = await SimplePermissions.requestPermission(Permission.WriteExternalStorage);
      Map<PermissionGroup, PermissionStatus> permissions = await PermissionHandler().requestPermissions([PermissionGroup.storage]);
      if (permissions[PermissionGroup.storage] == PermissionStatus.granted) {
        var res = await _saveFile(filePath);
        return res != null;
      }
    } else {
      var res = await _saveFile(filePath);
      return res != null;
    }
    return false;
  }

  Future<String> _saveFile(String filePath) async {
    try {
      var dir = await getExternalStorageDirectory();
      var testdir = await Io.Directory('${dir.path}/RemoteFiles').create(recursive: true);
      var filePathDownload = await _client.sftpDownload(
        path: filePath,
        toPath: testdir.path,
        callback: (progress) {
          print(progress); // read download progress
        },
      );
      return filePathDownload;
    } catch (e) {
      print(e);
      return null;
    }
  }

  AnimationController _rotationController;

  @override
  void initState() {
    _rotationController = AnimationController(duration: Duration(milliseconds: 100), vsync: this);
    _connectToSftp(
      address: widget.address,
      port: widget.port,
      username: widget.username,
      passwordOrKey: widget.passwordOrKey,
      path: widget.path,
    );
    super.initState();
  }

  double _tableFontSize = 16.2;

  _showFileBottomSheet(int index, BuildContext context) {
    bool isDirectory = _fileInfos[index]["isDirectory"] == "true";
    String filePath = ConnectionPage.currentConnection["path"];
    if (ConnectionPage.currentConnection["path"].substring(ConnectionPage.currentConnection["path"].length - 2) != "/") {
      filePath += "/";
    }
    filePath += _fileInfos[index]["filename"];
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
          return Container(
            child: Column(
              children: <Widget>[
                Container(
                  height: 56.0,
                  child: ListTile(
                    leading: Icon(isDirectory ? OMIcons.folder : Icons.insert_drive_file),
                    title: Padding(
                      padding: EdgeInsets.only(top: 4.0),
                      child: Text(
                        _fileInfos[index]["filename"],
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                Container(
                  height: 1.0,
                  color: Theme.of(context).dividerColor,
                ),
                Container(
                  height: constraints.maxHeight - 57.0,
                  child: ListView(
                    physics: BouncingScrollPhysics(),
                    children: <Widget>[
                      Padding(
                        padding: EdgeInsets.all(18.0),
                        child: Opacity(
                          opacity: .8,
                          child: Table(
                            columnWidths: {0: FixedColumnWidth(145.0)},
                            children: <TableRow>[
                              TableRow(children: [
                                Padding(
                                  padding: EdgeInsets.only(bottom: 2.0),
                                  child: Text(
                                    "Name:",
                                    style: TextStyle(fontSize: _tableFontSize),
                                  ),
                                ),
                                Text(
                                  _fileInfos[index]["filename"],
                                  style: TextStyle(fontSize: _tableFontSize),
                                ),
                              ]),
                              TableRow(children: [
                                Padding(
                                  padding: EdgeInsets.only(bottom: 2.0),
                                  child: Text(
                                    "Permissions:",
                                    style: TextStyle(fontSize: _tableFontSize),
                                  ),
                                ),
                                Text(
                                  _fileInfos[index]["permissions"],
                                  style: TextStyle(fontSize: _tableFontSize),
                                ),
                              ]),
                              TableRow(children: [
                                Padding(
                                  padding: EdgeInsets.only(bottom: 2.0),
                                  child: Text(
                                    "Modification Date:",
                                    style: TextStyle(fontSize: _tableFontSize),
                                  ),
                                ),
                                Text(
                                  _fileInfos[index]["modificationDate"],
                                  style: TextStyle(fontSize: _tableFontSize),
                                ),
                              ]),
                              TableRow(children: [
                                Padding(
                                  padding: EdgeInsets.only(bottom: 2.0),
                                  child: Text(
                                    "Last Access:",
                                    style: TextStyle(fontSize: _tableFontSize),
                                  ),
                                ),
                                Text(
                                  _fileInfos[index]["lastAccess"],
                                  style: TextStyle(fontSize: _tableFontSize),
                                ),
                              ]),
                              TableRow(children: [
                                Padding(
                                  padding: EdgeInsets.only(bottom: 2.0),
                                  child: Text(
                                    "Path:",
                                    style: TextStyle(fontSize: _tableFontSize),
                                  ),
                                ),
                                Text(
                                  ConnectionPage.currentConnection["path"] + "/" + _fileInfos[index]["filename"],
                                  style: TextStyle(fontSize: _tableFontSize),
                                ),
                              ]),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        height: 1.0,
                        margin: EdgeInsets.only(bottom: 8.0),
                        color: Theme.of(context).dividerColor,
                      ),
                      isDirectory
                          ? Container()
                          : ListTile(
                              leading: Icon(Icons.file_download, color: Theme.of(context).accentColor),
                              title: Padding(
                                padding: EdgeInsets.only(top: 2.0),
                                child: Text(
                                  "Download",
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ),
                              onTap: () async {
                                if (await _downloadFile(filePath)) {
                                  /*Scaffold.of(context).showSnackBar(SnackBar(
                                    content: Text("Downloading file..."),
                                  ));*/
                                  print("Downloading file...");
                                } else {
                                  /*Scaffold.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("Download failed"),
                                    ),
                                  );*/
                                  print("Download failed");
                                }
                              },
                            ),
                      ListTile(
                        leading: Icon(OMIcons.edit, color: Theme.of(context).accentColor),
                        title: Padding(
                          padding: EdgeInsets.only(top: 2.0),
                          child: Text(
                            "Rename",
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        onTap: () {
                          customShowDialog(
                            context: context,
                            builder: (context) {
                              return CustomAlertDialog(
                                title: Text(
                                  "Rename '${_fileInfos[index]["filename"]}'",
                                  style: TextStyle(fontFamily: "GoogleSans"),
                                ),
                                content: TextField(
                                  decoration: InputDecoration(
                                    labelText: "New name",
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: Theme.of(context).accentColor, width: 2.0),
                                    ),
                                  ),
                                  cursorColor: Theme.of(context).accentColor,
                                  autofocus: true,
                                  onSubmitted: (String value) async {
                                    String newFilePath = ConnectionPage.currentConnection["path"];
                                    if (ConnectionPage.currentConnection["path"].substring(ConnectionPage.currentConnection["path"].length - 2) != "/") {
                                      newFilePath += "/";
                                    }
                                    newFilePath += value;
                                    await _client.sftpRename(
                                      oldPath: filePath,
                                      newPath: newFilePath,
                                    );
                                    Navigator.pop(context);
                                    Navigator.pop(context);
                                    _connectToSftpMap(ConnectionPage.currentConnection);
                                  },
                                ),
                              );
                            },
                          );
                        },
                      ),
                      ListTile(
                        leading: Icon(OMIcons.delete, color: Theme.of(context).accentColor),
                        title: Padding(
                          padding: EdgeInsets.only(top: 2.0),
                          child: Text(
                            "Delete",
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        onTap: () => _showDeleteConfirmDialog(index, filePath),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  _showDeleteConfirmDialog(int index, String filePath) {
    customShowDialog(
        context: context,
        builder: (context) {
          return CustomAlertDialog(
            title: Text(
              "Delete '${_fileInfos[index]["filename"]}'?",
              style: TextStyle(fontFamily: "GoogleSans"),
            ),
            actions: <Widget>[
              FlatButton(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
                padding: EdgeInsets.only(top: 8.0, bottom: 6.5, left: 14.0, right: 14.0),
                child: Row(
                  children: <Widget>[
                    Text("Cancel"),
                  ],
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
              RaisedButton(
                color: Theme.of(context).accentColor,
                splashColor: Colors.black12,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
                padding: EdgeInsets.only(top: 8.0, bottom: 6.5, left: 14.0, right: 14.0),
                child: Row(
                  children: <Widget>[
                    Text(
                      "OK",
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                elevation: .0,
                onPressed: () async {
                  if (_fileInfos[index]["isDirectory"] == "true") {
                    await _client.sftpRmdir(filePath);
                  } else {
                    await _client.sftpRm(filePath);
                  }
                  Navigator.pop(context);
                  Navigator.pop(context);
                  _connectToSftpMap(ConnectionPage.currentConnection);
                },
              ),
              SizedBox(width: .0),
            ],
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(40.0),
        child: AppBar(
          elevation: 1.2,
          automaticallyImplyLeading: false,
          title: Text(
            ConnectionPage.currentConnection["path"] != null
                ? ConnectionPage.currentConnection["path"] != "" ? ConnectionPage.currentConnection["path"] : "/"
                : "",
            style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w500, fontFamily: "GoogleSans"),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.fade,
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        elevation: 8.0,
        child: Container(
          height: 55.0,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: BouncingScrollPhysics(),
            child: Row(
              children: <Widget>[
                CustomTooltip(
                  message: "Back",
                  child: IconButton(
                    icon: Icon(Icons.chevron_left),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                CustomTooltip(
                  message: "Show connection infos",
                  child: IconButton(
                    icon: Padding(
                      padding: EdgeInsets.only(top: 1.0),
                      child: Icon(OMIcons.flashOn),
                    ),
                    onPressed: () {
                      MyHomePage().showConnectionDialog(
                        context: context,
                        page: "connection",
                        primaryButton: RaisedButton(
                          color: Theme.of(context).accentColor,
                          splashColor: Colors.black12,
                          child: Row(
                            children: <Widget>[
                              Container(
                                margin: EdgeInsets.only(right: 3.5, bottom: 2.0),
                                child: Icon(
                                  OMIcons.edit,
                                  size: 19.0,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                "Edit",
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
                          padding: EdgeInsets.only(top: 8.0, bottom: 6.5, left: 12.0, right: 14.0),
                          elevation: .0,
                          onPressed: () {},
                        ),
                        hasSecondaryButton: true,
                        secondaryButton: FlatButton(
                          child: Row(
                            children: <Widget>[
                              Container(
                                margin: EdgeInsets.only(right: 3.5, bottom: 2.0),
                                child: Icon(
                                  Icons.remove_circle_outline,
                                  size: 19.0,
                                ),
                              ),
                              Text("Disconnect"),
                            ],
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
                          padding: EdgeInsets.only(top: 8.0, bottom: 6.5, left: 12.0, right: 14.0),
                          onPressed: () {
                            _client.disconnectSFTP();
                            Navigator.pop(context);
                            Navigator.pop(context);
                          },
                        ),
                      );
                    },
                  ),
                ),
                CustomTooltip(
                  message: "Go to parent directory",
                  child: IconButton(
                    icon: RotatedBox(quarterTurns: 2, child: Icon(Icons.subdirectory_arrow_right)),
                    onPressed: () {
                      _connectToDirectoryBefore();
                    },
                  ),
                ),
                CustomTooltip(
                  message: "Go to specific directory",
                  child: IconButton(
                    icon: Icon(Icons.youtube_searched_for),
                    onPressed: () {
                      _connectToSftp(
                        address: ConnectionPage.currentConnection["address"],
                        port: ConnectionPage.currentConnection["port"],
                        username: ConnectionPage.currentConnection["username"],
                        passwordOrKey: ConnectionPage.currentConnection["passwordOrKey"],
                        path: ConnectionPage.currentConnection["path"],
                      );
                      customShowDialog(
                        context: context,
                        builder: (context) {
                          return CustomAlertDialog(
                            title: Text("Go to directory", style: TextStyle(fontFamily: "GoogleSans", fontSize: 18.0)),
                            content: Container(
                              width: 260.0,
                              child: TextField(
                                decoration: InputDecoration(
                                  labelText: "Path",
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Theme.of(context).accentColor, width: 2.0),
                                  ),
                                ),
                                cursorColor: Theme.of(context).accentColor,
                                autofocus: true,
                                onSubmitted: (String value) {
                                  _goToDirectory(value);
                                  Navigator.pop(context);
                                },
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                CustomTooltip(
                  message: _showHiddenFiles ? "Don't show hidden files" : "Show hidden files",
                  child: IconButton(
                    icon: Icon(_showHiddenFiles ? OMIcons.visibilityOff : OMIcons.visibility),
                    onPressed: () {
                      setState(() {
                        _showHiddenFiles = !_showHiddenFiles;
                      });
                    },
                  ),
                ),
                CustomTooltip(
                  message: "Sort",
                  child: IconButton(
                    icon: Icon(Icons.sort),
                    onPressed: () {
                      customShowDialog(
                        context: context,
                        builder: (context) {
                          return CustomAlertDialog(
                            contentPadding: EdgeInsets.symmetric(vertical: 10.0),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Padding(
                                  padding: EdgeInsets.only(left: 24.0, right: 16.0, top: 4.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: <Widget>[
                                      Text(
                                        "Sort",
                                        style: TextStyle(fontFamily: "GoogleSans", fontSize: 20.0, fontWeight: FontWeight.w500),
                                      ),
                                      Switch(
                                        activeThumbImage: AssetImage("assets/arrow_drop_down.png"),
                                        activeColor: Colors.grey[50],
                                        activeTrackColor: Colors.grey[300],
                                        inactiveThumbImage: AssetImage("assets/arrow_drop_up.png"),
                                        inactiveTrackColor: Colors.grey[300],
                                        inactiveThumbColor: Colors.grey[50],
                                        value: true,
                                        onChanged: (bool value) {},
                                      )
                                    ],
                                  ),
                                ),
                                RadioListTile(
                                  title: Text("Name"),
                                  value: _radioValues[0],
                                  groupValue: 0,
                                  onChanged: (int value) {
                                    setState(() {
                                      _radioValues[1] = value;
                                    });
                                    Navigator.pop(context);
                    },
                  ),
                                RadioListTile(
                                  title: Text("Modification Date"),
                                  value: 1,
                                  groupValue: 0,
                                  onChanged: (int value) {},
                                ),
                                RadioListTile(
                                  title: Text("Last Access"),
                                  value: 1,
                                  groupValue: 0,
                                  onChanged: (int value) {},
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                ),
                        ),
                      )
                    : Container(),
              ],
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: SpeedDial(
        heroTag: "fab",
        child: RotationTransition(
          turns: Tween(begin: .0, end: 0.125).animate(_rotationController),
          child: Icon(Icons.add),
        ),
        onOpen: () {
          _rotationController.forward(from: .0);
        },
        onClose: () {
          _rotationController.animateBack(.0);
        },
        children: [
          SpeedDialChild(
            label: "Upload File",
            labelStyle: TextStyle(fontFamily: "GoogleSans", fontWeight: FontWeight.w500),
            child: Icon(OMIcons.cloudUpload),
            backgroundColor: Colors.white,
            foregroundColor: Theme.of(context).accentColor,
            elevation: 3.0,
            onTap: () {},
          ),
          SpeedDialChild(
            label: "Create Folder",
            labelStyle: TextStyle(fontFamily: "GoogleSans", fontWeight: FontWeight.w500),
            child: Icon(OMIcons.createNewFolder),
            backgroundColor: Colors.white,
            foregroundColor: Theme.of(context).accentColor,
            elevation: 3.0,
            onTap: () async {
              customShowDialog(
                context: context,
                builder: (context) {
                  return CustomAlertDialog(
                    title: Text(
                      "Folder Name",
                      style: TextStyle(fontFamily: "GoogleSans"),
                    ),
                    content: TextField(
                      decoration: InputDecoration(
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Theme.of(context).accentColor, width: 2.0),
                        ),
                      ),
                      cursorColor: Theme.of(context).accentColor,
                      autofocus: true,
                      autocorrect: false,
                      onSubmitted: (String value) async {
                        await _client.sftpMkdir(ConnectionPage.currentConnection["path"] + "/" + value);
                        Navigator.pop(context);
                        _connectToSftpMap(ConnectionPage.currentConnection);
                      },
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Scrollbar(
          child: RefreshIndicator(
            key: _refreshKey,
            onRefresh: () => _refresh(),
            child: ListView.builder(
              physics: BouncingScrollPhysics(),
              itemCount: _itemNum,
              itemBuilder: (BuildContext context, int index) {
                return Column(
                  children: <Widget>[
                    _isLoaded
                        ? !_showHiddenFiles && _fileInfos[index]["filename"].substring(0, 1) == "."
                            ? Container()
                            : ListTile(
                                leading: _fileInfos[index]["isDirectory"] == "true" ? Icon(OMIcons.folder) : Icon(Icons.insert_drive_file),
                                title: Text(_fileInfos[index]["filename"]),
                                onTap: () {
                                  if (_fileInfos[index]["isDirectory"] == "true") {
                                    setState(() {
                                      _directoryBefore = ConnectionPage.currentConnection["path"];
                                    });
                                    _connectToSftp(
                                      address: ConnectionPage.currentConnection["address"],
                                      port: ConnectionPage.currentConnection["port"],
                                      username: ConnectionPage.currentConnection["username"],
                                      passwordOrKey: ConnectionPage.currentConnection["passwordOrKey"],
                                      path: ConnectionPage.currentConnection["path"] + "/" + _fileInfos[index]["filename"],
                                    );
                                  } else {
                                    _showFileBottomSheet(index, context);
                                  }
                                },
                                onLongPress: () {
                                  _showFileBottomSheet(index, context);
                                },
                              )
                        : index == 0
                            ? Container(
                                child: Padding(
                                  padding: EdgeInsets.only(top: 60.0),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                              )
                            : Container(),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
