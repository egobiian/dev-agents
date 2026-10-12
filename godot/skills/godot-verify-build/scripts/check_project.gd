## Loads every script, scene, resource and shader in a Godot project and fails
## when the engine reports an error while loading any of them.
##
## Usage:
##   godot --headless --path <project> --script <absolute path to this file> [-- options]
##
## Options, after a `--` separator:
##   --skip <res://path>  Leave a directory or a file out. Repeatable.
##   --help               Print this help and exit.
##
## Hidden folders (`.godot` among them) and folders holding a `.gdignore` are
## never read. C# scripts are not checked: their own build does that.
##
## Exit codes:
##   0  every file loaded without an error
##   1  at least one file reported an error
##   2  bad arguments
##
## The last line printed always starts with `check_project:`. A run without that
## line checked nothing, whatever its exit code.
##
## Needs Godot 4.5 or later, for the Logger class.
extends SceneTree

const CHECKED_EXTENSIONS: PackedStringArray = ["gd", "gdshader", "tscn", "scn", "tres", "res"]
const MAX_MESSAGES_PER_FILE: int = 5
const MAX_FILES_LISTED: int = 50
const USAGE: String = """Usage: godot --headless --path <project> --script <this file> [-- options]

Loads every script, scene, resource and shader in the project and fails on any
error the engine reports while loading them.

Options, after a `--` separator:
  --skip <res://path>  Leave a directory or a file out. Repeatable.
  --help               Print this help and exit.

Exit codes: 0 clean, 1 at least one file reported an error, 2 bad arguments."""


class LoadLogger extends Logger:
	var errors: PackedStringArray = []
	var warnings: PackedStringArray = []
	var _mutex: Mutex = Mutex.new()

	# The engine may call this from any thread.
	func _log_error(
			_function: String,
			file: String,
			line: int,
			code: String,
			rationale: String,
			_editor_notify: bool,
			error_type: int,
			_script_backtraces: Array[ScriptBacktrace],
	) -> void:
		var message: String = rationale if not rationale.is_empty() else code
		# Script and resource errors point at project files; the rest point at
		# engine source, which says nothing useful here.
		if file.begins_with("res://"):
			message = "%s (%s:%d)" % [message, file, line]
		_mutex.lock()
		if error_type == Logger.ERROR_TYPE_WARNING:
			warnings.append(message)
		else:
			errors.append(message)
		_mutex.unlock()

	func take() -> Array[PackedStringArray]:
		_mutex.lock()
		var taken: Array[PackedStringArray] = [errors.duplicate(), warnings.duplicate()]
		errors.clear()
		warnings.clear()
		_mutex.unlock()
		return taken


func _initialize() -> void:
	var skipped: PackedStringArray = []
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = 0
	while index < args.size():
		match args[index]:
			"--help", "-h":
				print(USAGE)
				quit(0)
				return
			"--skip":
				index += 1
				if index >= args.size() or not args[index].begins_with("res://"):
					printerr("Error: --skip needs a path that starts with res://, such as res://addons.")
					quit(2)
					return
				skipped.append(args[index].trim_suffix("/"))
			_:
				printerr("Error: unknown option \"%s\". Options: --skip <res://path>, --help." % args[index])
				quit(2)
				return
		index += 1

	var paths: PackedStringArray = []
	_collect("res://", skipped, paths)
	paths.sort()

	var logger: LoadLogger = LoadLogger.new()
	OS.add_logger(logger)
	var failed: Dictionary[String, PackedStringArray] = {}
	var warned: Dictionary[String, PackedStringArray] = {}
	for path: String in paths:
		var resource: Resource = ResourceLoader.load(path)
		if resource is Shader:
			# Loading a shader does not compile it. Asking for its uniforms does.
			(resource as Shader).get_shader_uniform_list()
		var taken: Array[PackedStringArray] = logger.take()
		if resource == null and taken[0].is_empty():
			taken[0].append("The file did not load, and the engine gave no reason.")
		if not taken[0].is_empty():
			failed[path] = taken[0]
		elif not taken[1].is_empty():
			warned[path] = taken[1]
	OS.remove_logger(logger)

	_report("FAIL", failed)
	_report("WARN", warned)
	print("check_project: %d files checked, %d failed, %d with warnings" % [
		paths.size(),
		failed.size(),
		warned.size(),
	])
	quit(1 if not failed.is_empty() else 0)


func _collect(directory: String, skipped: PackedStringArray, paths: PackedStringArray) -> void:
	if directory.trim_suffix("/") in skipped:
		return
	var dir: DirAccess = DirAccess.open(directory)
	if dir == null or dir.file_exists(".gdignore"):
		return
	# Hidden entries are left out by default, which keeps `.godot` out.
	for subdirectory: String in dir.get_directories():
		_collect(directory.path_join(subdirectory), skipped, paths)
	for file: String in dir.get_files():
		var path: String = directory.path_join(file)
		if file.get_extension() in CHECKED_EXTENSIONS and path not in skipped:
			paths.append(path)


func _report(label: String, files: Dictionary[String, PackedStringArray]) -> void:
	var listed: int = 0
	for path: String in files:
		if listed == MAX_FILES_LISTED:
			print("... and %d more" % (files.size() - listed))
			break
		print("%s %s" % [label, path])
		var messages: PackedStringArray = files[path]
		for message_index: int in mini(messages.size(), MAX_MESSAGES_PER_FILE):
			print("  %s" % messages[message_index])
		if messages.size() > MAX_MESSAGES_PER_FILE:
			print("  ... and %d more" % (messages.size() - MAX_MESSAGES_PER_FILE))
		listed += 1
