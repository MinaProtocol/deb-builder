open Async
open Core
open Misc
open Templates

type debsig_verify =
  { pollicies_dir : string option
  ; keyrings_dir : string option
  ; debian_package_to_verify : string
  }

let debsig_commad ~(spec : debsig_verify) =
  Process.create ~prog:"debsig-verify"
    ~args:
      ( ( match spec.pollicies_dir with
        | None ->
            []
        | Some policies_dir ->
            [ "--policies-dir"; policies_dir ] )
      @ ( match spec.keyrings_dir with
        | None ->
            []
        | Some keyrings_dir ->
            [ "--keyrings-dir"; keyrings_dir ] )
      @ [ "--debug"; spec.debian_package_to_verify ] )
    ()

let build_policy_file ~(input : Templates.policy_file_input) ~output_file =
  let result = Templates.format_policy_file ~input in
  Out_channel.write_all output_file ~data:result

(* Presetup for debsig-verify.
   We need to create a directory containing the key and a policy file.
   Structure of such directory is as follows:
     key_id/
       key.gpg
       policy.pol
   Then policy file refers to the key filename.
*)
let build_verification_resources ~temp_dir ~key_id =
  let key_id_dir = Filename.concat temp_dir key_id in
  let key_filename = "key.gpg" in
  let dest_key = Filename.concat key_id_dir key_filename in
  FileUtil.mkdir key_id_dir ;
  let policy_file = Filename.concat key_id_dir "policy.pol" in
  let input : Templates.policy_file_input =
    { key_filename; key_id; description = "deb" }
  in
  build_policy_file ~input ~output_file:policy_file ;
  Log.Global.debug "Temporary policy file created at %s" policy_file ;
  dest_key

let verify ~debian_package_to_verify ~(public_key_file : string option) =
  let open Deferred.Or_error.Let_syntax in
  let%bind () = check_command_exists "debsig-verify" in
  let%bind () = check_command_exists "curl" in
  let%bind () = check_file_exists debian_package_to_verify in

  let temp_dir = Filename_unix.temp_dir "debsig_verify" "" in
  let%bind key_id = Viewer.signature debian_package_to_verify in
  let dest_key = build_verification_resources ~temp_dir ~key_id in

  let%bind process =
    match public_key_file with
    | None ->
        Log.Global.debug
          "No public key file provided. Key should reside in \
           /usr/share/debsig/keyring/[key_id]/key.gpg" ;
        debsig_commad
          ~spec:
            { pollicies_dir = Some temp_dir
            ; keyrings_dir = None
            ; debian_package_to_verify
            }
    | Some public_key_file ->
        let%bind public_key_file =
          if
            String.is_prefix public_key_file ~prefix:"http://"
            || String.is_prefix public_key_file ~prefix:"https://"
          then
            let temp_file = Filename.concat temp_dir "downloaded_key.gpg" in
            match%bind.Deferred
              download_file ~url:public_key_file temp_file
            with
            | Ok () ->
                Log.Global.debug "Downloaded public key file from URL to %s"
                  temp_file ;
                return temp_file
            | Error _ ->
                Deferred.Or_error.errorf
                  "Failed to download public key file from URL %s"
                  public_key_file
          else return public_key_file
        in

        Log.Global.debug
          "Public key file provided. Assuming policy and key resides in %s"
          public_key_file ;

        FileUtil.cp [ public_key_file ] dest_key ;
        Log.Global.debug "Copied public key file to %s" dest_key ;
        debsig_commad
          ~spec:
            { pollicies_dir = Some temp_dir
            ; keyrings_dir = Some temp_dir
            ; debian_package_to_verify
            }
  in

  let%bind.Deferred output = Process.collect_output_and_wait process in
  match output.exit_status with
  | Ok () ->
      return ()
  | Error _ ->
      Deferred.Or_error.errorf "Failed to verify debian package %s. %s"
        debian_package_to_verify output.stdout
