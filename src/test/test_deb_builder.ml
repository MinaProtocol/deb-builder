open Alcotest
open Core
open Async

let import_key path expected_key_id =
  let%bind output =
    Process.run_exn ~prog:"gpg"
      ~args:
        [ "--import"; "--import-options"; "import-show"; "--with-colons"; path ]
      ()
  in
  Async.printf "GPG output: %s\n%!" output ;
  
  (* Extract the key ID from the GPG output *)
  (* The regex matches the line with the key ID in the GPG output *)
  (* Example line: sec:u:3072:1:40C7DD112EDB4CA9:... *)
  let regex = Re2.create_exn "sec:u:3072:1:(\\w+):.*" in
  let key_id =
    match Re2.find_submatches regex output with
    | Ok [| _; Some id |] ->
        id
    | _ ->
        failwith "Failed to extract key ID from GPG output. "
  in
  Alcotest.(check string) "Key ID" key_id expected_key_id ;
  return key_id

let end_to_end_build_and_sign () =
  let open Deferred.Let_syntax in
  let cwd = Sys.getenv "PWD" |> Option.value_exn in
  Async.printf "Current working directory: %s\n%!" cwd ;
  let build_dir = Filename.concat cwd "res/build_dir" in
  let secret_key = Filename.concat cwd "res/secret-key.gpg" in
  let public_key = Filename.concat cwd "res/public-key.gpg" in
  let expected_key_id = "40C7DD112EDB4CA9" in

  let cmd_input =
    Deb_builder_lib.Builder.cmd_input_default ~build_dir
      ~package_name:"example-app" ~package_description:"example app"
      ~version:"1.0.0" ~output_dir:"./output" ~codename:"focal" ~suite:"stable"
      ~defaults_file:(Some (Filename.concat cwd "res/defaults.json"))
  in
  let input =
    Deb_builder_lib.Builder.evaluate_and_validate_inputs cmd_input
    |> Or_error.ok_exn
  in
  let%bind () =
    Deb_builder_lib.Builder.build_debian_package ~input
    |> Deferred.Or_error.ok_exn
  in
  let debian_package =
    Filename.concat input.output_dir
      (input.package_name ^ "_" ^ input.version ^ ".deb")
  in
  let%bind key_id = import_key secret_key expected_key_id in
  let%bind () =
    Deb_builder_lib.Signer.sign ~debian_package_to_sign:debian_package
      ~signing_key_id:key_id
    |> Deferred.Or_error.ok_exn
  in
  let%bind () =
    Deb_builder_lib.Signature_verifier.verify
      ~debian_package_to_verify:debian_package ~public_key_file:(Some public_key)
    |> Deferred.Or_error.ok_exn
  in
  return ()

let () =
  
      run "Test Suite"
        [ ( "Build And Sign"
          , [ test_case "Build debian and verify signature" `Quick
               (fun () -> Async.Thread_safe.block_on_async_exn (fun () -> end_to_end_build_and_sign ()))
            ] )
        ] 
