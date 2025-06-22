open Async
open Dolog

let build =
  let open Command.Let_syntax in
  Command.async ~summary:"Build debian package for given arguments"
    (let%map_open build_dir =
       flag "--debian" ~aliases:[ "build-dir" ]
         ~doc:
           "Path Path to the directory where the debian package artifacts are \
            stored"
         (required string)
     and output_dir =
       flag "--output-dir" ~aliases:[ "output-dir" ]
         ~doc:
           "Path Path to the directory where the output debian package will be \
            stored"
         (required string)
     and clean =
       flag "--clean" ~aliases:[ "clean" ]
         ~doc:
           "Boolean If true, clean the build directory before building the \
            debian package"
         no_arg
     and defaults_file =
       flag "--defaults-file" ~aliases:[ "defaults-file" ]
         ~doc:
           "Path Path to the json file which contains defaults values for the \
            debian package\n\
           \         like version, maintainer, authors, license, homepage etc. \
            Basically everything apart from:\n\
           \         package name, dependencies and description"
         (optional string)
     and package_name =
       flag "--package-name" ~aliases:[ "package-name" ]
         ~doc:"String Name of the debian package" (required string)
     and version =
       flag "--version" ~aliases:[ "version" ]
         ~doc:"String Version of the debian package" (required string)
     and depends =
       flag "--depends" ~aliases:[ "depends" ]
         ~doc:"String Dependencies of the debian package" (optional string)
     and suggested_depends =
       flag "--suggested-depends" ~aliases:[ "suggested-depends" ]
         ~doc:"String Suggested dependencies of the debian package"
         (optional string)
     and recommended_depends =
       flag "--recommended-depends" ~aliases:[ "recommended-depends" ]
         ~doc:"String Recommended dependencies of the debian package"
         (optional string)
     and pre_depends =
       flag "--pre-depends" ~aliases:[ "pre-depends" ]
         ~doc:"String Pre dependencies of the debian package" (optional string)
     and conflicts =
       flag "--conflicts" ~aliases:[ "conflicts" ]
         ~doc:"String Conflicts of the debian package" (optional string)
     and replaces =
       flag "--replaces" ~aliases:[ "replaces" ]
         ~doc:"String Replaces of the debian package" (optional string)
     and provides =
       flag "--provides" ~aliases:[ "provides" ]
         ~doc:"String Provides of the debian package" (optional string)
     and vendor =
       flag "--vendor" ~aliases:[ "vendor" ]
         ~doc:"String Vendor of the debian package" (optional string)
     and package_authors =
       flag "--authors" ~aliases:[ "authors" ]
         ~doc:"String Authors of the debian package" (optional string)
     and package_maintainer =
       flag "--maintainer" ~aliases:[ "maintainer" ]
         ~doc:"String Maintainer of the debian package" (optional string)
     and package_description =
       flag "--description" ~aliases:[ "package-description" ]
         ~doc:"String Description of the debian package" (required string)
     and package_section =
       flag "--section" ~aliases:[ "section" ]
         ~doc:"String Section of the debian package" (optional string)
     and package_priority =
       flag "--priority" ~aliases:[ "priority" ]
         ~doc:"String Priority of the debian package" (optional string)
     and package_homepage =
       flag "--homepage" ~aliases:[ "homepage" ]
         ~doc:"String Homepage of the debian package" (optional string)
     and package_installed_size =
       flag "--installed-size" ~aliases:[ "installed-size" ]
         ~doc:"String Installed size of the debian package" (optional string)
     and package_source =
       flag "--source" ~aliases:[ "source" ]
         ~doc:"String Source of the debian package" (optional string)
     and architecture =
       flag "--architecture" ~aliases:[ "architecture" ]
         ~doc:"String Architecture of the debian package" (optional string)
     and suite =
       flag "--suite" ~aliases:[ "suite" ]
         ~doc:"String Suite of the debian package" (required string)
     and codename =
       flag "--codename" ~aliases:[ "codename" ]
         ~doc:"String Codename of the debian package" (required string)
     and license =
       flag "--license" ~aliases:[ "license" ]
         ~doc:"String License of the debian package" (optional string)
     and githash =
       flag "--githash" ~aliases:[ "githash" ]
         ~doc:"String Git hash of the debian package" (optional string)
     and buildurl =
       flag "--buildurl" ~aliases:[ "buildurl" ]
         ~doc:"String Build url of the debian package" (optional string)
     in
     fun () ->
       Log.set_log_level Log.DEBUG ;

       Log.set_output Stdlib.stdout ;
       Log.info "Building debian package for %s...\n" package_name ;
       let open Deferred.Let_syntax in
       let cmd_input: Deb_builder_lib.Builder.cmd_input =
         { defaults_file 
         ; build_dir
         ; output_dir
         ; clean
         ; package_name
         ; version
         ; vendor
         ; package_authors
         ; package_maintainer
         ; package_description
         ; package_section
         ; package_priority
         ; package_homepage
         ; package_installed_size
         ; package_source
         ; architecture
         ; suite
         ; codename
         ; depends
         ; suggested_depends
         ; recommended_depends
         ; pre_depends
         ; conflicts
         ; replaces
         ; provides
         ; license
         ; githash
         ; buildurl }
       in

       let%bind input =
         match
           Deb_builder_lib.Builder.evaluate_and_validate_inputs cmd_input
         with
         | Ok input ->
             return input
         | Error err ->
             Log.error "Validation phase failed: %s\n" (Core.Error.to_string_hum err) ;
             exit 1
       in
       match%bind Deb_builder_lib.Builder.build_debian_package ~input with
       | Ok _ ->
           Log.info "Debian package for %s built successfully\n" package_name ;
           return ()
       | Error err ->
           Log.error "Building debian package failed: %s\n"
             (Core.Error.to_string_hum err) ;
           exit 1 )

let verify_content =
  let open Command.Let_syntax in
  Command.async ~summary:"Build debian package for given arguments"
    (let%map_open deb =
       flag "--deb" ~aliases:[ "deb" ]
         ~doc:
           "Path Path to the directory where the debian package artifacts are \
            stored"
         (required string)
     and defaults_file =
       flag "--defaults-file" ~aliases:[ "defaults-file" ]
         ~doc:
           "Path Path to the json file which contains defaults values for the \
            debian package\n\
           \             like version, maintainer, authors, license, homepage \
            etc. Basically everything apart from:\n\
           \             package name, dependencies and description"
         (optional string)
     and depends =
       flag "--depends" ~aliases:[ "depends" ]
         ~doc:"String Dependencies of the debian package" (optional string)
     and suggested_depends =
       flag "--suggested-depends" ~aliases:[ "suggested-depends" ]
         ~doc:"String Suggested dependencies of the debian package"
         (optional string)
     and recommended_depends =
       flag "--recommended-depends" ~aliases:[ "recommended-depends" ]
         ~doc:"String Recommended dependencies of the debian package"
         (optional string)
     and pre_depends =
       flag "--pre-depends" ~aliases:[ "pre-depends" ]
         ~doc:"String Pre dependencies of the debian package" (optional string)
     and conflicts =
       flag "--conflicts" ~aliases:[ "conflicts" ]
         ~doc:"String Conflicts of the debian package" (optional string)
     and replaces =
       flag "--replaces" ~aliases:[ "replaces" ]
         ~doc:"String Replaces of the debian package" (optional string)
     and provides =
       flag "--provides" ~aliases:[ "provides" ]
         ~doc:"String Provides of the debian package" (optional string)
     and vendor =
       flag "--vendor" ~aliases:[ "vendor" ]
         ~doc:"String Vendor of the debian package" (optional string)
     and package_authors =
       flag "--authors" ~aliases:[ "authors" ]
         ~doc:"String Authors of the debian package" (optional string)
     and package_maintainer =
       flag "--maintainer" ~aliases:[ "maintainer" ]
         ~doc:"String Maintainer of the debian package" (optional string)
     and package_description =
       flag "--description" ~aliases:[ "package-description" ]
         ~doc:"String Description of the debian package" (optional string)
     and package_section =
       flag "--section" ~aliases:[ "section" ]
         ~doc:"String Section of the debian package" (optional string)
     and package_priority =
       flag "--priority" ~aliases:[ "priority" ]
         ~doc:"String Priority of the debian package" (optional string)
     and package_homepage =
       flag "--homepage" ~aliases:[ "homepage" ]
         ~doc:"String Homepage of the debian package" (optional string)
     and package_installed_size =
       flag "--installed-size" ~aliases:[ "installed-size" ]
         ~doc:"String Installed size of the debian package" (optional string)
     and package_source =
       flag "--source" ~aliases:[ "source" ]
         ~doc:"String Source of the debian package" (optional string)
     and architecture =
       flag "--architecture" ~aliases:[ "architecture" ]
         ~doc:"String Architecture of the debian package" (optional string)
     and suite =
       flag "--suite" ~aliases:[ "suite" ]
         ~doc:"String Suite of the debian package" (optional string)
     and codename =
       flag "--codename" ~aliases:[ "codename" ]
         ~doc:"String Codename of the debian package" (optional string)
     and license =
       flag "--license" ~aliases:[ "license" ]
         ~doc:"String License of the debian package" (optional string)
     and githash =
       flag "--githash" ~aliases:[ "githash" ]
         ~doc:"String Git hash of the debian package" (optional string)
     and buildurl =
       flag "--buildurl" ~aliases:[ "buildurl" ]
         ~doc:"String Build url of the debian package" (optional string)
     in
     fun () ->
       Log.set_log_level Log.DEBUG ;

       Log.set_output Stdlib.stdout ;
       Log.info "Verifying debian package %s...\n" deb ;
       let open Deferred.Let_syntax in
       match%bind
         Deb_builder_lib.Content_verifier.verify ~deb ~defaults_file ~vendor
           ~package_authors ~package_maintainer ~package_description
           ~package_section ~package_priority ~package_homepage
           ~package_installed_size ~package_source ~architecture ~suite
           ~codename ~depends ~suggested_depends ~recommended_depends
           ~pre_depends ~conflicts ~replaces ~provides ~license ~githash
           ~buildurl
       with
       | Ok () ->
           return ()
       | Error err ->
           Log.error "Verification failed due to : %s\n"
             (Core.Error.to_string_hum err) ;
           exit 1 )

let sign =
  let open Command.Let_syntax in
  Command.async ~summary:"Sign debian package for given arguments"
    (let%map_open debian_package_to_sign =
       flag "--deb" ~aliases:[ "deb" ]
         ~doc:
           "Path Path to the directory where the debian package artifacts are \
            stored"
         (required string)
     and signing_key_id =
       flag "--key" ~aliases:[ "key" ]
         ~doc:"Path Public key id to sign the debian package" (required string)
     in
     fun () ->
       Log.set_log_level Log.DEBUG ;
       Log.set_output Stdlib.stdout ;
       let open Deferred.Let_syntax in
       match%bind
         Deb_builder_lib.Signer.sign ~debian_package_to_sign ~signing_key_id
       with
       | Ok _ ->
           return ()
       | Error err ->
           Async.eprintf "Signing failed due to : %s\n"
             (Core.Error.to_string_hum err) ;
           exit 1 )

let verify_signature =
  let open Command.Let_syntax in
  Command.async ~summary:"Verify debian package signature"
    (let%map_open debian_package_to_verify = anon ("deb" %: string)
     and public_key_file =
       flag "--key" ~aliases:[ "key" ]
         ~doc:"Path Public key id to verify the debian package"
         (optional string)
     in
     fun () ->
       Log.set_log_level Log.DEBUG ;
       Log.set_output Stdlib.stdout ;
       let open Deferred.Let_syntax in
       match%bind
         Deb_builder_lib.Signature_verifier.verify ~debian_package_to_verify
           ~public_key_file
       with
       | Ok _ ->
           Async.printf "Signature verified successfully\n" ;
           return ()
       | Error err ->
           Async.eprintf "Signature verification failed due to : %s\n"
             (Core.Error.to_string_hum err) ;
           exit 1 )

let lookup_signature_key =
  let open Command.Let_syntax in
  Command.async ~summary:"Lookup debian package signature key id"
    (let%map_open debian_package_to_view = anon ("deb" %: string) in

     fun () ->
       Log.set_log_level Log.DEBUG ;
       Log.set_output Stdlib.stdout ;
       let open Deferred.Let_syntax in
       match%bind Deb_builder_lib.Viewer.signature debian_package_to_view with
       | Ok signature ->
           Async.printf "%s\n" signature ;
           return ()
       | Error err ->
           Async.eprintf "Signature lookup failed due to : %s\n"
             (Core.Error.to_string_hum err) ;
           exit 1 )

let verify =
  Command.group ~summary:"Verify details of debian"
    [ ("signature", verify_signature); ("content", verify_content) ]

let lookup =
  Command.group ~summary:"Look up details of debian"
    [ ("sign-key", lookup_signature_key) ]

let version = "0.0.1-alpha1"

(* Build info can be any string that describes the build environment or
   the builder itself. It can include information like the builder name,
   version, or any other relevant details. *)

let build_info = "Deb Builder"

let () =
  Command_unix.run ~version ~build_info
    (Command.group
       ~summary:"Generate public keys for sending batches of transactions"
       [ ("build", build)
       ; ("verify", verify)
       ; ("sign", sign)
       ; ("lookup", lookup)
       ] )
