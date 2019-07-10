import 'dart:io';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

final flutterDir = Platform.environment['FLUTTER_ROOT'];
final pubCacheDirPath = Platform.environment['PUB_CACHE'];

main(List<String> args) async {
  try {
    if (flutterDir == null) {
      print('FLUTTER_ROOT is not set.');
      return 1;
    } else if (pubCacheDirPath == null) {
      print('PUB_CACHE is not set.');
      return 2;
    }
    final projectRoot = args.length >= 2 ? args[1] : await findProjectRoot();
    final outputFilePath = args.length >= 1 ? args[0] : path.join(projectRoot, 'lib', 'oss_licenses.dart');
    final licenses = await generateLicenseFile(projectRoot: projectRoot);
    await File(outputFilePath).writeAsString(licenses);
    return 0;
  } catch (e) {
    print(e);
    return 3;
  }
}

Future<String> generateLicenseFile({@required String projectRoot}) async {
  final deps = loadYaml(await File(path.join(projectRoot, 'pubspec.yaml')).readAsString())['dependencies'].keys;
  final pubspec = loadYaml(await File(path.join(projectRoot, 'pubspec.lock')).readAsString());

  final packages = pubspec['packages'] as Map<dynamic, dynamic>;
  var licenses = '''// This file is automatically generated by flutter_oss_licenses package.
// See https://github.com/espresso3389/flutter_oss_licenses for more.
Map<String, String> oss_licenses = {\n''';

  licenses += await loadLicense(
    name: 'Flutter',
    licenseFilePath: path.join(flutterDir, 'LICENSE'),
    defaultLicenseText: '');

  for (final name in deps) {
    final package = packages[name];
    if (package is! Map<dynamic, dynamic>)
      continue;
    final packPath = packagePath(package);
    if (packPath == null)
      continue;
    licenses += await loadLicense(
      name: name,
      licenseFilePath: path.join(pubCacheDirPath, packPath, 'LICENSE'),
      defaultLicenseText: '');
  }
  licenses += '};\n';

  return licenses;
}

Future<String> loadLicense({String name, String licenseFilePath, String defaultLicenseText}) async {
    String license = defaultLicenseText;
    try {
      license = await File(licenseFilePath).readAsString();
    } catch (e) {
      // ignore
    }
    return '//\n// $name\n//\n\'$name\': \'\'\'$license\'\'\',\n';
}

String packagePath(Map<dynamic, dynamic> package) {
  final source = package['source'];
  final descs = package['description'];
  if (source == 'hosted') {
    final host = removePrefix(descs['url']);
    final name = descs['name'];
    final version = package['version'];
    return 'hosted/$host/$name-$version';
  } else if (source == 'git') {
    final repo = gitRepoName(descs['url']);
    final commit = descs['resolved-ref'];
    return 'git/$repo-$commit';
  } else {
    return null;
  }
}

String removePrefix(String url) {
  if (url.startsWith('https://')) return url.substring(8);
  if (url.startsWith('http://')) return url.substring(7); // are there any?
  return url;
}

String gitRepoName(String url) {
  final name = url.substring(url.lastIndexOf('/') + 1);
  return name.endsWith('.git') ? name.substring(0, name.length - 4) : name;
}

Future<String> findProjectRoot({Directory from}) async {
  from = from ?? Directory.current;
  if (await File(path.join(from.path, 'pubspec.yaml')).exists())
    return from.path;
  return findProjectRoot(from: from.parent);
}
