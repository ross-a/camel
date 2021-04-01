package reloader_thread

import "core:thread"
import "core:fmt"
import "core:strings"
import "core:sys/win32"

Recompile_Proc :: #type proc() -> bool;

watcher_thread_proc :: proc(^thread.Thread) {
  //fmt.println("watching for changes in", _directory_to_watch);

  watch_subtree:win32.Bool : true;
  filter:u32 = win32.FILE_NOTIFY_CHANGE_LAST_WRITE;
  FALSE:win32.Bool : false;

  handle := win32.find_first_change_notification_a(_directory_to_watch, watch_subtree, filter);
  if handle == win32.INVALID_HANDLE {
    fmt.eprintln("FindFirstChangeNotification failed");
    return;
  }

  next_timeout_ms:u32 = win32.INFINITE;
  did_get_change := false;

  for {
    wait_status := win32.wait_for_single_object(handle, next_timeout_ms);

    switch wait_status {
    case win32.WAIT_OBJECT_0:
      // when we get a file change notification, it's often immediately followed by another one.
      // so we'll lower our timeout and use that as a signal to actually recompile, to coalesce
      // multiple updates into one.
      next_timeout_ms = 150;
      did_get_change = true;
    case win32.WAIT_TIMEOUT:
      if !did_get_change do panic("error: infinite timeout triggered");

      // actually recompile the game.dll
      did_get_change = false;
      next_timeout_ms = win32.INFINITE;
			if ok := _recompile_proc(); !ok {
				fmt.println("result:", ok);
			}
      case:
      fmt.eprintln("unhandled wait_status", wait_status);
      return;
    }

    if win32.find_next_change_notification(handle) == FALSE {
      fmt.eprintln("error in find_next_change_notification");
      return;
    }
  }

  return;
}

_recompile_proc: Recompile_Proc;
_directory_to_watch: cstring;

start :: proc(recompile_proc: Recompile_Proc, directory_to_watch: string) -> ^thread.Thread {
  assert(_recompile_proc == nil, "only one reloader thread can exist at once");

  _recompile_proc = recompile_proc;
  _directory_to_watch = strings.clone_to_cstring(directory_to_watch);

  watcher_thread := thread.create(watcher_thread_proc);
  thread.start(watcher_thread);
  return watcher_thread;
}

finish :: proc(watcher_thread: ^thread.Thread) {
  // TODO: signal to thread it should exit gracefully with CreateEvent like https://docs.microsoft.com/en-us/windows/desktop/sync/using-event-objects
}
