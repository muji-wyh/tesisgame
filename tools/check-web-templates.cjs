const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const childProcess = require('node:child_process');

const MARKER = 'WEB_TEMPLATE_PREFLIGHT:';
// A disposable editor project asks Godot for its own data path, including
// portable installations. The game project is never imported by this probe.
const PROBE = `@tool
extends EditorPlugin

func _enter_tree() -> void:
\t_report.call_deferred()

func _report() -> void:
\tawait get_tree().process_frame
\twhile EditorInterface.get_resource_filesystem().is_scanning():
\t\tawait get_tree().process_frame
\tvar request = JSON.parse_string(FileAccess.get_file_as_string("res://request.json"))
\tvar presets = ConfigFile.new()
\tif presets.load(request["presets_path"]) != OK:
\t\t_fail("Cannot read export_presets.cfg.")
\t\treturn
\tvar selected = ""
\tfor section in presets.get_sections():
\t\tif section.begins_with("preset.") and not section.ends_with(".options") and presets.get_value(section, "name", "") == "Web":
\t\t\tif selected != "":
\t\t\t\t_fail("The Web export preset must have a unique name.")
\t\t\t\treturn
\t\t\tselected = section
\tif selected == "" or presets.get_value(selected, "platform", "") != "Web":
\t\t_fail("A Web platform export preset named Web is required.")
\t\treturn
\tvar options = selected + ".options"
\tprint("${MARKER}" + JSON.stringify({
\t\t"version": Engine.get_version_info(),
\t\t"data_dir": EditorInterface.get_editor_paths().get_data_dir(),
\t\t"threads": presets.get_value(options, "variant/thread_support", false),
\t\t"extensions": presets.get_value(options, "variant/extensions_support", false),
\t\t"debug": presets.get_value(options, "custom_template/debug", ""),
\t\t"release": presets.get_value(options, "custom_template/release", "")
\t}))
\tget_tree().quit()

func _fail(message: String) -> void:
\tprint("${MARKER}" + JSON.stringify({"error": message}))
\tget_tree().quit(1)
`;

function queryEditor(rootDir) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'tesisgame-web-templates-'));
  try {
    const addon = path.join(directory, 'addons', 'template-probe');
    fs.mkdirSync(addon, { recursive: true });
    fs.writeFileSync(path.join(directory, 'project.godot'), 'config_version=5\n\n[application]\nconfig/name="Web template preflight"\n\n[editor_plugins]\nenabled=PackedStringArray("res://addons/template-probe/plugin.cfg")\n');
    fs.writeFileSync(path.join(addon, 'plugin.cfg'), '[plugin]\nname="Web template preflight"\nauthor=""\nversion="1"\nscript="plugin.gd"\n');
    fs.writeFileSync(path.join(addon, 'plugin.gd'), PROBE);
    fs.writeFileSync(path.join(directory, 'request.json'), JSON.stringify({ presets_path: path.join(rootDir, 'export_presets.cfg') }));
    const selected = process.env.GODOT_BIN || 'godot';
    const binary = /[/\\]/.test(selected) ? path.resolve(rootDir, selected) : selected;
    const result = childProcess.spawnSync(binary, ['--headless', '--editor', '--path', directory, '--quit-after', '600'], {
      cwd: directory, encoding: 'utf8', windowsHide: true, timeout: 30000, maxBuffer: 1024 * 1024
    });
    if (result.error) throw new Error(`Could not inspect Godot Web templates: ${result.error.message}`);
    const output = `${result.stdout || ''}${result.stderr || ''}`;
    const lines = (result.stdout || '').split(/\r?\n/).filter(line => line.startsWith(MARKER));
    let info;
    try { if (lines.length === 1) info = JSON.parse(lines[0].slice(MARKER.length)); } catch {}
    if (info?.error) throw new Error(`Godot Web template preflight: ${info.error}`);
    if (result.status !== 0 || !info || /(?:^|\n)(?:SCRIPT )?ERROR:/m.test(output)) {
      throw new Error(`Could not inspect Godot Web templates (exit ${result.status}). ${output.trim()}`);
    }
    return info;
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
}

function checkWebTemplates({ rootDir = path.resolve(__dirname, '..') } = {}) {
  rootDir = path.resolve(rootDir);
  const info = queryEditor(rootDir), version = info.version;
  if (!version || !['major', 'minor', 'patch'].every(key => Number.isSafeInteger(version[key]) && version[key] >= 0) ||
      typeof version.status !== 'string' || !/^[a-zA-Z0-9_-]+$/.test(version.status) || typeof info.data_dir !== 'string' || !path.isAbsolute(info.data_dir) ||
      typeof info.threads !== 'boolean' || typeof info.extensions !== 'boolean' ||
      typeof info.debug !== 'string' || typeof info.release !== 'string') {
    throw new Error('Godot returned invalid Web template settings.');
  }
  const templateVersion = `${version.major}.${version.minor}${version.patch ? `.${version.patch}` : ''}.${version.status}`;
  const templateDirectory = path.join(info.data_dir, 'export_templates', templateVersion);
  const stem = `web${info.extensions ? '_dlink' : ''}${info.threads ? '' : '_nothreads'}`;
  const templates = {};
  const missing = [];
  for (const kind of ['debug', 'release']) {
    const custom = info[kind];
    if (custom.startsWith('user://')) throw new Error(`Web custom_template/${kind} must use a filesystem or res:// path.`);
    const filename = custom ? path.resolve(rootDir, custom.replace(/^res:\/\//, '')) : path.join(templateDirectory, `${stem}_${kind}.zip`);
    templates[kind] = filename;
    let stat;
    try { stat = fs.statSync(filename); } catch (error) { if (!['ENOENT', 'ENOTDIR'].includes(error.code)) throw error; }
    if (!stat?.isFile() || stat.size === 0) missing.push(filename);
  }
  if (missing.length) {
    throw new Error(`Missing or empty Web export templates for Godot ${templateVersion}:\n${missing.map(file => `- ${file}`).join('\n')}\nInstall the matching ${templateVersion} export templates through Godot's Manage Export Templates, or correct the Web preset's custom_template/debug and custom_template/release paths. Then run npm run build:web. Templates from another engine version cannot replace this installation.`);
  }
  return { version: templateVersion, templateDirectory, templates };
}

module.exports = { checkWebTemplates };

if (require.main === module) {
  try {
    const result = checkWebTemplates();
    console.log(`Verified Web export templates for Godot ${result.version}:\n${result.templates.debug}\n${result.templates.release}`);
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
