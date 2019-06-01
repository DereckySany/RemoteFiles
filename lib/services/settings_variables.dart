import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services.dart';

class SettingsVariables {
  static SharedPreferences prefs;
  static Future<void> setSharedPreferences() async {
    prefs = await SharedPreferences.getInstance();
  }

  static Directory downloadDirectory;
  static Future<Directory> getDownloadDirectory() async {
    Directory dirDefault;
    if (!Platform.isIOS) {
      dirDefault = await getExternalStorageDirectory();
      dirDefault = Directory(dirDefault.path + "/RemoteFiles");
    } else {
      return Directory("");
    }
    Directory dirPrefs;
    if (prefs != null) {
      if (prefs.getString("downloadDirectoryPath") != null) dirPrefs = Directory(prefs.getString("downloadDirectoryPath"));
    }
    if (dirPrefs != null) return dirPrefs;
    return dirDefault;
  }

  static Future<void> setDownloadDirectory(String path) async {
    downloadDirectory = Directory(path);
    await prefs.setString("downloadDirectoryPath", path);
  }

  static Future<Directory> setDownloadDirectoryToDefault() async {
    if (!Platform.isIOS) {
      downloadDirectory = await getExternalStorageDirectory();
      downloadDirectory = Directory(downloadDirectory.path + "/RemoteFiles");
    }
    setDownloadDirectory(downloadDirectory.path);
    return downloadDirectory;
  }

  static String view = "list";
  static String getView() {
    String viewPrefs;
    if (prefs != null) viewPrefs = prefs.getString("view");
    if (viewPrefs != null) return viewPrefs;
    return view;
  }

  static Future<void> setView(String value) async {
    view = value;
    await prefs.setString("view", value);
  }

  static String detailedViewTimeInfo = "modificationDate";
  static String getDetailedViewTimeInfo() {
    String detailedViewTimeInfoPrefs;
    if (prefs != null) detailedViewTimeInfoPrefs = prefs.getString("detailedViewTimeInfo");
    if (detailedViewTimeInfoPrefs != null) return detailedViewTimeInfoPrefs;
    return detailedViewTimeInfo;
  }

  static Future<void> setDetailedViewTimeInfo(String value) async {
    detailedViewTimeInfo = value;
    await prefs.setString("detailedViewTimeInfo", value);
  }

  static String sort = "filename";
  static String getSort() {
    String sortPrefs;
    if (prefs != null) sortPrefs = prefs.getString("sort");
    if (sortPrefs != null) return sortPrefs;
    return sort;
  }

  static Future<void> setSort(String value) async {
    sort = value;
    await prefs.setString("sort", value);
  }

  static bool sortIsDescending = false;
  static bool getSortIsDescending() {
    bool sortIsDescendingPrefs;
    if (prefs != null) sortIsDescendingPrefs = prefs.getBool("sortIsDescending");
    if (sortIsDescendingPrefs != null) return sortIsDescendingPrefs;
    return sortIsDescending;
  }

  static Future<void> setSortIsDescending(bool value) async {
    sortIsDescending = value;
    await prefs.setBool("sortIsDescending", value);
  }

  static bool showHiddenFiles = true;
  static bool getShowHiddenFiles() {
    bool showHiddenFilesPrefs;
    if (prefs != null) showHiddenFilesPrefs = prefs.getBool("showHiddenFiles");
    if (showHiddenFilesPrefs != null) return showHiddenFilesPrefs;
    return showHiddenFiles;
  }

  static Future<void> setShowHiddenFiles(bool value) async {
    showHiddenFiles = value;
    await prefs.setBool("showHiddenFiles", value);
  }

  static String filesizeUnit = "automatic";
  static String getFilesizeUnit() {
    String filesizeUnitPrefs;
    if (prefs != null) filesizeUnitPrefs = prefs.getString("filesizeUnit");
    if (filesizeUnitPrefs != null) return filesizeUnitPrefs;
    return filesizeUnit;
  }

  /// can be 'B', 'KB', 'MB', 'GB' and 'automatic'.
  static Future<void> setFilesizeUnit(String value) async {
    filesizeUnit = value;
    await prefs.setString("filesizeUnit", value);

    int unitDivisor;
    switch (value) {
      case "B":
        unitDivisor = 1;
        break;
      case "KB":
        unitDivisor = 1000;
        break;
      case "MB":
        unitDivisor = 1000000;
        break;
      case "GB":
        unitDivisor = 1000000000;
        break;
    }
    connectionModel.fileInfos.forEach((v) {
      double convertedFileSize;
      String unitValue;
      if (v["fileSize"].length > 9) {
        convertedFileSize = (double.parse(v["fileSize"]) / 1000000000);
        unitValue = "GB";
      } else if (v["fileSize"].length > 6) {
        convertedFileSize = (double.parse(v["fileSize"]) / 1000000);
        unitValue = "MB";
      } else if (v["fileSize"].length > 3) {
        convertedFileSize = (double.parse(v["fileSize"]) / 1000);
        unitValue = "KB";
      } else {
        convertedFileSize = double.parse(v["fileSize"]);
        unitValue = "B";
      }
      if (unitDivisor != null) {
        convertedFileSize = (double.parse(v["fileSize"]) / unitDivisor.toDouble());
        unitValue = value;
      }
      for (int i = 0; i < convertedFileSize.toString().length; i++) {
        if (convertedFileSize.toString()[i] == ".") {
          convertedFileSize = double.parse(convertedFileSize.toString().substring(0, i + 3));
          break;
        }
      }
      v["convertedFileSize"] = convertedFileSize.toString() + " $unitValue";
    });
  }

  static bool showAddressInAppBar = true;
  static bool getShowAddressInAppBar() {
    bool showAddressInAppBarPrefs;
    if (prefs != null) showAddressInAppBarPrefs = prefs.getBool("showAddressInAppBar");
    if (showAddressInAppBarPrefs != null) return showAddressInAppBarPrefs;
    return showAddressInAppBar;
  }

  static Future<void> setShowAddressInAppBar(bool value) async {
    showAddressInAppBar = value;
    await prefs.setBool("showAddressInAppBar", value);
  }

  static String accentFont = "default";
  static String getAccentFont() {
    if (prefs != null) return prefs.getString("accentFont");
    return null;
  }

  static Future<void> setAccentFont(String value) async {
    accentFont = value;
    await prefs.setString("accentFont", value);
  }
}
