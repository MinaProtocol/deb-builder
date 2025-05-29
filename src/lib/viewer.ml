open Async
open Misc

let signature debian =
  let open Deferred.Or_error.Let_syntax in
  let%bind () = check_command_exists "debsig-verify" in
  let%bind () = check_file_exists debian in

  let%bind.Deferred process =
    Process.create_exn ~prog:"debsig-verify"
      ~args:[ "--policies-dir"; "fake"; debian ]
      ()
  in
  let%bind.Deferred output = Process.collect_output_and_wait process in
  match output.exit_status with
  | Ok _ ->
      let msg =
        Printf.sprintf
          "Cannot look up package signature due to internal error. Expecting \
           command to error out \n\
          \ %s" output.stdout
      in
      Log.Global.error "%s \n" msg ;
      Deferred.Or_error.error_string msg
  | Error _ -> (
      let pattern = Str.regexp ".*fake/\\([A-Z0-9]+\\):.*" in
      match Str.string_match pattern output.stdout 0 with
      | true ->
          let extracted_id = Str.matched_group 1 output.stdout in
          Deferred.Or_error.return extracted_id
      | false ->
          Deferred.Or_error.error_string "Failed to extract ID from output" )
