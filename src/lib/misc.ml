open Async

let check_command_exists command =
  let%bind.Deferred exit_code =
    Sys.command (Printf.sprintf "command -v %s >/dev/null 2>&1" command)
  in
  if exit_code = 0 then Deferred.Or_error.ok_unit
  else
    Deferred.Or_error.error_string
      (Printf.sprintf
         "Required program '%s' is not installed or not in PATH. `sudo apt-get \
          install %s`"
         command command )

let check_file_exists file =
  match%bind.Deferred Sys.file_exists file with
  | `Yes ->
      Deferred.Or_error.ok_unit
  | `No | `Unknown ->
      Deferred.Or_error.error_string
        (Printf.sprintf "File (%s) does not exist or permission denied" file)

let download_file ~url file =
  let%bind.Deferred process =
    Process.create_exn ~prog:"curl" ~args:[ "-s"; "-o"; file; url ] ()
  in
  let%bind.Deferred output = Process.collect_output_and_wait process in
  match output.exit_status with
  | Ok () ->
      Deferred.Or_error.ok_unit
  | Error _ ->
      Deferred.Or_error.error_string
        (Printf.sprintf "Failed to download file %s" file)
