open Core
open Async
open Dolog

type input =
  { build_dir : string
  ; output_dir : string
  ; clean : bool
  ; package_name : string
  ; version : string
  ; vendor : string
  ; package_authors : string
  ; package_maintainer : string
  ; package_description : string
  ; package_section : string
  ; package_priority : string
  ; package_homepage : string
  ; package_installed_size : string
  ; package_source : string
  ; architecture : string
  ; suite : string
  ; codename : string
  ; depends : string list option
  ; suggested_depends : string list option
  ; recommended_depends : string list option
  ; pre_depends : string list option
  ; conflicts : string list option
  ; replaces : string list option
  ; provides : string list option
  ; license : string
  ; githash : string
  ; buildurl : string
  }

let or_from_defaults_file opt default_opt ~defaults_file ~name =
  match opt with
  | None ->
      Result.of_option default_opt
        ~error:
          ( ( match defaults_file with
            | None ->
                Printf.sprintf "%s not defined in cli" name
            | Some defaults_file ->
                Printf.sprintf "%s not defined in defaults file (%s) nor in cli"
                  name defaults_file )
          |> Error.of_string )
  | Some value ->
      Ok value

let evaluate_and_validate_inputs ~build_dir ~output_dir ?(clean = false)
    ?defaults_file ~package_name ~version ?vendor ?package_authors
    ?package_maintainer ~package_description ?package_section ?package_priority
    ?package_homepage ?package_installed_size ?package_source ?architecture
    ~suite ~codename ?depends ?suggested_depends ?recommended_depends
    ?pre_depends ?conflicts ?replaces ?provides ?license ?githash ?buildurl () =
  let open Or_error.Let_syntax in
  let%bind defaults = Defaults.load defaults_file in

  let maybe_split = Option.map ~f:(String.split ~on:',') in

  let depends =
    Option.merge (maybe_split depends) defaults.depends ~f:(fun a b -> a @ b)
  in
  let suggested_depends =
    Option.merge (maybe_split suggested_depends) defaults.suggested_depends
      ~f:(fun a b -> a @ b )
  in
  let recommended_depends =
    Option.merge (maybe_split recommended_depends) defaults.recommended_depends
      ~f:(fun a b -> a @ b )
  in
  let pre_depends =
    Option.merge (maybe_split pre_depends) defaults.pre_depends ~f:(fun a b ->
        a @ b )
  in
  let conflicts =
    Option.merge (maybe_split conflicts) defaults.conflicts ~f:(fun a b ->
        a @ b )
  in
  let replaces =
    Option.merge (maybe_split replaces) defaults.replaces ~f:(fun a b -> a @ b)
  in
  let provides =
    Option.merge (maybe_split provides) defaults.provides ~f:(fun a b -> a @ b)
  in

  let%bind vendor =
    or_from_defaults_file vendor defaults.vendor ~defaults_file ~name:"vendor"
  in
  let%bind package_authors =
    or_from_defaults_file package_authors defaults.package_authors
      ~defaults_file ~name:"package_authors"
  in
  let%bind package_maintainer =
    or_from_defaults_file package_maintainer defaults.package_maintainer
      ~defaults_file ~name:"package_maintainer"
  in
  let%bind package_section =
    or_from_defaults_file package_section defaults.package_section
      ~defaults_file ~name:"package_section"
  in
  let%bind package_priority =
    or_from_defaults_file package_priority defaults.package_priority
      ~defaults_file ~name:"package_priority"
  in
  let%bind package_homepage =
    or_from_defaults_file package_homepage defaults.package_homepage
      ~defaults_file ~name:"package_homepage"
  in
  let%bind package_installed_size =
    or_from_defaults_file package_installed_size defaults.package_installed_size
      ~defaults_file ~name:"package_installed_size"
  in
  let%bind package_source =
    or_from_defaults_file package_source defaults.package_source ~defaults_file
      ~name:"package_source"
  in
  let%bind architecture =
    or_from_defaults_file architecture defaults.architecture ~defaults_file
      ~name:"architecture"
  in
  let%bind license =
    or_from_defaults_file license defaults.license ~defaults_file
      ~name:"license"
  in
  let%bind githash =
    or_from_defaults_file githash defaults.githash ~defaults_file
      ~name:"githash"
  in
  let%bind buildurl =
    or_from_defaults_file buildurl defaults.buildurl ~defaults_file
      ~name:"buildurl"
  in

  return
    { build_dir
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
    ; buildurl
    }

let to_control_input input : Templates.debian_control =
  { package_name = input.package_name
  ; version = input.version
  ; vendor = input.vendor
  ; package_authors = input.package_authors
  ; package_maintainer = input.package_maintainer
  ; package_description = input.package_description
  ; package_section = input.package_section
  ; package_priority = input.package_priority
  ; package_homepage = input.package_homepage
  ; package_installed_size = input.package_installed_size
  ; package_source = input.package_source
  ; architecture = input.architecture
  ; suite = input.suite
  ; codename = input.codename
  ; depends = input.depends
  ; suggested_depends = input.suggested_depends
  ; recommended_depends = input.recommended_depends
  ; pre_depends = input.pre_depends
  ; conflicts = input.conflicts
  ; replaces = input.replaces
  ; provides = input.provides
  ; license = input.license
  ; githash = input.githash
  ; buildurl = input.buildurl
  }

let build_debian_package ~(input : input) =
  let result = Templates.format_control_file (to_control_input input) in
  let open Async.Deferred.Or_error.Let_syntax in
  let%bind.Deferred dir_contents = Sys.readdir input.build_dir in

  if dir_contents |> Array.is_empty then
    Deferred.Or_error.errorf "Debian build directory is empty %s"
      input.build_dir
  else
    let control_file_dir = FilePath.concat input.build_dir "DEBIAN" in
    let control_file = FilePath.concat control_file_dir "control" in

    let%bind.Deferred () = Unix.mkdir ~p:() control_file in
    Out_channel.write_all control_file ~data:result ;

    Log.info "Building debian package..." ;

    let%bind.Deferred () = Unix.mkdir ~p:() input.output_dir in

    let debian_name = input.package_name ^ "_" ^ input.version ^ ".deb" in

    let debian_output = input.output_dir ^ "/" ^ debian_name in
    let%bind process =
      Process.create ~prog:"fakeroot"
        ~args:[ "dpkg-deb"; "--build"; input.build_dir; debian_output ]
        ()
    in
    let%bind.Deferred output = Process.collect_output_and_wait process in
    match output.exit_status with
    | Ok () ->
        Log.info "Package %s built at %s\n" debian_name input.output_dir ;
        if input.clean then (
          Log.info "Cleaning up...\n" ;
          FileUtil.rm ~recurse:true [ input.build_dir ] ;
          return () )
        else return ()
    | Error _ ->
        Log.error "Failed to build package %s. Stdout: %s , Stderr: %s"
          debian_name output.stdout output.stderr ;
        Deferred.Or_error.errorf "Failed to build debian package %s" debian_name
