open Core
open Async
open Dolog

let sign ~debian_package_to_sign ~signing_key_id =
  let open Deferred.Or_error.Let_syntax in
  let%bind () = Misc.check_command_exists "debsigs" in
  let%bind () = Misc.check_file_exists debian_package_to_sign in

  let () = Log.info "Signing package %s ...\n" debian_package_to_sign in

  let%bind process =
    Process.create ~prog:"debsigs"
      ~args:[ "--sign=origin"; "-k"; signing_key_id; debian_package_to_sign ]
      ()
  in
  let%bind.Deferred output = Process.collect_output_and_wait process in

  let%bind () =
    match output.exit_status with
    | Ok () ->
        return ()
    | Error _ ->
        Log.error "Failed to sign package %s. Stdout: %s , Stderr: %s."
          debian_package_to_sign output.stdout output.stderr ;
        Deferred.Or_error.errorf "Failed to sign debian package %s"
          debian_package_to_sign
  in

  Log.info "Package %s signed successfully using key %s \n"
    debian_package_to_sign signing_key_id ;
  return ()
